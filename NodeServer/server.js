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

const Particle = require('./particle.js')
const {updateMapData} = require('./map.js')
const {
    BASELINE,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    GRIDPX,
    DISPX,
    OCCUPY_THRESHOLD
} = require('./const.js')
const {ImportanceSampling, UpdateParticlesPose, UpdateParticlesWeight} = require('./localization.js')
const math = require('mathjs')
math.config({matrix: 'Array'})


// Start the server

server.listen(80);

console.log('Server started')
app.use(express.static('dist'))
app.use(express.static('bower_components'))

app.get('/', function (req, res) {
  res.sendFile(__dirname + '/index.html');
});

// Read the port data

var port = new SerialPort(ArduinoPortName, {
  parser: SerialPort.parsers.readline('\n')
});

var laserData = [];

function getLaserData(){
    //let t1 = now();
    laserData = Laser.getXY(LaserPortName);
    //console.log(now()-t1);
}

var leftEnc = 0;
var rightEnc = 0;

port.on('data', str=>{
    var leftExp = /[-]?\d+(?=l)/;
    var rightExp = /[-]?\d+(?=r)/;
    leftEnc = str.match(leftExp);
    rightEnc = str.match(rightExp);
})

setInterval(processData, 500);

io.on('connection', function (socket) {
    console.log('A browser comes in!');
    socket.emit('initialEncoders', [leftEnc, rightEnc])
    socket.on('setSpeed', ({left, right})=>setSpeed(left, right))
    socket.on('stop', ()=>setSpeed(0, 0))
});


function setSpeed(left, right){
    port.write(`${left}l${right}r`);
    console.log(`Set Speed: ${left}l${right}r`)
}

var pose = new Particle();
var particles = [pose];


var laserData = [];
/**
 * gridData is a matrix stores the odd count of all the grids
 * @type 2-d array
 */
var gridData = math.zeros(GRIDPX.MAP_LENGTH_PX, GRIDPX.MAP_LENGTH_PX);
/**
 * displayData is a matrix stores the odd count in a visualization level, i.e. more roughly than gridData
 * @type 2-d array
 */
var displayData = math.zeros(DISPX.MAP_LENGTH_PX, DISPX.MAP_LENGTH_PX);

function processData(){
    getLaserData();

    if (laserData){
        particles = ImportanceSampling(particles, pose.action);

        let [l, r] = [leftEnc, rightEnc];
        UpdateParticlesPose(particles, l, r, pose);
        //update occupancy grid
        updateMapData(pose, gridData, laserData, GRIDPX);
        // Update the visualization grid
        //get the boundary where the display grid has changed so we can update them within that boundary
        var boundary = updateMapData(pose, displayData, laserData, DISPX);
        //Update the grid map
        io.emit('updateDisplay', {boundary, displayData, pose, particles})
        UpdateParticlesWeight(particles, laserData, gridData, GRIDPX);

        //Pick the maximum weight
        pose = particles.reduce((max, p)=>max.weight<p.weight?p:max);

        io.emit('poseStr', `x: ${pose.pos[0]}, y: ${pose.pos[1]}, Angle: ${pose.theta* 57.296}`)
        //console.log(pose.pos);
    }
}
