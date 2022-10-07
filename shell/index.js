"use strict";
var shell = require("shelljs");

function main() {
  shell.exec("pnpm run prepare");
}

main();
