'use strict'

import {
    OCCUPY_REWARD,
    UNOCCUPY_REWARD,
    DISPX
} from './const.js'
import math from 'mathjs'
import bresenham from 'bresenham'


// calculatePixelPositions
// DESCRIPTION
//      Takes in particle, laser data, and pixel constants, and
//      generates the particle location in pixels as well as the
//      pixels bewteen the laser and the particle
// INPUTS
//      particle - Specific particle of class particle
//      laserData - 2D array of x,y coordinates for laser data
//      PX - Object containing useful length->pixel conversions
// OUTPUTS
//      px_x - Location of particle in x direction in pixels
//      px_y - Location of particle in y direction in pixels
//      points_btwen - 2D array of x,y coordinates for pixels between
//                     laser and particle

function calculatePixelPositions(particle, laserRay, PX) {
    let world_x = laserRay[0] + particle.pos[0];
    let world_y = laserRay[1] + particle.pos[1];

    let px_x = math.floor(PX.MAP_LENGTH_PX / 2 + world_x / PX.PX_LENGTH_METER);
    let px_y = math.floor(PX.MAP_LENGTH_PX / 2 + world_y / PX.PX_LENGTH_METER);

    let map_pos = particle.mapPos(PX);
    let points_btwn = bresenham(map_pos[0], map_pos[1], px_x, px_y);

    return {
        px_x,
        px_y,
        points_btwn
    }
}

/**
 * Using laser data, update Odd counts in the map
 * @param  {Particle} particle      Estimated pose
 * @param  {matrix} mapData   Map data , in grid or display px form
 * @param  {2d-array} laserData raw laser data
 * @param  {Object} PX        Constant ibjct contanining necessary constants
 * @return {Object}           Boundary of changed data
 */
function updateMapData(particle, mapData, laserData, PX) {

    var max_x = 0;
    var max_y = 0;
    var min_x = Infinity;
    var min_y = Infinity;

    for (let i = 0; i < laserData.length; i++) {

        // Calculating pixel coordinates and pixels inbetween
        var {
            px_x,
            px_y,
            points_btwn
        } = calculatePixelPositions(particle, laserData[i], PX);
        if (!(px_x >= 0 && px_x < PX.MAP_LENGTH_PX &&
                px_y >= 0 && px_y < PX.MAP_LENGTH_PX)) {
            continue;
        }

        if (PX === DISPX) {
            min_x = math.min(min_x, px_x);
            min_y = math.min(min_y, px_y);
            max_x = math.max(max_x, px_x);
            max_y = math.max(max_y, px_y);
        }
        mapData[px_x][px_y] += OCCUPY_REWARD; //Change to const
        for (var j = 0; j < points_btwn.length; j++) {
            let {
                x,
                y
            } = points_btwn[j];
            mapData[x][y] -= UNOCCUPY_REWARD;
        }
    }
    return {
        max_x,
        max_y,
        min_x,
        min_y
    }
}

export {
    updateMapData,
    calculatePixelPositions
}
