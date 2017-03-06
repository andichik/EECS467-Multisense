// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.

const SerialPort = require('serialport');
const Laser = require('./laser.js');
const {ArduinoPortName, LaserPortName} = require('./port.js');

var express = require('express')
var app = require('express')();
var server = require('http').Server(app);
var io = require('socket.io')(server);

// Start the server

server.listen(80);

console.log('Server started')
app.use(express.static('dist'))
app.use(express.static('bower_components'))

app.get('/', function (req, res) {
  res.sendFile(__dirname + '/index.html');
});

// Read the port data

var Readline = SerialPort.parsers.Readline;
ArduinoPort = new SerialPort(ArduinoPortName);
var parser = new Readline();
ArduinoPort.pipe(parser);

function postLaserData(){
    var laserData = Laser.getXY(LaserPortName);
    if (laserData){
        io.emit('laserData', laserData);
    }
}

var leftEnc, rightEnc;

parser.on('data', str=>{
    var leftExp = /\d+(?=l)/;
    var rightExp = /\d+(?=r)/;
    leftEnc = str.match(leftExp);
    rightEnc = str.match(rightExp);
    io.emit('encoderVal', [leftEnc, rightEnc]);
})
setInterval(postLaserData, 200)

io.on('connection', function (socket) {
    console.log('A browser comes in!');
    socket.emit('initialEncoders', [leftEnc, rightEnc])
    socket.on('setSpeed', ({left, right})=>setSpeed(left, right))
    socket.on('stop', ()=>setSpeed(0, 0))
});


function setSpeed(left, right){
    ArduinoPort.write(`${left}l${right}r`);
    console.log(`Set Speed: ${left}l${right}r`)
}
