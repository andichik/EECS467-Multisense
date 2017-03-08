// @flow

'use strict'

const {
    POSE_UPDATE_SIZE,
    BASELINE,
    TICK_STEP,
    NUM_PARTICLES,
    K1_TURN,
    K1_STRAIGHT,
    K2
} = require('./const.js');
const math = require('mathjs');
const gaussian = require('gaussian');

class Particle {
    constructor(l=0, r=0) {
        this.leftOld = l; // Old value when updating
        this.rightOld = r;
        this.pos = [0, 0, 0];
        this.weight = 1/NUM_PARTICLES;
        this.action = 'steady';
    }
    clone(action_in){
        var new_particle = new Particle();
        new_particle.leftOld = this.leftOld;
        new_particle.rightOld = this.rightOld;
        new_particle.pos = this.pos.slice();
        new_particle.weight = 1/NUM_PARTICLES;
        new_particle.action = action_in;

        return new_particle;
    }

    get theta(){
        return this.pos[2];
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
    updatePoseWithError(leftEnc, rightEnc, pose) {
        if (((leftEnc - this.leftOld) < POSE_UPDATE_SIZE) && (rightEnc - this.rightOld) < POSE_UPDATE_SIZE)
            return;
        else {
            let {delta_s, delta_theta, theta} = this.enc2odem(leftEnc,rightEnc);
            let delta_x = delta_s * Math.cos(theta);
            let delta_y = delta_s * Math.sin(theta);
            // Accounting for delta_x = 0
            if (delta_x === 0) delta_x = 0.00000001;
            if (delta_y === 0) delta_y = 0.00000001;

            let alpha = Math.atan2(delta_y,delta_x) - pose.theta;


            var K1 = K1_STRAIGHT;
            if (pose.action==='turn'){
                K1 = K1_TURN;
            }



            // Setting error terms for Action Error Model
            let e1 = gaussian(0,K1*math.abs(alpha)+0.00000001).ppf(Math.random());
            let e2 = gaussian(0,K2*math.abs(delta_s)+0.00000001).ppf(Math.random());
            let e3 = gaussian(0,K1*(math.abs(delta_theta-alpha))+0.00000001).ppf(Math.random());

			// Calculating new position for particle dispersion using error terms
			//console.log(`Delta_theta: ${delta_theta}, e1: ${e1}, e3: ${e3}`);
            //console.log((delta_s+e2), Math.cos(theta+alpha+e1))

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
        var [px_x, px_y] = [
            math.floor(PX.MAP_LENGTH_PX / 2 - this.pos[1] / PX.PX_LENGTH_METER),
            math.floor(PX.MAP_LENGTH_PX / 2 - this.pos[0] / PX.PX_LENGTH_METER),
        ];
        return [px_x, px_y];
    }
}

module.exports = Particle;
