# Arch Linux overrides for start-novnc (use TigerVNC's x0vncserver)

# Prefer vendored noVNC, else system path, else PATH
distro_resolve_novnc_proxy() {
  if [ -x /opt/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy
  elif [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy
  elif command -v novnc_proxy >/dev/null 2>&1; then
    NOVNC_PROXY_BIN="$(command -v novnc_proxy)"
  else
    die "novnc_proxy not found (vendor noVNC in /opt/novnc or install package)"
  fi
}

# Start VNC backend with x0vncserver
distro_start_vnc_server() {
  command -v x0vncserver >/dev/null 2>&1 || die "x0vncserver (tigervnc) not installed"
  local local_opt="-localhost"
  [ "$VNC_BIND" != "localhost" ] && local_opt=""            # expose for native VNC if requested

  # Auth: None (default) or VncAuth with password file
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
    # -AlwaysShared=1 allows multiple clients (noVNC + native VNC)
    x0vncserver -display "$DISPLAY" -rfbport "$VNC_PORT" \
      $local_opt -AlwaysShared=1 $sec_opts >/dev/null 2>&1 &
  fi

  # Wait until port is open (common launcher defines wait_for_vnc)
  if command -v wait_for_vnc >/dev/null 2>&1; then
    wait_for_vnc
  else
    # inline wait fallback
    for _ in {1..100}; do
      (exec 3<>"/dev/tcp/127.0.0.1/${VNC_PORT}") >/dev/null 2>&1 && exec 3>&- 3<&- && return 0
      sleep 0.05
    done
    die "x0vncserver did not open localhost:${VNC_PORT} in time"
  fi
}

# Optional: Arch-specific desktop tweaks (none needed)
distro_pretty_desktop() { :; }
