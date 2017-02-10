var socket = io();

$('#setSpeed').click(()=>{
    socket.emit('setSpeed', {
        left: $('#leftSpeed').val(),
        right: $('#rightSpeed').val()
    })
})
$('#stop').click(()=>socket.emit('stop'))

$('#laser_map').click(()=>socket.emit('showMap'))

socket.on('encoderVal', valArr=>{
    $('#decoder_l').text('Left encoder: '+valArr[0])
    $('#decoder_r').text('Right encoder: '+valArr[1])
})

var laserMap = SVG('laser').size(500, 500)

var laserData=[];

socket.on('laserData', (laser_d)=>laserData=laser_d)

var polyline = {remove:()=>{}};
function drawMap(){
    polyline.remove();
    polyline = laserMap.polyline(laserData).fill('none').stroke({ width: 1 })
    requestAnimationFrame(drawMap)
}

drawMap()
