// The player on macOS: AVPlayer, with a video output that hands frames over
// as BGRA for the program to take. See player.cpp.
module;
#include <stdint.h>
#include <string.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
module video.video;

namespace {

struct Player {
    AVPlayer* player = nil;
    AVPlayerItem* item = nil;
    AVPlayerItemVideoOutput* output = nil;
    bool attached = false;
    bool loop = false;
    bool ended = false;
    bool wantsPlay = false;
};

constexpr int32_t maxPlayers = 64;
Player* players[maxPlayers + 1] = {};

Player* lookup(int32_t h) {
    if (h <= 0 || h > maxPlayers) return nullptr;
    return players[h];
}

// Whether the item has reached its end.
bool atEnd(Player* p) {
    CMTime d = p->item.duration;
    if (!CMTIME_IS_NUMERIC(d)) return false;
    return CMTimeCompare(p->item.currentTime, d) >= 0;
}

}  // namespace

int32_t playerOpen(const char* url) noexcept {
    if (url == nullptr) return 0;
    int32_t h = 1;
    while (h <= maxPlayers && players[h] != nullptr) h++;
    if (h > maxPlayers) return 0;
    @autoreleasepool {
        NSString* text = [NSString stringWithUTF8String:url];
        if (text == nil) return 0;
        NSURL* u = [text containsString:@"://"] ? [NSURL URLWithString:text] : [NSURL fileURLWithPath:text];
        if (u == nil) return 0;
        Player* p = new Player();
        p->item = [AVPlayerItem playerItemWithURL:u];
        p->player = [AVPlayer playerWithPlayerItem:p->item];
        p->player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
        NSDictionary* attributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        p->output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:attributes];
        [p->item addOutput:p->output];
        players[h] = p;
    }
    return h;
}

void playerClose(int32_t h) noexcept {
    Player* p = lookup(h);
    if (p == nullptr) return;
    @autoreleasepool {
        [p->player pause];
        [p->item removeOutput:p->output];
    }
    players[h] = nullptr;
    delete p;
}

int32_t playerStatus(int32_t h) noexcept {
    Player* p = lookup(h);
    if (p == nullptr) return 2;
    // A program with no run loop of its own lets the system's callbacks in.
    if (![NSThread isMainThread] || CFRunLoopGetCurrent() != nullptr) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
    }
    switch (p->item.status) {
    case AVPlayerItemStatusReadyToPlay: return 1;
    case AVPlayerItemStatusFailed: return 2;
    default: return 0;
    }
}

void playerPlay(int32_t h) noexcept {
    if (Player* p = lookup(h)) {
        p->ended = false;
        [p->player play];
    }
}

void playerPause(int32_t h) noexcept {
    if (Player* p = lookup(h)) [p->player pause];
}

