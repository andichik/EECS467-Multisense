'use strict'

import Sampling from 'discrete-sampling'
import {calculatePixelPositions} from './map.js'
import {OCCUPY_THRESHOLD, NUM_PARTICLES} from './const.js'

// ImportanceSampling
//------------------------
// DESCRIPTION
//	Takes in N particles and redistributes them according
//	to their weights.
// INPUTS
//	particles - Array of N possible particles of class particle

function ImportanceSampling(particles){

	var newParticles = [];
	// Weight array
	var weights = particles.map(p=>p.weight);
	//Get sampled index
	var newIdx = Sampling.Discrete(weights).sample(NUM_PARTICLES);
	//Use plain for loop because it's the faster than for..of or forEach
	for (let i = 0 ; i< newIdx.length; i++){
		newParticles.push(particles[newIdx[i]].clone());
	}
	return newParticles;
}


// UpdateParticles (Action Model)
//-------------------------
// DESCRIPTION
//	Takes in N particles along with current encoder values
//	and disperses them with error terms based on gaussian
//	distribution with constants K1 and K2
// INPUTS
// 	particles - Array of N possible particles of class particle
// 	leftEnc - Raw left encoder value
//	rightEnc - Raw right encoder value

function UpdateParticlesPose(particles,leftEnc,rightEnc){
	for (let i = 0;i < particles.length;i++){
		particles[i].updatePoseWithError(leftEnc,rightEnc);
	}
}

// UpdateParticlesWeight (Sensor Model)
//-------------------------
// DESCRIPTION
//	Takes in N particles along with last laser scan and updates
//	weights based on this scan
// INPUTS
//	particles - Array of N possible particles of class particle
//	laser - Array of LIDAR points from one full scan
//	map - 2D Arrray of occupancy grid

function UpdateParticlesWeight(particles, laserData, mapData, PX){
    var log_prob_total = 0;
    var largest_prob = -Infinity;

    // Calculating log probabilities for all particles
    particles.forEach(particle=>{
		// Log probability total for particle
		var log_prob = 0;

		for (let i = 0; i<laserData.length; i++){
			//Get obstacle data for a laser ray
			var {px_x, px_y, points_btwn} = calculatePixelPositions(particle, laserData[i], PX);
			if (!(px_x >= 0 && px_x < PX.MAP_LENGTH_PX &&
					px_y >= 0 && px_y < PX.MAP_LENGTH_PX)) {
				continue;
			}
			//Now let's compare map data with it
			var log_prob_ray = -12;
			for (let j = 0; j< points_btwn.lenth; j++){
				var {x, y} = points_btwn[j];
				// Check if grid pixel is occupied
				if (mapData[x][y] >= OCCUPY_THRESHOLD){
					log_prob_ray = -8;
                    break;
                }
			}
			//If nearest obstacle isn't on the between line
			if (log_prob_ray!=-8){
				if(mapData[px_x][px_y]>=OCCUPY_THRESHOLD){
					log_prob_ray = -4;
				}
			}
			log_prob+=log_prob_ray;
		}

		//Saving largest prob for normalizing
		largest_prob = Math.max(largest_prob, log_prob);
		particle.weight = log_prob;

	})

    for (let i=0;i<particles.length;i++){
        // Shifting probabilities to prevent underflow
        particles[i].weight -= largest_prob;

        // Exponentiating each log
        particles[i].weight = Math.exp(particles[i].weight);

        // Calculating total for normalizing
        log_prob_total += particles[i].weight;
    }

    // Final normalizing step
    for (let i=0;i<particles.length;i++){
        particles[i].weight /= log_prob_total;
    }

}

export {ImportanceSampling, UpdateParticlesPose, UpdateParticlesWeight}
