# advanced_patch
# process_patch_file
	eval ${UBOOT_TOOLCHAIN:+env PATH=$UBOOT_TOOLCHAIN:$PATH} ${CROSS_COMPILE}gcc --version | head -1 | tee -a $DEST/debug/install.log
	echo
	local cthreads=$CTHREADS
	[[ $LINUXFAMILY == "marvell" ]] && local MAKEPARA="u-boot.mmc"
	[[ $BOARD == "odroidc2" ]] && local MAKEPARA="ARCH=arm" && local cthreads=""
	eval ${UBOOT_TOOLCHAIN:+env PATH=$UBOOT_TOOLCHAIN:$PATH} 'make $CTHREADS $BOOTCONFIG CROSS_COMPILE="$CROSS_COMPILE"' 2>&1 \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/compilation.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[ -f .config ] && sed -i 's/CONFIG_LOCALVERSION=""/CONFIG_LOCALVERSION="-armbian"/g' .config
	[ -f .config ] && sed -i 's/CONFIG_LOCALVERSION_AUTO=.*/# CONFIG_LOCALVERSION_AUTO is not set/g' .config
	[ -f $SOURCES/$BOOTSOURCEDIR/tools/logos/udoo.bmp ] && cp $SRC/lib/bin/armbian-u-boot.bmp $SOURCES/$BOOTSOURCEDIR/tools/logos/udoo.bmp
	touch .scmversion
	# patch mainline uboot configuration to boot with old kernels
	if [[ $BRANCH == "default" && $LINUXFAMILY == sun*i ]] ; then
		if [ "$(cat $SOURCES/$BOOTSOURCEDIR/.config | grep CONFIG_ARMV7_BOOT_SEC_DEFAULT=y)" == "" ]; then
			echo "CONFIG_ARMV7_BOOT_SEC_DEFAULT=y" >> $SOURCES/$BOOTSOURCEDIR/.config
			echo "CONFIG_OLD_SUNXI_KERNEL_COMPAT=y" >> $SOURCES/$BOOTSOURCEDIR/.config
	fi
	eval ${UBOOT_TOOLCHAIN:+env PATH=$UBOOT_TOOLCHAIN:$PATH} 'make $MAKEPARA $cthreads CROSS_COMPILE="$CROSS_COMPILE"' 2>&1 \
	# NOTE: Fix CC=$CROSS_COMPILE"gcc" before reenabling
	grab_version "$SOURCES/$LINUXSOURCEDIR" "VER"
	eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} ${CROSS_COMPILE}gcc --version | head -1 | tee -a $DEST/debug/install.log
	echo
			eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} 'make $CTHREADS ARCH=$ARCHITECTURE CROSS_COMPILE="$CROSS_COMPILE" silentoldconfig'
			eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} 'make $CTHREADS ARCH=$ARCHITECTURE CROSS_COMPILE="$CROSS_COMPILE" olddefconfig'
		eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} 'make $CTHREADS ARCH=$ARCHITECTURE CROSS_COMPILE="$CROSS_COMPILE" oldconfig'
		eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} 'make $CTHREADS ARCH=$ARCHITECTURE CROSS_COMPILE="$CROSS_COMPILE" menuconfig'
	eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} 'make $CTHREADS ARCH=$ARCHITECTURE CROSS_COMPILE="$CROSS_COMPILE" $TARGETS modules dtbs 2>&1' \
	# produce deb packages: image, headers, firmware, dtb
	eval ${KERNEL_TOOLCHAIN:+env PATH=$KERNEL_TOOLCHAIN:$PATH} 'make -j1 $KERNEL_PACKING KDEB_PKGVERSION=$REVISION LOCALVERSION="-"$LINUXFAMILY \
		KBUILD_DEBARCH=$ARCH ARCH=$ARCHITECTURE DEBFULLNAME="$MAINTAINER" DEBEMAIL="$MAINTAINERMAIL" CROSS_COMPILE="$CROSS_COMPILE" 2>&1 ' \
