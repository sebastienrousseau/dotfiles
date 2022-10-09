async function download() {

  const {promisify} = require('util');
  var fs = require('fs');
  var os = require('os');
  var path = require('path');
  const { dotfile, version } = require('./constants.js');
  var destPath = path.resolve(__dirname, os.homedir() + "/dotfiles_backup/");
  const https = require('https');
  const file = fs.createWriteStream(version);
  const mv = promisify(fs.rename);

  const request = https.get(
    dotfile, version, response => {
      console.log('STATUS: ' + response.statusCode);
      var headers = JSON.stringify(response.headers);
      console.log('HEADERS: ' + headers);
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        mv(version, `${destPath}/${version}`);
      });
    });
};

//   https.get(
//     "https://github.com/sebastienrousseau/dotfiles/archive/refs/tags/",
//     async function(response) {
//       console.log('STATUS: ' + response.statusCode);
//       var headers = JSON.stringify(response.headers);
//       console.log('HEADERS: ' + headers);
//       await response.pipe(file);
//       await mv(version, `${destPath}/${version}`);
//     // fs.rmSync(version);
//   })
// }

module.exports = download;
