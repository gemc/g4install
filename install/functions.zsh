#!/bin/zsh

# on distros installation module dir is

red=$(   tput setaf 1)
green=$( tput setaf 2)
yellow=$(tput setaf 3)
blue=$(  tput setaf 4)
magenta=$(tput setaf 5)
reset=$( tput sgr0)

# needed otherwise cmake could pick up the system cc
export CC=gcc
export CXX=g++

# should be deprecated soon
repo="https://www.jlab.org/12gev_phys/packages/sources"

n_cpu=$(getconf _NPROCESSORS_ONLN)

whine_and_quit() {
	echo "$red $1 error $reset"
	exit 1
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
			module()  { eval "$("${LMOD_CMD}" zsh "$@")"; }
		elif command -v modulecmd >/dev/null 2>&1; then
			local  mc
			mc="$( command -v modulecmd)"
			module()  { eval "$("${mc}" zsh "$@")"; }
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
		print                 -u2 -- "ERROR: cannot initialize modules"
		return                                                                  1
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
		print               -u2 -- "ERROR: module purge failed"
		return                                                          1
	}
	module load sim_system || {
		print                         -u2 -- "ERROR: module load sim_system failed"
		return                                                                              1
	}
	module load "$what/$version" || {
		print                               -u2 -- "ERROR: module load $what/$version failed"
		return                                                                                        1
	}

	return 0
}

log_general() {
	this_package=$1
	version=$2
	filename=$3
	base_dir=$4
	echo
	echo "> log_general():"
	print -r -- " > Package: «$this_package», version: «$version»"
	print -r -- " > Origin: «$filename»"
	print -r -- " > Destination: «$base_dir»"
	print -r -- " > Multithread Compilation: «$n_cpu»"
}

dir_remove_and_create() {
	dir=$1
	if [ -d "$dir" ]; then
		rm -rf "$dir"
	fi
	mkdir -p "$dir"
}

# run tar options if not macos, otherwise use gnutar
gnutar() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		gtar $@
	else
		tar $@
	fi
}

# contains the container certificate if the installation is done in a container
# notice: both the cacert and the -k option are given here. For some reason the cacert option
# was not enough on fedora line OSes
# see also https://curl.se/docs/sslcerts.html
curl_command() {
	certificate=""
	if [[ -n "$AUTOBUILD" ]]; then
		certificate=" --cacert /etc/pki/ca-trust/source/anchors/JLabCA.crt "
	fi
	curl_options=" -S --location-trusted --progress-bar --retry 4 $certificate $1 -k -O"
	echo
	echo curl options passed: $curl_options
	curl $=curl_options
}

unpack_source_in_directory_from_url() {
	url=$1
	dir=$2
	tar_strip=$3
	# if the fourth argument 'no_remove' is given, do not remove the tarball
	if [ "$#" -eq 4 ]; then
		no_remove=$4
	else
		no_remove=0
	fi
	filename=$(basename "$url")

	echo
	echo " > url: $url"
	echo " > dir: $dir"
	echo " > tar_strip: $tar_strip"
	echo " > filename: $filename"
	echo

	# if no_remove is 1, do not remove the tarball
	if [ "$no_remove" -eq 0 ]; then
		dir_remove_and_create "$dir"
	else
		mkdir -p "$dir"
	fi

	cd "$dir/.." || whine_and_quit "cd $dir"

	echo "$magenta > Fetching source from $url onto $filename$reset"
	rm -f "$filename"
	curl_command "$url" || whine_and_quit "curl failed on $url"
	ls -lrt
	cd "$dir" || whine_and_quit "cd $dir"
	echo "$magenta > gnutar Unpacking ../$filename in $dir$reset"
	gnutar -zxpf "../$filename" --strip-components="$tar_strip"
	ls -lrt "$dir"
	rm -f "$filename"
	echo "$magenta > Done with unpacking $filename"
	echo
}

