#!/usr/bin/env python3
"""
DeepSeek 余额 macOS 菜单栏应用
在状态栏实时显示 DeepSeek API 余额
"""

import os
import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path

import requests
import rumps
from AppKit import NSApplication, NSApplicationActivationPolicyAccessory

# ============================================================
# 路径配置
# ============================================================
APP_DIR = Path(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = APP_DIR / "config.json"
DATA_DIR = APP_DIR / "data"
DB_PATH = DATA_DIR / "balance_history.db"

DATA_DIR.mkdir(parents=True, exist_ok=True)


# ============================================================
# 配置管理
# ============================================================
def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)


def save_config(config):
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=4, ensure_ascii=False)


# ============================================================
# 数据库
# ============================================================
def init_db():
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS balance_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            total_balance REAL NOT NULL,
            granted_balance REAL NOT NULL,
            topped_up_balance REAL NOT NULL,
            is_available INTEGER NOT NULL
        )
    ''')
    conn.commit()
    conn.close()


def save_balance_record(total, granted, topped, is_available):
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute('''
        INSERT INTO balance_history
        (timestamp, total_balance, granted_balance, topped_up_balance, is_available)
        VALUES (?, ?, ?, ?, ?)
    ''', (now, total, granted, topped, 1 if is_available else 0))
    conn.commit()
    conn.close()


def get_today_usage():
    """今日使用量"""
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    today = datetime.now().strftime('%Y-%m-%d')
    cursor.execute('''
        SELECT total_balance FROM balance_history
        WHERE timestamp >= ? ORDER BY timestamp ASC LIMIT 1
    ''', (today + ' 00:00:00',))
    first = cursor.fetchone()
    cursor.execute('''
        SELECT total_balance FROM balance_history
        WHERE timestamp >= ? ORDER BY timestamp DESC LIMIT 1
    ''', (today + ' 00:00:00',))
    last = cursor.fetchone()
    conn.close()
    if first and last:
        return first[0] - last[0]
    return 0.0


# ============================================================
# DeepSeek API
# ============================================================
def fetch_balance(api_key, base_url):
    url = f"{base_url}/user/balance"
    headers = {
        'Accept': 'application/json',
        'Authorization': f'Bearer {api_key}'
    }
    try:
        resp = requests.get(url, headers=headers, timeout=15)
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.Timeout:
        raise Exception("请求超时，请检查网络")
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 401:
            raise Exception("API Key 无效，请在设置中更新")
        elif e.response.status_code == 429:
            raise Exception("请求过于频繁，请稍后重试")
        else:
            raise Exception(f"API 错误 (HTTP {e.response.status_code})")
    except requests.exceptions.ConnectionError:
        raise Exception("无法连接 DeepSeek 服务器")


# ============================================================
# 菜单栏应用
# ============================================================
class DeepSeekBalanceApp(rumps.App):
    def __init__(self):
        # 纯菜单栏应用，不显示 Dock 图标
        NSApplication.sharedApplication().setActivationPolicy_(NSApplicationActivationPolicyAccessory)

        # icon_path = str(APP_DIR / "icon.png")
        super().__init__(
            name="DeepSeekBalance",
            title="---",
            icon=str(APP_DIR / "icon.png"),
            quit_button=None
        )
        self.config = load_config()
        self.api_key = self.config.get('api_key', '')
        self.base_url = self.config.get('base_url', 'https://api.deepseek.com')
        self.poll_interval = self.config.get('poll_interval_minutes', 5) * 60

        self.current_balance = None
        self.is_loading = False

        init_db()
        self._build_menu()

        # 定时轮询
        self.timer = rumps.Timer(self._fetch_and_update, self.poll_interval)
        self.timer.start()

        # 首次立即加载
        self._fetch_and_update()

    def _build_menu(self):
        self.menu = [
            rumps.MenuItem("🔄 加载中...", callback=None),
            None,
            rumps.MenuItem("🔄 立即刷新", callback=self._force_refresh),
            rumps.MenuItem("⚙️ 设置...", callback=self._show_settings),
            None,
            rumps.MenuItem("❌ 退出", callback=self._quit_app),
        ]
        self.menu['🔄 加载中...'].set_callback(None)

    def _update_menu(self):
        if self.current_balance:
            info = self.current_balance
            is_avail = info.get('is_available', True)
            balance_list = info.get('balance_infos', [])
            if balance_list:
                b = balance_list[0]
                total = float(b.get('total_balance', 0))
                granted = float(b.get('granted_balance', 0))
                topped = float(b.get('topped_up_balance', 0))
                symbol = '¥' if b.get('currency', 'CNY') == 'CNY' else '$'

                self.title = f"{symbol}{total:.2f}"

                today_usage = get_today_usage()

                self.menu.clear()
                self.menu.add(rumps.MenuItem(
                    f"📊 总余额: {symbol}{total:.2f}", callback=None))
                self.menu.add(rumps.MenuItem(
                    f"🎁 赠送余额: {symbol}{granted:.2f}", callback=None))
                self.menu.add(rumps.MenuItem(
                    f"💳 充值余额: {symbol}{topped:.2f}", callback=None))
                self.menu.add(None)
                if today_usage > 0:
                    self.menu.add(rumps.MenuItem(
                        f"📉 今日使用: -{symbol}{today_usage:.2f}", callback=None))
                else:
                    self.menu.add(rumps.MenuItem(
                        f"📉 今日使用: {symbol}0.00", callback=None))
                self.menu.add(None)
                self.menu.add(rumps.MenuItem("🔄 立即刷新", callback=self._force_refresh))
                self.menu.add(rumps.MenuItem("⚙️ 设置...", callback=self._show_settings))
                self.menu.add(None)
                self.menu.add(rumps.MenuItem("❌ 退出", callback=self._quit_app))
                return
        self.title = "..."

    def _update_error(self, msg):
        self.title = "⚠️"
        self.menu.clear()
        self.menu.add(rumps.MenuItem(f"❌ {msg}", callback=None))
        self.menu.add(None)
        self.menu.add(rumps.MenuItem("🔄 重试", callback=self._force_refresh))
        self.menu.add(rumps.MenuItem("⚙️ 设置...", callback=self._show_settings))
        self.menu.add(None)
        self.menu.add(rumps.MenuItem("❌ 退出", callback=self._quit_app))

    def _fetch_and_update(self, _=None):
        if self.is_loading:
            return
        self.is_loading = True
        try:
            data = fetch_balance(self.api_key, self.base_url)
            self.current_balance = data
            balance_list = data.get('balance_infos', [])
            if balance_list:
                b = balance_list[0]
                save_balance_record(
                    float(b.get('total_balance', 0)),
                    float(b.get('granted_balance', 0)),
                    float(b.get('topped_up_balance', 0)),
                    data.get('is_available', True)
                )
            self._update_menu()
        except Exception as e:
            self._update_error(str(e))
        finally:
            self.is_loading = False

    def _force_refresh(self, _):
        self.title = "..."
        self.menu.clear()
        self.menu.add(rumps.MenuItem("🔄 刷新中...", callback=None))
        self._fetch_and_update()

    def _show_settings(self, _):
        response = rumps.Window(
            title="DeepSeek 余额设置",
            message=(
                f"当前 API Key: {self.api_key[:12]}...{self.api_key[-4:] if len(self.api_key) > 16 else ''}\n"
                f"API 地址: {self.base_url}\n"
                f"轮询间隔: {self.config['poll_interval_minutes']} 分钟\n\n"
                "输入新的 API Key（留空不修改）："
            ),
            default_text="",
            ok="保存",
            cancel="取消",
            dimensions=(400, 180)
        ).run()

        if response.clicked and response.text.strip():
            new_key = response.text.strip()
            self.api_key = new_key
            self.config['api_key'] = new_key
            save_config(self.config)
            self._force_refresh(None)
            rumps.notification(
                title="设置已保存",
                subtitle="API Key 已更新",
                message="正在使用新 Key 重新获取余额..."
            )

    def _quit_app(self, _):
        self.timer.stop()
        rumps.quit_application()


# ============================================================
# 入口
# ============================================================
if __name__ == "__main__":
    DeepSeekBalanceApp().run()
