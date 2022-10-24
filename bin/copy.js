/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
* Made with ♥ in London, UK by @sebastienrousseau
* Copyright (c) 2015-2022. All rights reserved
* License: MIT
*/

// 🅲🅾🅿🆈 - Copy function (src, dest).
async function copy(src, dest) {

  var fs = require('fs');
  var os = require("os");
  var path = require('path');
  var destPath = path.resolve(__dirname, os.homedir() + "/" + dest);
  var srcPath = path.resolve(__dirname, "../" + src);

  await fs.promises.copyFile(srcPath, destPath);

};

module.exports = copy;
