#include <Encoder.h>

class Motor {

  int pwm;
  int direction1;
  int direction2;

public:

  Motor(int pwm, int direction1, int direction2) :
  pwm(pwm), direction1(direction1), direction2(direction2) {}

  void setup() {

    pinMode(pwm, OUTPUT);
    pinMode(direction1, OUTPUT);
    pinMode(direction2, OUTPUT);
  }

  void setVelocity(int velocity) {

    bool forward = (velocity >= 0);
    
    analogWrite(pwm, abs(velocity));
    digitalWrite(direction1, forward);
    digitalWrite(direction2, !forward);
  }
};

Motor motorLeft(5, 12, 4);
Motor motorRight(11, 10, 9);
Encoder encdRight(3, 13);
Encoder encdLeft(2, 6);

void setup() {
  // put your setup code here, to run once:

  motorRight.setup();
  motorLeft.setup();
  
  Serial.begin(9600);
}

long positionLeft  = -999;
long positionRight = -999;

void loop() {

  if (Serial.available()) {

    String left = Serial.readStringUntil('l');
    String right = Serial.readStringUntil('r');

    int leftPWM = left.toInt() * 255 / 100;
    int rightPWM = right.toInt() * 255 / 100;
    //Serial.println(leftPWM);

    motorRight.setVelocity(rightPWM);
    motorLeft.setVelocity(leftPWM);
//    if (leftPWM == rightPWM && leftPWM == 0){
//      Serial.println("Reset both encoders to zero");
//      encdLeft.write(0);
//      encdRight.write(0);
//    }
  }

  long newLeft, newRight;
  newLeft = encdLeft.read();
  newRight = encdRight.read();
  if (newLeft != positionLeft || newRight != positionRight) {
    Serial.print("Left = ");\
    Serial.print(newLeft);
    Serial.print(", Right = ");
    Serial.print(newRight);
    Serial.println();
    positionLeft = newLeft;
    positionRight = newRight;
  }

}
