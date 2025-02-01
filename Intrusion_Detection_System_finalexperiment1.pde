import ddf.minim.*;
import processing.serial.*;
import java.awt.event.KeyEvent;
import java.io.IOException;
import java.lang.Thread;

Serial myPort;
float prevDistance = 0;
long prevTime = 0;
float objectSpeed = 0; // Speed in cm/s
String angle = "";
String distance = "";
String data = "";
String noObject;
float pixsDistance;
int iAngle, iDistance;
int index1 = 0;
int index2 = 0;
PFont orcFont;
String soundFilePath = "C:\\Users\\Admin\\Downloads\\OBJDETSOUND.wav";
String humsoundFilePath = "C:\\Users\\Admin\\Downloads\\3.mp3";
AudioPlayer player;
AudioSample radarHum;
Minim minim;
boolean objectDetected = false;
boolean soundPlaying = false;
boolean radarIsActive = false;

// Distance Graph Variables
int graphX = 20, graphY = 20;
int graphWidth = 300, graphHeight = 100;
int maxHistory = 100;
ArrayList<Integer> distanceHistory = new ArrayList<Integer>();
ArrayList<Integer> colorHistory = new ArrayList<Integer>();

void setup() {
  size(1160, 680);
  smooth();
  minim = new Minim(this);
  player = minim.loadFile(soundFilePath);
  Thread soundThread = new Thread(new SoundPlayer());
  soundThread.start();
  radarHum = minim.loadSample(humsoundFilePath);
  Thread radarHumThread = new Thread(new RadarHumPlayer());
  radarHumThread.start();
  myPort = new Serial(this, "COM4", 9600);
  myPort.bufferUntil('.'); 
}

void draw() {
  fill(98, 245, 31);
  noStroke();
  fill(0, 4);
  rect(0, 0, width, height - height * 0.065);
  fill(98, 245, 31);
  drawRadar();
  drawLine();
  drawObject();
  drawText();
  drawGraph();  // **HUD-style graph**
}

void serialEvent(Serial myPort) {
  data = myPort.readStringUntil('.');
  if (data == null || data.length() < 3) return;

  try {
    index1 = data.indexOf(",");
    angle = data.substring(0, index1);
    distance = data.substring(index1 + 1, data.length());
    iAngle = int(angle);
    iDistance = constrain(int(distance), 0, 40);

    // **Speed Calculation**
    long currentTime = millis();
    float timeDiff = (currentTime - prevTime) / 1000.0; // Convert to seconds

    if (timeDiff > 0) {
      objectSpeed = abs((iDistance - prevDistance) / timeDiff); // cm/s
    }

    prevDistance = iDistance;
    prevTime = currentTime;

    // **DEBUG: Print Speed in Console**
    println("Speed: " + objectSpeed + " cm/s");

    // **Update the Radar UI**
    if (distanceHistory.size() > maxHistory) {
      distanceHistory.remove(0);
      colorHistory.remove(0);
    }
    distanceHistory.add(iDistance);
    colorHistory.add(iDistance < 15 ? color(255, 0, 0) : (iDistance < 25 ? color(255, 255, 0) : color(0, 0, 255)));

    radarIsActive = iDistance >= 40;
  } catch (Exception e) {
    println("Serial Error: " + e.getMessage());
  }
}

class SoundPlayer implements Runnable {
  public void run() {
    while (true) {
      if (iDistance < 40 && !soundPlaying) {
        player.rewind();
        player.play();
        soundPlaying = true;
      } else if (iDistance >= 40) {
        soundPlaying = false;
      } 
      delay(10);
    }
  }
}

class RadarHumPlayer implements Runnable {
  public void run() {
    while (true) {
      if (radarIsActive) {
        if (!radarHum.isMuted()) {
          radarHum.trigger();
        }
      } else {
        radarHum.stop();
      }
      delay(10);
    }
  }
}

