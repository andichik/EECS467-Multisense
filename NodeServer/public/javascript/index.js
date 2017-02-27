'use strict'

import css from '../css/style.css'

import Pose from './pose.js'
import {
   POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    GRIDPX_PER_METER,
    MAP_LENGTH_METER,
    GRIDPX_LENGTH_METER,
    MAP_LENGTH_GRIDPX,
    DISPX_LENGTH_PPX,
    DISPX_LENGTH_METER,
    MAP_LENGTH_DISPX
    
} from './const.js'
import {
    pagePosToRealPos
} from './util.js'
import nipplejs from 'nipplejs'
import math from 'mathjs'
import bresenham from 'bresenham'

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

var gridMap = math.zeros(MAP_LENGTH_GRIDPX, MAP_LENGTH_GRIDPX);
var displayMap = math.zeros(MAP_LENGTH_DISPX, MAP_LENGTH_DISPX);

socket.on('laserData', (laser_d) => {
    laserData = laser_d;
    //update occupancy grid
    for (var i = 0; i < laserData.length; i++) {
        let world_x = laserData[i][0] + pose.pos[0];
        let world_y = laserData[i][1] + pose.pos[1];

        //update occupancy grid
        let grid_x = math.floor((MAP_LENGTH_GRIDPX + 1) / 2 + world_x / GRIDPX_LENGTH_METER);
        let grid_y = math.floor((MAP_LENGTH_GRIDPX + 1) / 2 + world_y / GRIDPX_LENGTH_METER);
        gridMap[grid_x][grid_y]++;

        let display_x = math.floor((MAP_LENGHT_DISPX + 1) / 2 + world_x / DISPX_LENGTH_METER);
        let display_y = math.floor((MAP_LENGTH_DISPX + 1) / 2 + world_y / DISPX_LENGTH_METER);
        displayMap[display_x][display_y]++;

        //call bresenham on pixel_x, pixel_y
        let grid_pos = pose.gridPos();
        let points_btwn = bresenham(grid_pos[0], grid_pos[1], pixel_x, pixel_y);
        for (var j = 0; j < points_btwn.length; j++) {
            gridMap[points_btwn[j].x][points_btwn[j].y]--;
        }

        let display_pos = pose.displayPos();
        let points_btwn = bresenham(display_pos[0], display_pos[1], display_x, display_y);
        for (var j = 0; j < points_btwn.length; j++) {
            displayMap[points_btwn[j].x][points_btwn[j].y]--;
        }
    }

})

// Trace Map things

var traceMap = SVG('trace').size(TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX);
var traceViewGroup = traceMap.group();
traceViewGroup.translate(TRACE_WIDTH_PPX / 2, TRACE_HEIGHT_PPX / 2)
    .scale(TRACE_SCALE, -TRACE_SCALE)
    .rotate(-90)
/*
traceMap.on('click', function(e) {
    var realPos = pagePosToRealPos([e.offsetX, e.offsetY])
    console.log(realPos);
    var pickedPoint = traceViewGroup.circle(1)
        .move(...realPos)
        .attr({
            'fill-opacity': 0.2,
            stroke: '#f44242',
            'stroke-width': 0.3
        })
        .animate().radius(1);
})
*/
var laserLine = {
    remove: () => {}
};
var botRect = traceViewGroup.rect(BASELINE, BASELINE)
var previousPos = [0, 0, 0];

function drawTrace() {
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

    requestAnimationFrame(drawTrace)
}

drawTrace();

// Joystick things

var joyStick = nipplejs.create({
    zone: document.getElementById('joystick'),
    mode: 'semi',
    catchDistance: 300,
    color: 'white'
});

joyStick.on('dir', (e, stick) => {
    console.log(`Sent command to ${stick.direction.angle}`);
    switch (stick.direction.angle) {
        case 'up':
            socket.emit('setSpeed', {
                left: 20,
                right: 20
            })
        case 'down':
            socket.emit('setSpeed', {
                left: 0,
                right: 0
            })
        case 'left':
            socket.emit('setSpeed', {
                left: 10,
                right: 40
            })
        case 'right':
            socket.emit('setSpeed', {
                left: 40,
                right: 10
            })
    }
})

joyStick.on('end', () => {
    socket.emit('stop')
})

//Map construction
var gridMap = SVG('trace').size(TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX).group();


var rectArr = math.zeros(RECT_ON_SIDE, RECT_ON_SIDE);
for (let i=0; i<RECT_ON_SIDE; i++){
    for (let j=0; j<RECT_ON_SIDE;j++){
        rectArr[i][j] = gridMap.rect(RECT_PX, RECT_PX)
                        .x(i*RECT_PX)
                        .y(j*RECT_PX)
                        .attr({
                            stroke: '#f44242',
                            fill: '#f4ee42'
                        })
                        .data('Odd', gridMap[i][j])
                        .click(()=>console.log(this.data('Odd')))
    }
}
