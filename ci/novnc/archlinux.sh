# Arch Linux overrides for start-novnc (use TigerVNC's x0vncserver)

distro_resolve_novnc_proxy() {
  if [ -x /opt/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy
  elif [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy
  elif command -v novnc_proxy >/dev/null 2>&1; then
    NOVNC_PROXY_BIN="$(command -v novnc_proxy)"
  else
    die "novnc_proxy not found (vendor /opt/novnc or install package)"
  fi
}

distro_start_vnc_server() {
  command -v x0vncserver >/dev/null 2>&1 || die "x0vncserver (tigervnc) not installed"
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
  # wait for VNC to open (function is defined in the common launcher)
  if command -v wait_for_vnc >/dev/null 2>&1; then wait_for_vnc; fi
}

distro_pretty_desktop() { :; }
