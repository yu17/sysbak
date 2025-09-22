#!/bin/bash

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
WEEKLY_DIR="ADD_PATH_HERE"
DAILY_DIR="ADD_PATH_HERE"
RETENTION_DAYS="60"
MINIMAL_INTERVAL_DAYS="3"

# Remove backups after a set time
# $1 - backup name. The weekly backup filename is constucted as "sysbak_$1_$(date +%Y%m%dw%U)"
discard_old_backups() {
	log_info "Discarding backups of $1 older than ${RETENTION_DAYS} days..."

	for file in ${WEEKLY_DIR}/sysbak_$1_*; do
		# Extract the date part of the backup name.
		file_date="${file#*sysbak_$1_}"
		# Match the date part of the file name. (Sanity check)
		if [[ "$file_date" =~ ^[0-9]{8}w[0-9]{2}$ ]]; then
			# Truncate file date to the YYYYMMDD part (first 8 chars)
			file_date="${file_date:0:8}"
			file_date_sec=$(date -d "${file_date}" +%s 2>/dev/null)
			current_date_sec=$(date +%s)
			# Skip if failed to parse the date
			if [ -z $file_date_sec ]; then
				log_warning "Failed to parse date of file ${file}. Skipping."
			else
				# Calculate the age and delete the backup if necessary
				age=$(( (current_date_sec - file_date_sec) / 86400 ))
				if [ $age -gt $RETENTION_DAYS ]; then
					log_info "Discarding backup: $file (age: $age days)"
					#btrfs subvolume delete -c $file
				else
					log_info "Keeping backup: $file (age: $age days)"
				fi
			fi
		fi
	done
}

# Create new backup (via archiving the latest backup from sysbak_daily)
# $1 - backup name. The daily backup is fetched using filename "sysbak_$1". The weekly backup filename is constucted as "sysbak_$1_$(date +%Y%m%dw%U)"
create_backup() {
	local backup_name="sysbak_$1"
	# Ensure that the backup directory exists
	mkdir -p ${WEEKLY_DIR}

	# Skip if backups within $MINIMAL_INTERVAL_DAYS was found
	for (( i=0; i<=$MINIMAL_INTERVAL_DAYS; i++ )) do
		checkdate=$(date --date='-'${i}' day' +%Y%m%dw%U)
		if [ -e ${WEEKLY_DIR}/${backup_name}_${checkdate} ]; then
			log_warning "Rotative Backup Aborted: Recent backup (within ${MINIMAL_INTERVAL_DAYS} days) found!"
			exit 0
		fi
	done

	# Abort if daily backups do not exist
	if ! [ -e ${DAILY_DIR}/${backup_name} ]; then
		log_error "Rotative Backup Aborted: Daily backup not found!"
		exit 1
	fi

	log_info "Rotative Backup: Creating backup ${backup_name}_$(date +%Y%m%dw%U)"
	btrfs subvolume snapshot -r ${DAILY_DIR}/${backup_name} ${WEEKLY_DIR}/${backup_name}_$(date +%Y%m%dw%U)
	log_info "Rotative Backup: Backup Finished Successfully!"
}

discard_old_backups root
discard_old_backups home
create_backup root
create_backup home
sync
