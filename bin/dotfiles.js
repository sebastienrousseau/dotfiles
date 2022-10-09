const copy = require('./copy.js');
const backup = require('./backup.js');
const download = require('./download.js');
const { aliases, copies } = require('./constants.js');

module.exports = function main() {

  let i = 0

  do {
    backup(aliases[i], aliases[i]);
    copy(copies[i], aliases[i]);
    i++
  } while (i < aliases.length && i < copies.length);

  download();

};
