/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
* Made with ♥ in London, UK by @wwdseb
* Copyright (c) 2015-2024. All rights reserved
* License: MIT
*/

import backup from "./backup.js";
import copy from "./copy.js";
import download from "./download.js";
import transfer from "./transfer.js";
import unpack from "./unpack.js";
import { aliases, copies } from "./constants.js";
import fs from "fs/promises";
import os from "os";
import path from "path";

const dir = path.resolve(__dirname, os.homedir());

const sleep = (waitTimeInMs) => new Promise((resolve) => setTimeout(resolve, waitTimeInMs));

const backupAndCopy = async () => {
  for (let i = 0; i < Math.min(aliases.length, copies.length); i++) {
    await backup(aliases[i], aliases[i]);
    await copy(copies[i], aliases[i]);
  }
};

const downloadAndUnpack = async () => {
  download(); // download the dotfiles
  await sleep(2500); // wait for download to complete
  unpack(); // unpack the downloaded file
  await sleep(2500); // wait for unpack to complete
};

const createDirIfNeeded = async () => {
  try {
    await fs.access(dir); // Check if directory exists asynchronously
  } catch (error) {
    if (error.code === "ENOENT") { // If directory does not exist
      await fs.mkdir(dir); // Create directory asynchronously
      await sleep(2500); // wait for mkdir to complete
    }
  }
};

const transferFiles = async () => {
  await transfer(dir);
};

const main = async () => {
  await backupAndCopy();
  await downloadAndUnpack();
  await createDirIfNeeded();
  await transferFiles();
};

export default main;
