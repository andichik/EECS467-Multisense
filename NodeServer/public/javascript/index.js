// @flow

'use strict'

import '../css/style.css';
import 'materialize-css/sass/materialize.scss';
import $ from 'jquery';
import 'materialize-css/dist/js/materialize.js';
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
import io from 'socket.io-client'
import SVG from 'svg.js'
var socket = io();
import PF from 'pathfinding';
import keyboardJS from 'keyboardjs';
import Particle from './particle.js'

var finder = new PF.AStarFinder();
// Input field and button functions
$('#setSpeed').click(() => {
    socket.emit('setSpeed', {
        left: $('#leftSpeed').val(),
        right: $('#rightSpeed').val()
    })
})
$('#stop').click(() => socket.emit('stop'))
//Initialize pose and particles

socket.on('updateDisplay', ({boundary, displayData, pose, particles})=>{
    var pose_t = new Particle();
    pose_t.from(pose);
    updateDisplay(boundary, displayData, rectArr, pose_t, particles)
})
socket.on('poseStr', str=>$('#direction').text(str))

function getPath(x_goal, y_goal) {
    var occupiedMatrix = displayData.map(row=>row.map(x=> x > OCCUPY_THRESHOLD?1:0));
    var [x_pose, y_pose] = pose.mapPos(DISPX);
    var grid = new PF.Grid(occupiedMatrix);
    var path = finder.findPath(x_pose, y_pose, x_goal, y_goal, grid);
    return path;
}

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
                left: 25,
                right: 25,
                action: 'straight'
            })
            break;
        case 'down':
            socket.emit('setSpeed', {
                left: -25,
                right: -25,
                action: 'straight'
            })
            break;
        case 'left':
            socket.emit('setSpeed', {
                left: -10,
                right: 40,
                action: 'turn'
            })
            break;
        case 'right':
            socket.emit('setSpeed', {
                left: 40,
                right: -10,
                action: 'turn'
            })
            break;
    }
})
joyStick.on('end', () => {
    socket.emit('stop');
})


keyboardJS.bind('up', function(e) {
    e.preventRepeat();
    e.preventDefault();
    socket.emit('setSpeed', {
        left: 30,
        right: 30,
        action: 'straight'
    })
}, function() {
    socket.emit('setSpeed', {
        left: 0,
        right: 0,
        action: 'steady'
    })
});

keyboardJS.bind('down', function(e) {
    e.preventRepeat();
    e.preventDefault();
    socket.emit('setSpeed', {
        left: -30,
        right: -30,
        action: 'straight'
    })
}, function() {
    socket.emit('setSpeed', {
        left: 0,
        right: 0,
        action: 'steady'
    })
});

keyboardJS.bind('left', function(e) {
    e.preventRepeat();
    e.preventDefault();
    socket.emit('setSpeed', {
        left: -40,
        right: 40,
        action: 'turn'
    })
}, function() {
    socket.emit('setSpeed', {
        left: 0,
        right: 0,
        action: 'steady'
    })
});

keyboardJS.bind('right', function(e) {
    e.preventRepeat();
    e.preventDefault();
    socket.emit('setSpeed', {
        left: 40,
        right: -40,
        action: 'turn'
    })
}, function() {
    socket.emit('setSpeed', {
        left: 0,
        right: 0,
        action: 'steady'
    })
});

/**
 * The array that stores all the visualization grid rectangles.
 * @type {Array}
 */
var {gridMap, rectArr} = initDisplay();
gridMap.click(function(e) {
    var x_goal = math.floor(e.offsetX / DISPX.PX_LENGTH_PPX);
    var y_goal = math.floor(e.offsetY / DISPX.PX_LENGTH_PPX);
    var path = getPath(x_goal, y_goal);
    for (var i = 0; i < path.length; i++) {
        var [x,y] = path[i];
        rectArr[x][y].attr({
            fill: 'blue'
        })
    }
})
