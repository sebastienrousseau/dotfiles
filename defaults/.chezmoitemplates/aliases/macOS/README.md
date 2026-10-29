# macOS Aliases

Manage macOS aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `macos.aliases.sh` and `vscode.aliases.sh`. Loaded only on macOS, by the eager alias layer `~/.config/shell/90-ux-aliases.sh`.

## Aliases

### `macos.aliases.sh`

Every definition in this file also checks that `$OSTYPE` is `darwin*`.

| Name | Definition | Notes |
| --- | --- | --- |
| `cleanup_dsstore` | `find . -type f -name "*.DS_Store" -ls -delete` | Recursively delete `.DS_Store` files, listing each one. |
| `emptytrash` | function | Ask for confirmation, then empty `~/.Trash`. Refuses unless `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |
| `finder_hide` | `defaults write com.apple.finder ShowAllFiles FALSE; killall Finder` | Hide hidden files in Finder. |
| `finder_show` | `defaults write com.apple.finder ShowAllFiles TRUE; killall Finder` | Show hidden files in Finder. |
| `desktop_hide` | `defaults write com.apple.finder CreateDesktop false; killall Finder` | Hide desktop icons. |
| `desktop_show` | `defaults write com.apple.finder CreateDesktop true; killall Finder` | Show desktop icons. |
| `ofd` | `open $PWD` | Open current directory in Finder. |
| `lockscreen` | `/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend` | Lock the screen. |
| `wifi_on` | `networksetup -setairportpower en0 on` | Turn Wi-Fi on (`en0`). |
| `wifi_off` | `networksetup -setairportpower en0 off` | Turn Wi-Fi off (`en0`). |
| `verify_perms` | `diskutil verifyPermissions /` | Verify disk permissions. |
| `verify_volume` | `diskutil verifyVolume /` | Verify the boot volume. |
| `xcode` | `open -a Xcode` | Open Xcode. |
| `iphone` | `open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app` | Open the iOS Simulator. |
| `cleanup_xcode` | function | Ask for confirmation, then remove Xcode DerivedData. Only when `DOTFILES_ENABLE_DANGEROUS_ALIASES=1`. |
| `cleanup_ls` | `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder` | Clean up LaunchServices to remove duplicates in the 'Open With' menu. |
| `no_network_ds` | `defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true` | Disable .DS_Store compilation on network stores. |
| `safari_safe` | `open -a Safari --args -safe-mode` | Open Safari in safe mode. |
| `screensaver` | `/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background` | Start the screensaver. |

### `vscode.aliases.sh`

Defined only when `code` is on PATH or the bundle's `code` is executable, and `uname` reports Darwin.

| Name | Definition | Notes |
| --- | --- | --- |
| `code` | `/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code` | Point `code` at the VS Code app bundle. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
