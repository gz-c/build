# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

# This file is a part of the Armbian build script
# https://github.com/armbian/build/

# Main program
#

if [[ $(basename $0) == main.sh ]]; then
	echo "Please use compile.sh to start the build process"
	exit -1
fi

# default umask for root is 022 so parent directories won't be group writeable without this
# this is used instead of making the chmod in prepare_host() recursive
umask 002

# destination
DEST=$SRC/output

TTY_X=$(($(stty size | awk '{print $2}')-6)) # determine terminal width
TTY_Y=$(($(stty size | awk '{print $1}')-6)) # determine terminal height

# We'll use this title on all menus
backtitle="Armbian building script, http://www.armbian.com | Author: Igor Pecovnik"

# if language not set, set to english
[[ -z $LANGUAGE ]] && export LANGUAGE="en_US:en"

# default console if not set
[[ -z $CONSOLE_CHAR ]] && export CONSOLE_CHAR="UTF-8"

[[ -z $FORCE_CHECKOUT ]] && FORCE_CHECKOUT=yes

# Load libraries
source $SRC/lib/debootstrap-ng.sh 			# System specific install
source $SRC/lib/image-helpers.sh			# helpers for OS image building
source $SRC/lib/distributions.sh 			# System specific install
source $SRC/lib/desktop.sh 				# Desktop specific install
source $SRC/lib/compilation.sh 				# Patching and compilation of kernel, uboot, ATF
source $SRC/lib/makeboarddeb.sh 			# Create board support package
source $SRC/lib/general.sh				# General functions
source $SRC/lib/chroot-buildpackages.sh			# Building packages in chroot

