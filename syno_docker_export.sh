#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
# Shamelessly borrowed from ctrlaltdelete
# https://www.synology-forum.de/threads/docker-container-backup.134937/post-1186059
#
# This uses the same method that Container Manager uses
#
# Works for running and stopped containers
#-----------------------------------------------------------------------------------

# Delete json exports older than X days
DeleteOlder=7

# Specify containers to ignore
# For example:
# IgnoredContainers=(jitsi_jicofo jitsi_jvb jitsi_prosody jitsi_web synology_docviewer_2 synology_docviewer_1)
IgnoredContainers=


#-----------------------------------------------------------------------------------

scriptver="v1.0.0"
script=Synology_Docker_Export
repo="007revad/Synology_Docker_Export"
scriptname=syno_docker_export

ding(){ 
    printf \\a
}

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    ding
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1  # Not running as sudo or root
fi

# Get NAS model
model=$(cat /proc/sys/kernel/syno_hw_version)
#modelname="$model"

# Show script version
#echo -e "$script $scriptver\ngithub.com/$repo\n"
echo "$script $scriptver"

# Get DSM full version
productversion=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION productversion)
buildphase=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildphase)
buildnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION buildnumber)
smallfixnumber=$(/usr/syno/bin/synogetkeyvalue /etc.defaults/VERSION smallfixnumber)

# Show DSM full version and model
if [[ $buildphase == GM ]]; then buildphase=""; fi
if [[ $smallfixnumber -gt "0" ]]; then smallfix="-$smallfixnumber"; fi
echo "$model DSM $productversion-$buildnumber$smallfix $buildphase"


#ExportDate="$(date +%Y-%m-%d_%H-%M)"
ExportDate="$(date +%Y%m%d_%H%M)"

# Get docker share location
# synoshare --get-real-path is case insensitive (docker or Docker both work)
DockerShare="$(synoshare --get-real-path docker)"

if [[ ! -d "${DockerShare}" ]]; then
    ding
    echo -e "\nERROR docker shared folder not found!\n"
    exit 1
else
    ExportDir="${DockerShare}/docker_exports"
fi

[ ! -d "${ExportDir}" ] && mkdir -p "${ExportDir}"

echo -e "\nExporting container settings to ${ExportDir}\n"
# Get list of all containers (running and stopped)
for container in $(docker ps --all --format "{{ .Names }}"); do
    if grep -q "$container" <<< "${IgnoredContainers[@]}" ; then
        echo "Skipping ${container} on ignore list."
        continue
    else
        export_file="${ExportDir:?}/${container}_${ExportDate}.json"
        #echo "Exporting ${container} json to ${ExportDir}"
        echo "Exporting ${container} json"
        # synowebapi -s or --silent does not work
        /usr/syno/bin/synowebapi --exec api=SYNO.Docker.Container.Profile method=export version=1 outfile="$export_file" name="$container" &>/dev/null

        # Check export was successful
        if [[ ! -f "$export_file" ]] || [[ $(stat -c %s "$export_file") -eq "0" ]]; then
            # No file or 0 bytes
            echo "Failed to export $container settings!"
        else
            chmod 660 "${ExportDir:?}/${container}_${ExportDate}.json"
        fi

        # Delete backups older than $DeleteOlder days
        if [[ $DeleteOlder =~ ^[2-9][0-9]?$ ]]; then
            find "$ExportDir" -name "${container,,}_*.json" -mtime +"$DeleteOlder" -exec rm {} \;
        fi
    fi
done

echo -e "\nFinished\n"

exit

