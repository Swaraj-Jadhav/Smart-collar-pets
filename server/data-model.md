
# 📦 Firebase Realtime Database Data Model



## 🗂️ Database Root Structure

```json
{
  "pets": {
    "petID_1": {
      "name": "Buddy",
      "ownerId": "user_123",
      "heartRate": 98,
      "temperature": 38.5,
      "steps": 1240,
      "location": {
        "latitude": 19.0760,
        "longitude": 72.8777
      },
      "lastUpdated": 1714741320000
    },
    "petID_2": {
      ...
    }
  },
  "users": {
    "user_123": {
      "name": "Alice Sharma",
      "email": "alice@example.com",
      "pets": {
        "petID_1": true
      }
    }
  }
}
