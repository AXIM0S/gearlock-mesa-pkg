## Ready to use kernel installation script by @AXON
## I strictly provide the rights to use this script with GearLock only.
## For proper developer documentation, visit https://supreme-gamers.com/gearlock
# Check `!zygote.sh` to configure your package functions or gearlock can also guide you during the build process.


#####--- Import Functions ---#####
get_base_dir # Returns execution directory path in $BD variable
check_compat 6.8 # Returns yes in $COMPAT variable if the user is running at least 6.8 GearLock
#####--- Import Functions ---#####


# Since GearLock 6.8 I decided to hold native installation scripts inside gearlock/core instead.
# To overcome the issue of needing to repack kernel packages just to update their install/uninstall scripts.
# It's recommended that you use native-scripts, but if you prefer to add your own functions then you may remove/mask this line.
## Load native scripts
rsync "$CORE/gxpm/mesa-native/uninstall.sh" "$CORE/gxpm/mesa-native/install.sh" "$BD" && exec "$BD/install.sh"


# Since building a mesa library which would work on any android version is quite impossible.
# Thus we must verify the host system android version. An example is given below (variable ref: https://supreme-gamers.com/gearlock/environment-variables)

MESA_ANDROID_VER="7" # Do not use a decimal number for this variable.
if [[ ! "$ANDROID_VER" =~ "$MESA_ANDROID_VER" ]]; then
	
	geco "\n[!!!] This $VERSION Mesa3D drivers we're build for android-${ANDROID_VER}."
	geco "[!!!] But your android version is ${ANDROID_VER}, which could be incompatible with it."
	read -rn1 -p "$(geco "++++ Do you wish to proceed ? [y/${GREEN}N${RC}]") " c
	test "${c,,}" != 'y' && exit 101 #(exit-code ref: https://supreme-gamers.com/gearlock/#install-sh-exit-code)
	
fi


# Do not allow GearLock versions below 6.8
# # if ! check_compat 6.8; then geco "+[!!!] Please update GearLock to install this"; exit 101; fi
test "$COMPAT" != "yes" && geco "\n[!!!] Please update GearLock to install this" && exit 101

# Warning info for installation from GUI to avoid system crash
test "$BOOTCOMP" == "yes" && geco "[!!!] You seem to be installing from a live system, best practice is to install from RECOVERY-MODE.\n"

# Check if /system is writable
! touch -c "$SYSTEM_DIR/lib" >/dev/null 2>&1 && geco "[!!!] $SYSTEM_DIR is not writable, did you ${PINK}SuperCharge${RC} it yet ?" && exit 101



function make_gbscript_updateMesa ()
{

	type main | tail -n+2 > "$GBSCRIPT"
	geco "\nmain \"\$STATDIR/UpdateMesa\"" >> "$GBSCRIPT"

}

function main ()
{

	# Define vars
	DALVIKDIR="/data/dalvik-cache"
	MESA_BACKUP_DIR="$STATDIR/_mesaBackup"
	MESA_BACKUP_FILE="$STATDIR/mesa_stock.bak"
	GBSCRIPT="$GBDIR/init/UpdateMesa"
	MESA_SOURCE="${1:-"$BD/system"}"

	# Define functions
	handleError ()
	{ 
	
		if [ $? != 0 ]; then
			# TODO: Revert back any incomplete changes
			geco "\n[!!!] Error: $1" && exit ${2:-101}
		fi
	
	}

	mesa_native ()
	{
		
		"$CORE/gxpm/mesa-native/job" "$@"
		
	}


	
	if test "$TERMINAL_EMULATOR" == "yes"; then
	
		# Remove any pre-existing UpdateMesa job
		rm -rf "$GBSCRIPT" "$STATDIR/UpdateMesa"  
		geco "\n+ Placing new Mesa dri & dependencie files for BOOT-UPDATE"
		gclone "$MESA_SOURCE/" "$STATDIR/UpdateMesa"; handleError "Failed to place files"
		make_gbscript_updateMesa
	
	else
		
		# Backup mesa
		if [ ! -f "$MESA_BACKUP_FILE" ]; then
			geco "\n+ Backing up stock Mesa dri & dependencies ..."
			mesa_native backup "$MESA_BACKUP_DIR"
			geco ">>>>>> Compressing backup ..."
			( cd "$MESA_BACKUP_DIR"; tar --zstd -cpf "$MESA_BACKUP_FILE" system ); handleError "Failed to backup current Mesa"
			rm -rf "$MESA_BACKUP_DIR"
		fi

		# Cleanup mesa
		geco "\n+ Cleaning up existing Mesa dri & dependencies ..." && mesa_native clean

		# Merge mesa
		geco "\n+ Placing new Mesa dri & dependencie files in your operating-system"
		gclone "$MESA_SOURCE/" "$SYSTEM_DIR"; handleError "Failed to place files"

		# Symlink dri
		geco "\n+ Symlinking dri directories if needed ..." && sleep 1
		for libX in lib lib64; do
			[ -e "$SYSTEM_DIR/$libX/dri" ] && [ ! -e "$SYSTEM_DIR/vendor/$libX/dri" ] && ln -srf "$SYSTEM_DIR/$libX/dri" "$SYSTEM_DIR/vendor/$libX/dri"
			[ -e "$SYSTEM_DIR/vendor/$libX/dri" ] && [ ! -e "$SYSTEM_DIR/$libX/dri" ] && ln -srf "$SYSTEM_DIR/vendor/$libX/dri" "$SYSTEM_DIR/$libX/dri"
		done

		# Clear dalvik-cache
		geco "\n+ Clearing dalvik-cache, it may take a bit long on your next boot" && rm -rf "$DALVIKDIR"/*
		
		# Remove any pre-existing UpdateMesa job
		rm -rf "$GBSCRIPT" "$STATDIR/UpdateMesa"
		
	fi

}

		main
