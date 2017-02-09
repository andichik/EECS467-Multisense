// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.

const SerialPort = require('serialport');
const Laser = require('./laser.js');
const SVG = require('svg.js')
const $ = require("jquery");

var express = require('express')
var app = require('express')();
var server = require('http').Server(app);
var io = require('socket.io')(server);

server.listen(80);

console.log('Server started')

app.use(express.static('public'))
app.use(express.static('bower_components'))

app.get('/', function (req, res) {
  res.sendFile(__dirname + '/index.html');
});

var ArduinoPort, LaserPortName, laserMap;

io.on('connection', function (socket) {
    socket.on('connectPort', ({ArduinoPortName, LaserPortName})=>{
        var Readline = SerialPort.parsers.Readline;
        ArduinoPort = new SerialPort(ArduinoPortName, {
          baudRate: 9600
        });
        var parser = new Readline();
        ArduinoPort.pipe(parser);
        parser.on('data', str=>socket.emit('encoderStr', str));
        console.log("try to connect")
        setImmediate(()=>{
            socket.emit('laserData', Laser.getXY(LaserPortName, 18, 100, 250))
        })
    })
    socket.on('setSpeed', ({left, right})=>setSpeed(left, right))
    socket.on('stop', ()=>setSpeed(0, 0))

});

function setSpeed(left, right){
    ArduinoPort.write(`${left}l${right}r`);
    console.log(`${left}l${right}r`)
}
/*
document.getElementById('connect').onclick = ()=>{
    const ArduinoPortName = document.getElementById('arduinoPort').value;
    const LaserPortName = document.getElementById('laserPort').value;

    function setSpeed(left, right){
        ArduinoPort.write(`${left}l${right}r`);
        console.log(`${left}l${right}r`)
    }

    document.getElementById('setSpeed').onclick=()=>{
        setSpeed(document.getElementById('leftSpeed').value, document.getElementById('rightSpeed').value)
    }

    document.getElementById('stop').onclick=()=>{
        setSpeed(0,0);
    }

    var polyline = {remove:()=>{}};
    function readLaser(){
        laserData = Laser.getXY(LaserPortName, 18, 100, 250);
        //console.log(laserData)
        polyline.remove();
        polyline = laserMap.polyline(laserData).fill('none').stroke({ width: 1 })
        requestAnimationFrame(readLaser)
    }

    var laserMap = SVG('laser').size(500, 500)
    //readLaser()
}
*/
