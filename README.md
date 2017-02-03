# EECS467 W17 Experimental Section

## Hardware

##### Motor Controllers

The motor controllers are the [Dual MC33926 Motor Driver Carrier](https://www.pololu.com/product/1213) from Polulu.


## Software

##### Quadrature

Code for motor control and basic quadrature encoder reading. Tested.

##### Quadrature\_2

Uses the Encoder library for encoder reading. Tested on January 31. Values printed for both wheels and trended in the right direction, but jumped around a lot. We need to change the wiring to use the interrupt pins.

##### Encoder

The [Encoder](https://www.pjrc.com/teensy/td_libs_Encoder.html) library used in Quadrature\_2. Has to be installed in the Arduino IDE ([instructions](https://www.arduino.cc/en/Guide/Libraries)) before you upload code to the Arduino.

##### MayApp

The macOS and iOS apps. It's one unified project so the two apps can share code. The Mac app is designed to run on a MacBook living in the robot. The iOS app is a remote control for the Mac app.

- Note: The Linux team will need to create a separate top level folder for their program.

##### urg_library

A C/C++ library and sample project for communicating with the Hokuyo laser range finder. Tested this on a MacBook and was able to read values using the calculate_xy sample program.

There is [comprehensive documentation](https://sourceforge.net/p/urgnetwork/wiki/Home/) for the sensor and this library.