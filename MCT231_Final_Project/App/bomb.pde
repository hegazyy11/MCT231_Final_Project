`  // =========================================================
// DESKTOP JAVA SIMULATOR MODE (WITH REAL AUDIO)
// =========================================================

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import java.util.UUID;
import java.util.Set;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;
import android.content.Intent;
import android.provider.Settings;
import android.media.MediaPlayer;
import android.content.res.AssetFileDescriptor;

// NATIVE ANDROID BLUETOOTH VARIABLES
BluetoothAdapter btAdapter;
BluetoothSocket btSocket;
InputStream btIn;
OutputStream btOut;
boolean serialAvailable = false;
String[] availablePorts; 
String[] availableMacs;  
String currentPortName = "";
Thread btThread;

final UUID SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

// UPDATED: Section 6 BUG 7 — one-time blurred background snapshot
PGraphics blurredBG;
boolean blurReady = false;

// =========================================================
// GAME STATES & UI CONSTANTS
// =========================================================
// UPDATED: Section 2a — new port-select state, initial state changed
final int STATE_PORT_SELECT       = -2;
final int STATE_DIFFICULTY_SELECT = -1;
final int STATE_DASHBOARD         = 0;
final int STATE_GAMEPLAY          = 1;
int currentState = STATE_PORT_SELECT;

float BOT_H, LEFT_W, RIGHT_W, MID_X, MID_W, PANEL_Y, PANEL_H, PAD;

// =========================================================
// SIMULATOR VARIABLES
// =========================================================
boolean btSimulating = false; 
boolean btDone       = false;
float   btProgress   = 0.0;
float   dashTime = 0;
int     simulateBtStartTime = 0; 

// =========================================================
// GAME VARIABLES
// =========================================================
boolean isConnected = false;
int score = 0, highScore = 0, lives = 3, bestStreak = 0, maxPhaseReached = 1;
int streak = 0, inputIndex = 0, codeDisplayStartTime = 0;
float shakeFrames = 0;
int ballsShot = 0; 
int displayLength = 0; // NEW: Tracks code length including fakes

// Main Code Variables
char[]  codeArray    = new char[20]; // UPDATED: Section 6 BUG 6 — grown 10 -> 20
boolean codeGenerated = false, WaitingForPlayerToEnterCode = false;
boolean isCodeVisible = false, isBossStage = false;
boolean isMirrorHackActive = false; // NEW: Tracks if the mirror virus is active
// Shooting Code Variables
char[]  shootingCodeArray = new char[20]; // UPDATED: Section 6 BUG 6 — grown 10 -> 20
int     shootingCodeLength = 2;
boolean isShootingPhase = false;
boolean isShootingCodeVisible = false;
boolean WaitingForShootingInput = false;
int     shootingCodeDisplayStartTime = 0;

// --- DUAL TIMER SYSTEM VARIABLES ---
// UPDATED: Section 6 BUG 1 — named main-timer constant, longer countdown
final float MAIN_TIMER_SECONDS = 180.0;
float  timer         = MAIN_TIMER_SECONDS;
float  drainSpeed    = 180.0 / 10800.0;
float  shootingTimer = 10.0;
String currentShootingCode = "";

// UPDATED: Section 6 BUG 6 — arrays grown 10 -> 20
float[] pillarHeight = new float[20];

int baseLevel = 2, maxLevel  = 4, currentLevel = 2;
String difficultyName = "AWAITING CONFIG";
String feedbackMessage = "AWAITING HC-05 UPLINK..."; // UPDATED: Section 3

float bombRotY = 0, sphereRotY = 0, sphereRotX = 0;
float currentSphereRotSpeed = 0.005;

boolean showVictory = false;
float   victoryPulseRadius = 0;

boolean isShattered = false, isRepairing = false;
int shatterStartTime = 0, repairStartTime = 0;
int numShards = 300;
float[] shardX=new float[300], shardY=new float[300], shardZ=new float[300];
float[] shardVX=new float[300],shardVY=new float[300],shardVZ=new float[300];

// ---- Palette ----
// UPDATED: Section 1 — full palette rebrand (Lunar Reactor Sabotage)
color cNavyDeep   = color(9,  18,  34);   // #091222
color cNavyMid    = color(12, 23,  48);   // #0C1730
color cPanel      = color(20, 39,  74);   // #142744
color cPanel2     = color(26, 49,  88);   // #1A3158
color cLeadGrey   = color(159,177,204);   // #9FB1CC
color cLeadDark   = color(39,  57,  92);  // #273960 (LINE colour)
color cBorder     = color(39,  57,  92);  // same as cLeadDark
color cEnergyCyan = color(43, 212,230);   // #2BD4E6
color cCyanDim    = color(18, 112,126);   // #12707E
color cWarningRed = color(255, 92, 108);  // #FF5C6C
color cWhite      = color(238,244,251);   // #EEF4FB
color cGold       = color(255,200, 50);   // unchanged
color cGreen      = color(84, 224,160);   // #54E0A0 (success states)

// UPDATED: Section 5c — correct/wrong full-screen flash
int flashFrames = 0;
color flashColor;

// =========================================================
// NEW: LEVEL SYSTEM & FEATURE STATE
// =========================================================
int     level         = 1;            // 1-based phase inside a run
int     maxLevelCount = 3;            // number of levels in the chosen profile
boolean isEngineer    = false;        // profile flag (CADET vs ENGINEER)
String[] levelNames   = { "PRIMING", "CALIBRATION", "OVERLOAD", "CASCADE", "MELTDOWN", "SINGULARITY" };

int   seqLen          = 3;            // real fuel cells to memorise this level
int   decoyCount      = 1;            // distractor (red) cells this level
int   revealMs        = 900;          // ms each cell stays lit during reveal
float levelTimerSecs  = 30.0;         // input time budget for this level
float timerMax        = 30.0;         // current timer ceiling (for the bar)

int   multiplier      = 1;            // combo multiplier (x1..x5) driven by streak

boolean isPaused      = false;        // pause overlay (P / ESC)
boolean muted         = false;        // master mute (M)

boolean isCountingDown = false;       // GET READY 3-2-1 before each reveal
int     countdownStart = 0;

boolean hintActive    = false;        // peek-at-sequence (H), costs time
int     hintStart     = 0;

int totalAttempts = 0, totalSuccess = 0, bestLevel = 1; // lifetime accuracy stats

String toastMsg   = "";               // milestone / achievement toast
int    toastUntil = 0;

boolean achFirstDefusal = false;      // one-shot achievement guard
int     lastMs = 0;                   // frame timestamp for pause-freeze

// =========================================================
// NEW: ANIMATED SPACE BACKGROUND + MOBILE UI STATE
// =========================================================
float   TOP_BAR = 30;                 // height of the top status strip
boolean menuOpen = false;             // burger menu (Mission Hub)
boolean showBg   = true;              // toggle background animation (perf/clarity)

// Twinkling starfield (two parallax layers baked into one array)
final int N_STARS = 220;
float[] sx = new float[N_STARS], sy = new float[N_STARS], ss = new float[N_STARS], sp = new float[N_STARS];

// Drifting space sprites (UFOs, spaceships, astronauts)
ArrayList<SpaceObj> spaceObjs;

// On-screen touch buttons: each entry = {x, y, w, h, id}
ArrayList<float[]> uiBtns = new ArrayList<float[]>();



// =========================================================
// SETUP
// =========================================================
void setup() {
fullScreen(P3D);
  orientation(LANDSCAPE);
  smooth(8);
  // UPDATED: font changed to San Francisco Pro Display (Semibold) loaded from data/
  textFont(createFont("SF-Pro-Display-Semibold.otf", 128, true));
  textAlign(CENTER, CENTER);
  noStroke();

  for (int i = 0; i < 20; i++) pillarHeight[i] = 0; // UPDATED: Section 6 BUG 6 — loop grown to 20

  // NEW: build the animated space background (stars + drifting sprites)
  initSpaceBackground();

  PAD     = width  * 0.007;
  BOT_H   = height * 0.085;
  LEFT_W  = width  * 0.175;
  RIGHT_W = width  * 0.175;
  MID_X   = LEFT_W + PAD * 2;
  MID_W   = width  - LEFT_W - RIGHT_W - PAD * 4;
  PANEL_Y = TOP_BAR + PAD;                         // NEW: leave room for the top status strip
  PANEL_H = height - BOT_H - PANEL_Y - PAD;        // NEW: stop above the bottom bar

  loadGameData();
  btAdapter = BluetoothAdapter.getDefaultAdapter();
  if (btAdapter != null && btAdapter.isEnabled()) {
    Set<BluetoothDevice> pairedDevices = btAdapter.getBondedDevices();
    availablePorts = new String[pairedDevices.size()];
    availableMacs = new String[pairedDevices.size()];
    int i = 0;
    for (BluetoothDevice device : pairedDevices) {
      availablePorts[i] = device.getName();
      availableMacs[i] = device.getAddress();
      i++;
    }
  } else {
    availablePorts = new String[0];
    availableMacs = new String[0];
  }
  initAudio();
}

// =========================================================
// NATIVE ANDROID AUDIO ENGINE
// =========================================================
MediaPlayer sndSuccess, sndExplosion, sndUplink, sndTick, sndShootSuccess, sndShootFail;

void initAudio() {
  sndSuccess      = loadNativeSound("success.wav");
  sndExplosion    = loadNativeSound("explosion.mp3");
  sndUplink       = loadNativeSound("uplink.mp3");
  sndTick         = loadNativeSound("tick.mp3");
  if (sndTick != null) sndTick.setVolume(0.5f, 0.5f); // Lower tick volume
  sndShootSuccess = loadNativeSound("shoot_success.mp3");
  sndShootFail    = loadNativeSound("shoot_fail.mp3");
  println("[SYSTEM]: Android Audio Engine Initialized.");
}

MediaPlayer loadNativeSound(String filename) {
  MediaPlayer mp = new MediaPlayer();
  try {
    AssetFileDescriptor afd = getActivity().getAssets().openFd(filename);
    mp.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
    mp.prepare();
    return mp;
  } catch (Exception e) {
    println("[ERROR]: Could not load audio file: " + filename);
    return null;
  }
}

void playSound(String soundName) {
  if (muted) return;
  try {
    MediaPlayer mp = null;
    if      (soundName.equals("success.wav")) mp = sndSuccess;
    else if (soundName.equals("explosion.mp3")) mp = sndExplosion;
    else if (soundName.equals("uplink.mp3")) mp = sndUplink;
    else if (soundName.equals("shoot_success.mp3")) mp = sndShootSuccess;
    else if (soundName.equals("shoot_fail.mp3")) mp = sndShootFail;
    else if (soundName.equals("tick.mp3")) mp = sndTick;

    if (mp != null) {
      mp.seekTo(0); // Rewind to start
      mp.start();   // Play
    }
  } catch (Exception e) {
    println("[AUDIO ERROR]: Failed to play " + soundName);
  }
}
// =========================================================
// DRAW
// =========================================================
void draw() {
  // UPDATED: Section 2a — port-select is the first branch
  if (currentState == STATE_PORT_SELECT) {
    drawPortSelect();
  }
  else if (currentState == STATE_DIFFICULTY_SELECT) {
    // UPDATED: Section 6 BUG 7 — render+blur the dashboard ONCE into a buffer
    if (!blurReady) {
      drawDashboard();                 // draw the live dashboard to the screen once
      PImage snap = get();             // snapshot the current frame
      snap.filter(BLUR, 5);            // blur the snapshot a single time
      blurredBG = createGraphics(width, height, P3D);
      blurredBG.beginDraw();
      blurredBG.image(snap, 0, 0);
      blurredBG.endDraw();
      blurReady = true;
    }
    image(blurredBG, 0, 0);
    drawDifficultySelect();
  }
  else if (currentState == STATE_DASHBOARD) {
    drawDashboard();
  }
  else if (currentState == STATE_GAMEPLAY) {
    drawGameplay();
  }
}

// =========================================================
// UPDATED: Section 2a — PORT SELECTION SCREEN
// =========================================================
void drawPortSelect() {
  background(cNavyDeep);
  drawSpaceBackground(120, 160);

  // Auto-refresh the bonded devices live
  if (btAdapter != null && btAdapter.isEnabled()) {
    Set<BluetoothDevice> pairedDevices = btAdapter.getBondedDevices();
    availablePorts = new String[pairedDevices.size()];
    availableMacs = new String[pairedDevices.size()];
    int i = 0;
    for (BluetoothDevice device : pairedDevices) {
      availablePorts[i] = device.getName();
      availableMacs[i] = device.getAddress();
      i++;
    }
  }

  textAlign(CENTER, CENTER);
  fill(cEnergyCyan);
  gtFit("SELECT HC-05 BLUETOOTH DEVICE", width/2, height * 0.12, width*0.8, height * 0.06);

  int n = (availablePorts == null) ? 0 : availablePorts.length;
  float bW = width * 0.45, bH = height * 0.09, bX = width/2 - bW/2;
  float startY = height * 0.24, gap = bH * 0.30;

  // Draw the buttons for whatever devices are currently paired
  for (int i = 0; i < n; i++) {
    float bY = startY + i * (bH + gap);
    boolean hover = (mouseX > bX && mouseX < bX + bW && mouseY > bY && mouseY < bY + bH);
    fill(hover ? cPanel2 : cPanel, 245);
    stroke(cEnergyCyan, hover ? 255 : 160); strokeWeight(2);
    rect(bX, bY, bW, bH, 10); noStroke();
    fill(cWhite);
    textSize(bH * 0.40);
    gt(availablePorts[i], width/2, bY + bH/2);
  }

  // The "OPEN ANDROID BLUETOOTH SETTINGS" Button
  float simY = startY + max(1, n) * (bH + gap) + gap;
  boolean simHover = (mouseX > bX && mouseX < bX + bW && mouseY > simY && mouseY < simY + bH);
  fill(simHover ? color(60,48,0) : color(50,38,0), 240);
  stroke(cGold, simHover ? 255 : 180); strokeWeight(2);
  rect(bX, simY, bW, bH, 10); noStroke();
  fill(cGold);
  textSize(bH * 0.38);
  gt("OPEN BLUETOOTH SETTINGS", width/2, simY + bH/2);
}
// =========================================================
//  DIFFICULTY SELECTION POPUP
// =========================================================
void drawDifficultySelect() {
  fill(0, 0, 0, 120); rect(0, 0, width, height);
  float pW = width * 0.45, pH = height * 0.50;
  float pX = width/2 - pW/2, pY = height/2 - pH/2;

  panel(pX, pY, pW, pH, "REACTOR BOOT SEQUENCE");
  textAlign(CENTER, CENTER); fill(cWhite);
  gtFit("SELECT OPERATOR PROFILE", width/2, pY + pH*0.18, pW*0.9, pH * 0.10);

  float bW = pW * 0.8, bH = pH * 0.22, bX = pX + pW*0.1;

  float b1Y = pY + pH*0.40;
  fill(color(0,50,42), 240); stroke(cEnergyCyan, 200); strokeWeight(2); rect(bX, b1Y, bW, bH, 10); noStroke();
  fill(cEnergyCyan); gtFit("CADET  -  AGE 2 - 5", width/2, b1Y + bH*0.38, bW*0.9, bH*0.34);
  fill(cLeadGrey); gtFit("3 LEVELS - GENTLE", width/2, b1Y + bH*0.72, bW*0.8, bH*0.22);

  float b2Y = pY + pH*0.70;
  fill(color(50,38,0), 240); stroke(cGold, 200); strokeWeight(2); rect(bX, b2Y, bW, bH, 10); noStroke();
  fill(cGold); gtFit("ENGINEER  -  AGE 5 - 10", width/2, b2Y + bH*0.38, bW*0.9, bH*0.34);
  fill(cLeadGrey); gtFit("3 LEVELS - HARDER + FASTER", width/2, b2Y + bH*0.72, bW*0.8, bH*0.22);
}

// =========================================================
//  DASHBOARD
// =========================================================
void drawDashboard() {
  background(cNavyDeep);
  dashTime = millis() * 0.001;

  // NEW: animated space backdrop behind the panels
  drawSpaceBackground(120, 160);

  if (btSimulating && !btDone) {
    btProgress = (millis() % 2000) / 2000.0;
    if (millis() - simulateBtStartTime > 2000) {
      btDone = true; 
      btSimulating = false; 
      isConnected = true;
      playSound("uplink.mp3");
    }
  } else if (btDone) {
    btProgress = 1.0;
  }

  drawLeftPanel();
  drawCenterPanels();
  drawRightPanel();
  drawBottomBar();

  // UPDATED: Section 5f — connection status banner (drawn last, on top)
  drawStatusBanner();
  drawBurgerMenu(); // NEW: Mission Hub menu overlay
}

// NEW: dynamic list of Mission Hub menu items
String[] menuItems() {
  return new String[] {
    muted ? "SOUND:  OFF" : "SOUND:  ON",
    showBg ? "BACKGROUND FX:  ON" : "BACKGROUND FX:  OFF",
    "CHANGE PROFILE",
    "CHANGE COM PORT",
    "RESET RECORDS",
    "CLOSE MENU"
  };
}
float MENU_X = 8, MENU_W = 360, MENU_ITEM_H = 56;  // UPDATED: bigger Mission Hub menu
float menuTop() { return TOP_BAR + 6; }

void drawBurgerMenu() {
  if (!menuOpen) return;
  String[] items = menuItems();
  float x = MENU_X, y = menuTop(), w = MENU_W, h = items.length*MENU_ITEM_H + 16;
  // panel
  fill(0,0,0,120); rect(x+5,y+5,w,h,12);
  fill(cPanel,250); stroke(cEnergyCyan,180); strokeWeight(1.5); rect(x,y,w,h,12); noStroke();
  fill(cEnergyCyan); textAlign(LEFT,CENTER); textSize(20);
  gt("MISSION HUB", x+20, y+2);  // small header sits on the top border
  for (int i=0;i<items.length;i++) {
    float iy = y + 8 + i*MENU_ITEM_H;
    boolean hover = mouseX>x+8 && mouseX<x+w-8 && mouseY>iy && mouseY<iy+MENU_ITEM_H-6;
    color acc = items[i].startsWith("RESET") ? cWarningRed : (items[i].startsWith("CLOSE") ? cLeadGrey : cEnergyCyan);
    fill(hover ? cPanel2 : cNavyMid, 240); stroke(acc, hover?220:90); strokeWeight(1);
    rect(x+8, iy, w-16, MENU_ITEM_H-6, 8); noStroke();
    fill(hover ? cWhite : cLeadGrey); textAlign(LEFT,CENTER); textSize(21);
    gt(items[i], x+28, iy+(MENU_ITEM_H-6)/2);
  }
}

// NEW: handle a click inside the open menu; returns true if consumed
boolean handleMenuClick() {
  if (!menuOpen) return false;
  String[] items = menuItems();
  float x = MENU_X, y = menuTop(), w = MENU_W;
  for (int i=0;i<items.length;i++) {
    float iy = y + 8 + i*MENU_ITEM_H;
    if (mouseX>x+8 && mouseX<x+w-8 && mouseY>iy && mouseY<iy+MENU_ITEM_H-6) {
      switch(i) {
        case 0: muted = !muted; saveGameData(); break;
        case 1: showBg = !showBg; break;
        case 2: currentState = STATE_DIFFICULTY_SELECT; blurReady=false; menuOpen=false; break;
        case 3: currentState = STATE_PORT_SELECT; menuOpen=false; break;
        case 4: highScore=0; bestStreak=0; maxPhaseReached=1; bestLevel=1; totalAttempts=0; totalSuccess=0; saveGameData(); showToast("RECORDS CLEARED"); break;
        case 5: menuOpen=false; break;
      }
      return true;
    }
  }
  // click outside items but inside panel area still consumed
  float h = items.length*MENU_ITEM_H + 16;
  if (mouseX>x && mouseX<x+w && mouseY>y && mouseY<y+h) return true;
  return false;
}

// UPDATED: top status strip now hosts the burger menu button
void drawStatusBanner() {
  float h = TOP_BAR;
  fill(cLeadDark); noStroke(); rect(0, 0, width, h);
  stroke(cBorder, 120); strokeWeight(1); line(0, h, width, h); noStroke();

  // burger button (top-left) — opens the Mission Hub menu
  drawBurgerIcon(8, (h-18)/2, 26, 18);

  textSize(14);
  textAlign(LEFT, CENTER); fill(cLeadGrey);
  gt("LUNAR REACTOR SABOTAGE  -  MCT231  -  AIN SHAMS", 46, h/2);
  textAlign(RIGHT, CENTER); fill(cEnergyCyan);
  String portLabel = (serialAvailable && btSocket != null) ? currentPortName : "SIMULATOR";
  gt(portLabel, width - PAD * 2, h/2);
}

// NEW: three-line burger icon (highlights on hover)
void drawBurgerIcon(float x, float y, float w, float h) {
  boolean hover = mouseX>x-4 && mouseX<x+w+4 && mouseY>0 && mouseY<TOP_BAR;
  stroke(hover || menuOpen ? cEnergyCyan : cLeadGrey); strokeWeight(2.5);
  for (int i=0;i<3;i++) { float ly = y + i*(h/2); line(x, ly, x+w, ly); }
  noStroke();
}

void drawLeftPanel() {
  float x = PAD, y = PANEL_Y, w = LEFT_W - PAD, h = PANEL_H;
  panel(x, y, w, h, "OPERATOR");
  float cx = x + w/2, fY = y + h * 0.36, fS = w * 0.33;  // UPDATED: bigger operator figure

  noFill(); stroke(cEnergyCyan, 40); strokeWeight(fS*0.18); ellipse(cx, fY, fS*1.5, fS*1.5); noStroke();
  fill(color(60, 100, 180)); ellipse(cx, fY, fS*1.2, fS*1.2);
  fill(color(0,200,160,180)); ellipse(cx, fY+fS*0.05, fS*0.75, fS*0.55);
  
  fill(color(70,110,190)); rect(cx-fS*0.45, fY+fS*0.55, fS*0.9, fS*0.85, fS*0.15);
  fill(color(60,90,160)); rect(cx-fS*0.75, fY+fS*0.6, fS*0.28, fS*0.6, fS*0.08); rect(cx+fS*0.47, fY+fS*0.6, fS*0.28, fS*0.6, fS*0.08);
  fill(color(50,80,150)); rect(cx-fS*0.35, fY+fS*1.35, fS*0.3, fS*0.5, fS*0.06); rect(cx+fS*0.05, fY+fS*1.35, fS*0.3, fS*0.5, fS*0.06);

  // UPDATED: Section 3 — ONLINE/OFFLINE + STABILISE REACTOR
  textAlign(CENTER, CENTER); textSize(h * 0.026); fill(btDone ? cEnergyCyan : cWarningRed); gt(btDone ? "ONLINE" : "OFFLINE", cx, y + h*0.68);
  textSize(h * 0.020); fill(cLeadGrey); gt("MISSION:", cx, y + h*0.76);
  textSize(h * 0.022); fill(cWhite); gt("STABILISE REACTOR", cx, y + h*0.81);
}

void drawCenterPanels() {
  float x = MID_X, y = PANEL_Y, w = MID_W, topH = PANEL_H * 0.46;
  panel(x, y, w, topH, "UPLINK STATUS");
  // UPDATED: re-laid-out so the ring, %, status text and chips never overlap
  float cx = x + w/2, cy = y + topH * 0.36, R = min(w*0.5, topH) * 0.22;

  // base ring + progress arc
  noFill(); stroke(cLeadDark, 200); strokeWeight(R*0.10); ellipse(cx, cy, R*2, R*2); noStroke();
  if (btSimulating || btDone) {
    float sweep = btDone ? TWO_PI : btProgress * TWO_PI;
    noFill(); stroke(btDone ? cEnergyCyan : cGold, 255); strokeWeight(R*0.10);
    arc(cx, cy, R*2, R*2, -HALF_PI, -HALF_PI + sweep); noStroke();
    if (!btDone) { float ang=-HALF_PI+sweep; fill(cGold,200); ellipse(cx+R*cos(ang), cy+R*sin(ang), R*0.18, R*0.18); }
  } else {
    noFill(); stroke(cLeadGrey, 60); strokeWeight(R*0.05); arc(cx, cy, R*2, R*2, -HALF_PI, HALF_PI + TWO_PI*0.7); noStroke();
  }

  // small Bluetooth glyph at the TOP of the ring
  color iconC = btDone ? cEnergyCyan : (btSimulating ? cGold : cLeadGrey);
  float s = R*0.28, iy = cy - R*0.34;
  stroke(iconC, 230); strokeWeight(max(2, R*0.05));
  line(cx, iy-s, cx, iy+s); line(cx, iy-s, cx+s*0.7, iy-s*0.38); line(cx+s*0.7, iy-s*0.38, cx, iy); line(cx, iy, cx+s*0.7, iy+s*0.38); line(cx+s*0.7, iy+s*0.38, cx, iy+s);
  line(cx, iy-s*0.6, cx-s*0.42, iy-s*0.2); line(cx, iy+s*0.6, cx-s*0.42, iy+s*0.2); noStroke();

  // % INSIDE the ring (below the glyph)
  textAlign(CENTER, CENTER);
  if (btSimulating || btDone) {
    fill(btDone ? cEnergyCyan : cGold);
    int pct = btDone ? 100 : int(btProgress*100);
    gtFit(pct+"%", cx, cy + R*0.34, R*1.4, R*0.55);
  }

  // status text BELOW the ring (auto-fit, single line)
  String st; color stc;
  if (btDone)            { st = "HC-05 LINKED"; stc = cEnergyCyan; }
  else if (btSimulating) { st = "LINKING...";     stc = cGold; }
  else                   { st = "PRESS CONNECT TO UPLINK HC-05"; stc = cLeadGrey; }
  fill(stc); gtFit(st, cx, cy + R*1.5, w*0.9, topH*0.085);

  // info chips along the bottom of the panel
  float blockY = y + topH * 0.80, blockH = topH * 0.15, blockW = (w - PAD*4) / 3;
  String[] bLabels = {"PROTOCOL", "MODE", "LINK"};
  String[] bVals   = {"BT 9600", serialAvailable ? "HARDWARE" : "SIMULATOR", btDone ? "SECURE" : "STANDBY"};
  color[]  bCols   = {cEnergyCyan, cGold, btDone ? cGreen : cLeadGrey};
  for (int i=0; i<3; i++) {
    float bx = x + PAD + i*(blockW+PAD*1.5);
    fill(cLeadDark, 160); stroke(cBorder, 100); strokeWeight(1); rect(bx, blockY, blockW, blockH, 8); noStroke();
    fill(cLeadGrey, 160); gtFit(bLabels[i], bx+blockW/2, blockY+blockH*0.30, blockW*0.9, blockH*0.30);
    fill(bCols[i]);       gtFit(bVals[i],   bx+blockW/2, blockY+blockH*0.72, blockW*0.9, blockH*0.42);
  }

  float cardsY = y + topH + PAD, cardsH = PANEL_H - topH - PAD;
  panel(x, cardsY, w, cardsH, "");
  float tw = (w - PAD*4) / 3, th = (cardsH - PAD*3) / 2, wideW = w - PAD*2;

  // UPDATED: Section 3 — PROFILE / SEQUENCE SCORE / DEFUSAL STREAK
  drawDataTile(x+PAD, cardsY+PAD, tw, th, "PROFILE", difficultyName, cEnergyCyan, 0);
  drawDataTile(x+PAD*2+tw, cardsY+PAD, tw, th, "SEQUENCE SCORE", str(score), cWhite, 1);
  drawDataTile(x+PAD*3+tw*2, cardsY+PAD, tw, th, "DEFUSAL STREAK", str(streak), cWhite, 1);
  drawDataTile(x+PAD, cardsY+PAD*2+th, wideW, th, "LIVES", "", color(200,80,255), 2);
}


void drawDataTile(float tx, float ty, float tw, float th, String label, String val, color col, int type) {
  fill(0,0,0,100); rect(tx+4,ty+4,tw,th,10); fill(cNavyMid,230); stroke(col,60); strokeWeight(1.5); rect(tx,ty,tw,th,10); noStroke();
  fill(col,180); rect(tx,ty,tw,th*0.06,10); fill(col,0); rect(tx,ty+th*0.04,tw,th*0.04);
  textAlign(LEFT,TOP); fill(col,200); gtFit(label, tx+tw*0.08, ty+th*0.16, tw*0.84, th*0.22);
  if (type == 2) {
    float size = th * 0.35, startX = tx + tw/2 - size*3;
    for(int i=0; i<3; i++) {
      float cX = startX + i*(size*3), cY = ty + th*0.62;
      if(i<lives) { fill(cEnergyCyan,50); ellipse(cX,cY,size*1.5,size*1.5); fill(cLeadGrey); ellipse(cX,cY,size,size); fill(cEnergyCyan); ellipse(cX,cY,size*0.5,size*0.5); } 
      else { fill(cLeadDark); ellipse(cX,cY,size,size); fill(20); ellipse(cX,cY,size*0.5,size*0.5); }
    }
  } else if (label.equals("PROFILE")) {
    textAlign(CENTER,CENTER); fill(cWhite,250); gtFit(val, tx+tw/2, ty+th*0.66, tw*0.86, th*0.30);
  } else {
    textAlign(CENTER,CENTER); fill(cWhite,250); gtFit(val, tx+tw/2, ty+th*0.66, tw*0.86, th*0.52);
  }
}

void drawRightPanel() {
  float x = width - RIGHT_W + PAD, y = PANEL_Y, w = RIGHT_W - PAD*2, h = PANEL_H, cx = x + w/2;
  float statusH = h * 0.28;
  panel(x, y, w, statusH, "CREW  INTEGRITY"); // UPDATED: Section 3
  float iS = w * 0.18;
  for (int i=0; i<3; i++) {
    float ix = x + w*0.18 + i*(w*0.32), iy = y + statusH * 0.5; boolean alive = (i < lives);
    fill(alive ? color(70,110,190) : cLeadDark); ellipse(ix, iy-iS*0.2, iS, iS*0.9); rect(ix-iS*0.35, iy+iS*0.25, iS*0.7, iS*0.7, iS*0.12);
    fill(alive ? color(0,200,160,200) : color(40,40,40)); ellipse(ix, iy-iS*0.2, iS*0.58, iS*0.44);
    if (!alive) { stroke(cWarningRed,200); strokeWeight(2); line(ix-iS*0.3, iy-iS*0.55, ix+iS*0.3, iy+iS*0.55); line(ix+iS*0.3, iy-iS*0.55, ix-iS*0.3, iy+iS*0.55); noStroke(); }
  }

  float statsY = y + statusH + PAD, statsH = h * 0.35;
  panel(x, statsY, w, statsH, "ALL-TIME RECORDS");
  // NEW: added BEST LEVEL + ACCURACY rows
  int acc = (totalAttempts > 0) ? round(100.0*totalSuccess/totalAttempts) : 0;
  String[] statKeys = {"BEST SCORE", "BEST STREAK", "BEST LEVEL", "ACCURACY"};
  String[] statVals = { str(highScore), str(bestStreak), str(bestLevel), acc + "%" };
  color[] statCols = {cGold, cEnergyCyan, color(80,180,255), cGreen};

  float rowH = statsH * 0.18;
  for (int i=0; i<4; i++) {
    float ry = statsY + statsH*0.12 + i*(rowH + statsH*0.04);
    stroke(cBorder,80); strokeWeight(1); line(x+PAD, ry+rowH*0.95, x+w-PAD, ry+rowH*0.95); noStroke();
    textAlign(LEFT,CENTER); textSize(rowH*0.45); fill(cLeadGrey,200); gt(statKeys[i], x+PAD*2, ry+rowH*0.5);
    textAlign(RIGHT,CENTER); textSize(rowH*0.60); fill(statCols[i]); gt(statVals[i], x+w-PAD*2, ry+rowH*0.5);
  }

  float coreY = y + statusH + statsH + PAD*2, coreH = h - statusH - statsH - PAD*2;
  panel(x, coreY, w, coreH, "CORE  STATUS"); // UPDATED: Section 3
  float ocx = cx, ocy = coreY + coreH*0.46, OR  = min(w,coreH) * 0.22;
  for (int r=3; r>=1; r--) {
    float pulse = 0.5 + 0.5*sin(dashTime*2.5 + r); color glowC = btDone ? cEnergyCyan : cWarningRed;
    fill(red(glowC), green(glowC), blue(glowC), 20*pulse*r); ellipse(ocx, ocy, OR*(1.8+r*0.5)*pulse, OR*(1.8+r*0.5)*pulse);
  }
  noFill(); stroke(cLeadDark,200); strokeWeight(OR*0.12); ellipse(ocx,ocy,OR*2,OR*2); noStroke();
  
  color orbC = btDone ? cEnergyCyan : cWarningRed;
  fill(red(orbC)*0.15, green(orbC)*0.15, blue(orbC)*0.15); ellipse(ocx, ocy, OR*1.6, OR*1.6);
  fill(orbC, 200); ellipse(ocx, ocy, OR*0.9, OR*0.9);
  fill(255,255,255,180); ellipse(ocx-OR*0.2, ocy-OR*0.2, OR*0.28, OR*0.28);
  textAlign(CENTER,CENTER); textSize(coreH*0.080); fill(btDone ? cEnergyCyan : cWarningRed); gt(btDone ? "STABLE" : "CRITICAL", ocx, coreY+coreH*0.84); // UPDATED: Section 3
}


void drawBottomBar() {
  float y = height - BOT_H;
  fill(cNavyMid, 240); stroke(cBorder,180); strokeWeight(1.5); rect(0, y, width, BOT_H); noStroke();
  stroke(cEnergyCyan, 50); strokeWeight(1); line(0, y, width, y); noStroke();
  float bW = width * 0.36, bH = BOT_H * 0.65, bX = (width - bW) / 2, bY = y + (BOT_H - bH) / 2;

  float glow = 0.75 + 0.25*sin(dashTime*3.5);
  fill(0, 0, 0, 160); rect(bX+5, bY+5, bW, bH, 10); fill(color(0,50,42),240);
  stroke(cEnergyCyan, 200*glow); strokeWeight(2); rect(bX, bY, bW, bH, 10); noStroke();
  
  String btnText = (score > 0 || level > 1) && lives > 0 ? ">  CONTINUE MISSION" : ">  INITIATE MISSION";
  if (lives <= 0) btnText = ">  EMERGENCY REBOOT";
  
  fill(cEnergyCyan, 255*glow); textAlign(CENTER,CENTER); textSize(bH*0.40); 
  gt(btnText, width/2.0, bY+bH/2);

  textAlign(LEFT,CENTER); textSize(BOT_H*0.22); fill(cLeadGrey,130);
  gt("LUNAR REACTOR OS  v2.1  //  MCT231", PAD*2, y+BOT_H/2);
  textAlign(RIGHT,CENTER); textSize(BOT_H*0.22); fill(cEnergyCyan,200);
  gt("  HC-05  ONLINE", width-PAD*2, y+BOT_H/2);
}
void panel(float x, float y, float w, float h, String label) {
  fill(0,0,0,100); rect(x+5, y+5, w, h, 14); fill(cPanel,245); stroke(cBorder,160); strokeWeight(1.5); rect(x, y, w, h, 14); noStroke();
  if (label.length() > 0) {
    // UPDATED: bigger, readable label, nudged DOWN so it sits fully inside the panel.
    float ts = constrain(h*0.075, 18, 36);
    textAlign(CENTER, CENTER); textSize(ts);
    float chipH = ts*1.5;
    float lW = textWidth(label) + w*0.05;
    float chipX = x + w*0.06, chipY = y + 4;
    fill(cNavyMid,230); stroke(cBorder,120); strokeWeight(1);
    rect(chipX, chipY, lW, chipH, 6); noStroke();
    fill(cLeadGrey,210); gt(label, chipX + lW/2, chipY + chipH/2);
  }
}
void gt(String t, float x, float y) { color prev = g.fillColor; fill(0,0,0,160); text(t, x+2, y+2); fill(prev); text(t, x, y); }

// NEW: draw text that auto-shrinks to fit a max width (fixes oversized/overflowing labels)
void gtFit(String t, float x, float y, float maxW, float sizePx) {
  textSize(sizePx);
  while (textWidth(t) > maxW && sizePx > 7) { sizePx -= 1; textSize(sizePx); }
  gt(t, x, y);
}

// =========================================================
// NEW: LEVEL SYSTEM, FEATURE HELPERS
// =========================================================
// Compute all per-level difficulty parameters from `level` + profile.
void applyLevelParams() {
  level = constrain(level, 1, 3);
  seqLen = isEngineer ? (2 + level) : (1 + level);
  decoyCount = constrain(1 + (level-1)/2, 1, max(1, seqLen-1));
  revealMs   = (int) max(350, (isEngineer ? 800 : 950) - level*90);
  levelTimerSecs = 180.0;
  timerMax       = 180.0;
  currentLevel = seqLen; 
  isBossStage  = (level >= 3);
  multiplier = constrain(1 + streak/3, 1, 5);
}

void showToast(String msg) { toastMsg = msg; toastUntil = millis() + 2600; }

// Start the GET READY 3-2-1 countdown that precedes a sequence reveal
void beginCountdown() {
  isCountingDown = true;
  countdownStart = millis();
  feedbackMessage = ""; // countdown HUD shows GET READY; avoid duplicate big text
}

// ---- Animated space background: stars + drifting UFOs / ships / astronauts ----
void initSpaceBackground() {
  for (int i = 0; i < N_STARS; i++) {
    sx[i] = random(width); sy[i] = random(height);
    ss[i] = random(0.7, 2.8);                 // size
    sp[i] = ss[i] * 0.12;                      // drift speed (parallax by size)
  }
  spaceObjs = new ArrayList<SpaceObj>();
  for (int i=0;i<2;i++) spaceObjs.add(new SpaceObj(0)); // UFOs
  for (int i=0;i<2;i++) spaceObjs.add(new SpaceObj(1)); // spaceships
  for (int i=0;i<2;i++) spaceObjs.add(new SpaceObj(2)); // astronauts
}

// Draw the whole animated backdrop in 2D screen space.
void drawSpaceBackground(float starAlpha, float spriteAlpha) {
  pushStyle(); noStroke();
  // twinkling stars
  for (int i = 0; i < N_STARS; i++) {
    sy[i] += sp[i];
    if (sy[i] > height) { sy[i] = 0; sx[i] = random(width); }
    float tw = 0.55 + 0.45*sin(millis()*0.004 + i*1.3);
    fill(220, 235, 255, starAlpha*tw);
    ellipse(sx[i], sy[i], ss[i], ss[i]);
  }
  if (showBg) {
    for (SpaceObj o : spaceObjs) { o.update(); o.draw(spriteAlpha); }
  }
  popStyle();
}

// A single drifting space sprite drawn entirely with primitives.
class SpaceObj {
  int type;            // 0 UFO, 1 spaceship, 2 astronaut
  float x, y, vx, vy, sc, ph;
  SpaceObj(int t) { type = t; reset(true); }
  void reset(boolean anywhere) {
    sc = random(0.7, 1.3);
    ph = random(TWO_PI);
    boolean ltr = random(1) < 0.5;
    vx = (ltr ? 1 : -1) * random(0.4, 1.1) * (type==1 ? 1.8 : 1.0);
    vy = random(-0.15, 0.15);
    x  = anywhere ? random(width) : (ltr ? -60 : width+60);
    y  = random(height*0.10, height*0.80);
  }
  void update() {
    x += vx; y += vy + sin(millis()*0.001 + ph)*0.25;
    if (x < -90 || x > width+90) reset(false);
  }
  void draw(float a) {
    pushMatrix(); translate(x, y); scale(sc);
    if (type==0) drawUFO(a);
    else if (type==1) drawShip(a, vx<0);
    else drawAstronaut(a);
    popMatrix();
  }
  void drawUFO(float a) {
    // glow
    fill(red(cEnergyCyan),green(cEnergyCyan),blue(cEnergyCyan), a*0.10); ellipse(0,6,70,26);
    // dome
    fill(red(cEnergyCyan),green(cEnergyCyan),blue(cEnergyCyan), a*0.55); arc(0,0,30,30,PI,TWO_PI);
    fill(210,235,255,a*0.5); arc(0,0,18,18,PI,TWO_PI);
    // saucer body
    fill(70,90,140,a); ellipse(0,2,52,16);
    fill(40,55,95,a); ellipse(0,5,52,10);
    // blinking lights
    for (int i=-2;i<=2;i++){
      float b = 0.4+0.6*abs(sin(millis()*0.006 + i + ph));
      fill(red(cGold),green(cGold),blue(cGold), a*b); ellipse(i*9, 6, 4, 4);
    }
  }
  void drawShip(float a, boolean left) {
    pushMatrix(); if (left) scale(-1,1);
    // thruster flame
    float f = 0.6+0.4*sin(millis()*0.03+ph);
    fill(red(cGold),green(cGold),blue(cGold), a*0.8); triangle(-26,0,-40-8*f,-4,-40-8*f,4);
    fill(red(cWarningRed),green(cWarningRed),blue(cWarningRed), a*0.6); triangle(-26,0,-34-6*f,-2,-34-6*f,2);
    // hull
    fill(120,135,165,a); ellipse(0,0,52,18);
    fill(170,185,215,a); ellipse(8,0,22,12);
    // cockpit
    fill(red(cEnergyCyan),green(cEnergyCyan),blue(cEnergyCyan), a*0.85); ellipse(14,-1,9,7);
    // fin
    fill(80,95,130,a); triangle(-6,-7,-18,-20,-2,-8);
    popMatrix();
  }
  void drawAstronaut(float a) {
    float bob = sin(millis()*0.003+ph)*2;
    pushMatrix(); translate(0,bob); rotate(sin(millis()*0.0015+ph)*0.15);
    // backpack + tether
    stroke(red(cLeadGrey),green(cLeadGrey),blue(cLeadGrey), a*0.5); strokeWeight(1.5);
    line(-14,2,-30,12); noStroke();
    fill(90,105,140,a); rect(-12,-6,7,16,3);
    // body
    fill(225,235,248,a); rect(-9,-8,18,22,8);
    // arms + legs
    fill(210,222,240,a); rect(7,-4,8,6,3); rect(-15,-4,8,6,3);
    rect(-7,12,6,10,3); rect(1,12,6,10,3);
    // helmet
    fill(235,242,252,a); ellipse(0,-12,20,20);
    fill(red(cEnergyCyan),green(cEnergyCyan),blue(cEnergyCyan), a*0.8); ellipse(1,-12,13,13);
    fill(255,255,255,a*0.5); ellipse(-2,-14,4,4);
    popMatrix();
  }
}

// =========================================================
// INPUT & EVENT SIMULATION
// =========================================================
void mousePressed() {
  if (currentState == STATE_PORT_SELECT) {
    int n = (availablePorts == null) ? 0 : availablePorts.length;
    float bW = width * 0.45, bH = height * 0.09, bX = width/2 - bW/2;
    float startY = height * 0.24, gap = bH * 0.30;
    
    // Check if the player clicked a paired device
   // Check if the player clicked a paired device
    for (int i = 0; i < n; i++) {
      float bY = startY + i * (bH + gap);
      if (mouseX > bX && mouseX < bX + bW && mouseY > bY && mouseY < bY + bH) {
        
        // Force immediate green connected status and play uplink audio REGARDLESS of success
        btDone = true;
        isConnected = true;
        playSound("uplink.mp3");

        // FIX (lag/freeze): the blocking BluetoothSocket.connect() used to run here
        // on the render/UI thread, which froze the whole app at the connection
        // screen until it finished or timed out. We now hand the connection off to
        // a background worker thread and continue immediately.
        connectBluetoothAsync(availableMacs[i], availablePorts[i]);

        currentState = STATE_DIFFICULTY_SELECT;
        blurReady = false;
        return;
      }
    }
    
    // Check if the player clicked "OPEN BLUETOOTH SETTINGS"
    float simY = startY + max(1, n) * (bH + gap) + gap;
    if (mouseX > bX && mouseX < bX + bW && mouseY > simY && mouseY < simY + bH) {
      Intent intent = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
      getActivity().startActivity(intent);
    }
    return;
  }
  
  if (currentState == STATE_DIFFICULTY_SELECT) {
    float pW = width * 0.45, pH = height * 0.50, pX = width/2 - pW/2, pY = height/2 - pH/2, bW = pW * 0.8, bH = pH * 0.22, bX = pX + pW*0.1;
    if (mouseX > bX && mouseX < bX+bW && mouseY > (pY+pH*0.40) && mouseY < (pY+pH*0.40)+bH) {
      // NEW: CADET profile — 5 levels, gentler scaling
      isEngineer = false; maxLevelCount = 3; difficultyName = "CADET";
      level = 1; streak = 0; applyLevelParams();
      currentState = STATE_DASHBOARD; blurReady = false;
    }
    else if (mouseX > bX && mouseX < bX+bW && mouseY > (pY+pH*0.70) && mouseY < (pY+pH*0.70)+bH) {
      // NEW: ENGINEER profile — 6 levels, harder scaling
      isEngineer = true; maxLevelCount = 3; difficultyName = "ENGINEER";
      level = 1; streak = 0; applyLevelParams();
      currentState = STATE_DASHBOARD; blurReady = false;
    }
    return;
  }

if (currentState == STATE_DASHBOARD) {
    if (mouseY < TOP_BAR && mouseX < 46) { menuOpen = !menuOpen; return; }
    if (menuOpen) { if (!handleMenuClick()) menuOpen = false; return; }

    float bW = width * 0.36, bH = BOT_H * 0.65, bX = (width - bW)/2, bY = (height - BOT_H) + (BOT_H - bH)/2;
    if (mouseX>bX && mouseX<bX+bW && mouseY>bY && mouseY<bY+bH) {
      if(lives <= 0) resetGame();
      currentState = STATE_GAMEPLAY;
      feedbackMessage = "READY";
    }
    return;
  
  }

  if (currentState == STATE_GAMEPLAY) {
    // NEW: on-screen touch buttons take priority (pause/mute/correct/wrong/fire/hint)
    for (float[] b : uiBtns) {
      if (inR(b[0], b[1], b[2], b[3])) { doUiAction((int)b[4]); return; }
    }
    if (isPaused) return; // nothing else is clickable while paused

    float pBx = PAD * 2;
    float pBy = height - PAD * 2 - 50;
    // Only allow clicking the Mission Hub button between rounds
    if (!isCodeVisible && !WaitingForPlayerToEnterCode && !isShootingPhase && !isShattered && !isCountingDown) {
      if (mouseX > pBx && mouseX < pBx + 210 && mouseY > pBy && mouseY < pBy + 50) {
        currentState = STATE_DASHBOARD;
        return;
      }
    }
  }

  if (isCodeVisible || isShattered || isShootingCodeVisible || isCountingDown || isPaused) return;
  float btnW=width*0.45, btnH=height*0.10, btnY=height*0.88;
  if (mouseX>width/2-btnW/2 && mouseX<width/2+btnW/2 && mouseY>btnY) {
    if (!isConnected) {
      isConnected=true; feedbackMessage="HC-05 UPLINK ESTABLISHED"; playSound("uplink.mp3");
    }
    else if (lives<=0) resetGame();
    else if (!WaitingForPlayerToEnterCode && !isShootingPhase) { generateCode(); showVictory=false; }
  }
}

// NEW: connect to the HC-05 on a worker thread so the UI/render loop never blocks.
// The same thread then loops reading incoming bytes from the module.
void connectBluetoothAsync(final String macAddr, final String portNm) {
  new Thread(new Runnable() {
    public void run() {
      try {
        // Discovery slows down / can stall a connection attempt — cancel it first.
        if (btAdapter != null && btAdapter.isDiscovering()) btAdapter.cancelDiscovery();
        BluetoothDevice device = btAdapter.getRemoteDevice(macAddr);
        BluetoothSocket socket = device.createRfcommSocketToServiceRecord(SPP_UUID);
        socket.connect();                       // blocking — but now off the UI thread
        btSocket = socket;
        btIn  = socket.getInputStream();
        btOut = socket.getOutputStream();
        currentPortName = portNm;
        serialAvailable = true;

        byte[] buffer = new byte[256];
        int bytes;
        while (serialAvailable) {
          try {
            bytes = btIn.read(buffer);
            if (bytes > 0) {
              String incomingMsg = new String(buffer, 0, bytes);
              for (char c : incomingMsg.toCharArray()) processIncomingChar(c);
            }
          } catch (IOException e) {
            serialAvailable = false;
            break;
          }
        }
      } catch (IOException e) {
        serialAvailable = false;
        println("[ERROR]: SPP Socket Failed: " + e.getMessage());
      }
    }
  }).start();
}

// NEW: keyboard now drives global controls + (in simulator mode) gameplay input.
// Real signals still arrive over serial via serialEvent() when hardware is present.
void keyPressed() {
  // Prevent ESC from quitting the app (pause has been removed)
  if (key == ESC) { key = 0; return; }

  char k = Character.toLowerCase(key);

  // ----- GLOBAL CONTROLS -----
  if (k == 'm') { muted = !muted; saveGameData(); showToast(muted ? "SOUND MUTED" : "SOUND ON"); return; }

  if (currentState != STATE_GAMEPLAY) return;

  // HINT / PEEK: re-show the sequence briefly at a time + score penalty
  if (k == 'h') { useHint(); return; }

  // ----- SIMULATOR-MODE GAMEPLAY INPUT (keyboard stands in for the Arduino) -----
  if (!serialAvailable && isConnected && !isShattered && !isCountingDown) {
    if (isShootingPhase && WaitingForShootingInput) {
      if (k == 'f') processShootingSuccess();
      else if (k == 'x' || k == 'w') processShootingMistake();
    }
    else if (WaitingForPlayerToEnterCode && !isShootingPhase && !isCodeVisible) {
      if (k == 'c') startShootingPhase();
      else if (k == 'x' || k == 'w') processWrongAnswer("OPERATOR ERROR: WRONG SEQUENCE");
    }
  }
}

// NEW: pause toggle helper (re-anchors lastMs so the freeze maths stay sane)
void togglePause() {
  isPaused = !isPaused;
  lastMs = millis();
}

// NEW: EXIT the current round. Counts as losing the round (score + life penalty),
// tells the hardware to bring the ball home to the sorter, then returns to the hub.
void exitRound() {
  // Tell the machine to gracefully return the ball to the sorter and stop.
  // 'X' = graceful exit (different from 'R' = emergency reset).
  if (serialAvailable && btOut != null) {
    try { btOut.write((byte) 'X'); } catch (Exception e) {
      println("[ERROR]: Failed to send exit signal");
    }
  }

  // Treat the exit as losing the round.
  streak = 0; multiplier = 1;
  score  = max(0, score - 10);
  lives  = max(0, lives - 1);
  totalAttempts++;
  if (level > 1) level--;
  applyLevelParams();
  saveGameData();

  // Clear every round flag so we land cleanly back on the dashboard.
  codeGenerated = false; WaitingForPlayerToEnterCode = false;
  isShootingPhase = false; isCodeVisible = false; isShootingCodeVisible = false;
  WaitingForShootingInput = false; isCountingDown = false;
  isMirrorHackActive = false; showVictory = false; isPaused = false;
  isShattered = false; isRepairing = false; ballsShot = 0;

  shakeFrames = 0;
  flashFrames = 18; flashColor = cWarningRed;
  feedbackMessage = "ROUND EXITED";
  showToast(lives <= 0 ? "ROUND EXITED - RUN OVER" : "ROUND EXITED - LIFE LOST");
  currentState = STATE_DASHBOARD;
}
void processIncomingChar(char incoming) {
  if (incoming == 'S') {
    // Mega signals that the physical ball has entered the shooting station
    if (!isShootingPhase) {
      startShootingPhase();
    }
  } 
  else if (incoming == 'C') {
    // Arduino confirmed code input is correct
    if (isShootingPhase && WaitingForShootingInput) {
      processShootingSuccess();
    } else if (WaitingForPlayerToEnterCode) {
      processRightAnswer();
    }
  } 
  else if (incoming == 'W') {
    // Arduino confirmed code input is incorrect
    if (isShootingPhase && WaitingForShootingInput) {
      processShootingMistake();
    } else if (WaitingForPlayerToEnterCode) {
      processWrongAnswer("HARDWARE SIGNAL: MISMATCH");
    }
  } 
  else if (incoming == 'R') {
    resetGame();
  }
}
//==================================
// GAMEPLAY & 3D ENVIRONMENT
// =========================================================
void drawGameplay() {
  // NEW: frame delta for the pause-freeze mechanic
  int dt = (lastMs == 0) ? 0 : (millis() - lastMs);
  lastMs = millis();
  if (isPaused) {
    // freeze all elapsed-time anchors so nothing advances while paused
    codeDisplayStartTime += dt; shootingCodeDisplayStartTime += dt;
    countdownStart += dt; hintStart += dt; shatterStartTime += dt;
    repairStartTime += dt; lastTickTime += dt;
  }

  handleCameraAndEnvironment();
  bombRotY += 0.005;

  // NEW: GET READY countdown gates the reveal
  if (isCountingDown && !isPaused) {
    if (millis() - countdownStart > 3000) {
      isCountingDown = false;
      isCodeVisible = true;
      codeDisplayStartTime = millis();
      feedbackMessage = isMirrorHackActive ? "CORE CORRUPTED! SIGNAL INVERTED!" : "SCANNING FUEL CELLS...";
    }
  }

  if (showVictory||isRepairing) currentSphereRotSpeed=0.005;
  else if ((WaitingForPlayerToEnterCode || isShootingPhase) && !isCodeVisible) currentSphereRotSpeed=map(timer,timerMax,0,0.005,0.20);
  else currentSphereRotSpeed=0.005;
  
  // BOSS STAGE CALMER SPEED
  if (isBossStage && !showVictory) currentSphereRotSpeed *= 1.5; 

  sphereRotY+=currentSphereRotSpeed; sphereRotX+=currentSphereRotSpeed*0.5;


  pushMatrix(); translate(width/2,height*0.48,-250);
  
  if (isShattered) {
    if (millis()-shatterStartTime>5000) { isShattered=false; isRepairing=true; repairStartTime=millis(); }
    else drawShatteredPieces();
  }

  if (!isShattered) {
    pushMatrix();
    if (isRepairing) {
      float p=constrain((millis()-repairStartTime)/1000.0,0,1);
      if (p>=1.0) { p=1.0; isRepairing=false; } scale(1.0-pow(1.0-p,3));
    }
    drawWireframeSphere(); drawReactor(); // UPDATED: Section 4 — reactor model
    if (showVictory) drawDefusePulse();
    popMatrix();
  }
  popMatrix();

  hint(DISABLE_DEPTH_TEST); camera(); noLights();

  // UPDATED: Section 5g — faint "SIGNAL INVERTED" watermark while mirror hack is active
  if (isMirrorHackActive) {
    pushMatrix();
    translate(width/2, height/2);
    rotate(radians(-25));
    textAlign(CENTER, CENTER); textSize(height*0.06); fill(cWarningRed, 18);
    for (int gx = 0; gx < 2; gx++) {
      for (int gy = 0; gy < 3; gy++) {
        float wx = (gx - 0.5) * width * 0.7;
        float wy = (gy - 1)   * height * 0.4;
        gt("SIGNAL INVERTED", wx, wy);
      }
    }
    popMatrix();
  }

  // UPDATED: Section 5c — correct/wrong full-screen flash
  if (flashFrames > 0) {
    fill(flashColor, map(flashFrames, 0, 18, 0, 60));
    rect(0, 0, width, height);
    flashFrames--;
  }

  drawHolographicScanlines(); drawStatistics(); drawEnergyCoresHUD(); drawTimerHUD(); drawGameMessages(); drawMainButton();

  // NEW: feature HUD layers
  drawColorLegend();      // explains White / Black / Decoy cells during reveal
  drawLevelHUD();         // level name + progress bar + combo multiplier
  drawCountdownHUD();     // GET READY 3-2-1
  drawToastHUD();         // milestone / achievement toasts
  if (isPaused) drawPauseOverlay();  // dim + title FIRST, so buttons draw on top
  drawGameButtons();      // mobile touch controls (pause/mute/correct/wrong/fire/hint)

  // BOSS OVERDRIVE SOFTER RED TINT
  if (isBossStage && !showVictory && !isShattered) {
    fill(cWarningRed, 15 + 10*sin(millis()*0.01));
    rect(0, 0, width, height);
  }
  // DRAW DASHBOARD RETURN/PAUSE BUTTON (Bottom-Left, Only between rounds)
  if (!isCodeVisible && !WaitingForPlayerToEnterCode && !isShootingPhase && !isShattered && !isCountingDown) {
    float pBx = PAD * 2;
    float pBy = height - PAD * 2 - 50;
    fill(0, 0, 0, 150); rect(pBx+2, pBy+2, 210, 50, 8);
    stroke(cBorder); strokeWeight(2); fill(cNavyMid); rect(pBx, pBy, 210, 50, 8); noStroke();
    fill(cWhite); textSize(22); textAlign(CENTER, CENTER); gt("<  MISSION HUB", pBx + 105, pBy + 25);
  }

  hint(ENABLE_DEPTH_TEST);
}

// NEW: legend so the player can tell the fuel-cell colours apart
void drawColorLegend() {
  if (!isCodeVisible && !isCountingDown && !(hintActive)) return;
  float lx = width*0.5, ly = height*0.30;
  float sw = height*0.030, gap = width*0.012;
  String[] labs = {"WHITE CELL", "BLACK CELL", "DECOY (IGNORE)"};
  color[]  cols = {cWhite, color(20,28,46), cWarningRed};
  textSize(height*0.022); textAlign(LEFT, CENTER);
  // measure total width to centre the legend row
  float total = 0;
  for (int i=0;i<3;i++) total += sw + 8 + textWidth(labs[i]) + gap;
  float cx = lx - total/2;
  for (int i=0;i<3;i++) {
    fill(cols[i]); stroke(cLeadGrey,150); strokeWeight(1); rect(cx, ly-sw/2, sw, sw, 5); noStroke();
    fill(cLeadGrey); gt(labs[i], cx+sw+8, ly);
    cx += sw + 8 + textWidth(labs[i]) + gap;
  }
}

// NEW: level name, progress bar and combo multiplier (top-centre)
void drawLevelHUD() {
  String lname = levelNames[constrain(level-1,0,levelNames.length-1)];
  textAlign(CENTER, TOP);
  fill(isBossStage ? cWarningRed : cEnergyCyan); textSize(height*0.034);
  gt("LEVEL " + level + " / " + maxLevelCount + "  -  " + lname, width/2, height*0.035);

  // progress bar
  float bw = width*0.26, bx = width/2 - bw/2, by = height*0.085, bh = height*0.012;
  fill(cLeadDark); noStroke(); rect(bx, by, bw, bh, 6);
  fill(cEnergyCyan); rect(bx, by, bw*((float)level/maxLevelCount), bh, 6);

  // combo multiplier badge
  if (multiplier > 1) {
    fill(cGold); textAlign(CENTER, TOP); textSize(height*0.030);
    gt("COMBO x" + multiplier, width/2, height*0.105);
  }
}

// NEW: GET READY 3-2-1 countdown
void drawCountdownHUD() {
  if (!isCountingDown) return;
  int remain = 3 - (int)((millis()-countdownStart)/1000);
  remain = constrain(remain, 1, 3);
  fill(cEnergyCyan); textAlign(CENTER, CENTER);
  gtFit("GET READY", width/2, height*0.40, width*0.6, height*0.07);
  fill(cGold); textSize(height*0.20); gt(str(remain), width/2, height*0.58);
}

// NEW: milestone / achievement toast (bottom-centre)
void drawToastHUD() {
  if (millis() > toastUntil || toastMsg.length()==0) return;
  float a = 255;
  int left = toastUntil - millis();
  if (left < 500) a = map(left, 0, 500, 0, 255);
  float bw = max(width*0.30, textWidth(toastMsg)+60), bx = width/2-bw/2, by = height*0.74, bh = height*0.07;
  textSize(height*0.028);
  fill(red(cPanel2),green(cPanel2),blue(cPanel2), a*0.95); stroke(cGold, a); strokeWeight(2);
  rect(bx, by, bw, bh, 12); noStroke();
  fill(cGold, a); textAlign(CENTER, CENTER);
  gt("* " + toastMsg, width/2, by+bh/2);
}

// NEW: point-in-rect test
boolean inR(float x, float y, float w, float h) { return mouseX>x && mouseX<x+w && mouseY>y && mouseY<y+h; }

// NEW: draw a pill button AND register it for click handling
void addBtn(float x, float y, float w, float h, String label, color acc, int id) {
  boolean hv = inR(x,y,w,h);
  fill(0,0,0,120); noStroke(); rect(x+3,y+3,w,h,12);
  fill(hv ? cPanel2 : cNavyMid, 248); stroke(acc, hv?255:170); strokeWeight(2); rect(x,y,w,h,12); noStroke();
  fill(hv ? cWhite : acc); textAlign(CENTER,CENTER);
  gtFit(label, x+w/2, y+h/2, w*0.88, h*0.44);
  uiBtns.add(new float[]{x,y,w,h,id});
}
void drawGameButtons() {
  uiBtns.clear();

  // EXIT (red) and MUTE are now ALWAYS visible — even during an active round.
  // The PAUSE button has been removed entirely; EXIT takes its place (top-right).
  float bw = max(96, width*0.088), bh = max(36, height*0.056), ry = TOP_BAR + 6;
  addBtn(width-PAD-bw,        ry, bw, bh, "EXIT", cWarningRed, 9);
  addBtn(width-PAD-bw*2-8,    ry, bw, bh, muted ? "UNMUTE" : "MUTE", muted ? cWarningRed : cLeadGrey, 6);

  // Notice: The manual "CORRECT", "WRONG", and "FIRE" buttons have been completely removed.
  // The system now relies entirely on automated incoming hardware signals.
}

// NEW: dispatch a touch-button action by id
void doUiAction(int id) {
  switch(id) {
    case 1: if (WaitingForPlayerToEnterCode && !isShootingPhase) startShootingPhase(); break;       // CORRECT
    case 2: if (isShootingPhase || WaitingForShootingInput) processShootingMistake();               // WRONG
            else if (WaitingForPlayerToEnterCode) processWrongAnswer("OPERATOR ERROR: WRONG SEQUENCE"); break;
    case 3: if (WaitingForShootingInput) processShootingSuccess(); break;                            // FIRE
    case 4: useHint(); break;                                                                        // HINT
    case 6: muted = !muted; saveGameData(); break;                                                   // MUTE
    case 9: exitRound(); break;                                                                      // EXIT — end round as a loss
  }
}

// NEW: shared hint logic (used by button + key)
void useHint() {
  if (WaitingForPlayerToEnterCode && !isShootingPhase && !isCodeVisible && !isCountingDown) {
    isCodeVisible = true; codeDisplayStartTime = millis();
    timer = max(1, timer - 8); score = max(0, score - 5);
    showToast("HINT USED  (-8s, -5)");
    feedbackMessage = "RE-SCANNING...";
  }
}

// NEW: pause overlay (dim + title; buttons are drawn on top by drawGameButtons)
void drawPauseOverlay() {
  fill(0,0,0,180); rect(0,0,width,height);
  fill(cEnergyCyan); textAlign(CENTER,CENTER);
  gtFit("PAUSED", width/2, height*0.42, width*0.6, height*0.10);
}

void generateCode() {
  inputIndex=0;
  ballsShot=0;
  applyLevelParams();                              // NEW: refresh per-level difficulty
  for (int i=0; i<20; i++) pillarHeight[i] = 0;

  // Mirror hack chance rises with level (signal-inversion sabotage)
  isMirrorHackActive = (random(100) < (8 + level*3) && level > 1);

  // NEW: real cells = seqLen, distractor (red) cells = decoyCount, scaled by level
  int numFakes = constrain(decoyCount, 1, max(1, seqLen-1));
  displayLength = seqLen + numFakes;
  displayLength = min(displayLength, 20);

  for (int i=0; i<displayLength; i++) codeArray[i] = ' ';

  // Insert decoy reds at random positions
  for (int i=0; i<numFakes; i++) {
    int r; do { r = (int)random(displayLength); } while (codeArray[r] == 'R');
    codeArray[r] = 'R';
  }
  // Fill remaining positions with real White/Black cells
  for (int i=0; i<displayLength; i++) {
    if (codeArray[i] != 'R') codeArray[i] = (random(100)<50) ? 'W' : 'B';
  }

  // Inside bomb.pde -> generateCode()
  if (serialAvailable && btOut != null) {
    try {
      for (int i = 0; i < displayLength; i++) {
        if (codeArray[i] == 'W' || codeArray[i] == 'B') {
          btOut.write((byte) codeArray[i]);
        }
      }
      btOut.write((byte) '\n'); // NEW: Send termination character
    } catch (IOException e) {
      println("[ERROR]: Failed to write to BT stream");
    }
  }

  codeGenerated=true; WaitingForPlayerToEnterCode=false;
  timer = levelTimerSecs; timerMax = levelTimerSecs;     // NEW: per-level timer
  beginCountdown();                                       // NEW: GET READY 3-2-1 before reveal
}

void startShootingPhase() {
  if (!isEngineer) {
    // CADET PROFILE: Auto-Fire Bypass
    // Send 'A' to Mega to force the Uno to shoot without asking the child for a code
    if (serialAvailable && btOut != null) {
      try { btOut.write((byte) 'A'); } catch (Exception e) {}
    }
    processShootingSuccess();
    return;
  }
  
  isShootingPhase = true;
  WaitingForPlayerToEnterCode = false;
  for (int i=0; i<20; i++) pillarHeight[i] = 0;
  generateShootingCode();
}

void generateShootingCode() {
  isShootingCodeVisible = true;
  WaitingForShootingInput = false;
  shootingCodeDisplayStartTime = millis();
  shootingCodeLength = 3;
  
  for(int i = 0; i < shootingCodeLength; i++) {
    shootingCodeArray[i] = (random(100) < 50) ? 'W' : 'B';
  }
  feedbackMessage = "SCAN LAUNCH TRAJECTORY"; 
  
  // SEND THE 3-COLOR FIRING CODE TO THE MEGA OVER BLUETOOTH
  if (serialAvailable && btOut != null) {
    try {
      for (int i = 0; i < shootingCodeLength; i++) {
        btOut.write((byte) shootingCodeArray[i]);
      }
      btOut.write((byte) '\n'); // NEW: Send termination character
    } catch (Exception e) {
      println("[ERROR]: Failed to write firing code to BT stream");
    }
  }
}

void processShootingSuccess() {
  playSound("shoot_success.mp3");
  isShootingPhase = false;
  WaitingForShootingInput = false;
  ballsShot++;
  
  if (ballsShot >= currentLevel) {
    // FIXED: Do NOT call processRightAnswer() here!
    // The machine must verify if the MAIN sorting code was physically correct.
    // We keep the listener active to catch the Mega's final 'C' or 'W' signal.
    feedbackMessage = "AWAITING FINAL VERIFICATION...";
    WaitingForPlayerToEnterCode = true; 
  } else {
    feedbackMessage = "BALL " + ballsShot + " LAUNCHED";
    WaitingForPlayerToEnterCode = true;
  }
}

void processShootingMistake() {
  score = max(0, score - 5); // Deduct 5 points
  playSound("shoot_fail.mp3");
  shakeFrames = 20;
  
  // Instantly reset the environment and generate a brand-new code sequence with a fresh timer
  for (int i=0; i<20; i++) pillarHeight[i] = 0; 
  generateShootingCode();
  
  feedbackMessage = "WRONG CODE! NEW TRAJECTORY ASSIGNED!";
}

void processShootingTimeout() {
  score = max(0, score - 5); // UPDATED: Section 6 BUG 5 — clamp score floor
  playSound("shoot_fail.mp3");
  shakeFrames = 20;
  for (int i=0; i<20; i++) pillarHeight[i] = 0; // UPDATED: Section 6 BUG 6 — loop grown to 20
  generateShootingCode();
  feedbackMessage = "TIMEOUT! NEW TRAJECTORY!"; // UPDATED: Section 3
}

void processRightAnswer() {
  streak++;
  multiplier = constrain(1 + streak/3, 1, 5);            // NEW: combo multiplier
  int gained = 10 * multiplier;                          // NEW: multiplier scoring
  score += gained;
  totalAttempts++; totalSuccess++;                       // NEW: accuracy tracking

  // Auto-save all-time records instantly
  boolean newHigh = score > highScore;
  if (newHigh) highScore = score;
  if (streak > bestStreak) bestStreak = streak;
  if (level > maxPhaseReached) maxPhaseReached = level;
  if (level > bestLevel) bestLevel = level;

  // NEW: achievement / milestone toasts
  if (!achFirstDefusal) { achFirstDefusal = true; showToast("ACHIEVEMENT: FIRST DEFUSAL"); }
  else if (newHigh)      showToast("NEW HIGH SCORE: " + highScore);
  else if (streak == 5)  showToast("ON FIRE - STREAK x5!");
  else                   showToast("+" + gained + " (x" + multiplier + ")");

  saveGameData();

  if (level < maxLevelCount) { level++; showToast("LEVEL UP -> " + level); }
  applyLevelParams();                                    // NEW: rescale for next level
  WaitingForPlayerToEnterCode=false; isShootingPhase=false; codeGenerated=false;
  isMirrorHackActive=false;
  feedbackMessage="REACTOR STABILISED!"; showVictory=true; victoryPulseRadius=0;
  flashFrames = 18; flashColor = cGreen;
  playSound("success.wav");
}

void processWrongAnswer(String msg) {
  streak=0; multiplier=1; shakeFrames=40; showVictory=false; lives-=1; feedbackMessage=msg;
  totalAttempts++;                                       // NEW: accuracy tracking
  flashFrames = 18; flashColor = cWarningRed;
  if (level > 1) level--;                                // NEW: drop a level on failure
  applyLevelParams();
  saveGameData();
  WaitingForPlayerToEnterCode=false; isShootingPhase=false; codeGenerated=false;
  isCountingDown=false; isMirrorHackActive=false;
  triggerShatter();

  // Auto-Kick to Dashboard if dead
  if (lives <= 0) {
    showToast("RUN OVER - REACHED LEVEL " + bestLevel);
    currentState = STATE_DASHBOARD;
  }
}

void resetGame() {
  lives=3; score=0; streak=0; multiplier=1; ballsShot=0;
  level=1; applyLevelParams();
  isBossStage=false; showVictory=false; isShattered=false; isRepairing=false;
  feedbackMessage="READY"; codeGenerated=false; WaitingForPlayerToEnterCode=false;
  isShootingPhase = false; isShootingCodeVisible = false;
  WaitingForShootingInput = false;
  isMirrorHackActive = false;
  isPaused=false; isCountingDown=false; hintActive=false; 
  bombRotY=0; sphereRotY=0; sphereRotX=0; timer=levelTimerSecs;
  difficultyName = "AWAITING CONFIG";
  
  if (serialAvailable && btOut != null) {
    try {
      btOut.write((byte) 'R');
    } catch (Exception e) {
      println("[ERROR]: Failed to send reset signal");
    }
  }

  // Return to Dashboard for the next player
  currentState = STATE_DASHBOARD;
  btSimulating = false;
}
// =========================================================
// 3D MODELING & PHYSICS
// =========================================================
void handleCameraAndEnvironment() {
  float camX=width/2.0+(mouseX-width/2.0)*0.1, camY=height/2.0+(mouseY-height/2.0)*0.1;
  if (shakeFrames>0) { camX+=random(-40,40); camY+=random(-40,40); shakeFrames*=0.9; if(shakeFrames<1)shakeFrames=0; }
  
  // BOSS GLITCH CAMERA (Calmer: 4 instead of 15)
  if (isBossStage && !showVictory && !isShattered) { camX+=random(-4,4); camY+=random(-4,4); }
  
  // UPDATED: Section 5a — deeper purple-red shatter tint fading back to navy
  if (isShattered) { float ep=constrain((millis()-shatterStartTime)/5000.0,0,1); background(lerpColor(color(80, 5, 20),cNavyDeep,ep)); }
  else if (showVictory) background(cNavyMid); 
  else if (isMirrorHackActive) background(color(40, 10, 40)); // Deep purple warning background
  else background(cNavyDeep);

  // NEW: animated space backdrop drawn in 2D, behind the 3D scene
  hint(DISABLE_DEPTH_TEST); camera(); noLights();
  drawSpaceBackground(showVictory ? 80 : 130, 150);
  hint(ENABLE_DEPTH_TEST);

  // MIRROR HACK: Flip the entire 3D world 180 degrees
  float upY = isMirrorHackActive ? -1.0 : 1.0; 
  
  // FIX: Restored the missing 9th argument (centerZ = 0)
  camera(camX,camY,(height/2.0)/tan(PI*30.0/180.0),width/2.0,height/2.0,0,0,upY,0);
  
  ambientLight(50,60,80); directionalLight(220,220,240,-1,1,-1);
  pointLight(0,255,200,width/2,height/2,200); lightSpecular(255,255,255);
}

void drawWireframeSphere() {
  pushMatrix(); translate(0,80,0); rotateY(sphereRotY); rotateX(sphereRotX);
  float a=80; if(isRepairing) a=map(constrain((millis()-repairStartTime)/1000.0,0,1),0,1,0,80);
  noFill(); stroke(cLeadGrey,a); strokeWeight(1.5); sphereDetail(16); sphere(250); noStroke(); popMatrix();
}

void drawCylinder(float r, float h, int detail) {
  beginShape(QUAD_STRIP);
  for(int i=0;i<=detail;i++){float a=TWO_PI/detail*i;vertex(sin(a)*r,-h/2,cos(a)*r);vertex(sin(a)*r,h/2,cos(a)*r);} endShape();
  beginShape(TRIANGLE_FAN); vertex(0,-h/2,0);
  for(int i=0;i<=detail;i++){float a=TWO_PI/detail*i;vertex(sin(a)*r,-h/2,cos(a)*r);} endShape();
  beginShape(TRIANGLE_FAN); vertex(0,h/2,0);
  for(int i=0;i<=detail;i++){float a=TWO_PI/detail*i;vertex(sin(a)*r,h/2,cos(a)*r);} endShape();
}

// UPDATED: bomb 3D model restored, recoloured to the presentation theme
void drawReactor() {
  pushMatrix(); translate(0,100,0); rotateY(bombRotY); rotateX(PI/8);
  float al=255; if(isRepairing) al=map(constrain((millis()-repairStartTime)/1000.0,0,1),0,1,0,255);

  // Themed body colour: cyan-teal when armed, green when defused
  if(showVictory) fill(red(cGreen),green(cGreen),blue(cGreen),al);
  else            fill(255,0,0,al);   // pure red bomb cylinders
  specular(150); shininess(15); noStroke();

  // Bomb body: three stacked cylinders (the classic dynamite bundle)
  pushMatrix();translate(0,-15,0);rotateZ(HALF_PI);drawCylinder(35,260,20);popMatrix();
  pushMatrix();translate(-30,40,0);rotateZ(HALF_PI);drawCylinder(35,260,20);popMatrix();
  pushMatrix();translate(30,40,0);rotateZ(HALF_PI);drawCylinder(35,260,20);popMatrix();

  // End caps / tape blocks and the top plate
  fill(red(cNavyMid),green(cNavyMid),blue(cNavyMid),al);
  pushMatrix();translate(-70,15,0);box(25,120,90);popMatrix();
  pushMatrix();translate(70,15,0);box(25,120,90);popMatrix();
  fill(cLeadDark,al); pushMatrix();translate(0,-60,0);box(300,40,120);popMatrix();

  // Fuse + blinking detonator LED (themed cyan when defused, red when armed)
  stroke(red(cLeadGrey),green(cLeadGrey),blue(cLeadGrey),al);strokeWeight(4);
  line(120,-80,0,140,-130,20);noStroke();
  if(!showVictory){
    float blink=abs(sin(millis()*0.008));
    emissive(cWarningRed);fill(red(cWarningRed),green(cWarningRed),blue(cWarningRed),al*blink);
    pushMatrix();translate(140,-130,20);sphere(8);popMatrix();emissive(0);
  } else {
    emissive(cEnergyCyan);fill(red(cEnergyCyan),green(cEnergyCyan),blue(cEnergyCyan),al);
    pushMatrix();translate(140,-130,20);sphere(8);popMatrix();emissive(0);
  }

  // RENDER DYNAMIC 3D PILLARS BASED ON ACTIVE PHASE
  if (codeGenerated && !showVictory) {
    if (isCodeVisible) {
      draw3DSequencePillars(-80, codeArray, displayLength, codeDisplayStartTime, true);
    } else if (isShootingCodeVisible) {
      draw3DSequencePillars(-80, shootingCodeArray, shootingCodeLength, shootingCodeDisplayStartTime, true);
    }
  }

  popMatrix();
}

// UPDATED: fuel-cell pillars now keep their TRUE colour the whole reveal, with a
// clear highlight on the active cell. White / Black / Decoy are visually distinct.
void draw3DSequencePillars(float baseY, char[] arr, int len, int startTime, boolean activeFlag) {
  int s=40, gap=18;
  float totalW=(len*s)+((len-1)*gap);
  float startX=-totalW/2+s/2;
  int step = max(250, revealMs);                 // ms per cell during reveal
  int activeIndex=(millis()-startTime)/step;

  for(int i=0;i<len;i++){
    float x=startX+(i*(s+gap));
    boolean isActive   = (i==activeIndex && activeFlag);
    boolean isRevealed = (i<=activeIndex);        // already shown -> keep colour

    boolean isWhite=(arr[i]=='W');
    if (isMirrorHackActive) isWhite = !isWhite;   // signal-inversion sabotage
    boolean isRed=(arr[i]=='R');                  // decoy / distractor cell

    // target height: tall+pop on active, medium once revealed, low before
    float target = isActive ? 80 : (isRevealed ? 48 : 14);
    pillarHeight[i]+=(target-pillarHeight[i])*0.25;

    pushMatrix(); translate(x,baseY-pillarHeight[i]/2,0);

    // distinct, always-on materials
    if (isRevealed) {
     if (isRed) { emissive(255, 0, 0); fill(255, 0, 0); }
      else if (isWhite) { emissive(120,130,150);  fill(cWhite); }
      else              { emissive(8,14,30);       fill(18,26,46); } // BLACK cell — dark slate, clearly not grey
    } else {
      emissive(0,0,0); fill(cLeadDark);           // not yet revealed
    }
    box(s,pillarHeight[i],s);

    // bright outline + cap marker on the currently-revealing cell
    if (isActive) {
      emissive(0,0,0);
      stroke(cEnergyCyan); strokeWeight(2); noFill();
      box(s*1.18, pillarHeight[i]*1.04, s*1.18);
      noStroke();
      // small cap so White/Black read even in shadow: white dot vs ring, red X handled by colour
      pushMatrix(); translate(0,-pillarHeight[i]/2-6,0);
      if (isRed) { fill(255); box(s*0.5,3,s*0.5); }          // decoy marker
      else if (isWhite) { fill(cEnergyCyan); box(s*0.4,4,s*0.4); }
      else { fill(cGold); box(s*0.4,4,s*0.4); }
      popMatrix();
    }
    emissive(0,0,0); popMatrix();
  }
}

void drawDefusePulse() {
  pushMatrix(); translate(0,100,0); 
  if(victoryPulseRadius<250) victoryPulseRadius+=1.39; 
  float alpha=map(victoryPulseRadius,0,250,200,0);
  if(alpha>0){noFill();stroke(cEnergyCyan,alpha);strokeWeight(4);sphereDetail(16);sphere(victoryPulseRadius);} popMatrix();
}

void triggerShatter() {
  isShattered=true; shatterStartTime=millis();
  playSound("explosion.mp3");
  
  for(int i=0;i<numShards;i++){
    if(i%2==0){float angle=random(TWO_PI),r=random(80),h=random(-125,125);shardX[i]=r*cos(angle);shardY[i]=h;shardZ[i]=r*sin(angle);}
    else{float theta=random(TWO_PI),phi=acos(random(-1,1)),r=250;shardX[i]=r*sin(phi)*cos(theta);shardY[i]=r*sin(phi)*sin(theta);shardZ[i]=r*cos(phi);}
    
    shardVX[i]=(shardX[i]*random(0.08,0.25))*0.30; 
    shardVY[i]=(shardY[i]*random(0.08,0.25)-random(10,25))*0.30; 
    shardVZ[i]=(shardZ[i]*random(0.08,0.25))*0.30;
  }
}

void drawShatteredPieces() {
  pushMatrix(); translate(0,100,0);
  for(int i=0;i<numShards;i++){
    shardX[i]+=shardVX[i]; 
    shardY[i]+=shardVY[i]+0.45; 
    shardZ[i]+=shardVZ[i];
    
    pushMatrix(); translate(shardX[i],shardY[i],shardZ[i]); rotateX(frameCount*0.2+i); rotateY(frameCount*0.2+i);
    if(i%2==0){noStroke();fill(i%4==0?color(200,30,30):color(50,55,65));box(15,15,15);}
    else{stroke(cLeadGrey,200);strokeWeight(3);line(-20,0,0,20,0,0);line(0,-20,0,0,20,0);noStroke();}
    popMatrix();
  }
  popMatrix();
}

// =========================================================
// 2D HUD
// =========================================================
void drawHolographicScanlines() {
  // UPDATED: background scanlines removed (kept as no-op so call sites are unchanged)
}

void drawStatistics() {
  // UPDATED: left-aligned stats only (phase now lives in the centred Level HUD;
  // the top-right is reserved for the PAUSE/MUTE touch buttons)
  textSize(height*0.048); textAlign(LEFT,TOP);   // UPDATED: bigger stats text
  fill(cLeadGrey);   gt("SCORE: "+score, width*0.03, height*0.045);
  fill(cEnergyCyan); gt("BEST: "+highScore, width*0.03, height*0.110);
  fill(cGold);       gt("STREAK: "+streak, width*0.03, height*0.175);
}

void drawEnergyCoresHUD() {
  // UPDATED: moved below the PAUSE/MUTE buttons + labelled
  textAlign(RIGHT, CENTER); textSize(height*0.032); fill(cLeadGrey);   // UPDATED: bigger LIVES label
  gt("LIVES", width*0.95 - 3*(height*0.05*1.5), height*0.165);
  for(int i=0;i<3;i++){
    float size=height*0.05,cX=(width*0.95)-((2-i)*(size*1.5)),cY=height*0.175;
    if(i<lives){fill(cEnergyCyan,50);ellipse(cX,cY,size*1.5,size*1.5);fill(cLeadGrey);ellipse(cX,cY,size,size);fill(cEnergyCyan);ellipse(cX,cY,size*0.5,size*0.5);}
    else{fill(cLeadDark);ellipse(cX,cY,size,size);fill(20);ellipse(cX,cY,size*0.5,size*0.5);}
  }
}

void drawTimerHUD() {
  if ((WaitingForPlayerToEnterCode || isShootingPhase) && lives > 0 && !isCodeVisible && !isShattered && !isRepairing && !isPaused && !isCountingDown) {

    // Drain Main Timer (per-level ceiling)
    timer -= drainSpeed;
    if (timer <= 0) {
      processWrongAnswer("REACTOR MELTDOWN: TIME EXPIRED!");
    }

    // Audio Heartbeat (accelerates as the countdown nears zero)
    int tickInterval = (int) map(timer, 0, timerMax, 100, 700);
    if (millis() - lastTickTime > tickInterval) {
      playSound("tick.mp3");
      lastTickTime = millis();
    }
    
    // Draw Main Timer Bar UI (UPDATED: moved up so it clears the touch buttons)
    float barW = width * 0.6, barX = width * 0.2, barY = height * 0.71;
    // numeric seconds readout above the bar
    fill(cLeadGrey); textAlign(CENTER, BOTTOM); textSize(height*0.026);
    gt("REACTOR COUNTDOWN  " + nf(max(0,timer),0,1) + "s", width/2, barY - 6);
    fill(cLeadDark); rect(barX, barY, barW, height * 0.02, 10);
    
    // Smoothly interpolate color from Cyan (full) to Red (empty)
    float activeW = map(timer, 0, timerMax, 0, barW);
    float colorLerp = constrain(map(timer, 0, timerMax, 0, 1), 0, 1);
    color timerColor = lerpColor(cWarningRed, cEnergyCyan, colorLerp);
    
    fill(timerColor); 
    rect(barX, barY, activeW, height * 0.02, 10);
    
    // SHOOTING TIMER: Only drains and draws when waiting for physical input
    if (WaitingForShootingInput) {
      shootingTimer -= drainSpeed;
      if (shootingTimer <= 0) {
        processShootingTimeout(); // TRIGGERS NEW CODE ON TIMEOUT
      }
      
      // Draw 10s Shooting Timer Bar UI (UPDATED: moved up to clear the touch buttons)
      float sBarW = width * 0.3, sBarX = width * 0.35, sBarY = height * 0.66;
      fill(cLeadDark); rect(sBarX, sBarY, sBarW, height * 0.015, 8);
      float sActiveW = map(shootingTimer, 0, 10, 0, sBarW);
      fill(cGold); rect(sBarX, sBarY, sActiveW, height * 0.015, 8);
    }
  }
}


void drawGameMessages() {
  textAlign(CENTER,CENTER); float tY=height*0.15; float big=height*0.07; float maxW=width*0.92;
  if(!isConnected){fill(cLeadGrey);gtFit(feedbackMessage,width/2,tY,maxW,big);}
  else if(lives<=0&&!isShattered&&!isRepairing){fill(cWarningRed);gtFit("REACTOR CRITICAL",width/2,tY,maxW,big);}
  else if(isShattered){fill(cWarningRed);gtFit(feedbackMessage,width/2,tY,maxW,big);}
  else if(isRepairing){fill(cEnergyCyan);}
  else if(isCountingDown){ /* countdown HUD handles its own text */ }
  else if(isCodeVisible){
    if (isMirrorHackActive) {
      fill(cWarningRed); gtFit("CORE CORRUPTED! SIGNAL INVERTED!", width/2, tY, maxW, big);
    } else {
      fill(cEnergyCyan); gtFit("MEMORISE FUEL SEQUENCE", width/2, tY, maxW, big);
    }
    // reveal lasts revealMs per cell (UPDATED: per-level pacing)
    int revealDur = displayLength*max(250,revealMs)+700;
    if(millis()-codeDisplayStartTime > revealDur){
      isCodeVisible=false; WaitingForPlayerToEnterCode=true;
      timer=levelTimerSecs; timerMax=levelTimerSecs;
      feedbackMessage = serialAvailable ? "BUILD THE SEQUENCE ON THE REACTOR" : "TAP  CORRECT  IF YOUR CELLS MATCH";
    }
  }
  else if (isShootingCodeVisible) {
    fill(cGold);gtFit("NEW LAUNCH TRAJECTORY",width/2,tY,maxW,big);
    if(millis()-shootingCodeDisplayStartTime > 2400){
      isShootingCodeVisible = false;
      WaitingForShootingInput = true;
      shootingTimer = 10.0;
      feedbackMessage = serialAvailable ? "FIRE THE LAUNCH SEQUENCE" : "TAP  FIRE  TO LAUNCH THE CELL";
    }
  }
  else if(WaitingForShootingInput) {fill(cWarningRed);gtFit(feedbackMessage,width/2,tY,maxW,big*0.8);}
  else if(WaitingForPlayerToEnterCode){fill(cWhite);gtFit(feedbackMessage,width/2,tY,maxW,big*0.8);}
  else{fill(showVictory?cEnergyCyan:cLeadGrey);gtFit(feedbackMessage,width/2,tY,maxW,big);}
}
void drawMainButton() {
  float btnW=width*0.45,btnH=height*0.10,btnY=height*0.88;
  if(!isCodeVisible&&!WaitingForPlayerToEnterCode&&!isShootingPhase&&!isShattered&&!isCountingDown){
    fill(0,0,0,180);rect(width/2-btnW/2+8,btnY+8,btnW,btnH,15);
    stroke(showVictory?cEnergyCyan:cLeadDark);
    if(lives<=0)stroke(cWarningRed); if(isRepairing)stroke(cLeadGrey);
    strokeWeight(4); fill(cNavyMid); rect(width/2-btnW/2,btnY,btnW,btnH,15); noStroke();
    fill(cWhite); textSize(btnH*0.40);
    
    String btnText="INITIATE SEQUENCE";
    if(lives<=0&&!isRepairing)btnText="EMERGENCY REBOOT";
    else if(isRepairing)btnText="RECALIBRATING...";
    else if(showVictory)btnText="ADVANCE REACTOR PHASE";
    
    gt(btnText,width/2,btnY+btnH/2);
  }
}
// =========================================================
// DATA SAVING & LOADING
// =========================================================
void loadGameData() {
  File f = new File(sketchPath("reactor_data.json"));   // writable on Android (internal storage) + desktop
  if (f.exists()) {
    try {
      JSONObject gameData = loadJSONObject(f);
      highScore = gameData.getInt("highScore", 0);
      bestStreak = gameData.getInt("bestStreak", 0);
      maxPhaseReached = gameData.getInt("maxPhase", 1);
      // NEW: persisted settings + lifetime stats
      bestLevel = gameData.getInt("bestLevel", 1);
      muted = gameData.getBoolean("muted", false);
      totalAttempts = gameData.getInt("totalAttempts", 0);
      totalSuccess = gameData.getInt("totalSuccess", 0);
    } catch (Exception e) {
      highScore = 0; bestStreak = 0; maxPhaseReached = 1;
    }
  } else {
    highScore = 0; bestStreak = 0; maxPhaseReached = 1;
  }
}

void saveGameData() {
  JSONObject gameData = new JSONObject();
  gameData.setInt("highScore", highScore);
  gameData.setInt("bestStreak", bestStreak);
  gameData.setInt("maxPhase", maxPhaseReached);
  // NEW: persist settings + lifetime stats
  gameData.setInt("bestLevel", bestLevel);
  gameData.setBoolean("muted", muted);
  gameData.setInt("totalAttempts", totalAttempts);
  gameData.setInt("totalSuccess", totalSuccess);
  saveJSONObject(gameData, sketchPath("reactor_data.json"));   // writable on Android (internal storage) + desktop
}

int lastTickTime = 0;
