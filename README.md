# WhisperKit iOS Demo

A comprehensive iOS demo application showcasing the capabilities of WhisperKit for on-device speech recognition and transcription.

## Features

- Real-time audio transcription
- File-based transcription
- Multiple language support
- Multiple model support (tiny, base, small, medium, large)
- Audio recording and playback
- Transcription history management
- Extensive settings customization
- Dark mode support

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- An iOS device with Neural Engine (iPhone XS or newer recommended)

## Installation

### Option 1: Clone and Run

1. Clone the repository:
   ```bash
   git clone https://github.com/uakbr/WhisperKit-iOS-Demo.git
   cd WhisperKit-iOS-Demo
   ```

2. Open the project in Xcode:
   ```bash
   xed .
   ```
   Or open `WhisperKit-iOS-Demo.xcodeproj` directly from Finder

3. Install dependencies:
   - The project uses Swift Package Manager, which will automatically resolve dependencies
   - Wait for Xcode to finish downloading and setting up WhisperKit and other dependencies

4. Select your target device (physical iOS device recommended for best performance)

5. Build and run (⌘R)

### Option 2: Use as a Package Dependency

Add the following to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/uakbr/WhisperKit-iOS-Demo.git", .branch("main"))
]
```

## Setup and Configuration

### First Launch

1. When you first launch the app, it will guide you through:
   - Requesting microphone permissions
   - Downloading your first model (tiny model recommended for testing)
   - Setting up basic preferences

2. Model Management:
   - Go to Settings > Model Management
   - Choose and download your preferred model
   - Models are downloaded from the WhisperKit repository
   - Larger models provide better accuracy but require more storage and processing power

3. Language Settings:
   - Go to Settings > Language
   - Enable auto-detection or select a specific language
   - Language selection affects transcription accuracy

### Performance Optimization

1. Model Selection:
   - Tiny model: Fast, suitable for basic transcription
   - Base model: Good balance of speed and accuracy
   - Small model: Better accuracy, moderate performance impact
   - Medium/Large models: Best accuracy, significant performance impact

2. Compute Units:
   - CPU Only: Reliable but slower
   - Neural Engine Only: Fastest but may not support all operations
   - CPU and Neural Engine: Best balance (recommended)

3. Audio Settings:
   - Adjust quality based on your needs
   - Higher quality requires more storage
   - Supported formats: WAV, M4A, MP3

## Usage Guide

### Recording and Transcription

1. Real-time Transcription:
   - Tap the microphone button to start recording
   - Speech will be transcribed as you speak
   - Tap again to stop

2. File Import:
   - Tap the document icon to import audio files
   - Supported formats: WAV, M4A, MP3
   - Files are copied to the app's storage

3. Playback and Review:
   - Use the audio player controls to review recordings
   - Transcription segments show timestamps and confidence scores
   - Share or export transcriptions as needed

### History Management

1. Viewing History:
   - Access past transcriptions in the History tab
   - Sort by date, duration, or language
   - Search through transcriptions

2. Organizing:
   - Delete unneeded transcriptions
   - Export transcriptions
   - Share directly from the app

### Settings Management

1. Audio Settings:
   - Quality: Low/Medium/High
   - Format: WAV/M4A/MP3
   - Adjust based on storage needs

2. Transcription Settings:
   - Model selection
   - Language preferences
   - Task type (transcribe/translate)

3. Interface Settings:
   - Theme selection
   - Timestamp display
   - Export/Import preferences

## Troubleshooting

### Common Issues

1. Performance Issues:
   - Try a smaller model
   - Clear app storage if running low
   - Ensure device isn't in low power mode

2. Transcription Accuracy:
   - Check selected language
   - Try a larger model
   - Ensure good audio quality

3. Model Download Issues:
   - Check internet connection
   - Verify sufficient storage
   - Try restarting the app

### Error Messages

1. `Model Error`:
   - Usually indicates model download/loading issues
   - Try redownloading the model

2. `Audio Stream Error`:
   - Check microphone permissions
   - Restart audio session

3. `Storage Error`:
   - Clear app storage
   - Remove unused models

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - Core transcription engine
- [OpenAI Whisper](https://github.com/openai/whisper) - Original Whisper model

## Support

For support, please:
1. Check the [Issues](https://github.com/uakbr/WhisperKit-iOS-Demo/issues) page
2. Create a new issue if needed
3. Join the [Discussions](https://github.com/uakbr/WhisperKit-iOS-Demo/discussions)
