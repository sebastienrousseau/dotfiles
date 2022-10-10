async function unpack() {
  const compressing = require('compressing');
  var os = require('os');
  var path = require('path');
  const { version } = require('./constants.js');
  var destPath = path.resolve(__dirname, os.homedir() + "/dotfiles_backup/");
  compressing.tgz.uncompress(destPath+"/"+version, destPath+"/");
}

module.exports = unpack;
