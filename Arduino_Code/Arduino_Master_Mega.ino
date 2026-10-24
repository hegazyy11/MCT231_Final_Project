// ==========================================
// ARDUINO MEGA (MASTER - UI & COMMS)
// ==========================================

#include <Wire.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27, 16, 2); 

const int btnWhitePin  = 6;
const int btnBlackPin  = 9;
const int btnResetPin  = 2;  
const int btnSubmitPin = 13;
const int btStatePin   = 23;

// --- MAIN SORTING BUFFERS ---
char targetSequence[20];
int targetLength = 0;
char playerSequence[20];
int inputSlot = 0;

// --- SHOOTING PHASE BUFFERS ---
char fireTarget[5];
int fireLength = 0;
char firePlayer[5];
int fireSlot = 0;
bool isFiringPhase = false; // Flag to switch Mega's logic

int lastBtnWhiteState  = HIGH;
int lastBtnBlackState  = HIGH;
int lastBtnResetState  = HIGH;
int lastBtnSubmitState = HIGH;

enum GameState { 
  AWAIT_APP,     
  AWAIT_INPUT,   
  AWAIT_UNO      
};
GameState currentState = AWAIT_APP;

void setup() {
  Serial.begin(9600);    
  Serial1.begin(9600);   // Comm to Uno 
  Serial3.begin(9600);   // Comm to HC-05 

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("SYSTEM BOOTING..");
  delay(1000);

  pinMode(btnWhitePin, INPUT_PULLUP);
  pinMode(btnBlackPin, INPUT_PULLUP);
  pinMode(btnResetPin, INPUT_PULLUP);
  pinMode(btnSubmitPin, INPUT_PULLUP);
  pinMode(btStatePin, INPUT);

  resetToAwaitApp();
}

void loop() {
  // 1. Bluetooth Failsafe
  if (digitalRead(btStatePin) == LOW && currentState != AWAIT_APP) {
    Serial1.println("R"); 
    lcd.clear(); lcd.print("BT CONN LOST!"); delay(2000);
    resetToAwaitApp();
  }

  // 2. App Remote Reset / Graceful Exit
  if (Serial3.available() > 0) {
    char checkChar = Serial3.peek();
    if (checkChar == 'R') {
      while (Serial3.available() > 0) Serial3.read();
      Serial1.println("R");
      lcd.clear(); lcd.print("APP OVERRIDE"); delay(2000);
      resetToAwaitApp();
    }
    else if (checkChar == 'X') {
      // Graceful exit: tell the Uno to bring the ball home to the sorter, then stop.
      while (Serial3.available() > 0) Serial3.read();
      Serial1.println("X");
      lcd.clear(); lcd.print("ROUND EXITED"); delay(1500);
      resetToAwaitApp();
    }
  }

  switch (currentState) {
    case AWAIT_APP:   handleAwaitApp();   break;
    case AWAIT_INPUT: handleBatchInput(); break;
    case AWAIT_UNO:   handleAwaitUno();   break;
  }
}

void handleAwaitApp() {
  while (Serial3.available() > 0) {
    char c = Serial3.read();
    
    // Auto-Fire Bypass for Cadet Profile (Ages 2-5)
    if (c == 'A' && isFiringPhase) {
       Serial.println("[AUTO-FIRE]: Cadet bypass received.");
       Serial1.print('F'); // Send Fire command immediately
       lcd.clear(); lcd.setCursor(0,0); lcd.print("AUTO FIRING...");
       isFiringPhase = false;
       currentState = AWAIT_UNO; // Wait for Uno to finish lifting
       return;
    }
    
    // Store incoming color codes in the correct buffer
    if (c == 'W' || c == 'B') {
       if (isFiringPhase) fireTarget[fireLength++] = c;
       else targetSequence[targetLength++] = c;
    }
    
    // NEW: Wait for the newline termination character to confirm stream completion
    else if (c == '\n') {
       if (isFiringPhase && fireLength > 0) {
          currentState = AWAIT_INPUT;
          lcd.clear(); lcd.print("FIRE LEN: "); lcd.print(fireLength);
          updateLCDInput();
       } else if (!isFiringPhase && targetLength > 0) {
          currentState = AWAIT_INPUT;
          lcd.clear(); lcd.print("TARGET LEN: "); lcd.print(targetLength);
          updateLCDInput();
       }
    }
  }
}

