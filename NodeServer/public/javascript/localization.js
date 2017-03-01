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
	particles = newParticles;
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
	

}
