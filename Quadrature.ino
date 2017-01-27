//int quadA = 0;
//int quadB = 1;

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

Motor motorRight(3, 2, 4);
Motor motorLeft(11, 10, 9);

void setup() {
  // put your setup code here, to run once:

  //pinMode(quadA, INPUT_PULLUP);
  //pinMode(quadB, INPUT_PULLUP);

  motorRight.setup();
  motorLeft.setup();

  Serial.begin(9600);
}

//int count = 0;

//int currentA = LOW;
//int currentB = LOW;

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

  /*int newA = digitalRead(quadA);
  int newB = digitalRead(quadB);

  if (currentA == 0 && currentB == 0 && newA == 1 && newB == 0) {
    count++;
    Serial.println(count);
  } else if (currentA == 1 && currentB == 0 && newA == 0 && newB == 0) {
    count--;
    Serial.println(count);
  }

  currentA = newA;
  currentB = newB;*/
}
