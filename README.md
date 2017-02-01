# EECS467 W17 Experimental Section

##### Quadrature

Code for motor control and basic quadrature encoder reading. Tested.

##### Quadrature\_2

Uses the Encoder library for encoder reading. Tested on January 31. Values printed for both wheels and trended in the right direction, but jumped around a lot. We need to change the wiring to use the interrupt pins.

##### Encoder

The [Encoder](https://www.pjrc.com/teensy/td_libs_Encoder.html) library used in Quadrature\_2.

##### MayApp

The macOS and iOS apps. It's one unified project so the two apps can share code. The Mac app is designed to run on a MacBook living in the robot. The iOS app is a remote control for the Mac app.

- Note: The Linux team will need to create a separate top level folder for their program.