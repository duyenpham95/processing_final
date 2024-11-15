// *********** Dancing cat with light audio effect ***********
// Student ID: 25073709
import controlP5.*;
import ddf.minim.*;
import java.io.File;

PFont font;
PImage[] gifFrames;
PImage backgroundImg;
int currentFrame = 0;
int numFrames = 147;
int frameDisplayInterval = 65;
int lastFrameTime = 0;

Minim minim;
AudioInput input;
AudioRecorder recorder;
AudioSample sample;
AudioPlayer player;
float[] audioDataLeft;
float[] audioDataRight;

ControlP5 cp5;
float initVolume = 25;
float volumeValue = 0;
float speedValue = 1;

boolean recording = false;
boolean dataReady = false; // Flag to check if data is ready for visualization
int countdown = 2;
int lastCountdownTime;
int state = 1;
String recordedFilePath = "recorded_audio.wav";

int sampleStartTime = 0;
int playbackInterval = 1000;

// Arrays to store fixed positions and colors for the circles
PVector[] circlePositions = new PVector[32];
color[] circleColors = new color[32]; // Array to store colors for each circle

void setup() {
  size(600, 400);
  cp5 = new ControlP5(this);
  
  font = createFont("Arial", 32, true);
  textFont(font);
  fill(0);

  backgroundImg = loadImage("background.jpg");

  gifFrames = new PImage[numFrames];
  for (int i = 0; i < numFrames; i++) {
    gifFrames[i] = loadImage("frames/frame_" + i + ".gif");
  }

  minim = new Minim(this);
  input = minim.getLineIn(Minim.MONO, 512);
  recorder = minim.createRecorder(input, recordedFilePath, true);

  cp5.addButton("recordButton")
     .setPosition(width/2 - 50, height/2 - 25)
     .setSize(100, 50)
     .setLabel("Record");

  cp5.addSlider("volume")
     .setPosition(width - 150, 20)
     .setSize(110, 20)
     .setRange(0, 100)
     .setValue(initVolume)
     .bringToFront()
     .setLock(false)
     .onChange(e -> {
       volumeValue = e.getController().getValue();
     
       float gain = map(volumeValue, 0, 100, -25, 100);
       
       if (sample != null) {
         sample.setGain(gain); // Apply mapped gain to audio sample
         println("Volume changed to: " + volumeValue + " (Gain: " + gain + " dB)");
       }
     });

  cp5.addSlider("speed")
     .setPosition(width - 150, 50)
     .setSize(110, 20)
     .setRange(0.1, 5)
     .setValue(1)
     .bringToFront()
     .setLock(false)
     .onChange(e -> {
       speedValue = e.getController().getValue();
       if (sample != null) {
         updatePlaybackInterval();
         println("Speed changed to: " + speedValue);
       }
       updateFrameDisplayInterval();
     });
  
  // Generate random positions and colors for each circle
  for (int i = 0; i < circlePositions.length; i++) {
    float x = random(width);
    float y = random(height);
    circlePositions[i] = new PVector(x, y);
    
    // Generate and store a random color with opacity 75
    circleColors[i] = color(random(100, 255), random(100, 255), random(100, 255), 75);
  }
}

void updatePlaybackInterval() {
  playbackInterval = (int)(sample.length() / speedValue);
}

void updateFrameDisplayInterval() {
  int baseInterval = 65;
  frameDisplayInterval = (int)(baseInterval / speedValue);
}

void draw() {
  image(backgroundImg, 0, 0, width, height);

  if (state == 1) {  
    cp5.getController("recordButton").setVisible(true);
  } else if (state == 2) {  
    if (!recording) {
      println("Recording started...");
      startRecording();
    }
    
    if (millis() - lastCountdownTime >= 1000) {  
      countdown--;
      lastCountdownTime = millis();
    }
    
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Recording in progress: " + countdown, width/2, height/2 - 50);
    cp5.getController("recordButton").setLabel("Recording");

    if (countdown <= 0 && recording) {
      println("Recording stopped.");
      stopRecording();
      delay(500);  // Extra time for file save completion
      captureAudioDataDirectly();  // Direct buffer capture
      dataReady = true;  // Set flag to indicate data is ready
      state = 3;
    }
  } else if (state == 3) {  
    fill(255);
    text("Finished recording", width/2, height/2 - 50);
    cp5.getController("recordButton").setLabel("Next");
  } else if (state == 4) {  
    if (sample != null) {
      int elapsedTime = millis() - sampleStartTime;
      if (elapsedTime >= playbackInterval) {
        sample.trigger();
        sampleStartTime = millis();
      }
    }

    cp5.getController("volume").setVisible(true);
    cp5.getController("speed").setVisible(true);
    
    // Draw circles only if data is ready
    if (dataReady) {
      drawCirclesBasedOnAudioData();
    }

    // Draw the GIF as the top layer
    if (millis() - lastFrameTime >= frameDisplayInterval) {
      currentFrame = (currentFrame + 1) % numFrames;
      lastFrameTime = millis();
    }
    image(gifFrames[currentFrame], width/2 - gifFrames[currentFrame].width/2, height/2 - gifFrames[currentFrame].height/2);
  }
}

