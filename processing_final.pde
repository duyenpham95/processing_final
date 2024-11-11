import controlP5.*;
import ddf.minim.*;
import java.io.File;

PFont font;
PImage[] gifFrames;
int currentFrame = 0;
int numFrames = 147;
int frameDisplayInterval = 75;  // Default interval in milliseconds
int lastFrameTime = 0;           // Last time a new frame was shown

Minim minim;
AudioInput input;
AudioRecorder recorder;
AudioSample sample;
ControlP5 cp5;
float volumeValue = 0;
float speedValue = 1;

boolean recording = false;
int countdown = 2;
int lastCountdownTime;
int state = 1;
String recordedFilePath = "recorded_audio.wav";

int sampleStartTime = 0;
int playbackInterval = 1000;

void setup() {
  size(600, 400);
  cp5 = new ControlP5(this);
  
  font = createFont("Arial", 32, true);
  textFont(font);
  fill(0);

  // Load all frames from the "frames" folder
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

  // Set up volume slider with extended range
  cp5.addSlider("volume")
     .setPosition(width - 150, 20)
     .setSize(110, 20)
     .setRange(-100, 100)
     .setValue(0)
     .bringToFront()
     .setLock(false)
     .onChange(e -> {
       volumeValue = e.getController().getValue();
       if (sample != null) {
         sample.setGain(volumeValue);
         println("Volume changed to: " + volumeValue);
       }
     });

  // Set up speed slider with expanded range
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
       updateFrameDisplayInterval();  // Adjust frame interval for GIF playback
     });
}

void updatePlaybackInterval() {
  playbackInterval = (int)(sample.length() / speedValue);
}

void updateFrameDisplayInterval() {
  // Adjust frame interval inversely with speedValue
  int baseInterval = 100; // Base interval in milliseconds for normal speed
  frameDisplayInterval = (int)(baseInterval / speedValue); // Scale interval based on speed
}

void draw() {
  background(255);

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
    
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Recording in progress: " + countdown, width/2, height/2 - 50);
    cp5.getController("recordButton").setLabel("Recording");

    if (countdown <= 0 && recording) {
      println("Recording stopped.");
      stopRecording();
      delay(500);
      checkAudioFile();
      state = 3;
    }
  } else if (state == 3) {  
    fill(0);
    text("Finished recording", width/2, height/2 - 50);
    cp5.getController("recordButton").setLabel("Next");
  } else if (state == 4) {  
    // Display the current frame of the GIF with controlled timing
    if (millis() - lastFrameTime >= frameDisplayInterval) {
      currentFrame = (currentFrame + 1) % numFrames;  // Loop through frames
      lastFrameTime = millis();
    }
    image(gifFrames[currentFrame], width/2 - gifFrames[currentFrame].width/2, height/2 - gifFrames[currentFrame].height/2);

    if (sample != null) {
      int elapsedTime = millis() - sampleStartTime;
      if (elapsedTime >= playbackInterval) {
        sample.trigger();
        sampleStartTime = millis();
      }
    }

    cp5.getController("volume").setVisible(true);
    cp5.getController("speed").setVisible(true);
  }
}

void startRecording() {
  recording = true;
  recorder.beginRecord();
}

void stopRecording() {
  recording = false;
  recorder.endRecord();
  recorder.save();
  
  delay(1000);
  checkAudioFile();

  sample = minim.loadSample(recordedFilePath, 512);
}

void checkAudioFile() {
  File audioFile = new File("./" + dataPath(recordedFilePath));
  println(recordedFilePath);
  if (audioFile.exists()) {
    println("Audio file exists. File size: " + audioFile.length() + " bytes");
  } else {
    println("Audio file does not exist. Recording may have failed.");
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

    cp5.getController("volume").setValue(0);
    cp5.getController("speed").setValue(1);

    sample.trigger();
    sample.setGain(volumeValue);
    updatePlaybackInterval();
    updateFrameDisplayInterval();  // Set initial frame display interval based on speed
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
