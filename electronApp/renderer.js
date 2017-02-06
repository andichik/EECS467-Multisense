// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.

var SerialPort = require('serialport');
var Readline = SerialPort.parsers.Readline;
var port = new SerialPort('/dev/ttyS2', {
  baudRate: 9600
});
var parser = new Readline();
port.pipe(parser);
parser.on('data', printDecoder);

function printDecoder(str){
    var leftExp = /^\d+/;
    var rightExp = /\d+(?=r)/;
    document.getElementById("decoder_l").innerHTML = 'Left encoder: '+str.match(leftExp);
    document.getElementById("decoder_r").innerHTML = 'Right encoder: '+str.match(rightExp);
}

function setSpeed(left, right){
    port.write(`${left}l${right}r`);
}

document.getElementById('setSpeed').onclick=()=>{
    setSpeed(document.getElementById('leftSpeed').val, document.getElementById('rightSpeed').val)
}
