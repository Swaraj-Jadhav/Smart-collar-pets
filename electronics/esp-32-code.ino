#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"

// WiFi Configuration
#define WIFI_SSID "Swaraj's Galaxy S10"
#define WIFI_PASSWORD "Swaraj@2003"

// Firebase Configuration
#define API_KEY "abcd1234x"
#define DATABASE_URL "https://pet-track-288ac-default-rtdb.asia-southeast1.firebasedatabase.app"
#define USER_EMAIL "test@example.com"
#define USER_PASSWORD "test1234"

// Sensor Pins
#define TEMP_PIN 35      // LM35DZ analog input
#define GPS_RX_PIN 16    // GPS TX → ESP32 RX16
#define GPS_TX_PIN 17    // GPS RX → ESP32 TX17
#define PULSE_PIN 34     // Pulse sensor analog input

// Sensor Objects
Adafruit_MPU6050 mpu;
TinyGPSPlus gps;
HardwareSerial SerialGPS(1); // UART1 for GPS

// Firebase Objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Variables
unsigned long sendDataPrevMillis = 0;
int stepCount = 0;
float bodyTemp = 0;
int bpm = 0;
float latitude = 0, longitude = 0;
float lastAccel[3] = {0};  // For step detection

// Pulse Sensor Variables
int pulseThreshold = 2500;      // Adjust based on your sensor
unsigned long lastBeatTime = 0;
int beatCount = 0;
const int pulseWindow = 5000;   // 5-second window for BPM calculation

// System Status
bool mpuInitialized = false;
bool gpsValid = false;

