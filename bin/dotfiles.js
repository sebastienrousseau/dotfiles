const copy = require('./copy.js');
const transfer = require('./transfer.js');
const backup = require('./backup.js');
const download = require('./download.js');
const unpack = require('./unpack.js');
const { aliases, copies } = require('./constants.js');
const sleep = (waitTimeInMs) => new Promise(resolve => setTimeout(resolve, waitTimeInMs));
var fs = require('fs');
var os = require('os');
var path = require('path');

const dir=path.resolve(__dirname, os.homedir());

module.exports = async function main() {

  let i = 0

  do {
    backup(aliases[i], aliases[i]);
    copy(copies[i], aliases[i]);
    i++
  } while (i < aliases.length && i < copies.length);

  download(); // download the dotfiles
  await sleep(2500); // wait for download to complete
  unpack(); // unpack the downloaded file
  await sleep(2500); // wait for unpack to complete
  if (fs.existsSync(dir)){
    await transfer(dir); // transfer the unpacked files
  }
  else {
    await fs.mkdirSync(dir);
    await sleep(2500); // wait for mkdir to complete
    await transfer(dir); // transfer the unpacked files
  }
};
