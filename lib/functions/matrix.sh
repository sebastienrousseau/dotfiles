#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# matrix: Function to Enable Matrix Effect in the terminal
matrix() {
  printf '\e[1;40m'
  clear
  while : || true; do
    echo "${LINES} ${COLUMNS} $((RANDOM % COLUMNS)) $((RANDOM % 72))"
    sleep 0.05 || true
  done | awk '{ letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"; c=$4; letter=substr(letters,c,1);a[$3]=0;for (x in a) {o=a[x];a[x]=a[x]+1; printf "\033[%s;%sH\033[2;32m%s",o,x,letter; printf "\033[%s;%sH\033[1;37m%s\033[0;0H",a[x],x,letter;if (a[x] >= $1) { a[x]=0; } }}'
}

# matrix: Function to Enable Matrix Effect in the terminal in color
matrix_color() {
  printf '\e[1;40m'
  clear
  while : || true; do
    echo "${LINES} ${COLUMNS} $((RANDOM % COLUMNS)) $((RANDOM % 72))"
    sleep 0.05 || true
  done | awk '{
    letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()";
    c=$4;
    letter=substr(letters,c,1);
    a[$3]=0;
    for (x in a) {
      o=a[x];
      a[x]=a[x]+1;
      color="\033[38;5;" int(rand()*255) "m";
      printf "\033[%s;%sH%s%s",o,x,color,letter;
      printf "\033[%s;%sH\033[0m%s\033[0;0H",a[x],x,letter;
      if (a[x] >= $1) {
        a[x]=0;
      }
    }
  }'
}
