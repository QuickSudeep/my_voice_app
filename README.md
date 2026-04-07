# Nepali Voice Assistant App (साथी - Saathi)

A cross-platform voice recording application that works on Windows, Android, and iOS.

## Features

- ✅ **Cross-platform**: Works on Windows, Android, and iOS
- 🎤 **High-quality audio recording** with pause/resume functionality
- 📱 **Modern UI** with pulsing animations
- 💾 **Recording management** - View, play, and delete recordings
- ⚙️ **Customizable settings** - Audio quality, recording duration, etc.
- 🔒 **Automatic permission handling**
- 🎵 **Built-in audio playback**
- 📊 **Recording duration tracking**
- 🌐 **Bilingual interface** (Nepali & English)

## Requirements

### For Development

- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher

### Platform-Specific Requirements

#### Windows

- Windows 10 or later
- Visual Studio 2022 (for Windows desktop development)

#### Android

- Android Studio
- Android SDK (API level 21 or higher)
- Android device or emulator

#### iOS

- macOS
- Xcode 14 or later
- iOS device or simulator (iOS 12.0+)
- CocoaPods

## Installation

### 1. Clone or Download the Project

```bash
git clone <your-repository-url>
cd my_voice_assistant_app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Platform-Specific Setup

#### Android Setup

1. Open `android/app/src/main/AndroidManifest.xml` and verify permissions are present
2. Update `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

#### iOS Setup

1. Navigate to iOS directory:

```bash
cd ios
pod install
cd ..
```

2. Open `ios/Runner/Info.plist` and verify microphone permission is present

#### Windows Setup

No additional setup required. The app uses the `record` package which handles Windows audio recording natively.

## Running the App

### On Android

```bash
flutter run -d android
```

### On iOS

```bash
flutter run -d ios
```

### On Windows

```bash
flutter run -d windows
```

### On Any Connected Device

```bash
flutter devices  # List all devices
flutter run      # Run on default device
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── screens/
│   ├── home_screen.dart        # Main recording interface
│   ├── admin_screen.dart       # Settings screen
│   └── recordings_screen.dart  # Recordings list & playback
└── services/
    ├── voice_service.dart      # Audio recording service
    └── settings_service.dart   # Settings management
```

## Features Breakdown

### Home Screen

- Large microphone button with pulsing animation
- Real-time recording status in Nepali and English
- Recording duration display
- Pause/Resume/Cancel controls while recording
- SOS emergency button

### Recordings Screen

- List of all recordings with metadata
- Play/pause recordings directly
- Delete recordings with confirmation
- File size and date information
- Playback progress indicator

### Settings (Admin) Screen

- Auto-save recordings toggle
- Show recording duration toggle
- Maximum recording duration setting (1-60 minutes)
- Audio quality selection (Low/Medium/High)
- View total recordings count
- Clear all recordings option
- Reset settings to defaults

## Usage

### Recording Audio

1. **Start Recording**: Tap the large microphone button
2. **Pause**: Tap the pause button during recording
3. **Resume**: Tap the play button when paused
4. **Stop & Save**: Tap the check button
5. **Cancel**: Tap the X button to discard

### Managing Recordings

1. Navigate to Recordings screen from home or settings
2. Tap a recording to play/pause
3. Use the delete button to remove recordings
4. Playback controls appear at the bottom when playing

### Customizing Settings

1. Open Settings from the home screen
2. Adjust preferences:
   - Toggle auto-save
   - Show/hide recording timer
   - Set max recording duration
   - Choose audio quality
3. Save changes automatically

## Permissions

### Android

- `RECORD_AUDIO` - Required for audio recording
- `READ_MEDIA_AUDIO` - Required for accessing recordings (Android 13+)

### iOS

- `NSMicrophoneUsageDescription` - Required for audio recording

### Windows

- No special permissions required

## Troubleshooting

### Audio Not Recording

**Android/iOS:**

1. Check microphone permissions in device settings
2. Grant permissions when prompted
3. Restart the app

**Windows:**

1. Verify microphone is connected and enabled
2. Check Windows privacy settings for microphone access
3. Test microphone in other applications

### Recordings Not Saving

1. Check storage permissions (Android)
2. Ensure sufficient storage space
3. Check app's document directory permissions

### App Won't Build

**Flutter issues:**

```bash
flutter clean
flutter pub get
flutter run
```

**iOS issues:**

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

**Android issues:**

```bash
cd android
./gradlew clean
cd ..
flutter run
```

## Building for Release

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

### Windows

```bash
flutter build windows --release
```

## Future Enhancements

- [ ] Speech-to-text transcription (Nepali language support)
- [ ] Cloud backup for recordings
- [ ] Share recordings via email/messaging
- [ ] Recording tags and categories
- [ ] Voice assistant AI integration
- [ ] SOS emergency calling feature
- [ ] Multiple language support

## Dependencies

- `record` - Cross-platform audio recording
- `just_audio` - Audio playback
- `path_provider` - File system paths
- `permission_handler` - Runtime permissions
- `provider` - State management
- `shared_preferences` - Settings storage
- `uuid` - Unique file naming

## License

[Add your license here]

## Credits

Developed for Nepali-speaking communities with love ❤️

## Support

For issues and feature requests, please create an issue in the repository.

---

**साथी (Saathi)** - Your voice companion
