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
    wait_for_vnc
    return
  fi

  die "No VNC server found (need x11vnc or tigervnc/x0vncserver)"
}
