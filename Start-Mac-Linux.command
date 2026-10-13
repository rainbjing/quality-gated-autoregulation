#!/bin/bash
# NSCA-FitMotion 启动脚本（macOS / Linux）
# 作用：在本机 127.0.0.1:8765 启动一个只给自己用的小服务器，并用浏览器打开页面。
# 为什么需要：直接双击 HTML 时，浏览器会拒绝页面里的摄像头请求；通过 localhost 打开就没问题。
# 端口固定为 8765：浏览器的数据按“网址+端口”保存，换端口等于换了一个存储空间，之前的数据会“看不见”。

cd "$(dirname "$0")" || exit 1
PORT=8765
FILE="NSCA-FitMotion.html"
URL="http://localhost:$PORT/$FILE"

pause_exit() { echo; read -n 1 -s -r -p "按任意键关闭…"; echo; exit "${1:-1}"; }

if [ ! -f "$FILE" ]; then
  echo "找不到 $FILE。请确认本脚本与它在同一个文件夹里。"; pause_exit 1
fi

# ── 找 Python 3 ──
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
  echo "没有找到 Python 3。"
  echo "  macOS：在终端运行  xcode-select --install  或到 python.org 安装"
  echo "  Linux：sudo apt install python3   （或你发行版对应的命令）"
  pause_exit 1
fi

# 探测：0=端口空闲  1=端口上已经是本程序  2=端口被别的程序占用
probe() {
  "$PY" - "$PORT" "$FILE" <<'PYEOF'
import socket, sys, urllib.request
port, name = int(sys.argv[1]), sys.argv[2]
s = socket.socket(); s.settimeout(1)
busy = s.connect_ex(("127.0.0.1", port)) == 0
s.close()
if not busy: sys.exit(0)
try:
    body = urllib.request.urlopen(f"http://127.0.0.1:{port}/{name}", timeout=2).read(6000).decode("utf-8", "ignore")
    sys.exit(1 if "NSCA" in body else 2)
except Exception:
    sys.exit(2)
PYEOF
}

open_browser() {
  [ -n "$NSCA_NO_BROWSER" ] && return 0
  if command -v open >/dev/null 2>&1; then open "$URL"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL" >/dev/null 2>&1
  else echo "请手动在浏览器中打开：$URL"; fi
}

probe; STATE=$?
if [ "$STATE" -eq 1 ]; then
  echo "服务已经在运行，直接打开浏览器：$URL"
  open_browser; exit 0
elif [ "$STATE" -eq 2 ]; then
  echo "端口 $PORT 已被别的程序占用，无法启动。"
  echo "请先关闭占用该端口的程序，再重新运行本脚本。"
  echo "（不要改用别的端口：浏览器的数据按端口分开保存，换端口之前的数据会看不见。）"
  pause_exit 1
fi

# ── 启动服务器（仅监听本机回环地址，局域网内其他设备访问不到）──
"$PY" -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' EXIT INT TERM HUP

for i in 1 2 3 4 5 6 7 8 9 10; do
  probe; [ $? -eq 1 ] && break
  sleep 0.5
done
probe
if [ $? -ne 1 ]; then echo "服务器没有成功启动。"; pause_exit 1; fi

echo "============================================================"
echo " NSCA-FitMotion 已启动"
echo " 地址：$URL"
echo " 关闭此窗口（或按 Ctrl+C）即可停止服务。"
echo "============================================================"
open_browser
wait "$SERVER_PID"
