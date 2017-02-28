'use strict'

import css from '../css/style.css'

import Pose from './pose.js'
import {
    BASELINE,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX,
    TRACE_SCALE,
    GRIDPX,
    DISPX
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

var gridData = math.zeros(GRIDPX.MAP_LENGTH_PX, GRIDPX.MAP_LENGTH_PX);
var displayData = math.zeros(DISPX.MAP_LENGTH_PX, DISPX.MAP_LENGTH_PX);

function updateMapData(pose, mapData, laserData, PX){
    var max_x = 0;
    var max_y = 0;
    var min_x = Infinity;
    var min_y = Infinity;

    for (let i = 0; i < laserData.length;i++) {
        let world_x = laserData[i][0] + pose.pos[0];
        let world_y = laserData[i][1] + pose.pos[1];

        let px_x = math.floor(PX.MAP_LENGTH_PX / 2 + world_x / PX.PX_LENGTH_METER);
        let px_y = math.floor(PX.MAP_LENGTH_PX / 2 + world_y / PX.PX_LENGTH_METER);

        if (!(px_x >= 0 && px_x < PX.MAP_LENGTH_PX &&
            px_y >= 0 && px_y < PX.MAP_LENGTH_PX)) {
            continue;
        }
        if (PX===DISPX){
            min_x = math.min(min_x, px_x);
            min_y = math.min(min_y, px_y);
            max_x = math.max(max_x, px_x);
            max_y = math.max(max_y, px_y);
        }

        mapData[px_x][px_y] += 5; //Change to const
        let map_pos = pose.mapPos(PX);
        let points_btwn = bresenham(map_pos[0], map_pos[1], px_x, px_y);
        for (var j = 0; j < points_btwn.length; j++) {
            let {x, y} = points_btwn[j];
            mapData[x][y]--;
        }
    }
    return {max_x, max_y, min_x, min_y}
}


socket.on('laserData', (laser_d) => {
    laserData = laser_d;
    //update occupancy grid
    updateMapData(pose, gridData, laserData, GRIDPX);
    console.log(updateMapData(pose, displayData, laserData, DISPX));


    //debugger;

    //console.log([math.min(gridData), math.max(gridData)]);
    //console.log([math.min(displayData), math.max(displayData)]);

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
            break;
        case 'down':
            socket.emit('setSpeed', {
                left: 0,
                right: 0
            })
            break;
        case 'left':
            socket.emit('setSpeed', {
                left: 10,
                right: 40
            })
            break;
        case 'right':
            socket.emit('setSpeed', {
                left: 40,
                right: 10
            })
            break;
    }
})

joyStick.on('end', () => {
    socket.emit('stop')
})

//Map construction
var gridMap = SVG('grid').size(TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX).group();


var rectArr = math.zeros(DISPX.MAP_LENGTH_PX, DISPX.MAP_LENGTH_PX);
for (let i=0; i<DISPX.MAP_LENGTH_PX; i++){
    for (let j=0; j<DISPX.MAP_LENGTH_PX;j++){
        rectArr[i][j] = gridMap.rect(DISPX.PX_LENGTH_PPX, DISPX.PX_LENGTH_PPX)
                        .x(i*DISPX.PX_LENGTH_PPX)
                        .y(j*DISPX.PX_LENGTH_PPX)
                        .attr({
                            stroke: '#f44242',
                            fill: '#f4ee42'
                        })
                        .data('Odd', displayData[i][j])
    }
}
