
# 🎧 AUDIO TOOLKIT
Flutter Plugin for Screen Capture & Audio Recording with Transcription

> 📦 A Flutter plugin for **macOS 13+** to record **system audio**, **microphone**, and **transcribe voice to text** using built-in speech recognition.

We are currently working on **Windows**, **Android**, and **iOS** support.  
Perfect for building **voice assistants**, **audio analysis**, and **screen/audio capture apps** on macOS.

---

## 🧠 Features

- 🎙️ **System Audio Recording (macOS only)**
- 🎤 **Microphone Recording**
- 🗣️ **Speech-to-Text Transcription**
  - Transcribe recorded files to text
- ⏱️ **Real-time Streaming Transcription**
  - Get results segment-by-segment as audio is processed
- 📁 **Save Recordings to File**
  - Output to Downloads folder as `.wav`

---

## 🛠️ macOS Setup Guide

This plugin requires specific permissions & capabilities:

### 1. App Sandbox – Downloads Folder Access
> **Xcode** → **Signing & Capabilities** → **App Sandbox** → Enable **User Selected File** → Add **Downloads Folder**

![sandbox config](https://raw.githubusercontent.com/vuduchiieu/audio_toolkit/main/images/1.jpg)

---

### 2. Enable Hardened Runtime – Audio Input
> **Xcode** → **Signing & Capabilities** → **Hardened Runtime** → Enable **Audio Input**

![runtime config](https://raw.githubusercontent.com/vuduchiieu/audio_toolkit/main/images/2.jpg)

---

### 3. Add Permissions to `Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app requires microphone access to record audio.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to convert voice to text.</string>
```

---

## 📦 Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  audio_toolkit: <latest_version>
```

Then run:

```bash
flutter pub get
```

---

## ⚠️ Known Limitations

- ✅ Works only on macOS 13+
- 🔒 Speech recognition does not work in debug mode  
  Run your `.app` via `flutter build macos` instead of `flutter run`
- 📁 File output path is currently fixed to Downloads
- ⛔ Screen or system audio permissions may need to be granted manually

---

## 🧭 Use Cases

- 🎤 Voice-to-text dictation tools
- 📹 Screen recording with audio overlay
- 🎧 Podcast tools and voice editing apps
- 📊 Real-time voice analysis

---

## 🔮 Roadmap

- ✅ macOS support (Complete)
- ⏳ iOS / Android / Windows support
- 📜 Whisper & multilingual transcription
- 🎚️ Audio format & output customization

---

## 🤝 Contributions

Feel free to open an issue or submit a pull request.  
Your feedback makes this tool better 💜

Maintained by [@vuduchieu](https://github.com/vuduchiieu)
