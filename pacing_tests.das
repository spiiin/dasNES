options gen2
require pacing

[export]
def main(smoke : bool) : int {
    // Simulate one minute of presentation at several monitor refresh rates.
    // The last tick samples the same wall time regardless of refresh rate.
    for (hz in fixed_array(50, 60, 75, 120, 144, 240)) {
        var clock = FrameClock()
        var frames = 0
        for (tick in 0 .. hz * 60 + 1) {
            frames += due_frames(clock, uint64(tick) * 1000000000ul / uint64(hz))
        }
        verify(frames == 3606)
    }
    var clock = FrameClock()
    verify(due_frames(clock, 0ul) == 1)
    verify(due_frames(clock, 1000000ul) == 0)
    verify(due_frames(clock, 100000000ul) == 4)
    verify(due_frames(clock, 100000000ul) == 2)
    verify(due_frames(clock, 100000000ul) == 0)
    verify(due_frames(clock, 5000000000ul) == 1)
    verify(due_frames(clock, 5000000000ul) == 0)
    print("PASS: NTSC clock at 50/60/75/120/144/240 Hz, bounded catch-up and pause recovery\n")
    return 0
}
