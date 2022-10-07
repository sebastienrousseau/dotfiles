"use strict";
const exec = require("child_process").exec;

function main() {
  exec("make installer", function (err, stdout) {
    if (err) {
      console.error(err);
      return;
    }
    console.log(stdout);
  });
}

main();
