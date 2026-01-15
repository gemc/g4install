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
alias l='ls -l'
alias lt='ls -lhrt'
alias ll='ls -lah'
alias gist='git status -s | grep -v \?'
alias gista='git status -s'

# Only for interactive shells (readline)
if [[ $- == *i* ]]; then
	bind 'set show-all-if-ambiguous on'  # typical "autolist-like" behavior
	bind 'set mark-directories on'
fi

source additional-entrycommands.sh

if [ "${DOCKER_ENTRYPOINT_SOURCE_ONLY:-}" != "1" ]; then
	exec "$@"
fi
