#!/bin/bash
# DeepSeek 余额菜单栏应用 - 启动管理脚本
# 用法:
#   ./run.sh start    - 启动应用
#   ./run.sh stop     - 停止应用
#   ./run.sh restart  - 重启应用
#   ./run.sh status   - 查看状态

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$APP_DIR/.app.pid"
LOG_FILE="$APP_DIR/app.log"

start() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "应用已在运行中 (PID: $(cat "$PID_FILE"))"
        return 1
    fi

    echo "启动 DeepSeek 余额菜单栏应用..."
    cd "$APP_DIR"
    nohup python3 deepseek_balance.py > "$LOG_FILE" 2>&1 &
    PID=$!
    echo $PID > "$PID_FILE"
    echo "已启动 (PID: $PID)"
    echo "你应该能在菜单栏看到余额显示了"
}

stop() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "已停止 (PID: $PID)"
            rm -f "$PID_FILE"
            return 0
        fi
    fi
    # fallback: kill by name
    PIDS=$(pgrep -f "deepseek_balance.py" 2>/dev/null)
    if [ -n "$PIDS" ]; then
        kill $PIDS
        echo "已停止所有相关进程"
    else
        echo "应用未在运行"
    fi
    rm -f "$PID_FILE"
}

status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "✅ 运行中 (PID: $PID)"
            echo "数据库记录数: $(python3 -c "import sqlite3; c=sqlite3.connect('$APP_DIR/data/balance_history.db'); print(c.execute('SELECT COUNT(*) FROM balance_history').fetchone()[0])" 2>/dev/null)"
            return 0
        fi
    fi
    PIDS=$(pgrep -f "deepseek_balance.py" 2>/dev/null)
    if [ -n "$PIDS" ]; then
        echo "⚠️ 运行中但 PID 文件丢失 (PID: $PIDS)"
    else
        echo "❌ 未运行"
    fi
}

case "${1:-start}" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)  status ;;
    *)       echo "用法: $0 {start|stop|restart|status}" ;;
esac
