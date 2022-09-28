#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451)

# # function to delay script if the specified process is running
# waitForProcess() {

#   # Declating waitForProcess variables
#   processName=$1
#   fixedDelay=$2
#   terminate=$3

#   echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Waiting for '$processName' processes to end"
#   while pgrep aux | grep "$processName" | grep -v grep /dev/null >log; do

#     if [ "$terminate" = "true" ]; then
#       echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | $(appName) running, terminating $(processpath) ...${Reset}"
#       pkill -f "$processName"
#       return
#     fi

#     # If we've been passed a delay we should use it, otherwise we'll create a random delay each run
#     if [ ! "$fixedDelay" ]; then
#       delay=$(RANDOM % 50 + 10)
#     else
#       delay=$fixedDelay
#     fi

#     echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) |  + Another instance of $processName is running, waiting $delay seconds${Reset}"
#     sleep "$delay"
#   done

#   echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | No instances of $processName found, safe to proceed${Reset}"

# }

# downloadDotfiles() {

#   echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Starting downloading $(appName)${Reset}"

#   # wait for other downloads to complete
#   waitForProcess "curl -f"

#   #download the file
#   echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Downloading $(appName)${Reset}"

#   cd "$(tempDir)" || exit
#   curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 -L -J -O "$(webUrl)/$(fileVersion)"
#   if [ $? = 0 ]; then

#     # We have downloaded a file, we need to know what the file is called and what type of file it is
#     tempSearchPath="$(tempDir)/*"
#     for f in $tempSearchPath; do
#       tempFile=$f
#     done

#     case $tempFile in

#     *.zip | *.ZIP)
#       packageType="ZIP"
#       ;;

#     *)
#       # We can't tell what this is by the file name, lets look at the metadata
#       echo "${IRed}[ERROR]${Reset} ${IWhite}$(date) | Unknown file type $f, analysing metadata${Reset}"
#       metadata=$(file "$tempFile")
#       if [ "$metadata" = 'Zip archive data' ]; then
#         packageType="ZIP"
#         mv "$tempFile" "$(tempDir)/$(fileVersion)"
#         tempFile="$(tempDir)/$(fileVersion)"
#       fi
#       ;;
#     esac

#     if [ ! $packageType ]; then
#       echo "${IRed}[ERROR]${Reset} ${IWhite}Failed to determine temp file type $metadata${Reset}"
#       rm -rf "$(tempDir)"
#     else
#       echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Downloaded $(app) to $tempDir${Reset}"
#       echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Detected install type as $packageType${Reset}"
#     fi

#   else

#     echo "${IRed}[ERROR]${Reset} ${IWhite}$(date) | Failure to download $(webUrl)/$(fileVersion)${Reset}"
#     exit 1
#   fi

# }

# # backupDotfiles: Create a Backup folder
# backupDotfiles() {
#   echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Starts a one-time backup operation of the existing Dotfiles${Reset}"
#   if [ ! -d "$(backupDirectory)" ]; then
#     mkdir -p "$(backupDirectory)"
#   else
#     echo "${IYellow}[WARNING]${Reset} ${IWhite}$(date) | The Dotfiles backup folder seems to already exists.${Reset}"
#   fi
#   echo "${IGreen}[SUCCESS]${Reset}  ${IWhite}$(date) | The backup directory '$(backupDirectory)' was successfully created.${Reset}"
# }

# # documentDotfiles: Start Documentation
# documentDotfiles() {
#   cd -- "$(dirname "$0")" || exit
#   sh './tools/"${lang}"/05-setup-en.sh'
# }

# # recoverDotfiles: Recovers a previous backup folder
# recoverDotfiles() {
#   echo "${ICyan}[INFO]${Reset} ${IWhite}$(date) | Recovers a previous backup folder${Reset}"
#   mkdir -p "$(backupDirectory)"
#   echo "${ICyan}[INFO]${Reset}  ${IWhite}$(date) | Wrong option.${Reset}"
# }

# # startLog: start logging - Output to log file and STDOUT
# startLog() {
#   if [ ! -d "$HOME/$(logsDirectory)" ]; then

#     echo "${ICyan}[INFO]${Reset} ${IWhite}$(date) | Creating $(logsDirectory) to store Dotfiles logs.${Reset}"

#     # Switching directory to $HOME and creating Dotfiles logs folder
#     cd "$HOME" && mkdir -p "$(logsDirectory)" && touch "$(logFile)"

#   else
#     echo "${IYellow}[WARNING]${Reset} ${IWhite}$(date) | The Dotfiles logs folder seems to already exists.${Reset}"
#   fi

#   exec 1>>"${logFile}"

# }

# # Initiate logging
# # startLog

# echo ""
# echo "${IWhite}[INFO]${Reset} ${IWhite}$(date)${Reset}"
# echo "${IWhite}[INFO]${Reset} ${IWhite}Logging procedure has started of ${appName} to '${logFile}${Reset}'"
# echo ""

# helpMenuDotfiles

# Load configuration files
# shellcheck disable=SC2154
# shellcheck disable=SC2002
# shellcheck disable=SC3000
# shellcheck disable=SC4000
# shellcheck disable=SC1091

# shellcheck source=/dev/null
. ./installer/colors.sh

# shellcheck source=/dev/null
. ./installer/utilities.sh

# Create the setup function
# setup() {
  # if [ -f ./07-docs-en.sh ]; then
  #   ./07-docs-en.sh
  # else
  #   error "$LINENO: File \"${0}\" not found. Check the file name and try again. "
  # fi
# }

# Call the setup function
# setup
