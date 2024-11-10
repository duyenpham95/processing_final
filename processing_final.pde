import controlP5.*;
import gifAnimation.*;
import ddf.minim.*;
import java.io.File;

PFont font;
Gif gifCat;
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

// Variables for manual looping with speed control
int sampleStartTime = 0;
int playbackInterval = 1000;

void setup() {
  size(600, 400);
  cp5 = new ControlP5(this);
  
  font = createFont("Arial", 32, true);
  textFont(font);
  fill(0);

  gifCat = new Gif(this, "cat-dance.gif");
  gifCat.loop();

  minim = new Minim(this);
  input = minim.getLineIn(Minim.MONO, 512);
  recorder = minim.createRecorder(input, recordedFilePath, true);

  // Set up the "Record" button in the middle of the screen
  cp5.addButton("recordButton")
     .setPosition(width/2 - 50, height/2 - 25)
     .setSize(100, 50)
     .setLabel("Record");

  // Set up volume slider with extended range
  cp5.addSlider("volume")
     .setPosition(width - 150, 20)
     .setSize(100, 20)
     .setRange(-100, 100) // Increased volume range from -100 to 100 dB
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
     .setSize(100, 20)
     .setRange(0.1, 3) // Expanded speed range from 0.1 (slow) to 3 (fast)
     .setValue(1)
     .bringToFront()
     .setLock(false)
     .onChange(e -> {
       speedValue = e.getController().getValue();
       if (sample != null) {
         updatePlaybackInterval();
         println("Speed changed to: " + speedValue);
       }
     });
}

void updatePlaybackInterval() {
  playbackInterval = (int)(sample.length() / speedValue);
}

void draw() {
  background(255);

  if (state == 1) {  // Show record button
    cp5.getController("recordButton").setVisible(true);
  } else if (state == 2) {  // Countdown and recording status
    if (!recording) {
      println("Recording started...");
      startRecording();
    }
    
    if (millis() - lastCountdownTime >= 1000) {  // Update every second
      countdown--;
      lastCountdownTime = millis();
    }
    
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Recording in progress: " + countdown, width/2, height/2 - 50);
    cp5.getController("recordButton").setLabel("Recording");

    if (countdown <= 0 && recording) { // When countdown reaches zero, stop recording
      println("Recording stopped.");
      stopRecording();
      delay(500);
      checkAudioFile();
      state = 3;
    }
  } else if (state == 3) {  // Finished recording
    fill(0);
    text("Finished recording", width/2, height/2 - 50);
    cp5.getController("recordButton").setLabel("Next");
  } else if (state == 4) {  // Display GIF, show sliders, and play recorded audio
    image(gifCat, width/2 - gifCat.width/2, height/2 - gifCat.height/2);

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

// Function to start recording
void startRecording() {
  recording = true;
  recorder.beginRecord();
}

// Function to stop recording and save audio
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
