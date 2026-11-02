// Package video plays video and audio files: a Player opens one, plays it
// with its sound, and hands over each new frame as pixels.
//
//     let p = video.Player(url: "clip.mp4")!
//     p.Play()
//     // Each frame of the program:
//     if p.Status == .ready, let f = p.Frame() { show(f) }
//
// macOS: AVFoundation. Elsewhere nothing opens yet.
package video

import "image/draw"

public enum Status: Equatable {
    case loading
    case ready
    case failed
}

public final class Player {
    let handle: int32
    var closed = false
    var pixels: [uint8] = []

    /// Starts loading a path or a URL; nil where this system has no player.
    public init?(url: string) {
        let h = url.withCString { playerOpen($0) }
        if h <= 0 { return nil }
        handle = h
    }

    deinit { Close() }

    public func Close() {
        if closed { return }
        closed = true
        playerClose(handle)
    }

    public var Status: Status {
        switch playerStatus(handle) {
        case 0: return .loading
        case 1: return .ready
        default: return .failed
        }
    }

    public func Play() { playerPlay(handle) }
    public func Pause() { playerPause(handle) }
    public func Seek(to seconds: float64) { playerSeek(handle, seconds) }
    public func SetVolume(volume: float32) { playerSetVolume(handle, volume) }
    public func SetMuted(muted: bool) { playerSetMuted(handle, muted ? 1 : 0) }
    public func SetLoop(loop: bool) { playerSetLoop(handle, loop ? 1 : 0) }

    public var Paused: bool { return playerPaused(handle) != 0 }
    public var Ended: bool { return playerEnded(handle) != 0 }
    public var Duration: float64 { return playerDuration(handle) }
    public var CurrentTime: float64 { return playerTime(handle) }
    public var Width: int32 { return playerWidth(handle) }
    public var Height: int32 { return playerHeight(handle) }

    /// The newest picture, when there's one not yet handed over.
    public func Frame() -> draw.Image? {
        let w = Width
        let h = Height
        if w <= 0 || h <= 0 { return nil }
        let need = int(w) * int(h) * 4
        if pixels.count != need { pixels = [uint8](repeating: 0, count: need) }
        let got = pixels.withUnsafeMutableBufferPointer { p in playerFrame(handle, p.baseAddress, int32(need)) }
        if got == 0 { return nil }
        return draw.Image(width: w, height: h, pixels: pixels)
    }
}

/// Writes a two-second movie for checks: a second of red, a second of blue.
public func WriteTestMovie(path: string, width: int32, height: int32) -> bool {
    return path.withCString { writeTestMovie($0, width, height) } != 0
}
