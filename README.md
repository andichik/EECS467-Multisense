# EECS467 W17 Experimental Section

## Hardware

##### Motor Controllers

The motor controllers are the [Dual MC33926 Motor Driver Carrier](https://www.pololu.com/product/1213) from Polulu.


## Software

##### Arduino 

The Arduino code to control the motors and get encoder readings. Wires each encoders to a interrupt pin. Requires the installation of the library in folder Encoder/ to run. Tested on Feb 3. 


##### Encoder

The [Encoder](https://www.pjrc.com/teensy/td_libs_Encoder.html) library used in Quadrature\_2. Has to be installed in the Arduino IDE ([instructions](https://www.arduino.cc/en/Guide/Libraries)) before you upload code to the Arduino.

##### MayApp

The macOS and iOS apps. It's one unified project so the two apps can share code. The Mac app is designed to run on a MacBook living in the robot. The iOS app is a remote control for the Mac app.

- Note: The Linux team will need to create a separate top level folder for their program.
- Note: Change the port number on line 16 in MayApp-common/RobotController.swift to the port connected to Arduino. (TODO: make it automatic)

##### urg\_library

A C/C++ library and sample project for communicating with the Hokuyo laser range finder. Tested this on a MacBook and was able to read values using the calculate\_xy sample program.

There is [comprehensive documentation](https://sourceforge.net/p/urgnetwork/wiki/Home/) for the sensor and this library.
