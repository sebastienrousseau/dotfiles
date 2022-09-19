#!/bin/zsh

# filehead: Function to display the first lines of a file.
filehead () { /usr/bin/xxd -u -g 1 $@ | /usr/bin/head ;}