clone_tag() {
	url=$1
	tag=$2
	destination_dir=$3

	echo
	echo "> clone_tag():"
	print -r -- " > url: «$url»"
	print -r -- " > tag: «$tag»"
	echo " > in directory: $destination_dir"
	echo " > command: git clone -c advice.detachedHead=false --recurse-submodules --single-branch -b $tag $url $destination_dir"

	git clone -c advice.detachedHead=false --recurse-submodules --single-branch -b "$tag" "$url" "$destination_dir" 2>&1 | sed 's/^/   /'
}

meson_install() {
	meson_options=$1
	install_dir=$2

	meson setup build "$meson_options" --wipe
	cd build
	meson configure -Dprefix="$install_dir"
	meson install
}

cmake_build_and_install() {
	source_dir=$1
	build_dir=$2
	install_dir=$3
	cmake_options=$4
	do_not_delete_source=$5

	echo
	echo "> cmake_build_and_install():"
	echo " > source_dir:    $source_dir"
	echo " > build_dir:     $build_dir"
	echo " > install_dir:   $install_dir"
	echo " > cmake_options: $cmake_options"
	# if delete_source is set, do not delete the source directory
	if [ -z "$do_not_delete_source" ]; then
		echo " > Deleting source directory $source_dir after installation"
	fi
	local cmd_start="$SECONDS"

	# install_dir is the base directory containing $build_dir
	dir_remove_and_create "$build_dir"
	cd "$build_dir" || whine_and_quit "cd $build_dir"

	echo
	echo "$magenta > Configuring cmake...$reset"
	cmake -DCMAKE_INSTALL_PREFIX="$install_dir" $=cmake_options "$source_dir" 2>"$install_dir/cmake_err.txt" 1>"$install_dir/cmake_log.txt" || whine_and_quit "  >>> failed: cmake -DCMAKE_INSTALL_PREFIX=$install_dir $=cmake_options $source_dir"
	if [ $? -ne 0 ]; then
		echo "cmake failed. Error Log: "
		cat $install_dir/cmake_err.txt
		echo "cmake failed. Build Log: "
		cat $install_dir/cmake_log.txt
		echo Test Failure
		exit 1
	else
		echo "$blue > cmake Successful"
		echo
		echo
	fi

	echo "$magenta > Done, now building...$reset"
	make -j "$n_cpu" 2>$install_dir/build_err.txt 1>"$install_dir/build_log.txt" || whine_and_quit "make -j $n_cpu"
	if [ $? -ne 0 ]; then
		echo "make failed. Build Log: "
		cat $install_dir/cmake_log.txt
		echo "$red Make Failure"
		exit 1
	else
		echo "$blue > build Successful"
		echo
		echo
	fi

	echo "$magenta > Done, now installing...$reset"
	make install 2>$install_dir/install_err.txt 1>"$install_dir/install_log.txt" || whine_and_quit "make install"
	if [ $? -ne 0 ]; then
		echo "make install failed. Install Log: "
		cat $install_dir/install_log.txt
		echo "$red Make Install Failure"
		exit 1
	else
		echo "$blue > install Successful"
		echo
		echo
	fi
	echo " Content of $install_dir after installation:"
	ls -l "$install_dir"
	if [[ -d "$install_dir/lib" ]]; then
		echo " Content of $install_dir/lib:"
		ls -l "$install_dir/lib"
	fi

	# cleanup
	cd # so that we do not delete pwd
	echo "$magenta > Cleaning up...$reset"
	echo "$magenta > Deleting build directory $build_dir...$reset"
	rm -rf "$build_dir"

	# if delete_source is set, do not delete the source directory
	if [ -z "$do_not_delete_source" ]; then
		echo "$magenta > Deleting source directory $source_dir...$reset"
		rm -rf "$source_dir"
	fi

	# if there is any .tar.gz or .tgz file inside $install_dir, remove it
	find "$install_dir" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tgz" \) -exec echo "Removing:" {} \; -exec rm -f {} \;

	local cmd_end="$SECONDS"
	elapsed=$((cmd_end - cmd_start))

	echo "$magenta > Compilation and installation completed in $elapsed seconds.$reset"
}

function moduleTestResult() {
	library=$1
	version=$2

	# we're only interested in the exit status
	module test "$library/$version" &>/dev/null
	echo $?
}
