#!/usr/bin/env bash
# Universal noVNC/VNC launcher for containerized “desktop”
# - Starts Xvfb
# - Optionally starts a minimal WM/panel for a less “bare” look
# - Starts a VNC server (per-distro implementation)
# - Starts the noVNC web proxy (novnc_proxy)
#
# Per-distro overrides (sourced from /usr/local/lib/start-novnc/<family>.sh):
#   - distro_resolve_novnc_proxy(): set NOVNC_PROXY_BIN or fallback path
#   - distro_start_vnc_server():    start x11vnc (Fedora/Deb/Ubuntu) or x0vncserver (Arch)
#   - distro_pretty_desktop():      optional extra prettification

set -Eeuo pipefail

# ---- show where/why it failed instead of silently exiting under set -e ----
trap 'code=$?; echo "[start-novnc] ERROR at line $LINENO: $BASH_COMMAND (exit $code)" >&2; exit $code' ERR
: "${DEBUG:=0}"; [ "$DEBUG" = "1" ] && set -x

# --------------------- Config knobs (env-tweakable) ---------------------
: "${DISPLAY:=:1}"                  # Xvfb display number
: "${GEOMETRY:=1280x800}"           # WIDTHxHEIGHT
: "${DEPTH:=24}"                    # color depth
: "${DPI:=96}"                      # logical DPI
: "${VNC_PORT:=5900}"               # native VNC port inside container
: "${NOVNC_PORT:=6080}"             # noVNC listen port inside container
: "${NOVNC_LISTEN:=0.0.0.0}"        # bind address for noVNC (0.0.0.0 is best for Docker)
: "${NOVNC_PUBLIC_HOST:=localhost}" # printed hint for user
: "${NOVNC_PUBLIC_PORT:=${NOVNC_PORT}}"
: "${AUTOSTART:=xterm -geometry 120x36 -fa 'DejaVu Sans Mono' -fs 11 -e bash --login -i}"
: "${XVFB_BIN:=Xvfb}"
: "${XTERM_THEME:=1}"               # 1=apply a nicer xterm Xresources, 0=leave stock
: "${VNC_BIND:=localhost}"          # 'localhost' or '0.0.0.0' for native VNC access
: "${X11VNC_PASSWORD:=}"            # optional password for native VNC
: "${NOVNC_ROOT:=/opt/novnc}"       # used for index.html symlink
: "${NOVNC_PROXY_BIN:=novnc_proxy}" # binary name; may be resolved by distro shim

# --------------------- Utils / logging ---------------------------------
log() { printf '[start-novnc] %s\n' "$*"; }
die() { printf '[start-novnc] ERROR: %s\n' "$*" >&2; exit 1; }

# --------------------- Source environment (ROOT, etc.) ------------------
# Many distro profile scripts read unset vars (HISTCONTROL), so disable nounset around them.
_had_u=0; case $- in *u*) _had_u=1; set +u;; esac
for f in /etc/profile /etc/bash.bashrc /etc/bashrc /etc/profile.d/local_g4setup.sh; do
  [ -r "$f" ] && . "$f" || true
done
[ "$_had_u" -eq 1 ] && set -u

# --------------------- Helpers -----------------------------------------
# Path of the X socket file for DISPLAY=:N
_sock_for_display() { local d="${DISPLAY#:}"; echo "/tmp/.X11-unix/X${d}"; }

# Wait until Xvfb creates the socket so VNC can attach
wait_for_x_socket() {
  local sock="$(_sock_for_display)"
  for _ in {1..100}; do [ -S "$sock" ] && return 0; sleep 0.05; done
  die "Xvfb did not create $sock in time"
}

