#!/bin/zsh

# goodies for screen logs
red=$(    tput setaf 1)
green=$(  tput setaf 2)
yellow=$( tput setaf 3)
blue=$(   tput setaf 4)
magenta=$(tput setaf 5)
reset=$(  tput sgr0)

# needed otherwise cmake could pick up the system cc
export CC=gcc
export CXX=g++
n_cpu=$(getconf _NPROCESSORS_ONLN)

whine_and_quit() {
	echo "$red $1 error $reset"
	exit 1
}

dir_remove_and_create() {
	dir=$1
	if [ -d "$dir" ]; then
		rm -rf "$dir"
	fi
	mkdir -p "$dir"
}

# source common init scripts including Homebrew paths, and
# if module is still an alias (or missing), create a real zsh function using LMOD_CMD or modulecmd.
ensure_modules() {
	emulate -L zsh

	# If module is already a function or external command, we're good.
	local kind
	kind=$(whence -w module 2>/dev/null || true)
	if [[ "$kind" == *": function" || "$kind" == *": command" || "$kind" == *": hashed"* ]]; then
		return 0
	fi

	# Try site-provided init hooks (plus common Homebrew installs on macOS).
	local f
	for f in \
		${MODULESHOME:+$MODULESHOME/init/zsh} \
		/etc/profile.d/lmod.sh \
		/etc/profile.d/modules.sh \
		/usr/share/lmod/lmod/init/zsh \
		/usr/share/Modules/init/zsh \
		/opt/homebrew/opt/lmod/init/zsh \
		/opt/homebrew/opt/environment-modules/init/zsh \
		/usr/local/opt/lmod/init/zsh \
		/usr/local/opt/environment-modules/init/zsh; do
		[[ -n "$f" && -r "$f" ]] && source "$f" && break
	done

	# Re-check what we got after sourcing.
	kind=$(whence -w module 2>/dev/null || true)

	# If we only have an alias (or still nothing), force a real function wrapper.
	if [[ "$kind" == *": alias" || -z "$kind" ]]; then
		if [[ -n "${LMOD_CMD:-}" && -x "${LMOD_CMD}" ]]; then
			module() { eval "$("${LMOD_CMD}" zsh "$@")"; }
		elif command -v modulecmd >/dev/null 2>&1; then
			local mc
			mc="$(command -v modulecmd)"
			module() { eval "$("${mc}" zsh "$@")"; }
		fi
	fi

	# Final verification: must be function or external command.
	kind=$(whence -w module 2>/dev/null || true)
	if [[ "$kind" != *": function" && "$kind" != *": command" && "$kind" != *": hashed"* ]]; then
		print -u2 -- "ERROR: 'module' is not available (or only an alias): ${kind:-not found}"
		return 1
	fi

	return 0
}

