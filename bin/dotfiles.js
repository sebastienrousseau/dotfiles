const copy = require('./copy.js');
const backup = require('./backup.js');
const download = require('./download.js');
const unpack = require('./unpack.js');
const { aliases, copies } = require('./constants.js');
const sleep = (waitTimeInMs) => new Promise(resolve => setTimeout(resolve, waitTimeInMs));

module.exports = async function main() {

  let i = 0

  do {
    backup(aliases[i], aliases[i]);
    copy(copies[i], aliases[i]);
    i++
  } while (i < aliases.length && i < copies.length);

  download(); // download the dotfiles
  await sleep(5000); // wait 5 seconds for download to complete
  unpack(); // unpack the downloaded file

};
