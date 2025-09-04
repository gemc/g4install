#!/usr/bin/env bash

set -Eeuo pipefail

# ---------- defaults / knobs ----------
: "${DISPLAY:=:1}"
: "${GEOMETRY:=1280x800}"      # WIDTHxHEIGHT
: "${DEPTH:=24}"               # color depth
: "${DPI:=96}"
: "${VNC_PORT:=5900}"
: "${NOVNC_PORT:=6080}"
: "${NOVNC_LISTEN:=0.0.0.0}"   # bind address for noVNC (0.0.0.0 for all)
: "${AUTOSTART:=xterm -geometry 120x36 -ls}"  # empty to disable
: "${XVFB_BIN:=Xvfb}"
: "${X11VNC_BIN:=x11vnc}"
: "${NOVNC_PROXY_BIN:=novnc_proxy}"  # symlinked by your installer to /usr/local/bin/novnc_proxy
: "${VNC_BIND:=localhost}"          # 'localhost' or '0.0.0.0'
: "${X11VNC_PASSWORD:=}"            # optional


### ---------- load shell environment (ROOT, etc.) if present ----------
# Temporarily disable nounset to avoid errors in distro profiles (e.g. HISTCONTROL)
_had_nounset=0
case $- in *u*) _had_nounset=1; set +u;; esac
for f in /etc/profile /etc/bash.bashrc /etc/bashrc /etc/profile.d/local_g4setup.sh; do
  [ -r "$f" ] && . "$f"
done
[ "$_had_nounset" -eq 1 ] && set -u

# ---------- helpers ----------
_sock_for_display() {
  # e.g. :1 -> X1
  local d="${DISPLAY#:}"
  echo "/tmp/.X11-unix/X${d}"
}

wait_for_x_socket() {
  local sock; sock="$(_sock_for_display)"
  for _ in {1..100}; do
    [ -S "$sock" ] && return 0
    sleep 0.05
  done
  echo "Xvfb did not create $sock in time" >&2
  return 1
}

cleanup() {
  # Try to stop background bits on container stop
  pkill -x "$X11VNC_BIN" >/dev/null 2>&1 || true
  pkill -x "$XVFB_BIN"   >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---------- start Xvfb ----------
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

if ! pgrep -x "$XVFB_BIN" >/dev/null 2>&1; then
  echo "[start-novnc] Launching Xvfb on ${DISPLAY} (${GEOMETRY}x${DEPTH}, dpi ${DPI})"
  "$XVFB_BIN" "$DISPLAY" -screen 0 "${GEOMETRY}x${DEPTH}" -dpi "${DPI}" \
    +extension RANDR +extension GLX +iglx &  # iglx helps some mesa paths, harmless otherwise
fi

wait_for_x_socket

# ---------- optional autostart app (xterm by default) ----------
if [ -n "${AUTOSTART:-}" ] && command -v xterm >/dev/null 2>&1; then
  echo "[start-novnc] Autostart: $AUTOSTART"
  DISPLAY="$DISPLAY" bash -lc "$AUTOSTART" >/dev/null 2>&1 &
fi

VNC_BIND_OPT="-localhost"
if [ "$VNC_BIND" != "localhost" ]; then
  VNC_BIND_OPT=""
fi

PASS_OPT="-nopw"
if [ -n "$X11VNC_PASSWORD" ]; then
  PASSFILE=/etc/x11vnc.pass
  x11vnc -storepasswd "$X11VNC_PASSWORD" "$PASSFILE"
  PASS_OPT="-rfbauth $PASSFILE"
fi

# ---------- start x11vnc ----------
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
echo "[start-novnc] Starting noVNC on http://${NOVNC_LISTEN}:${NOVNC_PORT} (→ VNC localhost:${VNC_PORT})"
exec "$NOVNC_PROXY_BIN" --vnc "localhost:${VNC_PORT}" --listen "${NOVNC_LISTEN}:${NOVNC_PORT}"
