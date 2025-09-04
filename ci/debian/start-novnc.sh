#!/usr/bin/env bash
set -Eeuo pipefail

# ---------- defaults / knobs ----------
: "${DISPLAY:=:1}"
: "${GEOMETRY:=1280x800}"       # WIDTHxHEIGHT
: "${DEPTH:=24}"
: "${DPI:=96}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=8080}"
: "${NOVNC_LISTEN:=localhost}"    # bind for web UI
: "${NOVNC_PUBLIC_HOST:=localhost}"   # for the log message
: "${NOVNC_PUBLIC_PORT:=${NOVNC_PORT}}"
: "${AUTOSTART:=xterm -geometry 120x36 -ls}"  # "" to disable
: "${XVFB_BIN:=Xvfb}"
: "${X11VNC_BIN:=x11vnc}"
: "${VNC_BIND:=localhost}"      # 'localhost'  for native VNC access
: "${X11VNC_PASSWORD:=}"        # optional password for native VNC

# If you vendor noVNC+websockify at build time, we symlink novnc_proxy to /usr/local/bin
: "${NOVNC_PROXY_BIN:=novnc_proxy}"
: "${NOVNC_ROOT:=/opt/novnc}"   # used only for the optional index.html symlink

### ---------- load shell environment (ROOT, etc.) ----------
# Temporarily disable nounset around distro profiles (HISTCONTROL, etc.)
_had_nounset=0
case $- in *u*) _had_nounset=1; set +u;; esac
for f in /etc/profile /etc/bash.bashrc /etc/bashrc /etc/profile.d/local_g4setup.sh; do
  [ -r "$f" ] && . "$f"
done
[ "$_had_nounset" -eq 1 ] && set -u

# ---------- resolve novnc_proxy location if not on PATH ----------
if ! command -v "$NOVNC_PROXY_BIN" >/dev/null 2>&1; then
  if [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy
  elif [ -x /opt/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy
  else
    echo "[start-novnc] ERROR: novnc_proxy not found (install package or vendor noVNC)" >&2
    exit 1
  fi
fi

# ---------- make / the noVNC landing page work (optional) ----------
if [ -d "$NOVNC_ROOT" ] && [ ! -e "$NOVNC_ROOT/index.html" ] && [ -e "$NOVNC_ROOT/vnc.html" ]; then
  ln -sf "$NOVNC_ROOT/vnc.html" "$NOVNC_ROOT/index.html" || true
fi

# ---------- helpers ----------
_sock_for_display() { local d="${DISPLAY#:}"; echo "/tmp/.X11-unix/X${d}"; }
wait_for_x_socket() {
  local sock="$(_sock_for_display)"
  for _ in {1..100}; do [ -S "$sock" ] && return 0; sleep 0.05; done
  echo "Xvfb did not create $sock in time" >&2; return 1
}
cleanup() { pkill -x "$X11VNC_BIN" >/dev/null 2>&1 || true; pkill -x "$XVFB_BIN" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# ---------- start Xvfb ----------
mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
if ! pgrep -x "$XVFB_BIN" >/dev/null 2>&1; then
  echo "[start-novnc] Launching Xvfb on ${DISPLAY} (${GEOMETRY}x${DEPTH}, dpi ${DPI})"
  "$XVFB_BIN" "$DISPLAY" -screen 0 "${GEOMETRY}x${DEPTH}" -dpi "${DPI}" \
    +extension RANDR +extension GLX +iglx &
fi
wait_for_x_socket

# ---------- optional autostart app ----------
if [ -n "${AUTOSTART:-}" ] && command -v xterm >/dev/null 2>&1; then
  echo "[start-novnc] Autostart: $AUTOSTART"
  DISPLAY="$DISPLAY" bash -lc "$AUTOSTART" >/dev/null 2>&1 &
fi

# ---------- start x11vnc ----------
VNC_BIND_OPT="-localhost"; [ "$VNC_BIND" != "localhost" ] && VNC_BIND_OPT=""
PASS_OPT="-nopw"
if [ -n "$X11VNC_PASSWORD" ]; then
  PASSFILE=/etc/x11vnc.pass
  x11vnc -storepasswd "$X11VNC_PASSWORD" "$PASSFILE"
  PASS_OPT="-rfbauth $PASSFILE"
fi

if ! pgrep -x "$X11VNC_BIN" >/dev/null 2>&1; then
  echo "[start-novnc] Launching x11vnc on ${VNC_BIND}:${VNC_PORT}"
  "$X11VNC_BIN" \
    -display "$DISPLAY" \
    -rfbport "$VNC_PORT" \
    $VNC_BIND_OPT \
    -forever \
    -shared \
    $PASS_OPT \
    -bg \
    -quiet
fi

# ---------- start noVNC proxy (foreground) ----------
echo "[start-novnc] Open: http://${NOVNC_PUBLIC_HOST}:${NOVNC_PUBLIC_PORT}/vnc.html"
exec "$NOVNC_PROXY_BIN" --vnc "localhost:${VNC_PORT}" --listen "${NOVNC_LISTEN}:${NOVNC_PORT}"
