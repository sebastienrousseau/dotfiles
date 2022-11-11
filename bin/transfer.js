/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
* Made with ♥ in London, UK by @sebastienrousseau
* Copyright (c) 2015-2022. All rights reserved
* License: MIT
*/

// 🆃🆁🅰🅽🆂🅵🅴🆁 - Transfer function.
async function transfer(dest) {

  const fs = require("fs-extra");
  var os = require("os");
  var path = require("path");

  const source = path.resolve(__dirname, os.homedir() + "/dotfiles_backup/package/dist/");
  const dotfiles = path.resolve(__dirname, "/" + dest + "/.dotfiles");
  const bin = path.resolve(__dirname, "/" + dest + "/.dotfiles/bin");
  const filesizes = path.resolve(__dirname, "/" + dest + "/.dotfiles/filesizes.txt");
  const make = path.resolve(__dirname, "/" + dest + "/.dotfiles/Makefile");

  // Remove the destination directory if it exists.
  if (fs.existsSync(dotfiles)) {
    await fs.removeSync(dotfiles);
  }

  // Copy the source directory to the destination.
  await fs.copy(source, dotfiles);

  // Clean up the destination directory, remove the files we don"t need.
  await fs.removeSync(bin);
  await fs.removeSync(filesizes);
  await fs.removeSync(make);

}

module.exports = transfer;
