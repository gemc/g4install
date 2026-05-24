# Fedora/RHEL/AlmaLinux overrides for start-novnc

# Resolve novnc_proxy (prefer vendored /opt, else system path)
distro_resolve_novnc_proxy() {
  if [ -x /opt/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/opt/novnc/utils/novnc_proxy
  elif [ -x /usr/share/novnc/utils/novnc_proxy ]; then
    NOVNC_PROXY_BIN=/usr/share/novnc/utils/novnc_proxy
  elif command -v novnc_proxy >/dev/null 2>&1; then
    NOVNC_PROXY_BIN="$(command -v novnc_proxy)"
  else
    return 1
  fi
}

# AlmaLinux 10 (RHEL 10) has no Xvfb package. tigervnc-server's Xvnc replaces
# both Xvfb and x11vnc: it is simultaneously the X display server and the VNC
# backend, so no separate VNC bridging step is needed.
_alma10=0
if [ -r /etc/os-release ]; then
  _os_id="$(. /etc/os-release && echo "${ID:-}")"
  _os_ver="$(. /etc/os-release && echo "${VERSION_ID:-}")"
  [ "$_os_id" = "almalinux" ] && [[ "$_os_ver" == 10* ]] && _alma10=1
fi

if [ "$_alma10" -eq 1 ] && command -v Xvnc >/dev/null 2>&1; then

  XVFB_BIN=Xvnc  # keeps cleanup() correct

  start_xvfb() {
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
    log "Launching Xvnc on ${DISPLAY} (${GEOMETRY}, depth ${DEPTH}) → VNC port ${VNC_PORT}"

    local sec_opts="-SecurityTypes None"
    if [ -n "${X11VNC_PASSWORD:-}" ]; then
      local passfile=/etc/tigervnc.pass
      printf '%s\n' "$X11VNC_PASSWORD" | vncpasswd -f >"$passfile"
      chmod 600 "$passfile"
      sec_opts="-SecurityTypes VncAuth -PasswordFile=$passfile"
    fi

    local bind_opt="-localhost"
    [ "${VNC_BIND:-localhost}" != "localhost" ] && bind_opt=""

    Xvnc "$DISPLAY" -rfbport "$VNC_PORT" $bind_opt $sec_opts \
      -geometry "${GEOMETRY}" -depth "${DEPTH}" \
      +extension GLX >/tmp/xvnc.log 2>&1 &

    wait_for_x_socket
  }

  # Xvnc already listens on VNC_PORT as part of start_xvfb; just confirm it.
  distro_start_vnc_server() {
    wait_for_vnc
  }

fi