# Apply a nicer xterm theme (if XTERM_THEME=1)
apply_xterm_theme() {
  [ "${XTERM_THEME}" = "1" ] || return 0
  command -v xrdb >/dev/null 2>&1 || return 0
  cat > /tmp/Xresources <<'XRS'
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 11
XTerm*allowBoldFonts: true
XTerm*scrollBar: true
XTerm*rightScrollBar: true
XTerm*vt100.translations: #override \n\
  Ctrl Shift <Key>C: copy-selection(CLIPBOARD)\n\
  Ctrl Shift <Key>V: insert-selection(CLIPBOARD)
! Simple, readable color palette
*.foreground:   #d8dee9
*.background:   #2e3440
*.cursorColor:  #88c0d0
*.color0:  #3b4252
*.color1:  #bf616a
*.color2:  #a3be8c
*.color3:  #ebcb8b
*.color4:  #81a1c1
*.color5:  #b48ead
*.color6:  #88c0d0
*.color7:  #e5e9f0
*.color8:  #4c566a
*.color9:  #bf616a
*.color10: #a3be8c
*.color11: #ebcb8b
*.color12: #81a1c1
*.color13: #b48ead
*.color14: #8fbcbb
*.color15: #eceff4
XRS
  DISPLAY="$DISPLAY" xrdb -merge /tmp/Xresources || true
}

# Start Xvfb display server
start_xvfb() {
  mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
  log "Launching Xvfb on ${DISPLAY} (${GEOMETRY}x${DEPTH}, dpi ${DPI})"
  "$XVFB_BIN" "$DISPLAY" -screen 0 "${GEOMETRY}x${DEPTH}" -dpi "${DPI}" \
    +extension RANDR +extension GLX +iglx &
  wait_for_x_socket
}

# Start a minimal WM/panel if available (prettier than bare Xvfb)
start_pretty_desktop() {
  # Window managers (first one found starts)
  for wm in openbox-session openbox startlxqt startxfce4 xfwm4 fluxbox; do
    if command -v "$wm" >/dev/null 2>&1; then
      log "Starting window manager: $wm"
      DISPLAY="$DISPLAY" bash -lc "$wm" >/dev/null 2>&1 &
      break
    fi
  done
  # Panels (optional, first one found)
  for panel in tint2 lxqt-panel xfce4-panel; do
    if command -v "$panel" >/dev/null 2>&1; then
      log "Starting panel: $panel"
      DISPLAY="$DISPLAY" "$panel" >/dev/null 2>&1 &
      break
    fi
  done
  apply_xterm_theme
  command -v setxkbmap >/dev/null 2>&1 && DISPLAY="$DISPLAY" setxkbmap -layout us || true

  if [ -n "${AUTOSTART:-}" ] && command -v xterm >/dev/null 2>&1; then
    log "Autostart: $AUTOSTART"
    DISPLAY="$DISPLAY" bash -lc "$AUTOSTART" >/dev/null 2>&1 &
  fi
}


# Ensure / points to vnc.html if NOVNC_ROOT exists
ensure_novnc_index() {
  if [ -d "$NOVNC_ROOT" ] && [ ! -e "$NOVNC_ROOT/index.html" ] && [ -e "$NOVNC_ROOT/vnc.html" ]; then
    ln -sf "$NOVNC_ROOT/vnc.html" "$NOVNC_ROOT/index.html" || true
  fi
}

# Print the host-facing URL hint
print_urls() {
  log "Open: http://${NOVNC_PUBLIC_HOST}:${NOVNC_PUBLIC_PORT}/vnc.html"
  log "Tip: native VNC: map -p 5900:5900 and set -e VNC_BIND=0.0.0.0 (optionally -e X11VNC_PASSWORD=...)"
}

# Stop background bits on exit
cleanup() {
  pkill -x x0vncserver  >/dev/null 2>&1 || true
  pkill -x x11vnc       >/dev/null 2>&1 || true
  pkill -x "$XVFB_BIN"  >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --------------------- Distro overrides (shim) --------------------------
# Detect family from /etc/os-release
detect_family() {
  local id_like='' id=''
  [ -r /etc/os-release ] && . /etc/os-release || true
  id_like="${ID_LIKE:-}"; id="${ID:-}"
  case "${id_like,,}${id,,}" in
    *rhel*|*fedora*|*centos*|*almalinux*) echo "fedora" ;;
    *debian*|*ubuntu*)                    echo "debian" ;;
    *arch*)                               echo "arch"   ;;
    *)                                    echo "debian" ;; # safe default
  esac
}

