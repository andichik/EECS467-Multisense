//int quadA = 0;
//int quadB = 1;

class Motor {

  int pwm;
  int direction1;
  int direction2;
  int quad1;
  int quad2;

public:

  Motor(int pwm, int direction1, int direction2, int quad1, int quad2) :
  pwm(pwm), direction1(direction1), direction2(direction2), quad1(quad1), quad2(quad2) {}

  void setup() {

    pinMode(pwm, OUTPUT);
    pinMode(direction1, OUTPUT);
    pinMode(direction2, OUTPUT);
    pinMode(quad1, INPUT_PULLUP);
    pinMode(quad2, INPUT_PULLUP);
  }

  void setVelocity(int velocity) {

    bool forward = (velocity >= 0);
    
    analogWrite(pwm, abs(velocity));
    digitalWrite(direction1, forward);
    digitalWrite(direction2, !forward);
  }

  int getQuadReading() {
    int quadA = digitalRead(quad1);
    int quadB = digitalRead(quad2);
    // return the quad reading as 0, 1, 2, or 3
    return (quadA << 1) + quadB;
  }
};

Motor motorRight(3, 2, 4, 5, 6);
Motor motorLeft(11, 10, 9, 12, 13);

void setup() {
  // put your setup code here, to run once:

  motorRight.setup();
  motorLeft.setup();
  
  
  Serial.begin(9600);
}

int countLeft = 0;
int countRight = 0;

int oldLeft = LOW;
int oldRight = LOW;

void loop() {

  if (Serial.available()) {

    String left = Serial.readStringUntil('l');
    String right = Serial.readStringUntil('r');

    int leftPWM = left.toInt() * 255 / 100;
    int rightPWM = right.toInt() * 255 / 100;
    //Serial.println(leftPWM);

    motorRight.setVelocity(rightPWM);
    motorLeft.setVelocity(leftPWM);
  }

  int newLeft = motorLeft.getQuadReading();
  int newRight = motorRight.getQuadReading();
  
  if (oldLeft == 0 && newLeft == 2) {
    countLeft++;
  } else if (oldLeft == 2 && newLeft == 0) {
    countLeft--;
  }

  oldLeft = newLeft;
  oldRight = newRight;
  if (!(countLeft%10)){
    Serial.println(countLeft);
  }
}
