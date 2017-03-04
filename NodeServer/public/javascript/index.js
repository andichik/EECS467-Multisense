'use strict'

import css from '../css/style.css'

import Particle from './particle.js'
import {updateMapData} from './map.js'
import {updateDisplay, initDisplay} from './display.js'
import {
    BASELINE,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    GRIDPX,
    DISPX,
    OCCUPY_THRESHOLD
} from './const.js'
import nipplejs from 'nipplejs'
import math from 'mathjs'

math.config({matrix: 'Array'})

var socket = io();
import PF from 'pathfinding';
var finder = new PF.AStarFinder();

// Input field and button functions

$('#setSpeed').click(() => {
    socket.emit('setSpeed', {
        left: $('#leftSpeed').val(),
        right: $('#rightSpeed').val()
    })
})
$('#stop').click(() => socket.emit('stop'))

//Initialize pose
var pose = new Particle();

setInterval(function(){
    console.log(pose.pos);
}, 2000);

// Show encoder values on the page and update the pose
socket.on('encoderVal', valArr => {
    let [l, r] = valArr;
    pose.updatePose(l, r);
    $('#decoder_l').text('Left encoder: ' + l);
    $('#decoder_r').text('Right encoder: ' + r);
})

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

socket.on('laserData', (laser_d) => {
    laserData = laser_d;
    //update occupancy grid
    updateMapData(pose, gridData, laserData, GRIDPX);
    // Update the visualization grid
    //get the boundary where the display grid has changed so we can update them within that boundary
    var boundary = updateMapData(pose, displayData, laserData, DISPX);
    //Update the grid map
    requestAnimationFrame(()=>updateDisplay(boundary, displayData, rectArr, pose))

})


function getPath(x_goal, y_goal) {
    var occupiedMatrix = displayData.map(row=>row.map(x=> x > OCCUPY_THRESHOLD?1:0));

    var [x_pose, y_pose] = pose.mapPos(DISPX);
    var grid = new PF.Grid(occupiedMatrix);
    var path = finder.findPath(x_pose, y_pose, x_goal, y_goal, grid);

    return path;

}

// Trace Map things
// The things down here are just for debugging and a little deprecated.
// Most of the code are for manipulating SVG
var traceMap = SVG('trace').size(TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX);
var traceViewGroup = traceMap.group();
traceViewGroup.translate(TRACE_WIDTH_PPX / 2, TRACE_HEIGHT_PPX / 2)
    .scale(TRACE_SCALE, -TRACE_SCALE)
    .rotate(-90)

var laserLine = {
    remove: () => {}
};
var botRect = traceViewGroup.rect(BASELINE, BASELINE)
var previousPos = [0, 0, 0];

function drawTrace(traceViewGroup, pose) {
    traceViewGroup.line(previousPos[0], previousPos[1], pose.pos[0], pose.pos[1])
        .attr({
            'stroke-width': 0.02
        });
    previousPos = pose.pos;
    botRect.translate(pose.pos[0], pose.pos[1]).rotate(pose.pos[2] * 57.296) //PI/180

    laserLine.remove();
    laserLine = traceViewGroup.polyline(laserData).fill('none').stroke({
            width: 0.02
        })
        .translate(pose.pos[0], pose.pos[1])

    requestAnimationFrame(()=>drawTrace(traceViewGroup, pose))
}

drawTrace(traceViewGroup, pose);

// Joystick things
var joyStick = nipplejs.create({
    zone: document.getElementById('joystick'),
    mode: 'semi',
    catchDistance: 300,
    color: 'white'
});

joyStick.on('dir', (e, stick) => {
    switch (stick.direction.angle) {
        case 'up':
            socket.emit('setSpeed', {
                left: 20,
                right: 20
            })
            break;
        case 'down':
            socket.emit('setSpeed', {
                left: -20,
                right: -20
            })
            break;
        case 'left':
            socket.emit('setSpeed', {
                left: -10,
                right: 40
            })
            break;
        case 'right':
            socket.emit('setSpeed', {
                left: 40,
                right: -10
            })
            break;
    }
})

joyStick.on('end', () => {
    socket.emit('stop')
})


//Map construction
var gridMap = SVG('grid').size(TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX).group();
gridMap.click(function(e) {
    var x_goal = math.floor(e.offsetX / DISPX.PX_LENGTH_PPX);
    var y_goal = math.floor(e.offsetY / DISPX.PX_LENGTH_PPX);

    var path = getPath(x_goal, y_goal);
    //console.log(getPath(x_goal, y_goal));

    for (var i = 0; i < path.length; i++) {
        var [x,y] = path[i];
        rectArr[x][y].attr({
            fill: 'blue'
        })

    }
})


/**
 * The array that stores all the visualization grid rectangles.
 * @type {Array}
 */
var rectArr = initDisplay();
