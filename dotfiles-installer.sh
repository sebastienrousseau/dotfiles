#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - Dotfiles installer.

## 🆅🅰🆁🅸🅰🅱🅻🅴🆂 - Set variables.
BASEDIR="${HOME}/.test_dotfiles"
BACKUPDIR="${BASEDIR}/backup"
DOWNLOADDIR="${HOME}/Downloads"

## 🅱🅰🅲🅺🆄🅿 - Backup existing files.
backup_dotfiles() {
  echo "Creating a backup directory for existing dotfiles..."
  mkdir -p "${BACKUPDIR}"

  echo "Backing up existing dotfiles in ${BACKUPDIR}..."
  # File list (use trailing slash for directories)
  FILES="
  .bashrc
  .curlrc
  .gitattributes
  .gitconfig
  .gitignore
  .gitmessage
  .inputrc
  .npmrc
  .profile
  .tmux.conf
  .vimrc
  .wgetrc
  .yarnrc
  .zshrc
  cacert.pem
  "

  for file in ${FILES}; do
    if [ -e "${HOME}/${file}" ]; then
      echo "Backing up ${file}..."
      cp -f "${HOME}"/"${file}" "${BACKUPDIR}"/"${file}"
    fi
  done
}

## 🅸🅽🆂🆃🅰🅻🅻🅴🆁 - Install dotfiles.
get_installer() {
  echo "Installing Dotfiles v0.2.452"
  wget https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/v0.2.452.zip -O "${DOWNLOADDIR}/v0.2.452.zip"
}

## 🆄🅽🅿🅰🅲🅺 - Unpack installer.
unpack_installer() {
  echo "Unpacking Dotfiles v0.2.452"
  unzip "${DOWNLOADDIR}/v0.2.452.zip" -d "${DOWNLOADDIR}"
  mv "${DOWNLOADDIR}/dotfiles-0.2.452/shell/" "${BASEDIR}"
  rm "${DOWNLOADDIR}/v0.2.452.zip"
}

## 🅼🅰🅸🅽 - Main function.
main() {
  backup_dotfiles &&
  get_installer &&
  unpack_installer &&
  echo "Done!"
}

## 🅸🅽🆂🆃🅰🅻🅻 - Install dotfiles.
run_install() {
  echo "Switching to the Dotfiles directory"
  cd "${BASEDIR}" || exit 1

  echo "Launching the installation script..."
  make help

  ${SHELL}

}

## 🅷🅴🅻🅿 🅼🅴🅽🆄 - Display help menu.
get_help() {
  cat <<EOF

Dotfiles v0.2.452 Installer

OPTIONS:

  -b, --backup    - Backup previous dotfiles from your ${HOME} directory.
  -d, --download  - Download the latest dotfiles package.
  -h, --help      - Show this help menu.
  -i, --install   - Install Dotfiles v0.2.452.
  -e, --execute   - Execute the installation scripts.
  -u, --unpack    - Unpack Dotfiles v0.2.452 package.

EOF
}

if [ "$1" = "-b" ] || [ "$1" = "--backup" ]; then
  backup_dotfiles
elif [ "$1" = "-d" ] || [ "$1" = "--download" ]; then
  get_installer
elif [ "$1" = "-e" ] || [ "$1" = "--execute" ]; then
  main
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  get_help
elif [ "$1" = "-i" ] || [ "$1" = "--install" ]; then
  run_install
elif [ "$1" = "-u" ] || [ "$1" = "--unpack" ]; then
  unpack_installer
else
  get_help
fi
