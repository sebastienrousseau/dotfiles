"use strict";
const exec = require("child_process").exec;

function main() {
  exec("make installer", (error, stdout, stderr) => {
    if (error) {
      return;
    }

    if (stderr) {
      return;
    }
  });
}

main();
