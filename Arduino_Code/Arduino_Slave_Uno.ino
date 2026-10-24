#include <Servo.h>
#include <SoftwareSerial.h>

// ==========================================
// ARDUINO UNO (SLAVE - SENSORS, SERVOS, MOTORS)
// ==========================================

// --- SOFTWARE SERIAL SETUP ---
// RX Pin = A0 (Connect to Mega TX1 Pin 18)
// TX Pin = A1 (Connect to Mega RX1 Pin 19)
SoftwareSerial megaComm(A0, A1);

// --- SORTING PINS ---
const int irPresencePin   = 3;
const int irColorPin      = 6;
const int colorIrPowerPin = 7;
const int holderServoPin  = 8;   // UPDATED to match sorting.ino
const int pathServoPin    = 9;   // UPDATED to match sorting.ino

// --- LIFTING PINS ---
const int liftir          = 5;   // UPDATED to match lifting.ino
const int liftServoPin    = 10;  // UPDATED to match lifting.ino

// --- SHOOTER PINS ---
const int limitSwitchPin  = 2;
const int irShooterPin    = 4;
const int enA = 11;              // PWM Speed Control
const int in1 = 12;              // Motor Direction 1
const int in2 = 13;              // Motor Direction 2

// --- SERVO ANGLES ---
const int HOLDER_HOME  = 180;    // UPDATED to match sorting.ino
const int HOLDER_REACH = 90;     // UPDATED to match sorting.ino

const int PATH_HOME    = 105;    // UPDATED to match sorting.ino
const int PATH_SHOOTER = 142;    // Mapped from PATH_WHITE in sorting.ino
const int PATH_RETURN  = 97;     // Mapped from PATH_BLACK in sorting.ino

// --- MOTOR SPEEDS ---
const int FULL_SPEED = 100;       // Speed for shooting
const int SLOW_SPEED = 35;       // Speed for retracting to limit switch

Servo holderServo;
Servo pathServo;
Servo liftServo;

String activeSequence = "";
int targetLength = 0;
int sortingSlot = 0;

enum SystemState { IDLE, SORTING };
SystemState currentState = IDLE;

// Graceful-exit flag: when set, the current ball is allowed to finish its trip
// back to the sorter (via shoot/lift), then the loop STOPS and accepts no new balls.
bool exitRequested = false;

void setup() {
  // 1. Hardware Serial for PC Debugging
  Serial.begin(9600);

  // 2. Software Serial for Mega Communication
  megaComm.begin(9600); 

  Serial.println("==================================");
  Serial.println("   UNO BRAWN SYSTEM BOOTING       ");
  Serial.println("==================================");

  // Initialize Sensors
  pinMode(irPresencePin, INPUT_PULLUP);
  pinMode(irColorPin, INPUT_PULLUP);
  pinMode(colorIrPowerPin, OUTPUT);
  digitalWrite(colorIrPowerPin, LOW); // Keep IR LED off initially
  pinMode(limitSwitchPin, INPUT_PULLUP);
  pinMode(irShooterPin, INPUT_PULLUP);
  
  // Initialize Lifting IR
  pinMode(liftir, INPUT_PULLUP);

  // Initialize Motor
  pinMode(enA, OUTPUT);
  pinMode(in1, OUTPUT);
  pinMode(in2, OUTPUT);
  stopMotor();

  // Initialize Servos
  holderServo.attach(holderServoPin);
  pathServo.attach(pathServoPin);
  liftServo.attach(liftServoPin);
  
  // Default Servo Positions
  holderServo.write(HOLDER_HOME);
  pathServo.write(PATH_HOME);
  liftServo.write(0); // Default lifting position
  delay(1000);

  // Initial Homing for Shooter
  Serial.println("[HOMING]: Retracting shooter...");
  while (digitalRead(limitSwitchPin) == HIGH) {
    retractMotor(SLOW_SPEED);
  }
  stopMotor();
  Serial.println("[HOMING]: Complete. Awaiting commands from Mega.");
}

