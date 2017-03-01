import gaussian from 'gaussian'

// Particle Filter
//----------------
//INPUTS
//	particles - Array of N possible particles of class particle


// Action Model
//-------------------------
// INPUTS
// 	particles - Array of N possible particles of pose class
// 	leftEnc - Raw left encoder value
//	rightEnc - Raw right encoder value

function action_model(particles,leftEnc,rightEnc){
	for (i = 0;i < particles.length;i++){
		particles[i].update(leftEnc,rightEnc);
	}	
}
