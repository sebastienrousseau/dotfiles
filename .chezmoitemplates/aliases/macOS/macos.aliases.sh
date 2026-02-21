# shellcheck shell=bash
# macOS Aliases

if [[ "$OSTYPE" == "darwin"* ]]; then

  # --- Finder & Desktop ---

  # Recursively delete .DS_Store files with check
  # alias clds='find . -type f -name "*.DS_Store" -ls -delete'
  alias cleanup_dsstore='find . -type f -name "*.DS_Store" -ls -delete'

  emptytrash() {
    if [[ "${DOTFILES_ENABLE_DANGEROUS_ALIASES:-0}" != "1" ]]; then
      echo "Refusing to empty trash: set DOTFILES_ENABLE_DANGEROUS_ALIASES=1" >&2
      return 1
    fi
    dot_confirm_destructive "rm -rf ${HOME}/.Trash/* (emptytrash)" || return 1
    rm -rf "${HOME}/.Trash/"*
  }

  # Hide/Show Hidden Files
  alias finder_hide='defaults write com.apple.finder ShowAllFiles FALSE; killall Finder'
  alias finder_show='defaults write com.apple.finder ShowAllFiles TRUE; killall Finder'

  # Hide/Show Desktop Icons
  alias desktop_hide='defaults write com.apple.finder CreateDesktop false; killall Finder'
  alias desktop_show='defaults write com.apple.finder CreateDesktop true; killall Finder'

  # Open current directory in Finder
  alias ofd='open $PWD'

  # --- System & Network ---

  alias lockscreen='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'

  # Wireless
  alias wifi_on='networksetup -setairportpower en0 on'
  alias wifi_off='networksetup -setairportpower en0 off'

  # Disk Utilities
  alias verify_perms='diskutil verifyPermissions /'
  alias verify_volume='diskutil verifyVolume /'

  # --- Development ---

  alias xcode='open -a Xcode'
  alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'

  # Clean Xcode DerivedData
  if [[ "${DOTFILES_ENABLE_DANGEROUS_ALIASES:-0}" == "1" ]]; then
    cleanup_xcode() {
      dot_confirm_destructive "rm -rf ~/Library/Developer/Xcode/DerivedData/*" || return 1
      rm -rf ~/Library/Developer/Xcode/DerivedData/*
    }
  fi

  # --- Misc ---

  # Clean up LaunchServices to remove duplicates in the 'Open With' menu
  alias cleanup_ls='
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user && \
    killall Finder
  '

  # Disable .DS_Store compilation on network stores
  alias no_network_ds='defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'

  alias safari_safe='open -a Safari --args -safe-mode'

  # Screensaver
  alias screensaver='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'

fi
