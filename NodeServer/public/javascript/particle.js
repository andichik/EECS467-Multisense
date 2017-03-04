import {
    POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP,
    NUM_PARTICLES
} from './const.js';
import math from 'mathjs';
import gaussian from 'gaussian';

class Particle {
    constructor() {
        this.leftOld = 0; // Old value when updating
        this.rightOld = 0;
        this.pos = [0, 0, 0];
	    this.weight = 1/NUM_PARTICLES;
    }
    clone(){
        new_particle = new Particle();
        new_particle.leftOld = this.leftOld;
        new_particle.rightOld = this.rightOld;
        new_particle.pos = this.pos.slice();
        new_particle.weight = this.weight;

        return new_particle;
    }

    // Updating pose for map generation without error
    updatePose(leftEnc, rightEnc) {
        if (((leftEnc - this.leftOld) < POSE_UPDATE_SIZE) && (rightEnc - this.rightOld) < POSE_UPDATE_SIZE)
            return;
        else {
            let odem = this.enc2odem(leftEnc,rightEnc);

			// Calculating new position for particle dispersion using error terms
            let pos = math.add(this.pos, [(odem.delta_s) * Math.cos(odem.theta), (odem.delta_s) * Math.sin(odem.theta), odem.delta_theta]);
            this.leftOld = leftEnc;
            this.rightOld = rightEnc;
        }
    }
    // Updating pose for Action Error Model
    updatePoseWithError(leftEnc, rightEnc) {
        if (((leftEnc - this.leftOld) < POSE_UPDATE_SIZE) && (rightEnc - this.rightOld) < POSE_UPDATE_SIZE)
            return;
        else {
            let odem = this.enc2odem(leftEnc,rightEnc);
	    	let delta_x = odem.delta_s + cos(odem.theta) - pos[0];
	    	let delta_y = odem.delta_s + sin(odem.theta) - pos[1];
	    	// Accounting for delta_x = 0
	    	if (delta_x === 0) delta_x = 0.0001;

	    	let alpha = Math.atan2(delta_y,delta_x) - odem.delta_theta;

	    	// Setting error terms for Action Error Model
	    	e1 = gaussian(0,k1*alpha);
	    	e2 = gaussian(0,k2*odem.delta_s);
	    	e3 = gaussian(0,k1*(odem.delta_theta-alpha));

			// Calculating new position for particle dispersion using error terms
            let pos = math.add(this.pos, [(odem.delta_s+e2) * Math.cos(odem.theta+alpha+e1), (odem.delta_s+e2) * Math.sin(odem.theta+alpha+e1), odem.delta_theta+e1+e3]);
            this.leftOld = leftEnc;
            this.rightOld = rightEnc;
        }
    }
    // Calculating odometery using raw encoder values
    enc2odem(leftEnc,rightEnc){
        let d_l = (leftEnc - this.leftOld) * TICK_STEP;
        let d_r = (rightEnc - this.rightOld) * TICK_STEP;
        let delta_s = (d_r + d_l) / 2;
        let delta_theta = (d_r - d_l) / BASELINE;
        let theta = this.pos[2];
        return {
            d_l:d_l,
            d_r:d_r,
            delta_s:delta_s,
            delta_theta:delta_theta,
            theta:theta
        };
    }

	updateWeight(newWeight){
		this.weight = newWeight;
	}
    mapPos(PX) {
        return [
            math.floor(PX.MAP_LENGTH_PX / 2 + this.pos[0] / PX.PX_LENGTH_METER),
            math.floor(PX.MAP_LENGTH_PX / 2 + this.pos[1] / PX.PX_LENGTH_METER),
        ]
    }
}

export default Particle;
