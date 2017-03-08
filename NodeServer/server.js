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
var now = require("performance-now");

const Particle = require('./particle.js')
const {updateMapData} = require('./map.js')
const {
    BASELINE,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    GRIDPX,
    DISPX,
    OCCUPY_THRESHOLD,
    N_BEST_PARTICLES
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


var leftEnc = 0;
var rightEnc = 0;

port.on('data', str=>{
    var leftExp = /[-]?\d+(?=l)/;
    var rightExp = /[-]?\d+(?=r)/;
    let l = str.match(leftExp);
    let r = str.match(rightExp);
    UpdateParticlesPose(particles, l, r, pose);
})

setInterval(processData,300);

io.on('connection', function (socket) {
    console.log('A browser comes in!');
    socket.emit('initialEncoders', [leftEnc, rightEnc])
    socket.on('setSpeed', ({left, right, action})=>{
        pose.action = action;
        setSpeed(left, right)
    })
    socket.on('stop', ()=>{
        pose.action='steady';
        setSpeed(0, 0)
    })
});


function setSpeed(left, right){
    port.write(`${left}l${right}r`);
    console.log(`Set Speed: ${left}l${right}r`)
}

var pose = new Particle();
var particles = [pose];

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
    //    var start = now();

    var laserData = Laser.getXY(LaserPortName);

    if (laserData){
        particles = ImportanceSampling(particles, pose.action);
        //update occupancy grid
        updateMapData(pose, gridData, laserData, GRIDPX);
        // Update the visualization grid
        //get the boundary where the display grid has changed so we can update them within that boundary
        var boundary = updateMapData(pose, displayData, laserData, DISPX);
        //Update the grid map
        io.emit('updateDisplay', {boundary, displayData, pose, particles})
        UpdateParticlesWeight(particles, laserData, gridData, GRIDPX);

        //Pick the maximum weight
        //pose = particles.reduce((max, p)=>max.weight<p.weight?p:max);
        particles.sort((a,b)=>b.weight-a.weight);
        var p_sum_pos = 0;
        var p_sum_weight = 0;
        for (let i = 0; i<N_BEST_PARTICLES; i++){
            p_sum_pos = math.add(p_sum_pos, math.multiply(particles[i].pos, particles[i].weight));
            p_sum_weight+=particles[i].weight;
        }
        pose = new Particle();
        pose.pos = math.divide(p_sum_pos, p_sum_weight);
        pose.action = particles[0].action;

        io.emit('poseStr', `x: ${pose.pos[0]}, y: ${pose.pos[1]}, Angle: ${pose.theta* 57.296}`)
        //console.log(pose.pos);
    }
    //var end = now()
    //console.log((start-end).toFixed(3));
}