void playerSeek(int32_t h, double seconds) noexcept {
    if (Player* p = lookup(h)) {
        p->ended = false;
        [p->player seekToTime:CMTimeMakeWithSeconds(seconds, 600) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
}

void playerSetVolume(int32_t h, float volume) noexcept {
    if (Player* p = lookup(h)) p->player.volume = volume;
}

void playerSetMuted(int32_t h, int32_t muted) noexcept {
    if (Player* p = lookup(h)) p->player.muted = muted != 0;
}

void playerSetLoop(int32_t h, int32_t loop) noexcept {
    if (Player* p = lookup(h)) p->loop = loop != 0;
}

int32_t playerPaused(int32_t h) noexcept {
    Player* p = lookup(h);
    if (p == nullptr) return 1;
    return p->player.rate == 0 ? 1 : 0;
}

int32_t playerEnded(int32_t h) noexcept {
    Player* p = lookup(h);
    if (p == nullptr) return 0;
    if (atEnd(p) && p->player.rate == 0 && !p->ended) {
        if (p->loop) {
            [p->player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            [p->player play];
            return 0;
        }
        p->ended = true;
    }
    return p->ended ? 1 : 0;
}

double playerDuration(int32_t h) noexcept {
    Player* p = lookup(h);
    if (p == nullptr) return 0;
    CMTime d = p->item.duration;
    return CMTIME_IS_NUMERIC(d) ? CMTimeGetSeconds(d) : 0;
}

double playerTime(int32_t h) noexcept {
    Player* p = lookup(h);
    if (p == nullptr) return 0;
    CMTime t = p->item.currentTime;
    return CMTIME_IS_NUMERIC(t) ? CMTimeGetSeconds(t) : 0;
}

int32_t playerWidth(int32_t h) noexcept {
    Player* p = lookup(h);
    return p == nullptr ? 0 : (int32_t)p->item.presentationSize.width;
}

int32_t playerHeight(int32_t h) noexcept {
    Player* p = lookup(h);
    return p == nullptr ? 0 : (int32_t)p->item.presentationSize.height;
}

int32_t playerFrame(int32_t h, uint8_t* pixels, int32_t cap) noexcept {
    Player* p = lookup(h);
    if (p == nullptr || pixels == nullptr) return 0;
    @autoreleasepool {
        CMTime now = p->item.currentTime;
        if (![p->output hasNewPixelBufferForItemTime:now]) return 0;
        CVPixelBufferRef buffer = [p->output copyPixelBufferForItemTime:now itemTimeForDisplay:nullptr];
        if (buffer == nullptr) return 0;
        CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        const int32_t w = (int32_t)CVPixelBufferGetWidth(buffer);
        const int32_t h2 = (int32_t)CVPixelBufferGetHeight(buffer);
        const size_t stride = CVPixelBufferGetBytesPerRow(buffer);
        const uint8_t* base = (const uint8_t*)CVPixelBufferGetBaseAddress(buffer);
        int32_t copied = 0;
        if (base != nullptr && (int64_t)w * h2 * 4 <= (int64_t)cap) {
            for (int32_t y = 0; y < h2; y++) {
                const uint8_t* src = base + (size_t)y * stride;
                uint8_t* dst = pixels + (size_t)y * (size_t)w * 4;
                for (int32_t x = 0; x < w; x++) {
                    dst[0] = src[2];
                    dst[1] = src[1];
                    dst[2] = src[0];
                    dst[3] = src[3];
                    src += 4;
                    dst += 4;
                }
            }
            copied = 1;
        }
        CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
        CVPixelBufferRelease(buffer);
        return copied;
    }
}

int32_t writeTestMovie(const char* path, int32_t width, int32_t height) noexcept {
    @autoreleasepool {
        NSURL* url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        NSError* error = nil;
        AVAssetWriter* writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        if (writer == nil) return 0;
        NSDictionary* settings = @{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @(width), AVVideoHeightKey: @(height)};
        AVAssetWriterInput* input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
        NSDictionary* attributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                     (id)kCVPixelBufferWidthKey: @(width), (id)kCVPixelBufferHeightKey: @(height)};
        AVAssetWriterInputPixelBufferAdaptor* adaptor =
            [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input sourcePixelBufferAttributes:attributes];
        [writer addInput:input];
        if (![writer startWriting]) return 0;
        [writer startSessionAtSourceTime:kCMTimeZero];
        constexpr int32_t fps = 10, frames = 20;
        for (int32_t i = 0; i < frames; i++) {
            while (!input.readyForMoreMediaData) [NSThread sleepForTimeInterval:0.005];
            CVPixelBufferRef buffer = nullptr;
            CVPixelBufferPoolCreatePixelBuffer(nullptr, adaptor.pixelBufferPool, &buffer);
            if (buffer == nullptr) return 0;
            CVPixelBufferLockBaseAddress(buffer, 0);
            uint8_t* base = (uint8_t*)CVPixelBufferGetBaseAddress(buffer);
            const size_t stride = CVPixelBufferGetBytesPerRow(buffer);
            bool first = i < fps;
            for (int32_t y = 0; y < height; y++) {
                uint8_t* p = base + (size_t)y * stride;
                for (int32_t x = 0; x < width; x++) {
                    p[0] = first ? 0 : 255;
                    p[1] = 0;
                    p[2] = first ? 255 : 0;
                    p[3] = 255;
                    p += 4;
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, 0);
            [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(i, fps)];
            CVPixelBufferRelease(buffer);
        }
        [input markAsFinished];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        return writer.status == AVAssetWriterStatusCompleted ? 1 : 0;
    }
}
