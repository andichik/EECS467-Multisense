const execFile = require('child_process').execFile

var child = execFile("./calculate_xy", [],
  function (error, stdout, stderr) {
    // This callback is invoked once the child terminates
    // You'd want to check err/stderr as well!
    console.log("Here is the complete output of the program: ");
    console.log(stdout)
});
