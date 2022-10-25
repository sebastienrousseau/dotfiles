# GNU coreutils aliases

The `gnucoreutls-aliases.sh` file creates helpful shortcut aliases for many commonly used [GNU coreutils][coreutils] commands. The GNU Core Utilities are
the basic file, shell and text manipulation utilities of the GNU operating
system.

These are the core utilities which are expected to exist on every operating
system.

## 🆕 GNU coreutils aliases

| Alias | Command | Description |
|---|---|---|
| awk | `gawk` | Pattern-directed scanning and processing language. |
| b2sum | `gb2sum` | Compute and check BLAKE2b checksums. |
| base32 | `gbase32` | Base32 encode or decode FILE, or standard input, to standard output. |
| base64 | `gbase64` | Base64 encode or decode FILE, or standard input, to standard output. |
| basename | `gbasename` | Strip directory and suffix from FILEs. |
| basenc | `gbasenc` | Encode or decode FILE, or standard input, to standard output. |
| cat | `gcat` | Concatenate FILE(s), or standard input, to standard output. |
| chcon | `gchcon` | Change the SELinux security context of each FILE to CONTEXT. |
| chown | `gchown` | Change the owner and/or group of each FILE to OWNER and/or GROUP. |
| chroot | `gchroot` | Run COMMAND with root directory set to NEWROOT. |
| cksum | `gcksum` | Print CRC checksum and byte counts. |
| comm | `gcomm` | Compare two sorted files line by line. |
| cp | `gcp` | Copy SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY. |
| csplit | `gcsplit` | Split a file into sections determined by context lines. |
| cut | `gcut` | Print selected parts of lines from each FILE to standard output. |
| date | `gdate` | Print or set the system date and time. |
| dd | `gdd` | Convert and copy a file, converting and formatting according to the operands. |
| df | `gdf` | Report file system disk space usage. |
| dir | `gdir` | List directory contents. |
| dircolors | `gdircolors` | Color setup for ls. |
| dirname | `gdirname` | Print each FILE's directory. |
| diff | `gdiff` | Report differences between two files. |
| du | `gdu` | Estimate file space usage. |
| echo | `gecho` | Display a line of text. |
| env | `genv` | Run a program in a modified environment. |
| expand | `gexpand` | Convert tabs to spaces. |
| expr | `gexpr` | Evaluate expressions. |
| factor | `gfactor` | Print the prime factors of each number given. |
| false | `gfalse` | Do nothing, unsuccessfully. |
| fmt | `gfmt` | Reformat paragraph text. |
| fold | `gfold` | Wrap each input line to fit in specified width. |
| head | `ghead` | Output the first part of files. |
| hostid | `ghostid` | Print the numeric host identifier. |
| id | `gid` | Print real and effective user and group IDs. |
| install | `ginstall` | Copy files and set attributes. |
| join | `gjoin` | Join lines of two files on a common field. |
| link | `glink` | Create a link to a file. |
| ln | `gln` | Make links between files. |
| logname | `glogname` | Print current user name. |
| ls | `gls` | List directory contents. |
| make | `gmake` | GNU version of the 'make' utility. |
| md5sum | `gmd5sum` | Compute and check MD5 message digest. |
| mkdir | `gmkdir` | Make directories. |
| mkfifo | `gmkfifo` | Make FIFOs (named pipes). |
| mknod | `gmknod` | Make block or character special files. |
| mktemp | `gmktemp` | Create a temporary file or directory. |
| mv | `gmv` | Move (rename) SOURCE to DEST, or multiple SOURCE(s) to DIRECTORY. |
| nice | `gnice` | Run a utility with modified scheduling priority. |
| nl | `gnl` | Number lines of files. |
| nohup | `gnohup` | Run a command immune to hangups, with output to a non-tty. |
| nproc | `gnproc` | Print the number of processing units available. |
| numfmt | `gnumfmt` | Reformat numbers. |
| od | `god` | Dump files in octal and other formats. |
| paste | `gpaste` | Merge lines of files. |
| patch | `gpatch` | Apply a diff file to an original. |
| pathchk | `gpathchk` | Check whether a given pathnames are valid or portable. |
| pinky | `gpinky` | Print information about a user or users. |
| pr | `gpr` | Paginate or columnate FILE(s) for printing. |
| printenv | `gprintenv` | Print the current environment. |
| printf | `gprintf` | Format and print data. |
| ptx | `gptx` | Display information about a terminal. |
| pwd | `gpwd` | Print the name of the current working directory. |
| readlink | `greadlink` | Display value of a symbolic link or canonical file name. |
| realpath | `grealpath` | Canonicalize path names by resolving symbolic links. |
| rm | `grm` | Remove (unlink) the FILE(s). |
| rmdir | `grmdir` | Remove the DIRECTORY(ies), if they are empty. |
| runcon | `gruncon` | Run a program in a modified SELinux security context. |
| seq | `gseq` | Print a sequence of numbers. |
| sha1sum | `gsha1sum` | Compute and check SHA1 message digest. |
| sha224sum | `gsha224sum` | Compute and check SHA224 message digest. |
| sha256sum | `gsha256sum` | Compute and check SHA256 message digest. |
| sha384sum | `gsha384sum` | Compute and check SHA384 message digest. |
| sha512sum | `gsha512sum` | Compute and check SHA512 message digest. |
| shred | `gshred` | Overwrite a file to hide its contents, and optionally delete it. |
| shuf | `gshuf` | Randomly permute lines of input. |
| sleep | `gsleep` | Pause for NUMBER seconds. |
| sort | `gsort` | Sort lines of text files. |
| split | `gsplit` | Split a file into pieces. |
| stat | `gstat` | Display file or file system status. |
| stdbuf |`gstdbuf`| Run COMMAND with modified buffering operations. |
| stty | `gstty`| Set terminal line parameters and print current values. |
| sum | `gsum`| Print checksum and block counts for each FILE. |
| sync | `gsync`| Invoke the sync() system call to flush buffers to disk. |
| tac | `gtac`| Concatenate and print files in reverse. |
| tail | `gtail`| Output the last part of files. |
| tar | `gnutar`| The GNU version of the tar archiving utility. |
| tee | `gtee`| Read from standard input and write to standard output and files. |
| test | `gtest`| Evaluate conditional expression. |
| timeout | `gtimeout`| Run a command with a time limit. |
| touch | `gtouch`| Change file timestamps. |
| tr | `gtr`| Translate, squeeze, and/or delete characters from standard input. |
| true | `gtrue`| Do nothing, successfully. |
| truncate | `gtruncate`| Shrink or extend the size of a file to the specified size. |
| tsort | `gtsort`| Topological sort. |
| tty | `gtty`| Print file name of terminal connected to standard input. |
| unexpand | `gunexpand`| Convert spaces to tabs. |
| uniq | `guniq`| Report or omit repeated lines. |
| unlink | `gunlink`| Remove (unlink) the FILE(s). |
| users | `gusers`| Print the user names of currently logged in users. |
| vdir | `gvdir`| List directory contents. |
| wc | `gwc`| Print newline, word, and byte counts for each FILE, and a total line if more than one FILE is specified. |
| who | `gwho`| Print who is currently logged in. |
| whoami | `gwhoami`| Print effective userid. |
| yes | `gyes` | Output a string repeatedly until killed. |

[coreutils]: https://www.gnu.org/software/coreutils/