void handleBatchInput() {
  int whiteState  = digitalRead(btnWhitePin);
  int blackState  = digitalRead(btnBlackPin);
  int resetState  = digitalRead(btnResetPin);
  int submitState = digitalRead(btnSubmitPin);

  // WHITE BUTTON
  if (whiteState == LOW && lastBtnWhiteState == HIGH) {
    delay(50);
    if (isFiringPhase) {
      if (fireSlot < fireLength) { firePlayer[fireSlot++] = 'W'; updateLCDInput(); }
    } else {
      if (inputSlot < targetLength) { playerSequence[inputSlot++] = 'W'; updateLCDInput(); }
    }
  }

  // BLACK BUTTON
  if (blackState == LOW && lastBtnBlackState == HIGH) {
    delay(50);
    if (isFiringPhase) {
      if (fireSlot < fireLength) { firePlayer[fireSlot++] = 'B'; updateLCDInput(); }
    } else {
      if (inputSlot < targetLength) { playerSequence[inputSlot++] = 'B'; updateLCDInput(); }
    }
  }

  // RESET BUTTON
  if (resetState == LOW && lastBtnResetState == HIGH) {
    delay(50);
    if (isFiringPhase) {
      fireSlot = 0; memset(firePlayer, 0, sizeof(firePlayer)); updateLCDInput();
    } else {
      inputSlot = 0; memset(playerSequence, 0, sizeof(playerSequence)); updateLCDInput();
    }
  }

  // SUBMIT BUTTON
  if (submitState == LOW && lastBtnSubmitState == HIGH) {
    delay(50);
    
    if (isFiringPhase) {
      // --- SUBMITTING FIRING CODE (Verify Immediately) ---
      if (fireSlot == fireLength) {
         bool isCorrect = true;
         for (int i=0; i<fireLength; i++) {
            if (firePlayer[i] != fireTarget[i]) isCorrect = false;
         }
         if (isCorrect) {
            Serial3.print('C'); // App registers success
            Serial1.print('F'); // Uno shoots
            lcd.clear(); lcd.print("FIRING...");
            isFiringPhase = false;
            currentState = AWAIT_UNO; // Go back to waiting for next ball or 'D'
         } else {
            Serial3.print('W'); // App registers fail, sends new code
            lcd.clear(); lcd.print("WRONG! NEW CODE.");
            delay(1500);
            // Clear buffers to receive the new code from App
            fireSlot = 0; fireLength = 0;
            memset(fireTarget, 0, sizeof(fireTarget));
            memset(firePlayer, 0, sizeof(firePlayer));
            currentState = AWAIT_APP; 
         }
      } else { showLCDWarning("INCOMPLETE CODE!"); }
      
    } else {
      // --- SUBMITTING MAIN SORTING CODE ---
      if (inputSlot == targetLength) {
         for(int i = 0; i < inputSlot; i++) Serial1.print(playerSequence[i]);
         Serial1.println();
         currentState = AWAIT_UNO;
         lcd.clear(); lcd.setCursor(0, 0); lcd.print("DATA SENT...");
         lcd.setCursor(0, 1); lcd.print("UNO EXECUTING...");
      } else { showLCDWarning("INCOMPLETE CODE!"); }
    }
  }

  lastBtnWhiteState  = whiteState;  lastBtnBlackState  = blackState;
  lastBtnResetState  = resetState;  lastBtnSubmitState = submitState;
}

// Dynamically draws the correct buffer based on the active phase
void updateLCDInput() {
  lcd.setCursor(0, 1); lcd.print("IN: ");
  int limit = isFiringPhase ? fireLength : targetLength;
  int current = isFiringPhase ? fireSlot : inputSlot;
  char* arr = isFiringPhase ? firePlayer : playerSequence;

  for (int i = 0; i < current; i++) lcd.print(arr[i]);
  for (int i = current; i < limit; i++) lcd.print('_');
  lcd.print("     ");
}

void showLCDWarning(const char* msg) {
  lcd.clear(); lcd.print("!! WARNING !!"); lcd.setCursor(0,1); lcd.print(msg);
  delay(1500);
  lcd.clear(); lcd.setCursor(0, 0); 
  if (isFiringPhase) { lcd.print("FIRE LEN: "); lcd.print(fireLength); } 
  else { lcd.print("TARGET LEN: "); lcd.print(targetLength); }
  updateLCDInput();
}

void handleAwaitUno() {
  if (Serial1.available() > 0) {
    char response = Serial1.read();
    
    // Uno signals ball is at shooter
    if (response == 'S') {
      isFiringPhase = true;
      Serial3.print('S'); // Tell App to trigger shooting UI
      lcd.clear(); lcd.print("BALL AT SHOOTER");
      
      // Prepare memory for incoming 3-color firing code
      fireLength = 0; fireSlot = 0;
      memset(fireTarget, 0, sizeof(fireTarget));
      memset(firePlayer, 0, sizeof(firePlayer));
      currentState = AWAIT_APP;
    } 
    // Uno signals entire physical process is complete
    else if (response == 'D') {
      isFiringPhase = false;
      verifyFinalSequence(); 
    }
  }
}

// Verifies the MAIN sorting code and closes the level
void verifyFinalSequence() {
  bool isCorrect = true;
  for (int i = 0; i < targetLength; i++) {
    if (playerSequence[i] != targetSequence[i]) isCorrect = false;
  }

  lcd.clear(); lcd.print("VERIFICATION:"); lcd.setCursor(0, 1);
  if (isCorrect) {
    Serial3.print('C'); // App closes main level
    lcd.print("** SUCCESS! **");
  } else {
    Serial3.print('W');
    lcd.print("FAILED-TRY AGAIN");
  }
  delay(4000); 
  resetToAwaitApp();
}

void resetToAwaitApp() {
  targetLength = 0; inputSlot = 0;
  memset(targetSequence, 0, sizeof(targetSequence));
  memset(playerSequence, 0, sizeof(playerSequence));
  
  fireLength = 0; fireSlot = 0;
  memset(fireTarget, 0, sizeof(fireTarget));
  memset(firePlayer, 0, sizeof(firePlayer));
  
  isFiringPhase = false;
  currentState = AWAIT_APP;

  // Drop any stale bytes still sitting in the Uno link (e.g. an 'S'/'D' left over
  // from a graceful exit) so they cannot trigger a phantom phase next round.
  while (Serial1.available() > 0) Serial1.read();

  lcd.clear(); lcd.setCursor(0, 0); lcd.print("AWAITING APP...");
  lcd.setCursor(0, 1);
  if(digitalRead(btStatePin) == HIGH) lcd.print("BT: CONNECTED");
  else lcd.print("BT: DISCONNECTED");
}