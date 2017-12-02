#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# DO NOT EDIT THIS FILE
# use configuration files like config-default.conf to set the build configuration
# check Armbian documentation for more info

SRC="$(dirname "$(realpath "${BASH_SOURCE}")")"
# fallback for Trusty
[[ -z "${SRC}" ]] && SRC="$(pwd)"

# check for whitespace in $SRC and exit for safety reasons
grep -q "[[:space:]]" <<<"${SRC}" && { echo "\"${SRC}\" contains whitespace. Not supported. Aborting." >&2 ; exit 1 ; }

cd $SRC

if [[ -f $SRC/lib/general.sh && -L $SRC/main.sh ]]; then
	source $SRC/lib/general.sh
else
	echo "Error: missing build directory structure"
	echo "Please clone the full repository https://github.com/armbian/build/"
	exit -1
fi

# copy default config from the template
[[ ! -f $SRC/config-default.conf ]] && cp $SRC/config/templates/config-example.conf $SRC/config-default.conf

# source build configuration file
if [[ -n $2 && -f $SRC/config-$2.conf ]]; then
	display_alert "Using config file" "config-$2.conf" "info"
	source $SRC/config-$2.conf
else
	display_alert "Using config file" "config-default.conf" "info"
	source $SRC/config-default.conf
fi

if [[ $EUID != 0 ]]; then
	display_alert "This script requires root privileges, trying to use sudo" "" "wrn"
	sudo "$SRC/node5.sh" "$@"
	exit $?
fi

if [[ ! -f $SRC/.ignore_changes ]]; then
	echo -e "[\e[0;32m o.k. \x1B[0m] This script will try to update"
	git pull origin master
	CHANGED_FILES=$(git diff --name-only)
	if [[ -n $CHANGED_FILES ]]; then
		echo -e "[\e[0;35m warn \x1B[0m] Can't update since you made changes to: \e[0;32m\n${CHANGED_FILES}\x1B[0m"
		echo -e "Press \e[0;33m<Ctrl-C>\x1B[0m to abort compilation, \e[0;33m<Enter>\x1B[0m to ignore and continue"
		read
	else
		git checkout ${LIB_TAG:- master}
	fi
fi

if [[ $BUILD_ALL == yes || $BUILD_ALL == demo ]]; then
	source $SRC/lib/build-all.sh
else
	source $SRC/lib/node5_main.sh $1
fi
