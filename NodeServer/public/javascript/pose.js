import {POSE_UPDATE_SIZE, BASELINE} from './const.js';
import math from 'mathjs';

class Pose {
    constructor() {
        this.leftOld = 0; // Old value when updating
        this.rightOld = 0;
        this.pos = [0, 0, 0];
    }
    update(leftEnc, rightEnc){
        if (((leftEnc - this.leftOld) < POSE_UPDATE_SIZE) && (rightEnc - this.rightOld))
            return;
        else {
            let d_l = leftEnc - this.leftOld;
            let d_r = rightEnc - this.rightOld;
            let delta_x = (d_r + d_l)/2;
            let delta_theta = (d_r - d_l)/BASELINE;
            let theta = this.pos[2];
            this.pos = math.add(this.pos, [delta_x*Math.sin(theta), delta_x*Math.cos(theta), delta_theta]);
            this.leftOld = leftEnc;
            this.rightOld = rightEnc;
        }
    }
}

export default Pose;

