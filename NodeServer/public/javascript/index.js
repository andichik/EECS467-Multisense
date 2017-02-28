'use strict'

import css from '../css/style.css'

import Pose from './pose.js'
import {updateMapData} from './map.js'
import {updateDisplay, initDisplay} from './display.js'
import {
    BASELINE,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    GRIDPX,
    DISPX,
} from './const.js'
import {
    pagePosToRealPos
} from './util.js'
import nipplejs from 'nipplejs'
import math from 'mathjs'

math.config({matrix: 'Array'})

var socket = io();

// Decoder things

$('#setSpeed').click(() => {
    socket.emit('setSpeed', {
        left: $('#leftSpeed').val(),
        right: $('#rightSpeed').val()
    })
})
$('#stop').click(() => socket.emit('stop'))

var pose = new Pose();

socket.on('encoderVal', valArr => {
    let [l, r] = valArr;
    pose.update(l, r);
    $('#decoder_l').text('Left encoder: ' + l);
    $('#decoder_r').text('Right encoder: ' + r);
})

// Get laser data

var laserData = [];

var gridData = math.zeros(GRIDPX.MAP_LENGTH_PX, GRIDPX.MAP_LENGTH_PX);
var displayData = math.zeros(DISPX.MAP_LENGTH_PX, DISPX.MAP_LENGTH_PX);

socket.on('laserData', (laser_d) => {
    laserData = laser_d;
    //update occupancy grid
    updateMapData(pose, gridData, laserData, GRIDPX);
    var boundary = updateMapData(pose, displayData, laserData, DISPX);

    requestAnimationFrame(()=>updateDisplay(boundary, displayData, rectArr, pose))

})

// Trace Map things

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

var rectArr = initDisplay();
