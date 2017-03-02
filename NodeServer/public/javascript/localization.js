import gaussian from 'gaussian'
var SJS = Sampling = require('disrete-sampling');

// Particle Filter
//------------------------
// DESCRIPTION
//	Takes in N particles and redistributes them according
//	to their weights.
// INPUTS
//	particles - Array of N possible particles of class particle

function particle_filter(particles){

	// Declaring temporary array of new particles
	var newParticles = [];
	var weights = [];

	// Looping through particle weights
	for (i = 0;i < particles.length;i++){

		// Adding weights to array
        if(particle[i].weight > 0.001)
		    weights.push(particle[i].weight);
    }

    // Generate distribution of weights
    dist = Sampling.Discrete(weights);

    // Sample N weights
    new_weights = dist.sample(NUM_PARTICLES);

    // Sort weights for easy particle pairing
    new_weights.sort(function(a,b){return b-a});

    // Sort particles for easy particle pairing
    particles.sort(function(a,b){return b.weight-a.weight});

    // Pairing new sampled weights to particles
    let j = 0;
    for (i = 0;i < new_weight.length;i++){

        // Since ordered, can add same particle until weight changes
        if (particles[j].weight === new_weights[i])
            newParticles.push(particle[j].clone());

        // If no more of said weight, move onto next weight
        // and delete last particle
        else
            delete particle[j];
            newParticles.push(particle[++j].clone());          
    }

    // Delete particles whose weight below threshold
    for (j;j < NUM_PARTICLES;j++)
        delete particle[j];
    
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

function sensor_model(particles, laser, map){
    let log_prob_total = 0;

    // Calculating log probabilities for all particles
    for (let j = 0; j < particles.length;j++){

        // Log probability total for particle
        let log_prob_particle = 0;

	    for (let i = 0; i < laserData.length;i++) {
            
		    // Calculating pixel coordinates and pixels inbetween
		    px_calc = calculatePixelPositions(particle, laserData,PX);

            // Setting log probability for case where obstacle is past laser
            log_prob = -12;

            // Looping through between particle and laser to find obstacle
		    for (var j = 0; j < px_calc.points_btwn.length; j++) {
		        let {x, y} = px_calc.points_btwn[j];

			    // Check if grid pixel is occupied
		        if (mapData[x][y] >= 0.5){
                    // Checking if occupied pixel is laser pixel
			        if (j === px_calc.points_btwn.length-1){
				        log_prob = -4;
                        break;
                    }
                    // If not, we know there is object before laser point
			        else{
				        log_prob = -8;
                        break;
                    }
                }
		    }
            log_prob_particle += log_prob;
	    }
        particle[j].weight = log_prob_particle;
        log_prob_total += log_prob_particle;
    }

    // Normalizing log probabilities
    // NOT CORRECT, needs work to prevent underflow issues
    // ref 07_localization slides
    for (i=0;i<particles.length;i++){
        particle[i].weight /= log_prob_total;

}
