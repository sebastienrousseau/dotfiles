/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
* Made with ♥ in London, UK by @sebastienrousseau
* Copyright (c) 2015-2023. All rights reserved
* License: MIT
*/

// 🅱🅰🅲🅺🆄🅿 - Backup function (src, dest).
async function backup(src, dest) {
  var fs = require("fs");
  var os = require("os");
  var path = require("path");
  var dir = path.resolve(__dirname, os.homedir() + "/dotfiles_backup");

  if (!fs.existsSync("~/.dotfiles_backup")) {
    fs.mkdirSync("~/.dotfiles_backup");
  }

  var srcPath = path.resolve(__dirname, os.homedir() + "/" + src);
  var destPath = dir + "/" + dest;

  await fs.promises.copyFile(srcPath, destPath);

}

module.exports = backup;

