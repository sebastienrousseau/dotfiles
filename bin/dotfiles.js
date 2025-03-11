/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
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
import { createLogger, transports, format } from "winston";

const dir = path.resolve(__dirname, os.homedir());
const logger = createLogger({
  level: "error",
  format: format.combine(
    format.timestamp(),
    format.json()
  ),
  transports: [
    new transports.Console(),
    new transports.File({ filename: "error.log" })
  ]
});

const sleep = (waitTimeInMs) => new Promise((resolve) => setTimeout(resolve, waitTimeInMs));

// Function to validate and sanitize input
const validateAndSanitizeInput = (input) => {
  return input.replace(/[^\w]/g, ""); // Example: Remove non-word characters
};

const backupAndCopy = async () => {
  try {
    for (let i = 0; i < Math.min(aliases.length, copies.length); i++) {
      // Validate and sanitize input before passing it to backup and copy functions
      const alias = validateAndSanitizeInput(aliases[i]);
      const copyName = validateAndSanitizeInput(copies[i]);

      // Call backup and copy functions with sanitized input
      await backup(alias, alias);
      await copy(copyName, alias);
    }
  } catch (error) {
    logger.error(`Error in backupAndCopy: ${error.message}`);
  }
};

const downloadAndUnpack = async () => {
  try {
    download(); // download the dotfiles
    await sleep(2500); // wait for download to complete
    unpack(); // unpack the downloaded file
    await sleep(2500); // wait for unpack to complete
  } catch (error) {
    logger.error(`Error in downloadAndUnpack: ${error.message}`);
  }
};

const createDirIfNeeded = async () => {
  try {
    await fs.access(dir); // Check if directory exists asynchronously
  } catch (error) {
    if (error.code === "ENOENT") { // If directory does not exist
      try {
        await fs.mkdir(dir); // Create directory asynchronously
        await sleep(2500); // wait for mkdir to complete
      } catch (error) {
        logger.error(`Error creating directory: ${error.message}`);
      }
    }
  }
};

const transferFiles = async () => {
  try {
    await transfer(dir);
  } catch (error) {
    logger.error(`Error in transferFiles: ${error.message}`);
  }
};

const main = async () => {
  try {
    await backupAndCopy();
    await downloadAndUnpack();
    await createDirIfNeeded();
    await transferFiles();
  } catch (error) {
    logger.error(`Error in main: ${error.message}`);
  }
};

export default main;
