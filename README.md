# EECS467 W17 Experimental Section

## Hardware

##### Motor Controllers

The motor controllers are the [Dual MC33926 Motor Driver Carrier](https://www.pololu.com/product/1213) from Polulu.


## Software

##### Quadrature

Code for motor control and basic quadrature encoder reading. Tested.

##### Quadrature\_2

Uses the Encoder library for encoder reading. Tested with interrupt pins and works very well. This should be renamed to Arduino, replacing both version.

##### Encoder

The [Encoder](https://www.pjrc.com/teensy/td_libs_Encoder.html) library used in Quadrature\_2. Has to be installed in the Arduino IDE ([instructions](https://www.arduino.cc/en/Guide/Libraries)) before you upload code to the Arduino.

##### MayApp

The macOS and iOS apps. It's one unified project so the two apps can share code. The Mac app is designed to run on a MacBook living in the robot. The iOS app is a remote control for the Mac app.

- To build the Mac App, you will need to pull the ORSSerialPort *git submodule* separately from the main repo. To do this, run `git submodule update --init --recursive` from the root directory of the repo
- The iOS and Mac App talk to each other through the MultipeerConnectivity framework. Currently, data structures are packaged up into JSON for transmission.
- The Mac app talks to the Arduino through a custom protocol over serial.
    - Send "#l#r" to set speed of the motor where the first # is the speed of the left motor and the second # is the speed of the right motors.
    - The Arduino sends encoder values back in the form "#l#r" where each # corresponds to the values of the encoders for the left and right motors. (NOTE: this is not complete)

##### urg_library

A C/C++ library and sample project for communicating with the Hokuyo laser range finder. Tested this on a MacBook and was able to read values using the calculate_xy sample program.

There is [comprehensive documentation](https://sourceforge.net/p/urgnetwork/wiki/Home/) for the sensor and this library.

## Metrics

- One wheel revolution is about 1820 ticks
- Four feet of distance traveled is about 3200 ticks (we're still sampling this)