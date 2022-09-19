#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

set -e

# Load configuration files
# shellcheck disable=SC2154
# shellcheck disable=SC3000
# shellcheck disable=SC4000
# shellcheck disable=SC1091
# shellcheck disable=SC2009
# shellcheck disable=SC2181

# chmod u+r+x ./tools/en/*.sh
# Load locales configuration files
# "$(printf '%s' "$LANG" | cut -c 1,2)"

# shellcheck source=/dev/null
. ./02-colors-en.sh

# shellcheck source=/dev/null
. ./03-variables-en.sh

# helpMenuDotfiles: Present the Help Menu.
helpMenuDotfiles() {
  echo "${BPurple}┌──────────────────────────────────────┐${Reset}"
  echo "${BPurple}│                                      │${Reset}"
  echo "${BPurple}│          ${BGreen}DotFiles (v0.2.450)${Reset}${BPurple}         │${Reset}"
  echo "${BPurple}│                                      │${Reset}"
  echo "${BPurple}└──────────────────────────────────────┘${Reset}"
  echo
  echo "${BGreen}[INFO]${Reset}  ${White}Available options:${Reset}"
  echo "
  ${BCyan}[1]${Reset} ${White}Backup an existing Dotfiles folder${Reset}
  ${BCyan}[2]${Reset} ${White}Download the latest Dotfiles release${Reset}
  ${BCyan}[3]${Reset} ${White}Recover a previous Dotfiles folder${Reset}
  ${BCyan}[4]${Reset} ${White}Generate the Dotfiles documentation locally${Reset}
  ${BCyan}[0]${Reset} ${White}Exit menu.${Reset}"
  echo
  echo "${BGreen}[INFO]${Reset}  ${White}Please choose an option and press [ENTER]:${Reset}"
  read -r a
  case $a in
  0) clear exit 0 ;;
  1)
    backupDotfiles
    helpMenuDotfiles
    ;;
  2)
    downloadDotfiles
    helpMenuDotfiles
    ;;
  3)
    recoverDotfiles
    helpMenuDotfiles
    ;;
  4)
    documentDotfiles
    helpMenuDotfiles
    ;;
  *) echo "${Red}[ERROR]${Reset} ${White}Wrong option.${Reset}" ;;
  esac
}

# function to delay script if the specified process is running
waitForProcess() {

  # Declating waitForProcess variables
  processName=$1
  fixedDelay=$2
  terminate=$3

  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Waiting for '$processName' processes to end"
  while pgrep aux | grep "$processName" | grep -v grep /dev/null >log; do

    if [ "$terminate" = "true" ]; then
      echo "${Cyan}[INFO]${Reset}  ${White}$(date) | $(appName) running, terminating $(processpath) ...${Reset}"
      pkill -f "$processName"
      return
    fi

    # If we've been passed a delay we should use it, otherwise we'll create a random delay each run
    if [ ! "$fixedDelay" ]; then
      delay=$(RANDOM % 50 + 10)
    else
      delay=$fixedDelay
    fi

    echo "${Cyan}[INFO]${Reset}  ${White}$(date) |  + Another instance of $processName is running, waiting $delay seconds${Reset}"
    sleep "$delay"
  done

  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | No instances of $processName found, safe to proceed${Reset}"

}

downloadDotfiles() {

  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Starting downloading $(appName)${Reset}"

  # wait for other downloads to complete
  waitForProcess "curl -f"

  #download the file
  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Downloading $(appName)${Reset}"

  cd "$tempDir" || exit
  curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 -L -J -O "$(webUrl)/$(fileVersion)"
  if [ $? = 0 ]; then

    # We have downloaded a file, we need to know what the file is called and what type of file it is
    tempSearchPath="$tempDir/*"
    for f in $tempSearchPath; do
      tempFile=$f
    done

    case $tempFile in

    *.zip | *.ZIP)
      packageType="ZIP"
      ;;

    *)
      # We can't tell what this is by the file name, lets look at the metadata
      echo "${Red}[ERROR]${Reset} ${White}$(date) | Unknown file type $f, analysing metadata${Reset}"
      metadata=$(file "$tempFile")
      if [ "$metadata" = 'Zip archive data' ]; then
        packageType="ZIP"
        mv "$tempFile" "$tempDir/$(fileVersion)"
        tempFile="$tempDir/$(fileVersion)"
      fi
      ;;
    esac

    if [ ! $packageType ]; then
      echo "${Red}[ERROR]${Reset} ${White}Failed to determine temp file type $metadata${Reset}"
      rm -rf "$tempDir"
    else
      echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Downloaded $(app) to $tempDir${Reset}"
      echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Detected install type as $packageType${Reset}"
    fi

  else

    echo "${Red}[ERROR]${Reset} ${White}$(date) | Failure to download $(webUrl)/$(fileVersion)${Reset}"
    exit 1
  fi

}

# backupDotfiles: Create a Backup folder
backupDotfiles() {
  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Starts a one-time backup operation of the existing Dotfiles${Reset}"
  if [ ! -d "$(backupDirectory)" ]; then
    mkdir -p "$(backupDirectory)"
  else
    echo "${Yellow}[WARNING]${Reset} ${White}$(date) | The Dotfiles backup folder seems to already exists.${Reset}"
  fi
  echo "${Green}[SUCCESS]${Reset}  ${White}$(date) | The backup directory '$(backupDirectory)' was successfully created.${Reset}"
}

# documentDotfiles: Start Documentation
documentDotfiles() {
  cd -- "$(dirname "$0")" || exit
  sh './tools/en/dotfiles-setup-en.sh'
}

# recoverDotfiles: Recovers a previous backup folder
recoverDotfiles() {
  echo "${Cyan}[INFO]${Reset} ${White}$(date) | Recovers a previous backup folder${Reset}"
  mkdir -p "$(backupDirectory)"
  echo "${Cyan}[INFO]${Reset}  ${White}$(date) | Wrong option.${Reset}"
}

# startLog: start logging - Output to log file and STDOUT
startLog() {
  if [ ! -d "$HOME/$(logsDirectory)" ]; then

    echo "${Cyan}[INFO]${Reset} ${White}$(date) | Creating $(logsDirectory) to store Dotfiles logs.${Reset}"

    # Switching directory to $HOME and creating Dotfiles logs folder
    cd "$HOME" && mkdir -p "$(logsDirectory)" && touch "$(logFile)"

  else
    echo "${Yellow}[WARNING]${Reset} ${White}$(date) | The Dotfiles logs folder seems to already exists.${Reset}"
  fi

  exec 1>>"$(logFile)"

}

# Initiate logging
# startLog

echo ""
echo "${Cyan}[INFO]${Reset} ${White}$(date) | Logging procedure has started of $(appName) to $(logFile)${Reset}"
echo ""

helpMenuDotfiles