// Direct data capture from input buffers
void captureAudioDataDirectly() {
  if (input != null) {
    int bufferSize = input.bufferSize();
    println("Buffer size:", bufferSize);
    
    audioDataLeft = new float[bufferSize];
    audioDataRight = new float[bufferSize];
    
    for (int i = 0; i < bufferSize; i++) {
      audioDataLeft[i] = input.left.get(i);  // Access left channel
    }
    
    float[] numericDataFromAudio = calculateSampleData(audioDataLeft);
    
    for (int i = 0; i < 32; i++) {
      print(" ", numericDataFromAudio[i]);
    }
  } else {
    println("Error: Audio input not initialized.");
  }
}

void drawCirclesBasedOnAudioData() {
  float[] averagedData = calculateSampleData(audioDataLeft);
  
  // Calculate flashing interval based on speed
  int flashInterval = (int) map(speedValue, 0.1, 5, 1000, 100);  // Faster flashes with higher speed
  
  // Determine visibility of stroke based on flash interval
  boolean showStroke = (millis() % flashInterval) < flashInterval / 2;

  for (int i = 0; i < averagedData.length; i++) {
    // Map the averaged values to the range 5 to 50 for base radius
    float baseRadius = map(averagedData[i], min(averagedData), max(averagedData), 5, 50);
    
    // Adjust radius based on volume
    float adjustedRadius = baseRadius * map(volumeValue, -100, 100, 0.5, 1.5);  // Increase/decrease radius with volume
    
    // Use fixed positions from circlePositions array
    float x = circlePositions[i].x;
    float y = circlePositions[i].y;

    // Draw circle fill
    fill(circleColors[i]);  // Fixed random color with opacity 75
    noStroke();  // Ensure fill is always drawn without stroke

    // Draw the circle with adjusted radius
    ellipse(x, y, adjustedRadius * 2, adjustedRadius * 2);  // radius * 2 since ellipse uses diameter

    // Conditionally add a flashing stroke
    if (showStroke) {
      stroke(255, 255, 255, 50);  // White stroke with low opacity for a soft blur effect
      strokeWeight(6);             // Increase stroke weight for a blur-like appearance
      ellipse(x, y, adjustedRadius * 2, adjustedRadius * 2);  // Stroke only
    }
  }
}

float[] calculateSampleData(float[] audioDataLeft) {
  int numBatches = 32;      // Number of batches
  int batchSize = 16;       // Number of values per batch
  float[] averagedValues = new float[numBatches]; // Array to store averages
  
  // Loop through each batch
  for (int i = 0; i < numBatches; i++) {
    float sum = 0;
    
    // Calculate the sum of 16 values in the current batch
    for (int j = 0; j < batchSize; j++) {
      int index = i * batchSize + j;  // Calculate the correct index
      sum += audioDataLeft[index];
    }
    
    // Calculate the average for the current batch
    averagedValues[i] = sum / batchSize;
  }
  
  return averagedValues;  // Return the array of 32 averaged values
}

void startRecording() {
  recording = true;
  recorder.beginRecord();
}

void stopRecording() {
  if (recording) {
    recording = false;
    recorder.endRecord();
    recorder.save();

    delay(1000);  // Ensure enough time for saving

    // Load the audio sample for playback
    sample = minim.loadSample(recordedFilePath, 512);
  }
}

void recordButton() {
  if (state == 1) {
    countdown = 2;
    lastCountdownTime = millis();
    state = 2;
  } else if (state == 3) {
    state = 4;
    cp5.getController("recordButton").setPosition(-200, -200);

    cp5.getController("volume").setValue(initVolume);
    cp5.getController("speed").setValue(1);

    sample.trigger();
    sample.setGain(volumeValue);
    updatePlaybackInterval();
    updateFrameDisplayInterval();
    sampleStartTime = millis();
  }
}

void stop() {
  if (sample != null) {
    sample.close();
  }
  minim.stop();
  super.stop();
}