void loop() {
  // ==========================================
  // 1. Check for commands from Mega on the A0/A1 pins
  // ==========================================
  if (megaComm.available() > 0) {
    String incoming = megaComm.readStringUntil('\n');
    incoming.trim();
    
    if (incoming == "R") {
      Serial.println("\n[MEGA COMMAND]: EMERGENCY RESET!");
      resetSystem();
    }
    else if (incoming == "X") {
      // Graceful exit. If a ball is mid-loop, the sorting handler sees this flag and
      // brings it home; if we are idle right now, just stop everything at the sorter.
      Serial.println("\n[MEGA COMMAND]: GRACEFUL EXIT REQUESTED.");
      exitRequested = true;
      if (currentState == IDLE) stopAtSorter();
    }
    else if (incoming.length() > 0 && currentState == IDLE) {
      activeSequence = incoming;
      targetLength = incoming.length();
      sortingSlot = 0;
      currentState = SORTING;
      
      Serial.print("\n[MEGA COMMAND]: New Sequence Secured: ");
      Serial.println(activeSequence);
    }
  }

  // ==========================================
  // 2. Execute physical sorting if active
  // ==========================================
  if (currentState == SORTING) {
    executeSortingAndShooting();
  }
}

void executeSortingAndShooting() {
  // Graceful exit: stop here at the sorter and do NOT start a new ball into the loop.
  if (exitRequested) { stopAtSorter(); return; }

  int ballPresent = digitalRead(irPresencePin);

  // Check if a physical ball dropped into the holder
  if (ballPresent == LOW) {
    delay(400); // Wait for physical stabilization
    
    // Power up Color IR and read
    digitalWrite(colorIrPowerPin, HIGH);
    delay(50);
    int colorReading = digitalRead(irColorPin);
    char detectedColor = (colorReading == LOW) ? 'W' : 'B';
    digitalWrite(colorIrPowerPin, LOW);

    Serial.print("\n[SENSOR]: Detected a ");
    Serial.print(detectedColor == 'W' ? "WHITE" : "BLACK");
    Serial.println(" ball.");

    // ==========================================
    // COMPARISON LOGIC
    // ==========================================
    if (detectedColor == activeSequence[sortingSlot]) {
      
      // --- MATCH: SUCCESS -> SHOOTER PATH ---
      Serial.println("[RESULT]: Match! Routing to SHOOTER PATH.");
      pathServo.write(PATH_SHOOTER);
      delay(1000); // Wait for path to align
      
      holderServo.write(HOLDER_REACH);
      delay(2000); // Wait for ball to roll down to shooter IR
      
      holderServo.write(HOLDER_HOME);
      delay(500);
      pathServo.write(PATH_HOME);
      delay(500);

      // --- EXECUTE SHOOTING MECHANISM ---
      Serial.println("[SHOOTER]: Waiting for ball to arrive at barrel...");
      unsigned long shooterWaitStart = millis();
      while(digitalRead(irShooterPin) == HIGH) {
        // Abort on 'R'; on 'X' (graceful exit) keep waiting for the ball so we can
        // still fire it onward to the lift and home it to the sorter.
        if(megaComm.available() > 0) {
          char pc = megaComm.peek();
          if (pc == 'R') { megaComm.read(); resetSystem(); return; }
          else if (pc == 'X') { megaComm.read(); exitRequested = true; }
          else megaComm.read();
        }
        // Safety: on exit, never hang forever if the ball never reaches the barrel.
        if (exitRequested && millis() - shooterWaitStart > 6000) { stopAtSorter(); return; }
      }
      delay(100); // Debounce physical drop

      // NEW: Tell Mega the ball is ready and WAIT for the Fire Command.
      // On a graceful exit we skip this — the Mega has already reset and we are only
      // firing the ball onward to home it; a stray 'S' would confuse the next round.
      Serial.println("[SHOOTER]: Ball arrived! Requesting FIRE code from Mega...");
      if (!exitRequested) megaComm.print('S');

      bool fireCommandReceived = false;
      Serial.println("[SHOOTER]: Waiting for 'F' (Fire) command...");
      while (!fireCommandReceived) {
        // Graceful exit: don't wait for the Mega's 'F' — auto-fire to push the ball
        // toward the lift so it can be returned to the sorter.
        if (exitRequested) { fireCommandReceived = true; break; }
        if(megaComm.available() > 0) {
          char cmd = megaComm.read();
          if (cmd == 'F') {
            fireCommandReceived = true;
          } else if (cmd == 'R') {
            resetSystem();
            return;
          } else if (cmd == 'X') {
            exitRequested = true;
            fireCommandReceived = true;
          }
        }
      }

      Serial.println("[SHOOTER]: Fire command received! Firing...");
      while(digitalRead(irShooterPin) == LOW) {
        shootMotor(FULL_SPEED);
      }
      stopMotor();
      delay(100); // Prevent back-EMF voltage spike

      Serial.println("[SHOOTER]: Ball left chamber. Reloading...");
      while(digitalRead(limitSwitchPin) == HIGH) {
        retractMotor(SLOW_SPEED);
      }
      stopMotor();
      Serial.println("[SHOOTER]: Reloaded.");

      // --- EXECUTE LIFTING MECHANISM ---
      // If the emergency reset is triggered during lifting, exit the function.
      if (!runLiftingSequence()) return;

      // Graceful exit: the ball is now back at the sorter — stop the loop here.
      if (exitRequested) { stopAtSorter(); return; }

      // Move to next ball in sequence
      sortingSlot++;

      // Check if the entire sequence is complete
      if (sortingSlot >= targetLength) {
        Serial.println("[SYSTEM]: Sequence Complete! Telling Mega we are DONE.");
        megaComm.print('D'); // Transmit Completion Signal to Mega
        currentState = IDLE;
      }
      
    } else {
      
      // --- MISMATCH: FAIL -> RETURN PATH ---
      Serial.println("[RESULT]: Wrong ball! Routing to RETURN PATH.");
      pathServo.write(PATH_RETURN); 
      delay(1000); // Wait for path to align
      
      holderServo.write(HOLDER_REACH);
      delay(2000); // Wait for ball to bypass shooter and roll to the lift IR
      
      holderServo.write(HOLDER_HOME);
      delay(500);
      pathServo.write(PATH_HOME);
      delay(500);
      
      // --- EXECUTE LIFTING MECHANISM ---
      // The ball rolls directly to the lift. We wait for it and lift it.
      if (!runLiftingSequence()) return;

      // Graceful exit: the ball is now back at the sorter — stop the loop here.
      if (exitRequested) { stopAtSorter(); return; }

      // Note: sortingSlot does not increment. User must retry this exact slot.
    }
    delay(1000); // Safety delay between processing balls
  }
}

