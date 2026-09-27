options gen2
require ppu
require daslib/fio

var n = Nes()

[export]
def main(smoke : bool) : int {
    resize(n.pixels, 245760)

    n.pc = 0x8000
    n.prg[0] = 0xa9; n.prg[1] = 0x7f // LDA #$7f
    n.prg[2] = 0x69; n.prg[3] = 1 // ADC #1
    verify(cpu_step(n) == 2 && n.a == 127)
    verify(cpu_step(n) == 2 && n.a == 128 && (n.p & 192) == 192)
    // Zero-page indexed wrapping and indirect JMP's NMOS page bug.
    n.pc = 32768; n.x = 1; n.prg[0] = 181; n.prg[1] = 255; n.ram[0] = 66
    verify(cpu_step(n) == 4 && n.a == 66)
    n.pc = 32768; n.prg[0] = 108; n.prg[1] = 255; n.prg[2] = 2
    n.ram[767] = 52; n.ram[512] = 18; n.ram[768] = 99
    verify(cpu_step(n) == 5 && n.pc == 4660)
    // BRK pushes PC+2 and a status with B set; RTI clears the pseudo B flag.
    n.pc = 32768; n.sp = 253; n.prg[0] = 0
    n.prg[32766] = 0; n.prg[32767] = 144; n.prg[4096] = 64
    verify(cpu_step(n) == 7 && n.pc == 36864 && n.sp == 250)
    verify(n.ram[509] == 128 && n.ram[508] == 2 && (n.ram[507] & 48) == 48)
    verify(cpu_step(n) == 6 && n.pc == 32770 && n.sp == 253 && (n.p & 16) == 0)
    // CPU RAM mirrors and serial joypad; post-eight reads return one.
    write(n, 2, 171); verify(read(n, 6146) == 171)
    n.buttons = 165; write(n, 16406, 1); verify((read(n, 16406) & 1) == 1)
    write(n, 16406, 0)
    for (i in 0 .. 8) { verify((read(n, 16406) & 1) == ((165 >> i) & 1)) }
    verify((read(n, 16406) & 1) == 1)
    // Nametable and palette mirroring, CHR write protection.
    n.vertical = true; ppu_write(n, 8192, 17); verify(ppu_read(n, 10240) == 17)
    n.vertical = false; verify(ppu_read(n, 9216) == 17)
    ppu_write(n, 16144, 33); verify(ppu_read(n, 16128) == 33)
    n.chr_ram = false; n.chr[0] = 7; ppu_write(n, 0, 9); verify(n.chr[0] == 7)
    n.chr_ram = true; ppu_write(n, 0, 9); verify(n.chr[0] == 9)
    // $2007 buffering, address increments, status resets the write latch.
    n.v = 8192; n.buffer = 85; n.ctrl = 0
    verify(read(n, 8199) == 85 && n.v == 8193)
    verify(read(n, 8199) == 17)
    n.v = 16128; verify(read(n, 8199) == 33)
    n.status = 224; n.latch = true; verify((read(n, 8194) & 224) == 224)
    verify(n.status == 96 && !n.latch)
    n.ctrl = 4; n.v = 8192; write(n, 8199, 31); verify(n.v == 8224)
    // DMA wraps OAM address, stalls CPU, and advances PPU while stalled.
    n.oa = 255; n.ram[256] = 91; n.ram[257] = 92; n.cycles = 0
    write(n, 16404, 1); verify(n.oam[255] == 91 && n.oam[0] == 92)
    verify(cpu_step(n) == 513)
    n.ctrl = 128; n.line = 241; n.dot = 0; n.nmi = false
    tick_ppu(n, 1); verify((n.status & 128) != 0 && n.nmi)
    n.prg[32762] = 0; n.prg[32763] = 144
    verify(cpu_step(n) == 7 && n.pc == 36864 && !n.nmi)
    n.line = 261; n.dot = 0; tick_ppu(n, 1); verify((n.status & 224) == 0)
    // Known background pixel, left-edge clipping, sprite priority and hit.
    for (i in 0 .. 4096) { n.nt[i] = 0 }
    for (i in 0 .. 8192) { n.chr[i] = 0 }
    for (i in 0 .. 256) { n.oam[i] = 255 }
    n.chr[1] = 128; n.mask = 30; n.ctrl = 0; n.scroll_x = 0; n.scroll_y = 0
    n.pal[0] = 15; n.pal[1] = 33; n.pal[17] = 22
    n.v = 4096; n.fine_x = 0
    render_line(n, 1)
    verify(n.pixels[1024] == 100 && n.pixels[1025] == 176 && n.pixels[1026] == 255)
    n.oam[0] = 0; n.oam[1] = 1; n.oam[2] = 32; n.oam[3] = 0; n.chr[16] = 128
    render_line(n, 1); verify(n.sprite0_dot == 1 && n.pixels[1024] == 100)
    n.oam[2] = 0; render_line(n, 1); verify(n.pixels[1024] == 181)
    n.mask = 24; render_line(n, 1); verify(n.pixels[1024] == 0)
    print("PASS: CPU, bus, joypad, mirroring, PPU registers, DMA, NMI, background and sprites\n")
    return 0
}



