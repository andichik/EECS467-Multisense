import gaussian from 'gaussian'

// Particle Filter
//------------------------
// DESCRIPTION
//	Takes in N particles and redistributes them according
//	to their weights.
// INPUTS
//	particles - Array of N possible particles of class particle
// ASSUMPTIONS
//	Function assumes sensor model ensures no "half particles",
//	i.e. there are no weights which are not divisible by 1/N

function particle_filter(particles){

	// Declaring temporary array of new particles
	var newParticles = [];
	var num_particles = 0;

	// Looping through particle weights
	for (i = 0;i < particles.length;i++){

		// Copying particles based on weight, i.e.
		// higher weight gets more particles
		num_particles = particle[i].weight*NUM_PARTICLES;

		// Pushing copies of old particle to array
		for (j = 0;j < num_particles;j++){		
			newParticles.push(particle[i].clone());
		}
		
		delete particle[i];

	// Set old particles reference to new particles
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
		        if (mapData[x][y] >= 0.5)
                    // Checking if occupied pixel is laser pixel
			        if (j === px_calc.points_btwn.length-1)
				        log_prob = -4;
                        break;
                    // If not, we know there is object before laser point
			        else
				        log_prob = -8;
                        break;
		    }
            log_prob_particle += log_prob;
	    }
        particle[j].weight = log_prob_particle;
        log_prob_total += log_prob_particle;
    }

    // Normalizing log probabilities
    // Not correct, need to look into underflow problem
    //for (i=0;i<particles.length;i++){
    //    particle[i].weight /= log_prob_total;

}
