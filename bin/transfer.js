async function transfer(dest) {

  const fs = require('fs-extra');
  var os = require('os');
  var path = require('path');

  const source = path.resolve(__dirname, os.homedir() + "/dotfiles_backup/package/dist/");
  const dotfiles =  path.resolve(__dirname, "/" + dest + "/.dotfiles");
  const bin =  path.resolve(__dirname, "/" + dest + "/.dotfiles/bin");
  const filesizes =  path.resolve(__dirname, "/" + dest + "/.dotfiles/filesizes.txt");
  const make =  path.resolve(__dirname, "/" + dest + "/.dotfiles/Makefile");

  if (fs.existsSync(dotfiles)){
    await fs.removeSync(dotfiles);
  }

  // Copy the files
  await fs.copy(source, dotfiles);

  // Clean up
  await fs.removeSync(bin);
  await fs.removeSync(filesizes);
  await fs.removeSync(make);

  // await fs.move(tmp, destination, {overwrite: true});


};

module.exports = transfer;