// ==========================================
// LIFTING CONTROL HELPER
// ==========================================
// Returns true if completed successfully, false if aborted by a reset command.
bool runLiftingSequence() {
  Serial.println("[LIFT]: Waiting for ball to arrive at the elevator...");
  unsigned long liftWaitStart = millis();
  while(digitalRead(liftir) == HIGH) {
    // Abort on 'R'; on 'X' (graceful exit) keep going so the lift still carries the
    // ball back up to the sorter before we stop.
    if(megaComm.available() > 0) {
      char pc = megaComm.peek();
      if (pc == 'R') { megaComm.read(); resetSystem(); return false; }
      else if (pc == 'X') { megaComm.read(); exitRequested = true; }
      else megaComm.read();
    }
    // Safety: on exit, never hang forever if the ball never reaches the lift.
    if (exitRequested && millis() - liftWaitStart > 6000) { stopAtSorter(); return false; }
  }
  
  Serial.println("[LIFT]: Object detected! Waiting 2 seconds...");
  delay(2000);
  
  Serial.println("[LIFT]: Moving servo to 95 degrees.");
  liftServo.write(95);
  
  delay(2000);
  
  Serial.println("[LIFT]: Returning servo to 0 degrees.");
  liftServo.write(0);
  delay(1000); // Buffer delay

  return true;
}

// ==========================================
// MOTOR CONTROL HELPERS
// ==========================================
void shootMotor(int speed) {
  digitalWrite(in1, HIGH);
  digitalWrite(in2, LOW);
  analogWrite(enA, speed);
}

void retractMotor(int speed) {
  digitalWrite(in1, LOW);
  digitalWrite(in2, HIGH);
  analogWrite(enA, speed);
}

void stopMotor() {
  digitalWrite(in1, LOW);
  digitalWrite(in2, LOW);
  analogWrite(enA, 0);
}

// ==========================================
// GRACEFUL EXIT
// ==========================================
// Called once the ball is safely back at the sorter. Parks every mechanism and
// stops the loop so no further balls are sorted until a new round starts.
void stopAtSorter() {
  Serial.println("\n[EXIT]: Ball home at sorter. Stopping the loop.");
  stopMotor();
  holderServo.write(HOLDER_HOME);
  pathServo.write(PATH_HOME);
  liftServo.write(0);
  currentState = IDLE;
  activeSequence = "";
  sortingSlot = 0;
  exitRequested = false;
}

// ==========================================
// SYSTEM RESET
// ==========================================
void resetSystem() {
  Serial.println("\n[SYSTEM]: Performing Emergency Reset.");
  stopMotor();
  holderServo.write(HOLDER_HOME);
  pathServo.write(PATH_HOME);
  liftServo.write(0);
  currentState = IDLE;
  activeSequence = "";
  sortingSlot = 0;
  exitRequested = false;
}