boolean blinkState = false; // For blinking effect
int lastBlinkTime = 0;
int blinkInterval = 500; // Blink every 500ms

void drawGraph() {
  pushMatrix();
  translate(graphX, graphY);

  // **HUD-style background**
  fill(0, 50, 0, 180);
  rect(0, 0, graphWidth, graphHeight);

  // **Graph Border (Same as Arc Lines)**
  stroke(98, 245, 31);
  strokeWeight(2);
  noFill();
  rect(0, 0, graphWidth, graphHeight);

  // **Make the graph grid lines ultra-thin**
  stroke(98, 245, 31, 100); // Light green, semi-transparent
  strokeWeight(0.5); // **Thinner than arc lines**
  for (int i = 0; i <= 4; i++) {
    int y = graphHeight - i * (graphHeight / 4);
    line(0, y, graphWidth, y);
  }

  // **Graph Labels**
  fill(98, 245, 31);
  textSize(12);
  text("0cm", graphWidth + 5, graphHeight);
  text("10cm", graphWidth + 5, graphHeight - (graphHeight / 4));
  text("20cm", graphWidth + 5, graphHeight - (graphHeight / 2));
  text("30cm", graphWidth + 5, graphHeight - (graphHeight * 3 / 4));
  text("40cm", graphWidth + 5, 10);

  // **Distance Plot**
  strokeWeight(2);
  beginShape();
  for (int i = 1; i < distanceHistory.size(); i++) {
    float x1 = (i - 1) * (graphWidth / (float) maxHistory);
    float y1 = graphHeight - map(distanceHistory.get(i - 1), 0, 40, 0, graphHeight);
    float x2 = i * (graphWidth / (float) maxHistory);
    float y2 = graphHeight - map(distanceHistory.get(i), 0, 40, 0, graphHeight);

    stroke(colorHistory.get(i - 1));
    line(x1, y1, x2, y2);
  }
  endShape();
  popMatrix();
}

// **Animated Blinking Indicator for Detected Objects**
void drawBlinkingIndicator() {
  if (millis() - lastBlinkTime > blinkInterval) {
    blinkState = !blinkState; // Toggle state
    lastBlinkTime = millis();
  }

  if (iDistance < 40 && blinkState) { // Blink only when an object is detected
    pushMatrix();
    translate(width / 2, height - height * 0.1);
    fill(255, 0, 0, 200); // Red glowing effect
    noStroke();
    ellipse(0, 0, 20, 20); // Blinking indicator
    popMatrix();
  }
}

String getCurrentTime() {
  int h = hour();
  int m = minute();
  int s = second();
  return nf(h, 2) + ":" + nf(m, 2) + ":" + nf(s, 2);
}


