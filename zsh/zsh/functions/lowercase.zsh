# lowercase: Function to move filenames or directory names to lowercase
function lowercase()  
{
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] The filename or directory name is incorrect." >&2
    return 1
  fi
  for file ; do
      filename=${file##*/}
      case "$filename" in
      */*) dirname==${file%/*} ;;
      *) dirname=.;;
      esac
      nf=$(echo $filename | tr A-Z a-z)
      newname="${dirname}/${nf}"
      if [ "$nf" != "$filename" ]; then
          mv "$file" "$newname"
          echo "[INFO] Renaming $file to lowercase: $newname"
      else
          echo "[ERROR] The operation is not valid, $file has not changed."
      fi
  done
}