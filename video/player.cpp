// Playback for package video/video: one player per handle, polled by the
// program. macOS's is an AVPlayer (player_darwin.mm), which decodes, keeps
// sound and picture together and plays the sound itself; elsewhere there is
// none yet.
module;
#include <stdint.h>
#if defined(__APPLE__)
#pragma vertex framework("AVFoundation")
#pragma vertex framework("CoreMedia")
#pragma vertex framework("CoreVideo")
#pragma vertex framework("Foundation")
#endif
export module video.video;

// playerOpen starts loading a URL, or a path. Answers a handle (> 0), or 0.
export int32_t playerOpen(const char* url) noexcept;
export void playerClose(int32_t handle) noexcept;
// playerStatus: 0 loading, 1 ready, 2 failed. It also lets the system's
// callbacks run, in a program with no run loop of its own.
export int32_t playerStatus(int32_t handle) noexcept;
export void playerPlay(int32_t handle) noexcept;
export void playerPause(int32_t handle) noexcept;
export void playerSeek(int32_t handle, double seconds) noexcept;
export void playerSetVolume(int32_t handle, float volume) noexcept;
export void playerSetMuted(int32_t handle, int32_t muted) noexcept;
export void playerSetLoop(int32_t handle, int32_t loop) noexcept;
export int32_t playerPaused(int32_t handle) noexcept;
export int32_t playerEnded(int32_t handle) noexcept;
export double playerDuration(int32_t handle) noexcept;
export double playerTime(int32_t handle) noexcept;
export int32_t playerWidth(int32_t handle) noexcept;
export int32_t playerHeight(int32_t handle) noexcept;
// playerFrame copies the newest picture, if there is one not yet taken, as
// RGBA into pixels (width * height * 4, cap bytes). Answers whether it did.
export int32_t playerFrame(int32_t handle, uint8_t* pixels, int32_t cap) noexcept;
// writeTestMovie writes a short H.264 movie for the checks, each second a
// solid color: red, then blue. Answers whether it did.
export int32_t writeTestMovie(const char* path, int32_t width, int32_t height) noexcept;

#if !defined(__APPLE__)
int32_t playerOpen(const char*) noexcept { return 0; }
void playerClose(int32_t) noexcept {}
int32_t playerStatus(int32_t) noexcept { return 2; }
void playerPlay(int32_t) noexcept {}
void playerPause(int32_t) noexcept {}
void playerSeek(int32_t, double) noexcept {}
void playerSetVolume(int32_t, float) noexcept {}
void playerSetMuted(int32_t, int32_t) noexcept {}
void playerSetLoop(int32_t, int32_t) noexcept {}
int32_t playerPaused(int32_t) noexcept { return 1; }
int32_t playerEnded(int32_t) noexcept { return 0; }
double playerDuration(int32_t) noexcept { return 0; }
double playerTime(int32_t) noexcept { return 0; }
int32_t playerWidth(int32_t) noexcept { return 0; }
int32_t playerHeight(int32_t) noexcept { return 0; }
int32_t playerFrame(int32_t, uint8_t*, int32_t) noexcept { return 0; }
int32_t writeTestMovie(const char*, int32_t, int32_t) noexcept { return 0; }
#endif
