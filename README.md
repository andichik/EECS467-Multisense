# EECS467 W17 Experimental Section

## Hardware

#### Motor Controllers

The motor controllers are the [Dual MC33926 Motor Driver Carrier](https://www.pololu.com/product/1213) from Polulu.


## Software

#### Arduino

The Arduino code to control the motors and get encoder readings. Wires each encoder to a interrupt pin. Requires the installation of the library in folder Encoder/ to run. Tested on Feb 3.

#### Encoder

The [Encoder](https://www.pjrc.com/teensy/td_libs_Encoder.html) library used in Quadrature\_2. Has to be installed in the Arduino IDE ([instructions](https://www.arduino.cc/en/Guide/Libraries)) before you upload code to the Arduino.

#### MayApp

The macOS and iOS apps. It's one unified project so the two apps can share code. The Mac app is designed to run on a MacBook living in the robot. The iOS app is a remote control for the Mac app.

- Note: Change the port numbers on 16, 17 in MayApp-common/RobotController.swift to the usb ports connected to the devices (Arduino / sensor). (TODO: make it automatic)
- To build the Mac App, you will need to pull the ORSSerialPort *git submodule* separately from the main repo. To do this, run `git submodule update --init --recursive` from the root directory of the repo
- The iOS and Mac App talk to each other through the MultipeerConnectivity framework. Currently, data structures are packaged up into JSON for transmission.
- The Mac app talks to the Arduino through a custom protocol over serial.
    - Send "#l#r" to set speed of the motor where the first # is the speed of the left motor and the second # is the speed of the right motors.
    - The Arduino sends encoder values back in the form "b#l#r" where each # corresponds to the values of the encoders for the left and right motors.

#### ElectronApp

The alternative to MayApp, a cross-platform app that can run on Windows, Linux and Mac. Built using [Electon](http://electron.atom.io) with JavaScript.

##### How to Use

Currently exe or other executable file are noy generated. Just clone the repo, then run `npm install` followed by `npm run rebuild` to set up the environment. Finally, run `npm start to see the app running`

You need to add your serial port info to html and select them through the app.

##### urg\_library

A C/C++ library and sample project for communicating with the Hokuyo laser range finder. Tested this on a MacBook and was able to read values using the calculate\_xy sample program.

There is [comprehensive documentation](https://sourceforge.net/p/urgnetwork/wiki/Home/) for the sensor and this library.

## Metrics

- One wheel revolution is about 1820 ticks
- Four feet of distance traveled is about 3500 ticks (we're still sampling this)
