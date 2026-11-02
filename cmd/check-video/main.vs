// check-video plays a movie it writes itself, through video.Player and then
// through a web.Page, and looks at the frames that come out.
package main

import (
    "image/draw"
    "time"
    "video/host"
    "video/video"
    "web"
)

var failures = 0

func check(ok: bool, what: string) {
    if ok {
        print("ok    \(what)")
    } else {
        print("FAIL  \(what)")
        failures += 1
    }
}

func wait(seconds: float64, until done: () -> bool) -> bool {
    var left = seconds
    while left > 0 {
        if done() { return true }
        time.Sleep(time.Duration.Milliseconds(10))
        left -= 0.01
    }
    return done()
}

func main() -> int32 {
    let path = "/tmp/check-video.mp4"
    check(video.WriteTestMovie(path, width: 32, height: 16), "a movie is written")
    guard let p = video.Player(url: path) else {
        check(false, "a player opens")
        return 1
    }
    check(wait(5, until: { p.Status != .loading }) && p.Status == .ready, "it becomes ready")
    check(p.Duration > 1.5 && p.Duration < 2.5, "its duration (\(p.Duration))")
    check(wait(2, until: { p.Width > 0 }) && p.Width == 32 && p.Height == 16, "its size (\(p.Width)x\(p.Height))")
    check(p.Paused, "it starts paused")
    p.SetMuted(true)
    p.Play()
    check(!p.Paused, "Play plays")
    var first: draw.Image? = nil
    check(wait(1, until: {
        _ = p.Status
        first = p.Frame()
        return first != nil
    }), "a frame comes")
    if let f = first {
        check(f.Pixels[0] > 180 && f.Pixels[2] < 80, "the first second is red (\(f.Pixels[0]) \(f.Pixels[1]) \(f.Pixels[2]))")
    }
    var frames = 0
    var last: draw.Image? = nil
    check(wait(5, until: {
        _ = p.Status
        if let f = p.Frame() {
            frames += 1
            last = f
        }
        return p.Ended
    }), "it ends")
    check(frames >= 5, "frames keep coming (\(frames), at \(p.CurrentTime))")
    if let f = last {
        check(f.Pixels[2] > 180 && f.Pixels[0] < 80, "the last second is blue (\(f.Pixels[0]) \(f.Pixels[1]) \(f.Pixels[2]))")
    }
    p.Seek(to: 0)
    p.Close()

    let page = web.Page()
    page.SetViewportSize(draw.Size(100, 100))
    host.Install(page)
    page.LoadHTML("<style>body { margin: 0 } video { display: block }</style><video id=v autoplay muted src='\(path)'></video>")
    guard let v = page.QuerySelector("#v") else { return 1 }
    var events: [string] = []
    for type in ["loadedmetadata", "play", "ended"] {
        _ = page.Document?.AddEventListener(v, type, handler: { e in events.append(e.Type) })
    }
    var t: float64 = 0
    let ended = wait(8, until: {
        t += 0.01
        _ = page.Advance(time: t)
        return events.contains("ended")
    })
    check(ended && events.contains("loadedmetadata") && events.contains("play"), "through a page: \(events)")
    check(page.BoundsOf(v)?.Width == 32, "the page lays the video out at its picture's size")
    var pixels = [uint8](repeating: 0, count: 100 * 100 * 4)
    page.Draw(into: &pixels, width: 100, height: 100, scale: 1)
    let i = (8 * 100 + 16) * 4
    check(pixels[i + 2] > 180 && pixels[i] < 80, "the page paints the last frame, blue (\(pixels[i]) \(pixels[i + 1]) \(pixels[i + 2]))")

    if failures == 0 {
        print("ALL VIDEO CHECKS PASSED")
        return 0
    }
    print("\(failures) FAILED")
    return 1
}
