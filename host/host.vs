// Package host gives a web.Page its players, so <video> and <audio> play.
package host

import (
    "image/draw"
    "video/video"
    "web"
)

/// A video.Player as the page asks for one. A file:// URL is opened as the
/// path it names.
final class Adapter: web.MediaPlayer {
    let player: video.Player

    init(player: video.Player) { self.player = player }

    var Ready: bool { return player.Status == .ready }
    var Failed: bool { return player.Status == .failed }
    var Paused: bool { return player.Paused }
    var Ended: bool { return player.Ended }
    var Duration: float64 { return player.Duration }
    var CurrentTime: float64 { return player.CurrentTime }
    var VideoWidth: int32 { return player.Width }
    var VideoHeight: int32 { return player.Height }
    func Play() { player.Play() }
    func Pause() { player.Pause() }
    func Seek(to seconds: float64) { player.Seek(to: seconds) }
    func SetVolume(volume: float32) { player.SetVolume(volume) }
    func SetMuted(muted: bool) { player.SetMuted(muted) }
    func SetLoop(loop: bool) { player.SetLoop(loop) }
    func Frame() -> draw.Image? { return player.Frame() }
    func Close() { player.Close() }
}

/// Makes this package the page's source of players.
@MainActor
public func Install(page: web.Page) {
    page.SetMediaOpener { url in
        guard let p = video.Player(url: url) else { return nil }
        return Adapter(player: p)
    }
}
