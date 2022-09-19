#!/usr/bin/env sh
# last: List the modified files within 60 minutes.
function last() {
  find . -type f -mmin -60
}
