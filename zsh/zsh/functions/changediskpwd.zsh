# changediskpwd: Function to change the password on an encrypted disk image
function changediskpwd() {
  hdiutil chpass '$1'
}