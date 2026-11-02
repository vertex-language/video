# video

Plays video and audio files: decoding, sound out of the device, and each frame as pixels. `web` decodes nothing itself. `video/host` is what gives a `web.Page` its players.

## Quick Start

```bash
vsc run -replace web=../../web -replace image=../../image check-video
```

## Packages

| Package | What it is |
| --- | --- |
| **`video/video`** | `Player`: opens a file or URL, plays, pauses and seeks, and hands over the newest frame. macOS: AVFoundation. Elsewhere it opens nothing yet. |
| **`video/host`** | `host.Install(page)`: makes `Player` the page's `web.MediaPlayer`, so `<video>` and `<audio>` play. |

## Publishing it

1. Create `vertex-language/video` and push this folder to it.
2. In `ui/webview`, call `host.Install(view.Page)` where the page is made.
