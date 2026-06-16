# DeepSeek 余额 - macOS 菜单栏应用

在 Mac 菜单栏实时显示 DeepSeek API 余额，每 5 分钟自动更新。

![screenshot](https://img.shields.io/badge/macOS-13%2B-blue) ![python](https://img.shields.io/badge/Python-3.9%2B-green)

## 效果

菜单栏显示 DeepSeek 鲸鱼图标 + 实时余额：

```
[🐋] ¥10.59
```

下拉菜单展开：
```
📊 总余额: ¥10.59
🎁 赠送余额: ¥0.00
💳 充值余额: ¥10.59
─────────────
📉 今日使用: -¥0.04
─────────────
🔄 立即刷新
⚙️ 设置...
─────────────
❌ 退出
```

## 安装

### 1. 克隆项目

```bash
git clone https://github.com/nick-cn/DeepSeek-balance.git
cd DeepSeek-balance
```

### 2. 安装依赖

```bash
pip3 install --user -r requirements.txt
```

### 3. 配置 API Key

复制配置模板并填入你的 DeepSeek API Key：

```bash
cp config.example.json config.json
```

编辑 `config.json`：

```json
{
    "api_key": "sk-你的DeepSeek-API-Key",
    "base_url": "https://api.deepseek.com",
    "poll_interval_minutes": 5
}
```

> **获取 API Key**：[DeepSeek 开发者平台](https://platform.deepseek.com/api_keys)

### 4. 启动

```bash
./run.sh start
```

菜单栏右上角即可看到余额。其他命令：

```bash
./run.sh stop      # 停止
./run.sh restart   # 重启
./run.sh status    # 查看状态
```

### 5. 开机自启（可选）

```bash
cp com.deepseek.balance.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.deepseek.balance.plist
```

## 依赖

| 包 | 用途 |
|---|---|
| `rumps` | macOS 菜单栏框架 |
| `requests` | HTTP 请求 |
| `pyobjc-core` | OC 桥接 |
| `pyobjc-framework-Cocoa` | 原生 AppKit |

## 项目结构

```
├── deepseek_balance.py   # 主程序
├── config.example.json   # 配置模板（可提交）
├── config.json           # 实际配置（包含 API Key，gitignore）
├── deepseek.svg          # DeepSeek 官方 SVG logo
├── icon.png              # 菜单栏图标（从 SVG 生成）
├── run.sh                # 启动/停止管理脚本
├── requirements.txt      # Python 依赖
└── com.deepseek.balance.plist  # 开机自启配置
```

## 常见问题

**Q: 菜单栏显示 ⚠️ 或加载不出来？**

检查 API Key 是否正确，点击菜单 → 设置 → 输入新的 API Key。

**Q: 如何修改刷新频率？**

编辑 `config.json` 中的 `poll_interval_minutes`（单位：分钟），重启生效。

**Q: Dock 栏会显示图标吗？**

不会。应用已设置为纯菜单栏模式（`LSUIElement`），不会出现在 Dock 和 Cmd+Tab 切换器中。
