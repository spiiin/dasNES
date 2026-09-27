options gen2
module pacing

// NES time is independent of the display refresh rate. A 60 Hz display
// occasionally presents the latest of two 60.0988 Hz NES frames; a 144 Hz
// display repeats frames. Neither case changes CPU/APU speed.
let ntsc_frame_ns = 16639267ul
struct FrameClock {
    next_frame : uint64
}
def due_frames(var clock : FrameClock; now : uint64) : int {
    if (now < clock.next_frame) { return 0 }
    // Resume without replaying a whole debugger/window-drag pause.
    if (now - clock.next_frame > 250000000ul) { clock.next_frame = now }
    var count = int((now - clock.next_frame) / ntsc_frame_ns) + 1
    if (count > 4) { count = 4 }
    clock.next_frame += uint64(count) * ntsc_frame_ns
    return count
}
