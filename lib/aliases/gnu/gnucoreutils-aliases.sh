#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462)' - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c)' 2015-2022. All rights reserved
# License: MIT

# 🅶🅽🆄 🅲🅾🆁🅴🆄🆃🅸🅻🆂 🅰🅻🅸🅰🆂🅴🆂
if command -v 'gdate' >/dev/null; then
  alias b2sum=gb2sum         # b2sum: Print or check BLAKE2b (512-bit) checksums.
  alias base32=gbase32       # base32: Base32 encode or decode FILE, or standard input, to standard output.
  alias base64=gbase64       # base64: Base64 encode or decode FILE, or standard input, to standard output.
  alias basename=gbasename   # basename: Print NAME with any leading directory components removed.
  alias basenc=gbasenc       # basenc: Encode or decode FILE, or standard input, to standard output.
  alias cat=gcat             # cat: Concatenate FILE(s), or standard input, to standard output.
  alias chcon=gchcon         # chcon: Change the SELinux security context of each FILE to CONTEXT.
  alias chgrp=gchgrp         # chgrp: Change the group of each FILE to GROUP.
  alias chmod=gchmod         # chmod: Change the mode of each FILE to MODE.
  alias chown=gchownn        # chown: Change the owner and/or group of each FILE to OWNER and/or GROUP.
  alias chroot=gchroot       # chroot: Run COMMAND with root directory set to NEWROOT.
  alias cksum=gcksum         # cksum: Print CRC checksum and byte counts.
  alias comm=gcomm           # comm: Compare two sorted files line by line.
  alias cp=gcp               # cp: Copy SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY.
  alias csplit=gcsplit       # csplit: Split a file into sections determined by context lines.
  alias cut=gcut             # cut: Print selected parts of lines from each FILE to standard output.
  alias date=gdate           # date: Print or set the system date and time.
  alias dd=gdd               # dd: Copy a file, converting and formatting according to the operands.
  alias df=gdf               # df: Report file system disk space usage.
  alias dir=gdir             # dir: List directory contents.
  alias dircolors=gdircolors # dircolors: Convert ls' output colors to dircolors' format.
  alias dirname=gdirname     # dirname: Print NAME with its last non-slash component and trailing slashes removed.
  alias du=gdu               # du: Estimate file space usage.
  alias echo=gecho           # echo: Display a line of text.
  alias env=genv             # env: Print the current environment.
  alias expand=gexpand       # expand: Convert tabs in each FILE to spaces, writing to standard output.
  alias expr=gexpr           # expr: Evaluate EXPRESSION.
  alias factor=gfactor       # factor: Print prime factors of each given number.
  alias false=gfalse         # false: Do nothing, unsuccessfully.
  alias fmt=gfmt             # fmt: Reformat paragraph text.
  alias fold=gfold           # fold: Wrap each input line to fit in specified width.
  alias grep=ggrep           # grep: Print lines matching a pattern.
  alias groups=ggroups       # groups: Print the groups a user is in.
  alias head=ghead           # head: Print the first 10 lines of each FILE to standard output.
  alias hostid=ghostid       # hostid: Print the hostid.
  alias id=gid               # id: Print real and effective user and group IDs.
  alias install=ginstall     # install: Copy files and set attributes.
  alias join=gjoin           # join: Join lines of two files on a common field.
  alias kill=gkill           # kill: Send a signal to a process.
  alias link=glink           # link: Create a link to a file.
  alias ln=gln               # ln: Make links between files.
  alias logname=glogname     # logname: Print the user name associated with the current effective user ID.
  alias ls=gls               # ls: List directory contents.
  alias md5sum=gmd5sum       # md5sum: Print or check MD5 (128-bit) checksums.
  alias mkdir=gmkdir         # mkdir: Create the DIRECTORY(ies), if they do not already exist.
  alias mkfifo=gmkfifo       # mkfifo: Create named pipes (FIFOs) named PIPE.
  alias mknod=gmknod         # mknod: Create special files.
  alias mktemp=gmktemp       # mktemp: Create a temporary file or directory, safely.
  alias mv=gmv               # mv: Move SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY.
  alias nice=gnice           # nice: Run a utility with modified scheduling priority.
  alias nl=gnl               # nl: Number lines of files, writing to standard output.
  alias nohup=gnohup         # nohup: Run a command immune to hangups, with output to a non-tty.
  alias nproc=gnproc         # nproc: Print the number of processing units available.
  alias numfmt=gnumfmt       # numfmt: Reformat numbers.
  alias od=god               # od: Dump a file in octal and other formats.
  alias paste=gpaste         # paste: Merge lines of files.
  alias pathchk=gpathchk     # pathchk: Check whether a file name is valid or portable.
  alias pinky=gpinky         # pinky: Print information about users.
  alias pr=gpr               # pr: Paginate FILE for printing.
  alias printenv=gprintenv   # printenv: Print the current environment.
  alias printf=gprintf       # printf: Format and print data.
  alias ptx=gptx             # ptx: Display the contents of a terminal control file.
  alias pwd=gpwd             # pwd: Print the name of the current working directory.
  alias readlink=greadlink   # readlink: Print value of a symbolic link or canonical file name.
  alias realpath=grealpath   # realpath: Canonicalize existing file names.
  alias rm=grm               # rm: Remove (unlink) the FILE(s).
  alias rmdir=grmdir         # rmdir: Remove the DIRECTORY(ies), if they are empty.
  alias runcon=gruncon       # runcon: Run a command with a different SELinux security context.
  alias sed=gsed             # sed: Stream editor for filtering and transforming text.
  alias seq=gseq             # seq: Print a sequence of numbers.
  alias sha1sum=gsha1sum     # sha1sum: Print or check SHA1 (160-bit) checksums.
  alias sha224sum=gsha224sum # sha224sum: Print or check SHA224 (224-bit) checksums.
  alias sha256sum=gsha256sum # sha256sum: Print or check SHA256 (256-bit) checksums.
  alias sha384sum=gsha384sum # sha384sum: Print or check SHA384 (384-bit) checksums.
  alias sha512sum=gsha512sum # sha512sum: Print or check SHA512 (512-bit) checksums.
  alias shred=gshred         # shred: Overwrite a file to hide its contents, and optionally delete it.
  alias shuf=gshuf           # shuf: Output a random permutation of the input lines.
  alias sleep=gsleep         # sleep: Pause for NUMBER seconds.
  alias sort=gsort           # sort: Sort lines of text files.
  alias split=gsplit         # split: Split a file into pieces.
  alias stat=gstat           # stat: Display file or file system status.
  alias stdbuf=gstdbuf       # stdbuf: Run COMMAND with modified buffering operations for its standard streams.
  alias stty=gstty           # stty: Get and set terminal attributes.
  alias sum=gsum             # sum: Print CRC checksum and byte counts.
  alias sync=gsync           # sync: Invoke sync to flush filesystem buffers.
  alias tac=gtac             # tac: Concatenate and print files in reverse.
  alias tail=gtail           # tail: Output the last part of files.
  alias tee=gtee             # tee: Read from standard input and write to standard output and files.
  alias test=gtest           # test: Evaluate conditional expression.
  alias timeout=gtimeout     # timeout: Run a command with a time limit.
  alias touch=gtouch         # touch: Change file timestamps.
  alias tr=gtr               # tr: Translate, squeeze, and/or delete characters.
  alias true=gtrue           # true: Do nothing, successfully.
  alias truncate=gtruncate   # truncate: Shrink or extend the size of a file to the specified size.
  alias tsort=gtsort         # tsort: Topological sort.
  alias tty=gtty             # tty: Print file name of terminal connected to standard input.
  alias uname=guname         # uname: Print certain system information.
  alias unexpand=gunexpand   # unexpand: Convert spaces in each FILE to tabs, writing to standard output.
  alias uniq=guniq           # uniq: Filter adjacent matching lines from INPUT (or standard input), writing to OUTPUT (or standard output).
  alias unlink=gunlink       # unlink: Call the unlink function to remove the specified FILE.
  alias uptime=guptime       # uptime: Print the current time, the length of time the system has been up, the number of users on the system, and the average number of jobs in the run queue over the last 1, 5 and 15 minutes.
  alias users=gusers         # users: Output who is currently logged in.
  alias vdir=gvdir           # vdir: List information about the FILEs (the current directory by default).
  alias wc=gwc               # wc: Print newline, word, and byte counts for each FILE, and a total line if more than one FILE is specified.
  alias who=gwho             # who: Print information about users who are currently logged in.
  alias whoami=gwhoami       # whoami: Print the user name associated with the current effective user ID.
  alias yes=gyes             # yes: Repeatedly output a line with all specified STRING(s), or 'y'.
fi