void setup() {
  Serial.begin(115200);
  SerialGPS.begin(9600, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  // Initialize I2C with robust settings
  Wire.begin(21, 22); // SDA=GPIO21, SCL=GPIO22
  Wire.setClock(100000); // Reduced speed for reliability
  Wire.setTimeout(100);

  // Initialize WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected with IP: " + WiFi.localIP().toString());

  // Initialize Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Initialize MPU6050 with retry logic
  mpuInitialized = initMPU6050();

  // Configure analog inputs
  analogReadResolution(12);  // ESP32 12-bit ADC
  pinMode(TEMP_PIN, INPUT);
  pinMode(PULSE_PIN, INPUT);

  // Wait for Firebase authentication
  Serial.println("Waiting for Firebase auth...");
  while (auth.token.uid == "") {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nSystem Ready!");
}

bool initMPU6050() {
  uint8_t retries = 5;
  while(retries--) {
    if(mpu.begin()) {
      mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
      mpu.setGyroRange(MPU6050_RANGE_500_DEG);
      mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
      Serial.println("MPU6050 Initialized");
      return true;
    }
    Serial.println("MPU6050 retrying...");
    delay(200);
  }
  Serial.println("MPU6050 Failed!");
  return false;
}

void loop() {
  // 1. Read GPS Data
  readGPS();

  // 2. Read Temperature (LM35DZ)
  bodyTemp = readTemperature();

  // 3. Count Steps
  if(mpuInitialized) {
    detectSteps();
  }

  // 4. Read Pulse Sensor
  readPulse();

  // 5. Send to Firebase every 5 seconds
  if (Firebase.ready() && (millis() - sendDataPrevMillis > 5000)) {
    sendDataPrevMillis = millis();
    sendToFirebase();
  }

  delay(10);  // Small delay for stability
}

void readGPS() {
  while (SerialGPS.available() > 0) {
    if (gps.encode(SerialGPS.read())) {
      if (gps.location.isValid()) {
        latitude = gps.location.lat();
        longitude = gps.location.lng();
        gpsValid = true;
      } else {
        gpsValid = false;
      }
    }
  }
  
  // Debug output every 10 seconds
  static unsigned long lastGPSTime = 0;
  if(millis() - lastGPSTime > 10000) {
    lastGPSTime = millis();
    Serial.print("GPS Status: ");
    Serial.println(gpsValid ? "Valid" : "No Fix");
    Serial.print("Satellites: ");
    Serial.println(gps.satellites.value());
  }
}

float readTemperature() {
  // Read 5 samples and average
  float sum = 0;
  for(int i=0; i<5; i++) {
    sum += analogReadMilliVolts(TEMP_PIN);
    delay(2);
  }
  float temp = (sum/5) / 10.0; // Convert mV to °C
  
  // Debug output if reading is 0
  if(temp == 0) {
    Serial.print("LM35 Debug - Raw mV: ");
    Serial.println(analogReadMilliVolts(TEMP_PIN));
  }
  
  return temp;
}

void detectSteps() {
  sensors_event_t a, g, temp;
  if(mpu.getEvent(&a, &g, &temp)) {
    float accelChange = abs(a.acceleration.x - lastAccel[0]) + 
                       abs(a.acceleration.y - lastAccel[1]) + 
                       abs(a.acceleration.z - lastAccel[2]);

    if (accelChange > 1.5 && millis() - lastBeatTime > 200) {  
      stepCount++;
    }

    lastAccel[0] = a.acceleration.x;
    lastAccel[1] = a.acceleration.y;
    lastAccel[2] = a.acceleration.z;
  }
}

void readPulse() {
  int pulseValue = analogRead(PULSE_PIN);
  
  // Auto-adjust threshold (70% of max reading)
  static int maxReading = 0;
  if(pulseValue > maxReading) maxReading = pulseValue;
  pulseThreshold = maxReading * 0.7;
  
  if (pulseValue > pulseThreshold && millis() - lastBeatTime > 200) {
    lastBeatTime = millis();
    beatCount++;
    
    if (millis() % pulseWindow < 100) {
      bpm = (beatCount * 60000) / pulseWindow;
      beatCount = 0;
      bpm = constrain(bpm, 60, 180); // Valid range for dogs
    }
  }
  
  // Debug output every 2 seconds
  static unsigned long lastPulseDebug = 0;
  if(millis() - lastPulseDebug > 2000) {
    lastPulseDebug = millis();
    Serial.print("Pulse Sensor - Raw: ");
    Serial.print(pulseValue);
    Serial.print(" | Threshold: ");
    Serial.println(pulseThreshold);
  }
}

void sendToFirebase() {
  FirebaseJson json;
  
  // Only send valid temperature readings
  if(bodyTemp > 0) {
    json.set("health/temperature", bodyTemp);
  } else {
    json.set("health/temperature", "null"); // Send as string "null"
  }
  
  json.set("steps", stepCount);
  
  // Only send valid heart rate
  if(bpm > 0) {
    json.set("health/heart_rate", bpm);
  } else {
    json.set("health/heart_rate", "null"); // Send as string "null"
  }
  
  // Only send valid GPS data
  if(gpsValid) {
    json.set("location/latitude", latitude);
    json.set("location/longitude", longitude);
  } else {
    json.set("location/latitude", "null");
    json.set("location/longitude", "null");
  }
  
  json.set("timestamp", millis()/1000);

  String path = "pets/dog1/";
  
  if (Firebase.RTDB.updateNode(&fbdo, path, &json)) {
    printSensorData();
  } else {
    Serial.println("Failed to send data");
    Serial.print("Error: "); Serial.println(fbdo.errorReason());
  }
}

void printSensorData() {
  Serial.println("\n--- Sensor Data ---");
  Serial.print("Temperature: "); 
  Serial.print(bodyTemp > 0 ? String(bodyTemp) + "°C" : "N/A");
  
  Serial.print(" | Steps: "); Serial.print(stepCount);
  
  Serial.print(" | Heart Rate: ");
  Serial.print(bpm > 0 ? String(bpm) + " BPM" : "N/A");
  
  Serial.print(" | Location: ");
  if(gpsValid) {
    Serial.print(latitude, 6); Serial.print(", "); Serial.println(longitude, 6);
  } else {
    Serial.println("No GPS Fix");
  }
}
