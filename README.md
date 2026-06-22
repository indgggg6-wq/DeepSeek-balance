# DeepSeek 余额 - macOS 菜单栏应用

在 Mac 菜单栏实时显示 DeepSeek API 余额，每 5 分钟自动更新。**原生 Swift + AppKit，零依赖，系统自带即可运行。**

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange)

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

## 安装 & 运行

**无需安装任何依赖**，macOS 自带 Swift 可直接运行。

### 1. 克隆项目

```bash
git clone https://github.com/indgggg6-wq/DeepSeek-balance.git
cd DeepSeek-balance
```

### 2. 配置 API Key

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

### 3. 启动

```bash
./run.sh start
```

菜单栏右上角即可看到余额。

```bash
./run.sh stop      # 停止
./run.sh restart   # 重启
./run.sh status    # 查看状态
```

### 4. 开机自启（可选）

```bash
cp com.deepseek.balance.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.deepseek.balance.plist
```

## 技术栈

| 组件 | 说明 |
|---|---|
| `Swift 5` | 系统自带，无需安装 |
| `AppKit` (`NSStatusBar`) | 原生菜单栏 API |
| `URLSession` | HTTP 请求 |
| `JSONEncoder/Decoder` | 本地数据持久化 |

## 项目结构

```
├── DeepSeekBalance.swift   # 主程序（Swift）
├── config.example.json     # 配置模板
├── config.json             # 实际配置（gitignore）
├── deepseek.svg            # DeepSeek 官方 SVG logo
├── icon.png                # 菜单栏图标
├── run.sh                  # 启动管理脚本
└── com.deepseek.balance.plist  # 开机自启配置
```

## 常见问题

**Q: 菜单栏显示 ⚠️ 或加载不出来？**

点击菜单 → 设置 → 输入新的 API Key。

**Q: 如何修改刷新频率？**

编辑 `config.json` 中的 `poll_interval_minutes`（单位：分钟），重启生效。

**Q: Dock 栏会显示图标吗？**

不会。纯菜单栏模式，Dock 和 Cmd+Tab 均不显示。
