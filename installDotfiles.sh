#!/bin/sh
#
#  ____        _   _____ _ _
# |  _ \  ___ | |_|  ___(_) | ___  ___
# | | | |/ _ \| __| |_  | | |/ _ \/ __|
# | |_| | (_) | |_|  _| | | |  __/\__ \
# |____/ \___/ \__|_|   |_|_|\___||___/
#
# DotFiles v0.2.447
# https://dotfiles.io
#
# Description: Script to install the latest DotFiles v0.2.447
#
# Copyright (c) Sebastien Rousseau 2021. All rights reserved
# Licensed under the MIT license
#

# Load configuration files
# shellcheck disable=SC2154
# shellcheck disable=SC3000-SC4000
# shellcheck disable=SC1091
# shellcheck disable=SC2009
# shellcheck disable=SC2181
source "tools/en/dotfiles-colors-en.sh"
source "tools/en/dotfiles-variables-en.sh"

# helpMenuDotfiles: Present the Help Menu.
helpMenuDotfiles() {
  echo "${Green}┌──────────────────────────────────────┐${Reset}" 
  echo "${Green}│                                      │${Reset}"
  echo "${Green}│          ${White}DotFiles v0.2.447${Reset}           │${Reset}"
  echo "${Green}│                                      │${Reset}"
  echo "${Green}└──────────────────────────────────────┘${Reset}"
  echo
  echo "${Cyan}[INFO]${Reset}  ${White}Available options:${Reset}"
  echo "
  ${Green}[1]${Reset} Backup an existing Dotfiles folder
  ${Green}[2]${Reset} Download the latest Dotfiles release
  ${Green}[3]${Reset} Recover a previous Dotfiles folder
  ${Green}[4]${Reset} Generate the Dotfiles documentation locally
  ${Green}[0]${Reset} Exit menu."
  echo
  echo "${Cyan}[INFO]${Reset}  ${White}Please choose an option and press [ENTER]:${Reset}"
  read -r a
    case $a in
      0) clear exit 0 ;;
      1) backupDotfiles ; helpMenuDotfiles ;;
      2) downloadDotfiles; helpMenuDotfiles ;;
      3) recoverDotfiles ; helpMenuDotfiles ;;
      4) documentDotfiles ; helpMenuDotfiles ;;
  *) echo "${Red}[ERROR]${Reset} ${White}Wrong option.${Reset}";;
  esac
}

# function to delay script if the specified process is running
waitForProcess () {

    # Declating waitForProcess variables
    processName=$1
    fixedDelay=$2
    terminate=$3

    echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Waiting for '$processName' processes to end"
    while ps aux | grep "$processName" | grep -v grep &>/dev/null; do

        if [[ $terminate == "true" ]]; then
            echo "${Cyan}[INFO]${Reset}  ${White}$(date) | $appName running, terminating $processpath ...${Reset}"
            pkill -f "$processName"
            return
        fi

        # If we've been passed a delay we should use it, otherwise we'll create a random delay each run
        if [[ ! $fixedDelay ]]; then
            delay=$(( RANDOM % 50 + 10 ))
        else
            delay=$fixedDelay
        fi

        echo "${Cyan}[INFO]${Reset}  ${White}$(date) |  + Another instance of $processName is running, waiting $delay seconds${Reset}"
        sleep "$delay"
    done
    
    echo "${Cyan}[INFO]${Reset}  ${White}$(date) | No instances of $processName found, safe to proceed${Reset}"

}

downloadDotfiles () {

  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Starting downloading $appName${Reset}"

  # wait for other downloads to complete
  waitForProcess "curl -f"

  #download the file
  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Downloading $appName${Reset}"

  cd "$tempDir" || exit
  curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 -L -J -O "$webUrl/$fileVersion"
  if [ $? == 0 ]; then

          # We have downloaded a file, we need to know what the file is called and what type of file it is
          tempSearchPath="$tempDir/*"
          for f in $tempSearchPath; do
              tempFile=$f
          done

          case $tempFile in

          *.zip|*.ZIP)
              packageType="ZIP"
              ;;

          *)
              # We can't tell what this is by the file name, lets look at the metadata
              echo "${Red}[ERROR]${Reset} ${White}$(date) | Unknown file type $f, analysing metadata${Reset}"
              metadata=$(file "$tempFile")
              if [[ "$metadata" == *"Zip archive data"* ]]; then
                  packageType="ZIP"
                  mv "$tempFile" "$tempDir/$fileVersion"
                  tempFile="$tempDir/$fileVersion"
              fi          
              ;;
          esac

          if [[ ! $packageType ]]; then
              echo "${Red}[ERROR]${Reset} ${White}Failed to determine temp file type $metadata${Reset}"
              rm -rf "$tempDir"
          else
              echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Downloaded $app to $tempDir${Reset}"
              echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Detected install type as $packageType${Reset}"
          fi
        
  else
  
      echo "${Red}[ERROR]${Reset} ${White}$(date) | Failure to download $webUrl/$fileVersion${Reset}"
        exit 1
  fi

}

# backupDotfiles: Create a Backup folder
backupDotfiles () {
  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Starts a one-time backup operation of the existing Dotfiles${Reset}"
  if [[ ! -d "$backupDirectory" ]]; then
    mkdir -p "$backupDirectory"
  else
    echo "${Yellow}[WARNING]${Reset} ${White}$(date) | The Dotfiles backup folder seems to already exists.${Reset}"
  fi  
  echo "${Green}[SUCCESS]${Reset}  ${White}$(date) | The backup directory '$backupDirectory' was successfully created.${Reset}"
}

# documentDotfiles: Start Documentation
documentDotfiles () {
  cd -- "$(dirname "$0")" || exit
  sh './tools/en/dotfiles-setup-en.sh'
}

# recoverDotfiles: Recovers a previous backup folder
recoverDotfiles () {
  echo "${Cyan}[INFO]${Reset} ${White}$(date) | Recovers a previous backup folder${Reset}"
  mkdir -p "$backupDirectory"
  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Wrong option.${Reset}"
}

# startLog: start logging - Output to log file and STDOUT
startLog () {
    if [[ ! -d "$HOME/$logsDirectory" ]]; then
        
        echo "${Cyan}[INFO]${Reset} ${White}$(date) | Creating $logsDirectory to store Dotfiles logs.${Reset}"
        
        # Switching directory to $HOME and creating Dotfiles logs folder
        cd "$HOME" && mkdir -p "$logsDirectory" && touch "$logFile"
        
    else
      echo "${Yellow}[WARNING]${Reset} ${White}$(date) | The Dotfiles logs folder seems to already exists.${Reset}"
    fi

    #exec 1>>"$logFile"
    exec 1>>"$logFile"
    
}

# Initiate logging
startLog

echo ""
echo "${Cyan}[INFO]${Reset} ${White}$(date) | Logging procedure has started of $appName to $logFile${Reset}"
echo ""

helpMenuDotfiles