# advanced_patch <dest> <family> <device> <description>
#
# parameters:
# <dest>: u-boot, kernel
# <family>: u-boot: u-boot, u-boot-neo; kernel: sun4i-default, sunxi-next, ...
# <device>: cubieboard, cubieboard2, cubietruck, ...
# <description>: additional description text
#
# priority:
# $SRC/userpatches/<dest>/<family>/<device>
# $SRC/userpatches/<dest>/<family>
# $SRC/lib/patch/<dest>/<family>/<device>
# $SRC/lib/patch/<dest>/<family>
#
advanced_patch () {

	local dest=$1
	local family=$2
	local device=$3
	local description=$4

	display_alert "Started patching process for" "$dest $description" "info"
	display_alert "Looking for user patches in" "userpatches/$dest/$family" "info"

	local names=()
	local dirs=("$SRC/userpatches/$dest/$family/$device" "$SRC/userpatches/$dest/$family" "$SRC/lib/patch/$dest/$family/$device" "$SRC/lib/patch/$dest/$family")

	# required for "for" command
	shopt -s nullglob dotglob
	# get patch file names
	for dir in "${dirs[@]}"; do
		for patch in $dir/*.patch; do
			names+=($(basename $patch))
		done
	done
	# remove duplicates
	local names_s=($(echo "${names[@]}" | tr ' ' '\n' | LC_ALL=C sort -u | tr '\n' ' '))
	# apply patches
	for name in "${names_s[@]}"; do
		for dir in "${dirs[@]}"; do
			if [[ -f $dir/$name || -L $dir/$name ]]; then
				if [[ -s $dir/$name ]]; then
					process_patch_file "$dir/$name" "$description"
				else
					display_alert "... $name" "skipped" "info"
				fi
				break # next name
			fi
		done
	done
}

# process_patch_file <file> <description>
#
# parameters:
# <file>: path to patch file
# <description>: additional description text
#
process_patch_file() {

	local patch=$1
	local description=$2

	# detect and remove files which patch will create
	LANGUAGE=english patch --batch --dry-run -p1 -N < $patch | grep create \
		| awk '{print $NF}' | sed -n 's/,//p' | xargs -I % sh -c 'rm %'
	# main patch command
	echo "$patch $description" >> $DEST/debug/install.log
	patch --batch --silent -p1 -N < $patch >> $DEST/debug/install.log 2>&1

	if [ $? -ne 0 ]; then
		display_alert "... $(basename $patch)" "failed" "wrn";
		if [[ $EXIT_PATCHING_ERROR == "yes" ]]; then exit_with_error "Aborting due to" "EXIT_PATCHING_ERROR"; fi
	else
		display_alert "... $(basename $patch)" "succeeded" "info"
	fi
}

install_external_applications ()
{
display_alert "Installing extra applications and drivers" "" "info"
# cleanup for install_kernel and install_board_specific
umount $CACHEDIR/sdcard/tmp >/dev/null 2>&1

for plugin in $SRC/lib/extras/*.sh; do
	source $plugin
done
	make clean >/dev/null
	make ARCH=$ARCHITECTURE CC="${CROSS_COMPILE}gcc" KSRC="$SOURCES/$LINUXSOURCEDIR/" >> $DEST/debug/compilation.log 2>&1

	make ARCH=$ARCHITECTURE CC="${CROSS_COMPILE}gcc" KSRC="$SOURCES/$LINUXSOURCEDIR/" >> $DEST/debug/compilation.log 2>&1
# h3disp/sun8i-corekeeper.sh for sun8i/3.4.x
if [ "${LINUXFAMILY}" = "sun8i" -a "${BRANCH}" = "default" ]; then
	install -m 755 "$SRC/lib/scripts/sun8i-corekeeper.sh" "$CACHEDIR/sdcard/usr/local/bin"
	sed -i 's|^exit\ 0$|/usr/local/bin/sun8i-corekeeper.sh \&\n\n&|' "$CACHEDIR/sdcard/etc/rc.local"