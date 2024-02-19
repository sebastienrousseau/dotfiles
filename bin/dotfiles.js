// 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
// Made with ♥ in London, UK by @wwdseb
// Copyright (c) 2015-2024. All rights reserved
// License: MIT

// 🅼🅰🅸🅽 - Main function.
const copy = require("./copy.js");
const transfer = require("./transfer.js");
const backup = require("./backup.js");
const download = require("./download.js");
const unpack = require("./unpack.js");
const { aliases, copies } = require("./constants.js");
const sleep = (waitTimeInMs) => new Promise((resolve) => setTimeout(resolve, waitTimeInMs));
const fs = require("fs").promises; // Import promises version of fs
const os = require("os");
const path = require("path");

const dir = path.resolve(__dirname, os.homedir());

module.exports = async function main() {

  let i = 0;

  // Backup files and copy dotfiles.
  do {
    await backup(aliases[i], aliases[i]);
    await copy(copies[i], aliases[i]);
    i++;
  } while (i < aliases.length && i < copies.length);

  // Download and unpack dotfiles.
  download; // download the dotfiles
  await sleep(2500); // wait for download to complete
  unpack(); // unpack the downloaded file
  await sleep(2500); // wait for unpack to complete

  try {
    await fs.access(dir); // Check if directory exists asynchronously
  } catch (error) {
    if (error.code === 'ENOENT') { // If directory does not exist
      await fs.mkdir(dir); // Create directory asynchronously
      await sleep(2500); // wait for mkdir to complete
    }
  }

  await transfer(dir);
};
