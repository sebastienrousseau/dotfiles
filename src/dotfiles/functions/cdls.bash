#! /bin/bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

# cdls: Function cd & ls
cdls() {
    # Add \ because cd loops with alias
if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] The operation completed successfully, directory listing of $1:"
    \cd "$1" || exit;
    ls -lh;
}
