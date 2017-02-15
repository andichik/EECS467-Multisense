import Pose from './pose.js'
import {TRACE_HEIGHT, TRACE_WIDTH, TRACE_SCALE} from './const.js'
import {pagePosToRealPos} from './util.js'

var socket = io();

$('#setSpeed').click(()=>{
    socket.emit('setSpeed', {
        left: $('#leftSpeed').val(),
        right: $('#rightSpeed').val()
    })
})
$('#stop').click(()=>socket.emit('stop'))

var pose = new Pose();

socket.on('encoderVal', valArr=>{
    let [l, r] = valArr;
    pose.update(l, r);
    $('#decoder_l').text('Left encoder: '+l);
    $('#decoder_r').text('Right encoder: '+r);
})

//var laserMap = SVG('laser').size(500, 500);
var traceMap = SVG('trace').size(TRACE_HEIGHT, TRACE_WIDTH);
var traceViewGroup = traceMap.group();
traceViewGroup.translate(TRACE_WIDTH/2, TRACE_HEIGHT/2)
                .scale(TRACE_SCALE, -TRACE_SCALE)
                .rotate(-90)

traceMap.on('click', function(e){
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


var laserData=[];

socket.on('laserData', (laser_d)=>{
    laserData=laser_d;
})

var laserLine = {remove:()=>{}};
var botRect = traceViewGroup.rect(4, 4/2)
var previousPos = [0, 0, 0];
function drawTrace(){
    traceViewGroup.line(previousPos[0], previousPos[1], pose.pos[0], pose.pos[1])
                    .attr({
                        'stroke-width': 0.5
                    });
    previousPos = pose.pos;
    botRect.translate(pose.pos[0], pose.pos[1]).rotate(pose.pos[2]*57.296)//PI/180

    laserLine.remove();
    laserLine = traceViewGroup.polyline(laserData).fill('none').stroke({ width: 0.5})
                                .translate(pose.pos[0], pose.pos[1])
    requestAnimationFrame(drawTrace)
}

drawTrace();
