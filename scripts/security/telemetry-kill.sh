#!/bin/sh
set -e

if [ "${DOTFILES_TELEMETRY:-}" != "1" ]; then
  echo "Telemetry script is disabled by default."
  echo "Re-run with DOTFILES_TELEMETRY=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    echo "Disabling Ubuntu crash reporting (whoopsie/apport)..."
    sudo systemctl disable --now whoopsie 2>/dev/null || true
    sudo systemctl disable --now apport 2>/dev/null || true
    sudo systemctl mask apport 2>/dev/null || true
    echo "Disabling popularity-contest (if present)..."
    sudo systemctl disable --now popularity-contest 2>/dev/null || true
    ;;
  Darwin)
    echo "Disabling macOS analytics (manual confirmation may be required)."
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false || true
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist ThirdPartyDataSubmit -bool false || true
    ;;
  *)
    echo "Unsupported OS for telemetry kill."
    exit 1
    ;;
esac
