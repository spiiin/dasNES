options gen2
require ppu
var n = Nes()

[export]
def main(smoke : bool) : int {
    resize(n.pixels, 245760)
    // Coarse X wraps at 31, toggling horizontal nametable selection.
    verify(scroll_increment_x(31) == 1024)
    verify(scroll_increment_x(1055) == 0)
    verify(scroll_increment_x(30) == 31)
    // Fine Y overflow: coarse row 29 toggles the vertical nametable, row 31 does not.
    verify(scroll_increment_y(7 * 4096 + 29 * 32) == 2048)
    verify(scroll_increment_y(7 * 4096 + 31 * 32 + 2048) == 2048)
    verify(scroll_increment_y(6 * 4096 + 28 * 32) == 7 * 4096 + 28 * 32)
    n.line = 12; n.dot = 254; n.mask = 24; n.v = 4096 + 2 * 32 + 3; n.t = 2048 + 1024 + 17
    tick_ppu(n, 1)
    verify(n.dot == 257 && n.v == 8192 + 2 * 32 + 1024 + 17)
    n.line = 261; n.dot = 279; n.t = 5 * 4096 + 9 * 32 + 2048 + 7
    tick_ppu(n, 1)
    verify((n.v & 31712) == (n.t & 31712) && (n.v & 1055) == 1041)
    // Vertical reload is repeated through dot 304, including changes made mid-window.
    n.t = 4096 + 3 * 32
    tick_ppu(n, 1)
    verify((n.v & 31712) == (n.t & 31712))
    n.mask = 0; n.line = 261; n.dot = 279; n.v = 1234; n.t = 2345
    tick_ppu(n, 10); verify(n.v == 1234)
    // Reads/writes during rendering use both scroll increments; vblank uses CTRL's step.
    n.mask = 24; n.line = 100; n.v = 7 * 4096 + 29 * 32 + 31
    advance_ppu_address(n); verify(n.v == 3072)
    n.line = 241; n.ctrl = 4; n.v = 16368
    write(n, 8199, 12); verify(n.v == 16400 && ppu_read(n, 16128) == 12)

    // Reproduce SMB's split: CTRL still selects NT1, but PPUADDR restored v/t to NT0.
    // The only opaque background pixel under sprite zero is in NT0.
    n.vertical = true; n.line = 241; n.dot = 0; n.mask = 0
    write(n, 8192, 17)
    write(n, 8198, 0); write(n, 8198, 0)
    write(n, 8197, 0); write(n, 8197, 0)
    verify((n.ctrl & 1) == 1 && (n.t & 3072) == 0)
    n.nt[3 * 32 + 11] = 1
    n.chr[4096 + 16 + 1] = 128
    n.chr[32] = 128
    for (i in 0 .. 256) { n.oam[i] = 255 }
    n.oam[0] = 24; n.oam[1] = 2; n.oam[2] = 32; n.oam[3] = 88
    n.mask = 30; n.line = 261; n.dot = 0; n.status = 0
    while (n.line != 25) { tick_ppu(n, 1) }
    while (n.dot < 86) { tick_ppu(n, 1) }
    verify((n.status & 64) == 0 && n.sprite0_dot == 89)
    tick_ppu(n, 1)
    verify(n.dot >= 89 && (n.status & 64) != 0)
    // Reading status must not clear sprite-zero hit.
    read(n, 8194); verify((n.status & 64) != 0)
    // Non-overlap, disabled layers and the x=255 exclusion must not fake a hit.
    n.v = 4096 + 3 * 32 + 1024; render_line(n, 25); verify(n.sprite0_dot == -1)
    n.v = 4096 + 3 * 32; n.mask = 8; render_line(n, 25); verify(n.sprite0_dot == -1)
    n.mask = 30; n.oam[3] = 255; n.nt[3 * 32 + 31] = 1; n.chr[4096 + 17] = 1
    render_line(n, 25); verify(n.sprite0_dot == -1)
    n.oam[3] = 0; n.nt[3 * 32] = 1; n.chr[4096 + 17] = 128
    n.mask = 24; render_line(n, 25); verify(n.sprite0_dot == -1)
    n.mask = 30; render_line(n, 25); verify(n.sprite0_dot == 1)
    print("PASS: scroll wrapping, t/v transfers, PPUDATA and SMB-style sprite-zero split\n")
    return 0
}
