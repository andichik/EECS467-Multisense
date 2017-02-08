// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.

const SerialPort = require('serialport');
const Laser = require('./laser.js');
const SVG = require('svg.js')
const $ = require("jquery");

document.getElementById('connect').onclick = ()=>{
    const ArduinoPortName = document.getElementById('arduinoPort').value;
    const LaserPortName = document.getElementById('laserPort').value;

    var Readline = SerialPort.parsers.Readline;
    var ArduinoPort = new SerialPort(ArduinoPortName, {
      baudRate: 9600
    });
    var parser = new Readline();
    ArduinoPort.pipe(parser);
    parser.on('data', printDecoder);

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

function printDecoder(str){
    var leftExp = /\d+(?=l)/;
    var rightExp = /\d+(?=r)/;
    document.getElementById("decoder_l").innerHTML = 'Left encoder: '+str.match(leftExp);
    document.getElementById("decoder_r").innerHTML = 'Right encoder: '+str.match(rightExp);
}
