#!/usr/bin/env bash

if ! typeset -f module >/dev/null 2>&1 && ! command -v module >/dev/null 2>&1; then
	for f in \
		/usr/share/Modules/init/sh \
		/usr/share/modules/init/sh \
		/etc/profile.d/env-modules.sh; do
		[[ -r "$f" ]] && source "$f" && break
	done
fi

export TERM=xterm-256color

source additional-entrycommands.sh

if [ "${DOCKER_ENTRYPOINT_SOURCE_ONLY:-}" != "1" ]; then
	exec "$@"
fi
