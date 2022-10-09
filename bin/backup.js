async function backup(src, dest) {
  var fs = require('fs');
  var os = require('os');
  var path = require('path');
  var dir = path.resolve(__dirname, os.homedir() + '/dotfiles_backup');

  if (!fs.existsSync(dir)){
    fs.mkdirSync(dir);
  }

  var srcPath = path.resolve(__dirname, os.homedir() + "/" + src);
  var destPath = path.resolve(__dirname, os.homedir() + "/dotfiles_backup/" + dest);

  await fs.promises.copyFile(srcPath, destPath);

};

module.exports = backup;

