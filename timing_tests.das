options gen2
require ppu

var fast = Nes()
var reference = Nes()

// Per-dot reference scheduler for event batching (including scroll transfers).
def tick_reference(var n : Nes; cpu_cycles : int) {
    for (_ in 0 .. cpu_cycles * 3) {
        n.dot++
        if (n.line == 241 && n.dot == 1) { n.status |= 128; if ((n.ctrl & 128) != 0) { n.nmi = true } }
        if (n.line == 261 && n.dot == 1) { n.status &= 31; n.sprite0_dot = -1 }
        if (n.line < 240 && n.dot == 1) { render_line(n, n.line) }
        if (n.line < 240 && n.dot == n.sprite0_dot && (n.mask & 24) == 24) { n.status |= 64 }
        if ((n.mask & 24) != 0 && (n.line < 240 || n.line == 261)) {
            if (n.dot == 256) { n.v = scroll_increment_y(n.v) }
            if (n.dot == 257) { n.v = (n.v & ~1055) | (n.t & 1055) }
            if (n.line == 261 && n.dot >= 280 && n.dot <= 304) { n.v = (n.v & ~31712) | (n.t & 31712) }
        }
        let skip = n.line == 261 && n.dot == 340 && (n.frame & 1) != 0 && (n.mask & 24) != 0
        if (n.dot >= 341 || skip) {
            n.dot = 0; n.line++
            if (n.line == 262) { n.line = 0; n.frame++ }
        }
    }
}

def check_case(line, dot, frame, mask, ctrl, count : int) {
    fast.line = line; reference.line = line
    fast.dot = dot; reference.dot = dot
    fast.frame = frame; reference.frame = frame
    fast.mask = mask; reference.mask = mask
    fast.ctrl = ctrl; reference.ctrl = ctrl
    fast.status = 224; reference.status = 224
    fast.nmi = false; reference.nmi = false
    fast.v = 12345; reference.v = 12345
    fast.t = 23456; reference.t = 23456
    fast.sprite0_dot = -1; reference.sprite0_dot = -1
    tick_ppu(fast, count)
    tick_reference(reference, count)
    verify(fast.line == reference.line && fast.dot == reference.dot && fast.frame == reference.frame)
    verify(fast.status == reference.status && fast.nmi == reference.nmi)
    verify(fast.v == reference.v && fast.t == reference.t && fast.sprite0_dot == reference.sprite0_dot)
}

[export]
def main(smoke : bool) : int {
    resize(fast.pixels, 245760); resize(reference.pixels, 245760)
    for (line in fixed_array(0, 239, 240, 241, 260, 261)) {
        for (dot in fixed_array(0, 1, 88, 254, 255, 256, 257, 279, 280, 303, 304, 339, 340)) {
            for (frame in 0 .. 2) {
                for (mask in fixed_array(0, 8, 16, 24)) {
                    for (count in fixed_array(0, 1, 2, 114, 513, 514)) {
                        check_case(line, dot, frame, mask, 128, count)
                    }
                }
            }
        }
    }
    // Multiple complete frames in one call, both NMI enabled and disabled.
    check_case(0, 0, 0, 24, 0, 60000)
    check_case(261, 339, 1, 24, 128, 60000)
    for (i in 0 .. 245760) { verify(fast.pixels[i] == reference.pixels[i]) }
    print("PASS: 3746 PPU timing cases match per-dot reference, including scroll transfers\n")
    return 0
}
