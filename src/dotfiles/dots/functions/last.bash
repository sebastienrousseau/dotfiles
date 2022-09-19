#!/usr/bin/env bash
# last: List the modified files within 60 minutes.
function last() {
  find . -type f -mmin -60
}