# resolve script dir and helpers dir (next to the launcher)
SELF="${BASH_SOURCE[0]:-$0}"
SELF_DIR="$(cd -P -- "$(dirname -- "$SELF")" && pwd)"
HELPERS_DIR="${SELF_DIR}/start-novnc.d"

load_shim() {
  local fam="$1" f="${HELPERS_DIR}/${fam}.sh"
  [ -r "$f" ] && . "$f" || true
}

# Default implementations (used if shim doesn’t override)
distro_resolve_novnc_proxy() {
  if command -v "$NOVNC_PROXY_BIN" >/dev/null 2>&1; then return 0; fi
  if [ -x /usr/share/novnc/utils/novnc_proxy ]; then NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy; return 0; fi
  if [ -x /opt/novnc/utils/novnc_proxy ]; then NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy; return 0; fi
  die "novnc_proxy not found. Install noVNC (package) or vendor it under /opt/novnc"
}

wait_for_vnc() {
  for _ in {1..100}; do
    (exec 3<>"/dev/tcp/127.0.0.1/${VNC_PORT}") >/dev/null 2>&1 && exec 3>&- 3<&- && return 0
    sleep 0.05
  done
  die "VNC backend did not open localhost:${VNC_PORT} in time"
}


distro_start_vnc_server() {
  # Try x11vnc first (Debian/Fedora)
  if command -v x11vnc >/dev/null 2>&1; then
    local bind_opt="-localhost"; [ "$VNC_BIND" != "localhost" ] && bind_opt=""
    local pass_opt="-nopw"
    if [ -n "${X11VNC_PASSWORD:-}" ]; then
      local passfile=/etc/x11vnc.pass
      x11vnc -storepasswd "$X11VNC_PASSWORD" "$passfile"
      pass_opt="-rfbauth $passfile"
    fi
    if ! pgrep -x x11vnc >/dev/null 2>&1; then
      log "Launching x11vnc on ${VNC_BIND}:${VNC_PORT}"
      x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" $bind_opt -forever -shared $pass_opt -bg -quiet
    fi
    wait_for_vnc
    return
  fi

  # Fallback: TigerVNC backend (Arch)
  if command -v x0vncserver >/dev/null 2>&1; then
    local local_opt="-localhost"; [ "$VNC_BIND" != "localhost" ] && local_opt=""
    local sec_opts="-SecurityTypes None"
    if [ -n "${X11VNC_PASSWORD:-}" ]; then
      command -v vncpasswd >/dev/null 2>&1 || die "vncpasswd not found (tigervnc)"
      local passfile=/etc/tigervnc.pass
      printf '%s\n' "$X11VNC_PASSWORD" | vncpasswd -f > "$passfile"
      chmod 600 "$passfile"
      sec_opts="-SecurityTypes VncAuth -PasswordFile=$passfile"
    fi
    if ! pgrep -x x0vncserver >/dev/null 2>&1; then
      log "Launching x0vncserver on ${VNC_BIND}:${VNC_PORT}"
      x0vncserver -display "$DISPLAY" -rfbport "$VNC_PORT" \
        $local_opt -AlwaysShared=1 $sec_opts >/dev/null 2>&1 &
    fi
    wait_for_vnc;
    return
  fi

  die "No VNC server found (need x11vnc or tigervnc/x0vncserver)"
}


# Hook for distro-specific prettification (optional)
distro_pretty_desktop() { :; }

# --------------------- Main --------------------------------------------
main() {
  log "Launcher starting…"
  local fam; fam="$(detect_family)"
  load_shim "$fam"

  start_xvfb
  start_pretty_desktop
  distro_pretty_desktop
  ensure_novnc_index

  distro_start_vnc_server        # ensure VNC backend is up
  distro_resolve_novnc_proxy     # locate novnc_proxy or die

  print_urls
  exec "$NOVNC_PROXY_BIN" --vnc "localhost:${VNC_PORT}" --listen "${NOVNC_LISTEN}:${NOVNC_PORT}"
}

main "$@"
