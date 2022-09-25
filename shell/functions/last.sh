#!/usr/bin/env bash
# last: List the modified files within 60 minutes.
last() {
  find . -type f -mmin -60
}