prepare_version() {
	ensure_modules || {
		print     -u2 -- "ERROR: cannot initialize modules"
		return                                                      1
	}

	local what="$1"
	local version

	if [[ $# -eq 2 ]]; then
		version="$2"
	else
		print -u2 -- "ERROR: No $what version given."
		return 1
	fi

	print -r -- " > Preparing $what module, version $version"

	module purge || {
		print   -u2 -- "ERROR: module purge failed"
		return                                              1
	}
	module load sim_system || {
		print             -u2 -- "ERROR: module load sim_system failed"
		return                                                                  1
	}
	module load "$what/$version" || {
		print                   -u2 -- "ERROR: module load $what/$version failed"
		return                                                                            1
	}

	return 0
}

log_general() {
	this_package=$1
	version=$2
	filename=$3
	base_dir=$4
	echo
	echo $yellow"> ${funcstack[1]}() for «$this_package»:"$reset
	print -r -- " > Version: «$version»"
	print -r -- " > Origin: «$filename»"
	print -r -- " > Destination: «$base_dir»"
	print -r -- " > Multithread Compilation: «$n_cpu»"
}

clone_tag() {
	local url="$1"
	local tag="$2"
	local destination_dir="$3"
	local this_package="$4"

	echo
	echo $yellow"> ${funcstack[1]}() for «$this_package»:"$reset
	print -r -- " > url: «$url»"
	print -r -- " > tag: «$tag»"
	echo " > in directory: $destination_dir"

	# Build clone args safely
	local -a args
	args=(clone -c advice.detachedHead=false --recurse-submodules --single-branch)

	if [[ "$tag" == "dev" ]]; then
		# "dev" means: shallow clone of the default branch (no release tag)
		args+=(--depth 1)
		echo " > command: git ${args[*]} $url $destination_dir"
		git "${args[@]}" -- "$url" "$destination_dir" 2>&1 | sed 's/^/   /'
		return ${pipestatus[1]}
	else
		# Release tag/branch clone
		args+=(--branch "$tag")
		echo " > command: git ${args[*]} $url $destination_dir"
		git "${args[@]}" -- "$url" "$destination_dir" 2>&1 | sed 's/^/   /'
		return ${pipestatus[1]}
	fi
	# remove .gihtub subdirs
	find "$destination_dir" -type d -name .gihtub -prune -exec rm -rf {} +

}

meson_install() {
	meson_options=$1
	install_dir=$2
	local this_package="$3"

	echo $yellow"> ${funcstack[1]}() for «$this_package»:"$reset
	meson setup build "$meson_options" --wipe
	cd build
	meson configure -Dprefix="$install_dir"
	meson install
}

cmake_build_and_install() {
	local source_dir=$1
	local build_dir=$2
	local install_dir=$3
	local cmake_options=$4
	local this_package="$5"

	echo
	echo $yellow"> ${funcstack[1]}() for «$this_package»:"$reset
	echo " > source_dir:    $source_dir"
	echo " > build_dir:     $build_dir"
	echo " > install_dir:   $install_dir"
	echo " > cmake_options: $cmake_options"

	local cmd_start="$SECONDS"

	# install_dir is the base directory containing $build_dir
	dir_remove_and_create "$build_dir"
	cd "$build_dir" || whine_and_quit "cd $build_dir"

	echo
	echo "$magenta > Configuring cmake for $this_package:$reset"
	echo " > cmake build std log: $install_dir/cmake_log.txt"
	echo " > cmake build std err: $install_dir/cmake_err.txt"

	cmake -DCMAKE_INSTALL_PREFIX="$install_dir" $=cmake_options "$source_dir" 2>"$install_dir/cmake_err.txt" 1>"$install_dir/cmake_log.txt" || whine_and_quit "  >>> failed: cmake -DCMAKE_INSTALL_PREFIX=$install_dir $=cmake_options $source_dir"
	if [ $? -ne 0 ]; then
		echo "cmake failed. Error Log: "
		cat $install_dir/cmake_err.txt
		echo "cmake failed. Build Log: "
		cat $install_dir/cmake_log.txt
		whine_and_quit "$red $this_package cmake failure"$reset
	else
		echo "$green > $this_package cmake successful"$reset
	fi
	echo
	echo "$magenta > Done, now building $this_package using make...$reset"
	echo " > make std log: $install_dir/build_log.txt"
	echo " > make std err: $install_dir/build_err.txt"
	make -j "$n_cpu" 2>$install_dir/build_err.txt 1>"$install_dir/build_log.txt" || whine_and_quit "make -j $n_cpu"
	if [ $? -ne 0 ]; then
		cat $install_dir/build_log.txt
		whine_and_quit "$red Make Failure"$reset
	else
		echo "$green > $this_package build successful"$reset
	fi
	echo

	echo "$magenta > Done, now installing $this_package...$reset"
	echo " > install std log: $install_dir/install_log.txt"
	echo " > install std err: $install_dir/install_err.txt"
	make install 2>$install_dir/install_err.txt 1>"$install_dir/install_log.txt" || whine_and_quit "make install"
	if [ $? -ne 0 ]; then
		echo "make install failed. Install Log: "
		cat $install_dir/install_log.txt
		whine_and_quit "$red $this_package install failure"$reset
	else
		echo "$green > $this_package install successful"$reset
	fi
	echo
	echo "$yellow > Content of $install_dir after installation:"
	ls -l "$install_dir"
	echo
	if [[ -d "$install_dir/lib" ]]; then
		echo "$yellow > Content of $install_dir/lib:"
		ls -l "$install_dir/lib"
	fi
	echo

	# cleanup
	cd # so that we do not delete pwd
	echo "$magenta > Cleaning up: removing $this_package buid and source directories$reset"
	rm -rf "$build_dir" "$source_dir"

	local cmd_end="$SECONDS"
	elapsed=$((cmd_end - cmd_start))

	echo "$green > $this_package compilation and installation completed in «$elapsed» seconds.$reset"
}

function moduleTestResult() {
	local library=$1
	local version=$2

	# we're only interested in the exit status
	module test "$library/$version" &>/dev/null
	echo $?
}

function check_qmake_existance() {
	qmake_path=""
	if command -v qmake6 &>/dev/null; then
		qmake_path=$(command -v qmake6)
	elif command -v qmake &>/dev/null; then
		qmake_path=$(command -v qmake)
	fi
	# if qmake_path is not empty, print log
	if [[ $qmake_path != "" ]]; then
		echo "$green > QMake found at: $qmake_path$reset"
	else
		whine_and_quit "Error: qmake or qmake6 not found. Please install Qt development tools."
	fi
}
