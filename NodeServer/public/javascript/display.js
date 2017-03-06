import {
    DISPX,
    FULLY_OCCUPIED,
    FULLY_UNOCCUPIED,
    TRACE_HEIGHT_PPX,
    TRACE_WIDTH_PPX
} from './const.js'
import math from 'mathjs'
import SVG from 'svg.js'
/**
 * Update the visualization grid
 * @param  {matrix} boundary    Where the updated can be restricted to
 * @param  {matrix} displayData Odd count of the display grid
 * @param  {array}  rectArr     Rectangle array
 * @param  {Particle}  pose        Current estimation pose
 * @return null
 */
function updateDisplay(boundary, displayData, rectArr, pose, particles) {
    var color = new SVG.Color('#fff').morph('#000')
    var {
        max_x,
        max_y,
        min_x,
        min_y
    } = boundary;
    for (let x = min_x; x <= max_x; ++x) {
        for (let y = min_y; y <= max_y; ++y) {
            let colorStr = color.at(normalizeCount(displayData[x][y])).toHex();
            rectArr[x][y].attr({
                fill: colorStr
            })
        }
    }
    //Show particles
    particles.forEach(p => {
        let [pose_x, pose_y] = p.mapPos(DISPX);
        if (pose_x >= 0 && pose_x < DISPX.MAP_LENGTH_PX &&
                pose_y >= 0 && pose_y < DISPX.MAP_LENGTH_PX) {
            rectArr[pose_x][pose_y].attr({
                fill: 'blue'
            })
        }
    })
    // Show current position
    let [pose_x, pose_y] = pose.mapPos(DISPX);

    if (pose_x >= 0 && pose_x < DISPX.MAP_LENGTH_PX &&
            pose_y >= 0 && pose_y < DISPX.MAP_LENGTH_PX) {
        rectArr[pose_x][pose_y].attr({
            fill: '#f4ee42'
        })
    }

    function normalizeCount(count) {
        return (count - FULLY_UNOCCUPIED) / (FULLY_OCCUPIED - FULLY_UNOCCUPIED)
    }
}
/**
 * Create the grid SVG
 * @return {array} Array of all the created rectangles
 */
function initDisplay() {
    //Map construction
    var gridMap = SVG('grid').size(TRACE_HEIGHT_PPX, TRACE_WIDTH_PPX).group();
    //gridMap.scale(1, -1).rotate(-90);
    var rectArr = math.zeros(DISPX.MAP_LENGTH_PX, DISPX.MAP_LENGTH_PX);
    for (let i = 0; i < DISPX.MAP_LENGTH_PX; i++) {
        for (let j = 0; j < DISPX.MAP_LENGTH_PX; j++) {
            rectArr[i][j] = gridMap.rect(DISPX.PX_LENGTH_PPX, DISPX.PX_LENGTH_PPX)
                .x(i * DISPX.PX_LENGTH_PPX)
                .y(j * DISPX.PX_LENGTH_PPX)
                // .attr({
                //     stroke: '#f44242',
                //     fill: '#f4ee42'
                // })
        }
    }
    return {gridMap, rectArr};
}
export {
    updateDisplay,
    initDisplay
}
