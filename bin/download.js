/**
 * 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
 * Made with ♥ in London, UK by @wwdseb
 * Copyright (c) 2015-2024. All rights reserved
 * License: MIT
 */

import fs from "fs";
import os from "os";
import path from "path";
import { dotfile, version } from "./constants.js";
import { promisify } from "util";

const destPath = path.resolve(__dirname, os.homedir() + "/dotfiles_backup/");
const https = require("https");
const mv = promisify(fs.rename);

const download = async () => {
  const file = fs.createWriteStream(version);

  const request = https.get(dotfile, (response) => {
    response.pipe(file);
    file.on("finish", async () => {
      file.close();
      try {
        await mv(version, `${destPath}/${version}`);
        fs.rmSync(version);
      } catch (err) {
        console.error("Error during file download:", err);
      }
    });
  });

  request.on("error", (err) => {
    console.error("Error during file download:", err);
  });
};

export default download;
