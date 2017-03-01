import {
    POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP
} from './const.js';
import math from 'mathjs';
import gaussian from 'gaussian';

class Pose {
    constructor() {
        this.leftOld = 0; // Old value when updating
        this.rightOld = 0;
        this.pos = [0, 0, 0];
    }
    update(leftEnc, rightEnc) {
        if (((leftEnc - this.leftOld) < POSE_UPDATE_SIZE) && (rightEnc - this.rightOld) < POSE_UPDATE_SIZE)
            return;
        else {
            let d_l = (leftEnc - this.leftOld) * TICK_STEP;
            let d_r = (rightEnc - this.rightOld) * TICK_STEP;
            let delta_s = (d_r + d_l) / 2;
            let delta_theta = (d_r - d_l) / BASELINE;
            let theta = this.pos[2];
	    	let delta_x = delta_s + cos(theta) - pos[0];
	    	let delta_y = delta_s + sin(theta) - pos[1];
	    	// Accounting for delta_x = 0
	    	if (delta_x === 0) delta_x = 0.0001;

	    	// Setting error terms for Action Error Model
	    	e1 = gaussian(0,k1*alpha);
	    	e2 = gaussian(0,k2*delta_s);
	    	e3 = gaussian(0,k1*(delta_theta-alpha));

	    	let alpha = Math.atan2(delta_y,delta_x) - delta_theta;

			// Calculating new position for particle dispersion using error terms
            let pos = math.add(this.pos, [(delta_s+e2) * Math.cos(theta+alpha+e1), (delta_s+e2) * Math.sin(theta+alpha+e1), delta_theta+e1+e3]);
            this.leftOld = leftEnc;
            this.rightOld = rightEnc;
        }
    }
    mapPos(PX) {
        return [
            math.floor(PX.MAP_LENGTH_PX / 2 + this.pos[0] / PX.PX_LENGTH_METER),
            math.floor(PX.MAP_LENGTH_PX / 2 + this.pos[1] / PX.PX_LENGTH_METER),
        ]
    }
}

export default Pose;