# compress and remove old logs
mkdir -p $DEST/debug
(cd $DEST/debug && tar -czf logs-$(<timestamp).tgz *.log) > /dev/null 2>&1
rm -f $DEST/debug/*.log > /dev/null 2>&1
date +"%d_%m_%Y-%H_%M_%S" > $DEST/debug/timestamp
# delete compressed logs older than 7 days
(cd $DEST/debug && find . -name '*.tgz' -mtime +7 -delete) > /dev/null

# Script parameters handling
for i in "$@"; do
	if [[ $i == *=* ]]; then
		parameter=${i%%=*}
		value=${i##*=}
		display_alert "Command line: setting $parameter to" "${value:-(empty)}" "info"
		eval $parameter=$value
	fi
done

if [[ $BETA == yes ]]; then
	IMAGE_TYPE=nightly
elif [[ $BETA == no && $BUILD_ALL == yes && -n $GPG_PASS ]]; then
	IMAGE_TYPE=stable
else
	IMAGE_TYPE=user-built
fi

if [[ $PROGRESS_DISPLAY == none ]]; then
	OUTPUT_VERYSILENT=yes
elif [[ $PROGRESS_DISPLAY == dialog ]]; then
	OUTPUT_DIALOG=yes
fi
if [[ $PROGRESS_LOG_TO_FILE != yes ]]; then unset PROGRESS_LOG_TO_FILE; fi

SHOW_WARNING=yes
CAN_BUILD_STRETCH=yes

if [[ $USE_CCACHE != no ]]; then
	CCACHE=ccache
	export PATH="/usr/lib/ccache:$PATH"
	# private ccache directory to avoid permission issues when using build script with "sudo"
	# see https://ccache.samba.org/manual.html#_sharing_a_cache for alternative solution
	[[ $PRIVATE_CCACHE == yes ]] && export CCACHE_DIR=$SRC/cache/ccache
else
	CCACHE=""
fi

# Check and install dependencies, directory structure and settings
prepare_host

# if KERNEL_ONLY, KERNEL_CONFIGURE, BOARD, BRANCH or RELEASE are not set, display selection menu

if [[ -z $KERNEL_ONLY ]]; then
	KERNEL_ONLY="no"
	[[ -z $KERNEL_ONLY ]] && exit_with_error "No option selected"
fi


if [[ -z $KERNEL_CONFIGURE ]]; then
	KERNEL_CONFIGURE="no"
	[[ -z $KERNEL_CONFIGURE ]] && exit_with_error "No option selected"

fi

if [[ -z $BOARD ]]; then
	WIP_STATE=supported
	WIP_BUTTON='CSC/WIP/EOS'
	STATE_DESCRIPTION=' - Officially supported boards'
	[[ $EXPERT = yes ]] && DIALOG_EXTRA="--extra-button"
	temp_rc=$(mktemp)
	while true; do
		options=()
		if [[ $WIP_STATE == supported ]]; then
			for board in $SRC/config/boards/*.conf; do
				options+=("$(basename $board | cut -d'.' -f1)" "$(head -1 $board | cut -d'#' -f2)")
			done
		else
			for board in $SRC/config/boards/*.wip; do
				options+=("$(basename $board | cut -d'.' -f1)" "\Z1(WIP)\Zn $(head -1 $board | cut -d'#' -f2)")
			done
			for board in $SRC/config/boards/*.csc; do
				options+=("$(basename $board | cut -d'.' -f1)" "\Z1(CSC)\Zn $(head -1 $board | cut -d'#' -f2)")
			done
			for board in $SRC/config/boards/*.eos; do
				options+=("$(basename $board | cut -d'.' -f1)" "\Z1(EOS)\Zn $(head -1 $board | cut -d'#' -f2)")
			done
		fi
		if [[ $WIP_STATE != supported ]]; then
			cat <<-'EOF' > $temp_rc
			dialog_color = (RED,WHITE,OFF)
			screen_color = (WHITE,RED,ON)
			tag_color = (RED,WHITE,ON)
			item_selected_color = (WHITE,RED,ON)
			tag_selected_color = (WHITE,RED,ON)
			tag_key_selected_color = (WHITE,RED,ON)
			EOF
		else
			echo > $temp_rc
		fi
		# BOARD=$(DIALOGRC=$temp_rc dialog --stdout --title "Choose a board" --backtitle "$backtitle" --scrollbar --colors \
		# 	--extra-label "Show $WIP_BUTTON" $DIALOG_EXTRA --menu "Select the target board. Displaying:\n$STATE_DESCRIPTION" \
		# 	$TTY_Y $TTY_X $(($TTY_Y - 8)) "${options[@]}")
		BOARD="orangepiprime"
		STATUS=$?
		display_alert "STATUS" "$STATUS" "info"
		if [[ $STATUS == 3 ]]; then
			if [[ $WIP_STATE == supported ]]; then
				[[ $SHOW_WARNING == yes ]] && show_developer_warning
				STATE_DESCRIPTION=' - \Z1(CSC)\Zn - Community Supported Configuration\n - \Z1(WIP)\Zn - Work In Progress\n - \Z1(EOS)\Zn - End Of Support'
				WIP_STATE=unsupported
				WIP_BUTTON='supported'
			else
				STATE_DESCRIPTION=' - Officially supported boards'
				WIP_STATE=supported
				WIP_BUTTON='CSC/WIP/EOS'
			fi
			continue
		elif [[ $STATUS == 0 ]]; then
			break
		fi
		unset options
		[[ -z $BOARD ]] && exit_with_error "No board selected"
	done
fi
if [[ -f $SRC/config/boards/${BOARD}.conf ]]; then
	BOARD_TYPE='conf'
elif [[ -f $SRC/config/boards/${BOARD}.csc ]]; then
	BOARD_TYPE='csc'
elif [[ -f $SRC/config/boards/${BOARD}.wip ]]; then
	BOARD_TYPE='wip'
elif [[ -f $SRC/config/boards/${BOARD}.eos ]]; then
	BOARD_TYPE='eos'
fi

source $SRC/config/boards/${BOARD}.${BOARD_TYPE}

[[ -z $KERNEL_TARGET ]] && exit_with_error "Board configuration does not define valid kernel config"

if [[ -z $BRANCH ]]; then
	BRANCH="next"
	unset options
	[[ -z $BRANCH ]] && exit_with_error "No kernel branch selected"
	[[ $BRANCH == dev && $SHOW_WARNING == yes ]] && show_developer_warning
else
	[[ $KERNEL_TARGET != *$BRANCH* ]] && exit_with_error "Kernel branch not defined for this board" "$BRANCH"
fi

if [[ $KERNEL_ONLY != yes && -z $RELEASE ]]; then
	RELEASE="jessie"
	[[ -z $RELEASE ]] && exit_with_error "No release selected"
fi

if [[ $KERNEL_ONLY != yes && -z $BUILD_DESKTOP ]]; then
	BUILD_DESKTOP="no"
	[[ -z $BUILD_DESKTOP ]] && exit_with_error "No option selected"
fi

IS_MANAGER="no"

if [[ $IS_MANAGER != yes ]]; then
	MANAGER_CONFIG="192.168.0.2"
fi

NETWORK_ADDRESS="192.168.0.6"
NETWORK_NETMASK="255.255.255.0"
NETWORK_GATEWAY="192.168.0.254"


source $SRC/lib/configuration.sh

# optimize build time with 100% CPU usage
CPUS=$(grep -c 'processor' /proc/cpuinfo)
if [[ $USEALLCORES != no ]]; then
	CTHREADS="-j$(($CPUS + $CPUS/2))"
else
	CTHREADS="-j1"
fi

start=`date +%s`

[[ $CLEAN_LEVEL == *sources* ]] && cleaning "sources"

# ignore updates help on building all images - for internal purposes
# fetch_from_repo <url> <dir> <ref> <subdir_flag>
if [[ $IGNORE_UPDATES != yes ]]; then
	display_alert "Downloading sources" "" "info"
	fetch_from_repo "$BOOTSOURCE" "$BOOTDIR" "$BOOTBRANCH" "yes"
	fetch_from_repo "$KERNELSOURCE" "$KERNELDIR" "$KERNELBRANCH" "yes"
	if [[ -n $ATFSOURCE ]]; then
		fetch_from_repo "$ATFSOURCE" "$ATFDIR" "$ATFBRANCH" "yes"
	fi
	fetch_from_repo "https://github.com/linux-sunxi/sunxi-tools" "sunxi-tools" "branch:master"
	fetch_from_repo "https://github.com/armbian/config" "armbian-config" "branch:dev"
	fetch_from_repo "https://github.com/rockchip-linux/rkbin" "rkbin-tools" "branch:master"
	fetch_from_repo "https://github.com/MarvellEmbeddedProcessors/A3700-utils-marvell" "marvell-tools" "branch:A3700_utils-armada-17.10"
	fetch_from_repo "https://github.com/armbian/odroidc2-blobs" "odroidc2-blobs" "branch:master"
	fetch_from_repo "https://github.com/vyloy/skywire" "skywire" "branch:master"
fi

compile_sunxi_tools
install_rkbin_tools

BOOTSOURCEDIR=$BOOTDIR/${BOOTBRANCH##*:}
LINUXSOURCEDIR=$KERNELDIR/${KERNELBRANCH##*:}
[[ -n $ATFSOURCE ]] && ATFSOURCEDIR=$ATFDIR/${ATFBRANCH##*:}

# define package names
DEB_BRANCH=${BRANCH//default}
# if not empty, append hyphen
DEB_BRANCH=${DEB_BRANCH:+${DEB_BRANCH}-}
CHOSEN_UBOOT=linux-u-boot-${DEB_BRANCH}${BOARD}
CHOSEN_KERNEL=linux-image-${DEB_BRANCH}${LINUXFAMILY}
CHOSEN_ROOTFS=linux-${RELEASE}-root-${DEB_BRANCH}${BOARD}
CHOSEN_KSRC=linux-source-${BRANCH}-${LINUXFAMILY}

for option in $(tr ',' ' ' <<< "$CLEAN_LEVEL"); do
	[[ $option != sources ]] && cleaning "$option"
done

# Compile u-boot if packed .deb does not exist
if [[ ! -f $DEST/debs/${CHOSEN_UBOOT}_${REVISION}_${ARCH}.deb ]]; then
	if [[ -n $ATFSOURCE ]]; then
		compile_atf
	fi
	compile_uboot
fi

# Compile kernel if packed .deb does not exist
if [[ ! -f $DEST/debs/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb ]]; then
	compile_kernel
fi

overlayfs_wrapper "cleanup"

# extract kernel version from .deb package
VER=$(dpkg --info $DEST/debs/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb | grep Descr | awk '{print $(NF)}')
VER="${VER/-$LINUXFAMILY/}"

# create board support package
[[ -n $RELEASE && ! -f $DEST/debs/$RELEASE/${CHOSEN_ROOTFS}_${REVISION}_${ARCH}.deb ]] && create_board_package

# build additional packages
[[ $EXTERNAL_NEW == compile ]] && chroot_build_packages

if [[ $KERNEL_ONLY != yes ]]; then
	debootstrap_ng
else
	display_alert "Kernel build done" "@host" "info"
	display_alert "Target directory" "$DEST/debs/" "info"
	display_alert "File name" "${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb" "info"
fi

# hook for function to run after build, i.e. to change owner of $SRC
# NOTE: this will run only if there were no errors during build process
[[ $(type -t run_after_build) == function ]] && run_after_build || true

end=`date +%s`
runtime=$(((end-start)/60))
display_alert "Runtime" "$runtime min" "info"
