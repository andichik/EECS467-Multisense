import Pose from './pose.js'

var socket = io();

$('#setSpeed').click(()=>{
    socket.emit('setSpeed', {
        left: $('#leftSpeed').val(),
        right: $('#rightSpeed').val()
    })
})
$('#stop').click(()=>socket.emit('stop'))

$('#laser_map').click(()=>socket.emit('showMap'))

var pose = new Pose();

socket.on('encoderVal', valArr=>{
    let [l, r] = valArr;
    pose.update(l, r);
    $('#decoder_l').text('Left encoder: '+l);
    $('#decoder_r').text('Right encoder: '+r);
})

//var laserMap = SVG('laser').size(500, 500);
var traceMap = SVG('trace').size(500, 500);
var traceViewGroup = traceMap.group();
traceViewGroup.translate(250, 250).scale(8)

var laserData=[];

socket.on('laserData', (laser_d)=>laserData=laser_d)

var polyline = {remove:()=>{}};
function drawMap(){
    polyline.remove();
    polyline = laserMap.polyline(laserData).fill('none').stroke({ width: 1 })
    requestAnimationFrame(drawMap)
}

var previousPos = [0, 0, 0];
function drawTrace(){ 
    traceViewGroup.line(previousPos[0], previousPos[1], pose.pos[0], pose.pos[1]).stroke({width:1});
    previousPos = pose.pos;
    requestAnimationFrame(drawTrace)
}
setInterval(()=>console.log(pose.pos), 1000)

//drawMap()
drawTrace();
