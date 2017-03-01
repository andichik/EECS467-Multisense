import {OCCUPY_REWARD, UNOCCUPY_REWARD, DISPX} from './const.js'
import math from 'mathjs'
import bresenham from 'bresenham'

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

        mapData[px_x][px_y] += OCCUPY_REWARD; //Change to const
        let map_pos = pose.mapPos(PX);
        let points_btwn = bresenham(map_pos[0], map_pos[1], px_x, px_y);
        for (var j = 0; j < points_btwn.length; j++) {
            let {x, y} = points_btwn[j];
            mapData[x][y]-= UNOCCUPY_REWARD;
        }
    }
    return {max_x, max_y, min_x, min_y}
}

export {updateMapData}
