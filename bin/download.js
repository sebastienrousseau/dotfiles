/**
* 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
* Made with ♥ in London, UK by @wwdseb
* Copyright (c) 2015-2024. All rights reserved
* License: MIT
*/

import { promisify } from "util";
import fs from "fs";
import os from "os";
import path from "path";
import { dotfile, version } from "./constants.js";
import https from "https";

const destPath = path.resolve(__dirname, os.homedir(), "dotfiles_backup");

const download = async () => {
  try {
    const writeFileAsync = promisify(fs.writeFile);
    const renameAsync = promisify(fs.rename);

    const file = fs.createWriteStream(version);

    const request = https.get(dotfile, (response) => {
      response.pipe(file);
      file.on("finish", async () => {
        file.close();
        await renameAsync(version, path.join(destPath, version));
        fs.rmSync(version);
      });
    });

    request.on("error", (err) => {
      console.error("Error downloading file:", err);
    });
  } catch (err) {
    console.error("Error during file download:", err);
  }
};

export default download;
