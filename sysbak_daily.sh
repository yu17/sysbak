#!/bin/bash

#rsync -aHAXSP --info=backup0,copy0,del0,flist0,misc2,mount0,name0,progress0,remove0,skip0,stats2,symsafe --delete-delay --no-whole-file --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/var/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/home/*/.gvfs"} / /mnt/System_img/prologue_backup/sysbak_daily

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print Colored Logs
log_info() {
	echo -e "${GREEN}[sysbak]${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}[sysbak] Warning:${NC} $1"
}

log_error(){
	echo -e "${RED}[sysbak] Error:${NC} $1"
}

# Configuration
BACKUP_DIR="ADD_PATH_HERE"
SNAPSHOT_DIR="/.snapshots"

mkdir -p $BACKUP_DIR

# Create new backup
# $1 - backup_path
# $2 - backup_name (the actual name will be constructed as sysbak_$2 and/or sysbak_$2_update
create_backup(){
	local backup_path="$1"
	local backup_name="sysbak_$2"

	btrfs subvolume snapshot -r $backup_path ${SNAPSHOT_DIR}/${backup_name}_update
	log_info "Daily Backup: Taking snapshot of $2($1) at ${SNAPSHOT_DIR}/${backup_name}_update"

	if [ -e ${SNAPSHOT_DIR}/${backup_name} ] && [ -e ${BACKUP_DIR}/${backup_name} ]; then
		log_info "Daily Backup: Incremental backup for $2($1)"
		btrfs send -p ${SNAPSHOT_DIR}/${backup_name} ${SNAPSHOT_DIR}/${backup_name}_update | btrfs receive ${BACKUP_DIR}
	else
		log_warning "Daily Backup: Previous $2($1) backup not found! Creating new backup."
		btrfs send ${SNAPSHOT_DIR}/${backup_name}_update | btrfs receive ${BACKUP_DIR}
	fi

	if [ -e ${SNAPSHOT_DIR}/${backup_name} ]; then
		log_info "Daily Backup: Discarding previous daily backups ${SNAPSHOT_DIR}/${backup_name}"
		btrfs subvolume delete -c ${SNAPSHOT_DIR}/${backup_name}
	fi
	if [ -e ${BACKUP_DIR}/${backup_name} ]; then
		log_info "Daily Backup: Discarding previous daily backups ${BACKUP_DIR}/${backup_name}"
		btrfs subvolume delete -c ${BACKUP_DIR}/${backup_name}
	fi

	log_info "Daily Backup: Renaming updated backups"
	mv ${SNAPSHOT_DIR}/${backup_name}_update ${SNAPSHOT_DIR}/${backup_name}
	mv ${BACKUP_DIR}/${backup_name}_update ${BACKUP_DIR}/${backup_name}

	log_info "Daily Backup: Backup Finished!"
}

create_backup / root
create_backup /home home
sync
