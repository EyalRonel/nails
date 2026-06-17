# Nails

A macOS menu bar app that uses your webcam to detect nail biting in real time and alerts you to stop.

Nails runs quietly in your menu bar, continuously analyzing your webcam feed using Apple's Vision framework to detect when your fingers are near your mouth in a nail-biting posture. When it catches you, it can play a sound, show a screen alert, send a notification, and snap a photo for later review.

## Features

- **Real-time detection** — Uses hand pose and face landmark analysis to identify nail-biting behavior specifically (not just hand-near-mouth)
- **Multiple alert types** — Configurable sound alerts, on-screen overlay, and system notifications
- **Snapshot capture** — Optionally takes a photo on each detection for review
- **Adaptive learning** — Review detection snapshots and flag false alarms to improve accuracy over time
- **Configurable cooldowns** — Separate cooldown timers for sound and notification alerts
- **Pause on screen lock** — Automatically pauses monitoring when your screen is locked
- **Launch at login** — Start monitoring automatically when you log in
- **Privacy-first** — All processing happens on-device. No data is ever sent anywhere.

## Requirements

- macOS 14.0 or later
- A Mac with a built-in or connected webcam
- Camera permission (the app will prompt on first launch)

## Installation

### Download

1. Download the latest `nails.app.zip` from the [Releases](../../releases) page
2. Unzip and move `nails.app` to your Applications folder
3. Right-click the app and select **Open** (required on first launch since the app is not notarized)

### Build from Source

1. Clone the repository:
   ```
   git clone https://github.com/EyalRonel/nails.git
   ```
2. Open `nails.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Usage

Once launched, Nails appears as an eye icon in your menu bar:

- **Eye icon** — Monitoring is active
- **Eye slash icon** — Monitoring is paused
- **Warning triangle** — Nail biting detected

Click the menu bar icon to:

- **Toggle monitoring** on/off with the switch
- **Open Settings** to configure alerts, cooldowns, and preferences
- **Review Detections** to browse captured snapshots and flag false alarms

### Settings

- **Notification & Picture Cooldown** — How long to wait between notification/snapshot alerts (1-60s)
- **Sound Cooldown** — How long to wait between sound alerts (1-30s)
- **Take Picture on Detection** — Capture a snapshot when nail biting is detected
- **Show Screen Alert** — Display a floating overlay in the center of the screen
- **Play Sound on Detection** — Play a system sound with a configurable sound picker
- **Launch at Login** — Start automatically when you log in
- **Pause When Screen Is Locked** — Stop monitoring when the screen locks
- **Clear All** — Delete all detection history, images, and learned thresholds

### Improving Detection

1. Open **Review Detections** from the menu bar
2. For each snapshot, mark it as correct (checkmark) or a false alarm (X)
3. The app adjusts its detection threshold based on your feedback

## How It Works

Nails uses Apple's Vision framework to run two analyses on each video frame:

1. **Hand pose detection** — Identifies fingertip positions and finger orientation
2. **Face landmark detection** — Locates the mouth region

A detection triggers when 1-3 fingertips are near the mouth and at least one finger is oriented toward the mouth (tip closer than the DIP joint). This distinguishes nail biting from simply covering your mouth or resting your chin on your hand.

The camera runs at 15fps with frame processing at ~5fps to minimize CPU usage.

## Privacy

- All video processing happens locally on your Mac using Apple's Vision framework
- No images or data are transmitted over the network
- Snapshots are stored in your app sandbox (`~/Library/Containers/eyalronel.nails/`)
- The camera is used non-exclusively so other apps can access it simultaneously

## License

MIT
