# Smart Pet Collar

A smart IoT-based collar for pets that monitors:
- ❤️ Heart rate (MAX30102)
- 🌡️ Body temperature (DS18B20)
- 🐾 Movement & steps (MPU6050)
- 📍 Live GPS location (NEO-6M)
- 📱 Mobile app built with Flutter + Firebase 

## 🎯 Features

- Live tracking of vitals and location
- Step counting algorithm with MPU6050
- Geofencing alerts
- Push notifications using Firebase Cloud Messaging
- Real-time updates via Firebase

## 🧠 Tech Stack

- **Hardware:** ESP32, MAX30102, DS18B20, MPU6050, NEO-6M GPS.
- **Software:** Arduino IDE (Embedded C), Flutter (Dart), Firebase 
- **Cloud:** Firebase Cloud Messaging, Firebase Realtime Database, Firebase Auth

## 🛠️ How it works

1. Sensors collect data from the pet in real-time
2. ESP32 processes & sends data via Wi-Fi
3. Data is pushed to Firebase 
4. Flutter app fetches and displays the data
5. Alerts sent as notifications

## 📱 Screenshots
![login_page](https://github.com/user-attachments/assets/1b1c407c-cb48-4ed4-8e6d-31fe77846514)


![main_page](https://github.com/user-attachments/assets/6f157d21-958f-407b-b11d-e487d8d4c356)

## 🔧 Installation

### Flutter App
```bash
cd flutter_app
flutter pub get
flutter run