void drawText() {
  pushMatrix();
  fill(0, 0, 0); // **Black background to clear previous text**);
  noStroke();
  rect(width - width * 0.194, height - height * 0.973, 250, 40); // **Clear area before writing new speed**
  fill(98, 245, 31);
  textSize(25);
  text("Distance Graph", graphX, graphY - 3);
    if (iDistance > 40) {
    noObject = "Out of Range";
  } else {
    noObject = "In Range";
  }
  
  fill(0, 0, 0);
  rect(width - width * 0.194, height - height * 0.913, 250, 35); // **Clear area before writing new speed**
  fill(98, 245, 31);
  text("Time: " + getCurrentTime(), width - width * 0.194, height - height * 0.880);
  
  fill(98, 245, 31);
  textSize(25);

  // **Ensure Speed is Visible in GUI**
  text("Speed: " + nf(objectSpeed, 0, 2) + " cm/s", width - width * 0.194, height - height * 0.933);
  
  fill(0, 0, 0);
  noStroke();
  rect(0, height - height * 0.0648, width, height);
  fill(98, 245, 31);
  textSize(25);

  text("10cm", width - width * 0.415, height - height * 0.0833);
  text("20cm", width - width * 0.3131, height - height * 0.0833);
  text("30cm", width - width * 0.2046, height - height * 0.0833);
  text("40cm", width - width * 0.0989, height - height * 0.0833);
  textSize(40);
  text("Intrusion Detection System", width - width * 0.957, height - height * 0.0277);
  text("Angle: " + iAngle + "  ", width - width * 0.53, height - height * 0.0277);
  text("Distance: ", width - width * 0.360, height - height * 0.0277);
  if (iDistance < 40) {
    text("        " + iDistance + " cm", width - width * 0.225, height - height * 0.0277);
  }
  textSize(25);
  fill(98,245,60);
  translate((width-width*0.4994)+width/2*cos(radians(30)),(height-height*0.0907)-width/2*sin(radians(30)));
  rotate(-radians(-60));
  text("30 ",0,0);
  resetMatrix();
  translate((width-width*0.503)+width/2*cos(radians(60)),(height-height*0.0888)-width/2*sin(radians(60)));
  rotate(-radians(-30));
  text("60 ",0,0);
  resetMatrix();
  translate((width-width*0.507)+width/2*cos(radians(90)),(height-height*0.0833)-width/2*sin(radians(90)));
  rotate(radians(0));
  text("90 ",0,0);
  resetMatrix();
  translate(width-width*0.513+width/2*cos(radians(120)),(height-height*0.07129)-width/2*sin(radians(120)));
  rotate(radians(-30));
  text("120 ",0,0);
  resetMatrix();
  translate((width-width*0.5104)+width/2*cos(radians(150)),(height-height*0.0574)-width/2*sin(radians(150)));
  rotate(radians(-60));
  text("150 ",0,0);
  popMatrix();
}

void drawRadar() {
  pushMatrix();
  translate(width / 2, height - height * 0.074);
  noFill();
  strokeWeight(2);
  stroke(98, 245, 31);
  arc(0, 0, (width - width * 0.0625), (width - width * 0.0625), PI, TWO_PI);
  arc(0, 0, (width - width * 0.27), (width - width * 0.27), PI, TWO_PI);
  arc(0, 0, (width - width * 0.479), (width - width * 0.479), PI, TWO_PI);
  arc(0, 0, (width - width * 0.687), (width - width * 0.687), PI, TWO_PI);
  line(-width / 2, 0, width / 2, 0);
  line(0, 0, (-width / 2) * cos(radians(30)), (-width / 2) * sin(radians(30)));
  line(0, 0, (-width / 2) * cos(radians(60)), (-width / 2) * sin(radians(60)));
  line(0, 0, (-width / 2) * cos(radians(90)), (-width / 2) * sin(radians(90)));
  line(0, 0, (-width / 2) * cos(radians(120)), (-width / 2) * sin(radians(120)));
  line(0, 0, (-width / 2) * cos(radians(150)), (-width / 2) * sin(radians(150)));
  line((-width / 2) * cos(radians(30)), 0, width / 2, 0);
  popMatrix();
}

void drawObject() {
  pushMatrix();
  translate(width / 2, height - height * 0.074);
  strokeWeight(9);
  pixsDistance = iDistance * ((height - height * 0.1666) * 0.025); 

  if (iDistance < 15) stroke(255, 0, 0);
  else if (iDistance < 25) stroke(255, 255, 0);
  else stroke(0, 0, 255);

  if (iDistance < 40) {
    line(pixsDistance * cos(radians(iAngle)), -pixsDistance * sin(radians(iAngle)),
         (width - width * 0.505) * cos(radians(iAngle)), -(width - width * 0.505) * sin(radians(iAngle)));
  }
  popMatrix();
}

void drawLine() {
  pushMatrix();
  strokeWeight(9);
  stroke(30, 250, 60);
  translate(width / 2, height - height * 0.074);
  line(0, 0, (height - height * 0.12) * cos(radians(iAngle)), -(height - height * 0.12) * sin(radians(iAngle)));
  popMatrix();
}
