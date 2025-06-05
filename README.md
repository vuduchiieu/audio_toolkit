# 🎧 audio_toolkit

> **Only supported on macOS 13+**

We are currently developing support for **Windows**, **Android**, and **iOS** platforms.

## 🧠 Features

- 🎙️ **System Audio Recording**
- 🎤 **Microphone Recording**
- 🗣️ **Voice-to-Text Transcription**
  - Supports full file transcription
- ⏱️ **Streaming Transcription**
  - Get text segment by segment as audio is processed
- 📁 **Full File Recording**
  - Save audio directly to the Downloads folder

## 🛠️ Setup Instructions

### macOS App Permissions

This plugin requires enabling the following permissions:

#### 1. Enable access to the Downloads folder via App Sandbox

- Go to **Signing & Capabilities** → **App Sandbox** → Enable **User Selected File** → Choose **Downloads Folder**

![audio_toolkit](https://raw.githubusercontent.com/vuduchiieu/audio_toolkit/main/images/1.jpg)

#### 2. Enable Audio Input in Hardened Runtime

- Go to **Signing & Capabilities** → **Hardened Runtime** → Enable **Audio Input**

![audio_toolkit](https://raw.githubusercontent.com/vuduchiieu/audio_toolkit/main/images/2.jpg)

#### 3. Add the following permissions to your `Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app requires microphone access to record audio.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to convert voice to text.</string>
```

## 📦 Installation

```yaml
dependencies:
  audio_toolkit: <latest_version>
```

Then run:

```sh
flutter pub get
```

## ⚠️ Notes

- Only works on macOS 13 or higher
- Requires user permission to access mic, screen, and file system
- Save file location is currently fixed to the Downloads directory
- 🔒 **`initTranscribeAudio` only works when building a production app**.  
  It **does not work in debug mode** (e.g. run via VSCode) because **VSCode does not prompt for speech recognition permission**.  
  Please build the app using `flutter build macos` and run the `.app` directly.

## 🔮 Future Plans

- Cross-platform support for Windows, Android, iOS
- Audio format customization
- Whisper support for more accurate transcription

---

Feel free to contribute or open an issue!

📍 Maintained by [@vuduchieu](https://github.com/vuduchiieu)
