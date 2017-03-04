import {
    POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP,
    NUM_PARTICLES,
    K1,
    K2
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
        var new_particle = new Particle();
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
            let {delta_s, delta_theta, theta} = this.enc2odem(leftEnc,rightEnc);

			// Calculating new position for particle dispersion using error terms
            this.pos = math.add(this.pos, [delta_s * Math.cos(theta), delta_s * Math.sin(theta), delta_theta]);
            this.leftOld = leftEnc;
            this.rightOld = rightEnc;
        }
    }
    // Updating pose for Action Error Model
    // Yanda: This is TOO SLOW!!!
    updatePoseWithError(leftEnc, rightEnc) {
        if (((leftEnc - this.leftOld) < POSE_UPDATE_SIZE) && (rightEnc - this.rightOld) < POSE_UPDATE_SIZE)
            return;
        else {
            let {delta_s, delta_theta, theta} = this.enc2odem(leftEnc,rightEnc);
            let delta_x = delta_s + Math.cos(theta) - this.pos[0];
            let delta_y = delta_s + Math.sin(theta) - this.pos[1];
            // Accounting for delta_x = 0
            if (delta_x === 0) delta_x = 0.0001;

            let alpha = Math.atan2(delta_y,delta_x) - delta_theta;

            // Setting error terms for Action Error Model
            let e1 = gaussian(0,Math.abs(K1*alpha)).ppf(Math.random());
            let e2 = gaussian(0,Math.abs(K2*delta_s)).ppf(Math.random());
            let e3 = gaussian(0,Math.abs(K1*(delta_theta-alpha))).ppf(Math.random());

			// Calculating new position for particle dispersion using error terms
            this.pos = math.add(this.pos, [(delta_s+e2) * Math.cos(theta+alpha+e1), (delta_s+e2) * Math.sin(theta+alpha+e1), delta_theta+e1+e3]);
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
            delta_s,
            delta_theta,
            theta
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
