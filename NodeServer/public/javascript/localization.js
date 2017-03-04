'use strict'

import gaussian from 'gaussian'
import Sampling from 'discrete-sampling'
import Particle from './particle.js'
import {calculatePixelPositions} from './map.js'
import {OCCUPY_THRESHOLD} from './const.js'

// Particle Filter
//------------------------
// DESCRIPTION
//	Takes in N particles and redistributes them according
//	to their weights.
// INPUTS
//	particles - Array of N possible particles of class particle

function particle_filter(particles){

	var newParticles = [];
	// Weight array
	var weights = particales.map(p=>p.weight);
	//Get sampled index
	newIdx = Sampling.Discrete(weights);
	//Use plain for loop because it's the faster than for..of or forEach
	for (let i = 0 ; i< newIdx.length; i++){
		newParticles.push(particles[i].clone());
	}
	return newParticles;
}


// Action Model
//-------------------------
// DESCRIPTION
//	Takes in N particles along with current encoder values
//	and disperses them with error terms based on gaussian
//	distribution with constants K1 and K2
// INPUTS
// 	particles - Array of N possible particles of class particle
// 	leftEnc - Raw left encoder value
//	rightEnc - Raw right encoder value

function action_model(particles,leftEnc,rightEnc){
	for (i = 0;i < particles.length;i++){
		particles[i].updatePoseWithError(leftEnc,rightEnc);
	}
}

// Sensor Model
//-------------------------
// DESCRIPTION
//	Takes in N particles along with last laser scan and updates
//	weights based on this scan
// INPUTS
//	particles - Array of N possible particles of class particle
//	laser - Array of LIDAR points from one full scan
//	map - 2D Arrray of occupancy grid

function sensor_model(particles, laserData, mapData){
    var log_prob_total = 0;
    var largest_prob = -Infinity;

    // Calculating log probabilities for all particles
    particles.forEach(particle=>{
		// Log probability total for particle
		var log_prob = 0;

		for (let i = 0; i<laserData.length; i++){
			//Get obstacle data for a laser ray
			var {px_x, px_y, points_btwn} = calculatePixelPositions(particles, laserData[i], GRIDPX);
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

    for (i=0;i<particles.length;i++){
        // Shifting probabilities to prevent underflow
        particles[i].weight -= largest_prob;

        // Exponentiating each log
        particles[i].weight = Math.exp(particles[i].weight);

        // Calculating total for normalizing
        log_prob_total += particles[i].weight;
    }

    // Final normalizing step
    for (i=0;i<particles.length;i++){
        particles[i].weight /= log_prob_total;
    }

}

export {particle_filter, action_model, sensor_model}
