options gen2
module core
require daslib/fio
require daslib/defer

// NTSC NROM machine. CPU registers are int, explicitly masked to bus width.
struct Nes {
    ram : int[2048]
    prg : int[32768]
    chr : int[8192]
    sram : int[8192]
    nt : int[4096]
    pal : int[32]
    oam : int[256]
    pixels : array<uint8>
    a, x, y, pc : int
    sp : int = 253
    p : int = 36
    ctrl, mask, status, oa, v, t, fine_x, buffer, bus : int
    latch, vertical, four_screen, chr_ram, nmi, strobe : bool
    buttons, shift, scroll_x, scroll_y : int
    render_v, render_fine_x : int
    sprite0_dot : int = -1
    dot : int
    line : int = 261
    frame, stall : int
    cycles : int64
}

def nt_index(n : Nes; address : int) : int {
    let a = (address - 8192) & 4095
    let bank = a >> 10
    return n.four_screen ? a : (((n.vertical ? (bank & 1) : (bank >> 1)) << 10) | (a & 1023))
}
def pal_index(address : int) : int {
    var a = address & 31
    if ((a & 19) == 16) { a -= 16 }
    return a
}
def ppu_read(n : Nes; address : int) : int {
    let a = address & 16383
    if (a < 8192) { return n.chr[a] }
    if (a < 16128) { return n.nt[nt_index(n, a)] }
    return n.pal[pal_index(a)]
}
def ppu_write(var n : Nes; address, value : int) {
    let a = address & 16383
    if (a < 8192) { if (n.chr_ram) { n.chr[a] = value } }
    elif (a < 16128) { n.nt[nt_index(n, a)] = value }
    else { n.pal[pal_index(a)] = value & 63 }
}
def scroll_increment_x(v : int) : int {
    return (v & 31) == 31 ? ((v & ~31) ^ 1024) : v + 1
}
def scroll_increment_y(v : int) : int {
    if ((v & 28672) != 28672) { return v + 4096 }
    var result = v & ~28672
    var y = (result >> 5) & 31
    if (y == 29) { y = 0; result ^= 2048 }
    elif (y == 31) { y = 0 }
    else { y++ }
    return (result & ~992) | (y << 5)
}
def advance_ppu_address(var n : Nes) {
    if ((n.mask & 24) != 0 && (n.line < 240 || n.line == 261)) {
        n.v = scroll_increment_y(scroll_increment_x(n.v))
    } else {
        n.v = (n.v + ((n.ctrl & 4) != 0 ? 32 : 1)) & 32767
    }
}
def read(var n : Nes; address : int) : int {
    let a = address & 65535
    if (a < 8192) { return n.ram[a & 2047] }
    if (a < 16384) {
        let r = a & 7
        var result = n.bus
        if (r == 2) { result = (n.status & 224) | (n.bus & 31); n.status &= 127; n.latch = false }
        elif (r == 4) { result = n.oam[n.oa] }
        elif (r == 7) {
            let v = n.v & 16383
            result = n.buffer
            n.buffer = ppu_read(n, v)
            if (v >= 16128) { result = n.buffer; n.buffer = ppu_read(n, v - 4096) }
            advance_ppu_address(n)
        }
        n.bus = result
        return result
    }
    if (a == 16406) {
        let result = 64 | (n.strobe ? (n.buttons & 1) : (n.shift & 1))
        if (!n.strobe) { n.shift = (n.shift >> 1) | 128 }
        return result
    }
    if (a == 16407) { return 64 }
    if (a >= 32768) { return n.prg[a - 32768] }
    if (a >= 24576) { return n.sram[a - 24576] }
    return 0
}
def write(var n : Nes; address, value : int) {
    let a = address & 65535
    let b = value & 255
    if (a < 8192) { n.ram[a & 2047] = b }
    elif (a < 16384) {
        n.bus = b
        let r = a & 7
        if (r == 0) {
            if ((b & 128) != 0 && (n.ctrl & 128) == 0 && (n.status & 128) != 0) { n.nmi = true }
            n.ctrl = b; n.t = (n.t & 29695) | ((b & 3) << 10)
        }
        elif (r == 1) { n.mask = b }
        elif (r == 3) { n.oa = b }
        elif (r == 4) { n.oam[n.oa] = b; n.oa = (n.oa + 1) & 255 }
        elif (r == 5) {
            if (!n.latch) { n.scroll_x = b; n.fine_x = b & 7; n.t = (n.t & 32736) | (b >> 3) }
            else { n.scroll_y = b; n.t = (n.t & 3103) | ((b & 7) << 12) | ((b & 248) << 2) }
            n.latch = !n.latch
        }
        elif (r == 6) {
            if (!n.latch) { n.t = (n.t & 255) | ((b & 63) << 8) }
            else { n.t = (n.t & 32512) | b; n.v = n.t }
            n.latch = !n.latch
        }
        elif (r == 7) { ppu_write(n, n.v, b); advance_ppu_address(n) }
    }
    elif (a == 16404) {
        for (i in 0 .. 256) { n.oam[(n.oa + i) & 255] = read(n, (b << 8) | i) }
        n.stall += 513 + int(n.cycles & 1l)
    }
    elif (a == 16406) { n.strobe = (b & 1) != 0; n.shift = n.buttons }
    elif (a >= 24576 && a < 32768) { n.sram[a - 24576] = b }
}
def word(var n : Nes; a : int) : int { let lo = read(n, a); return lo | (read(n, a + 1) << 8) }
def fetch(var n : Nes) : int { let b = read(n, n.pc); n.pc = (n.pc + 1) & 65535; return b }
def fetch_word(var n : Nes) : int { let lo = fetch(n); return lo | (fetch(n) << 8) }
def push(var n : Nes; b : int) { write(n, 256 + n.sp, b); n.sp = (n.sp - 1) & 255 }
def pop(var n : Nes) : int { n.sp = (n.sp + 1) & 255; return read(n, 256 + n.sp) }
def flag(var n : Nes; mask : int; on : bool) { n.p = on ? (n.p | mask) : (n.p & ~mask) }
def nz(var n : Nes; b : int) : int { let v = b & 255; flag(n, 2, v == 0); flag(n, 128, (v & 128) != 0); return v }
def adc(var n : Nes; b : int) {
    let sum = n.a + b + (n.p & 1)
    flag(n, 64, ((~(n.a ^ b) & (n.a ^ sum)) & 128) != 0)
    flag(n, 1, sum > 255)
    n.a = nz(n, sum)
}
def compare(var n : Nes; a, b : int) { flag(n, 1, a >= b); nz(n, a - b) }
def interrupt(var n : Nes; vector : int; brk : bool) {
    push(n, n.pc >> 8); push(n, n.pc & 255); push(n, (n.p & 239) | 32 | (brk ? 16 : 0))
    n.p |= 4; n.pc = word(n, vector)
}
def reset(var n : Nes) { resize(n.pixels, 245760); n.a = 0; n.x = 0; n.y = 0; n.sp = 253; n.p = 36; n.pc = word(n, 65532); n.cycles = 7 }

def load_rom(var n : Nes; path : string) : bool {
    let f = fopen(path, "rb")
    if (f == null) { print("Cannot open ROM: {path}\n"); return false }
    defer() { if (f != null) { fclose(f) } }
    var h : uint8[16]
    if (fread(f, h) != 16 || h[0] != 78 || h[1] != 69 || h[2] != 83 || h[3] != 26) { print("Invalid iNES header\n"); return false }
    let flags6 = int(h[6]); let flags7 = int(h[7])
    let mapper = (flags6 >> 4) | (flags7 & 240)
    if ((flags7 & 12) == 8 || mapper != 0 || (flags7 & 3) != 0 || (h[4] != 1 && h[4] != 2) || int(h[5]) > 1 || (int(h[9]) & 1) != 0) {
        print("Supported ROMs: NTSC iNES 1.0 NROM, 16/32 KiB PRG, 0/8 KiB CHR\n"); return false
    }
    n.vertical = (flags6 & 1) != 0; n.four_screen = (flags6 & 8) != 0; n.chr_ram = h[5] == 0
    if ((flags6 & 4) != 0) {
        var trainer : uint8[512]
        if (fread(f, trainer) != 512) { print("Truncated trainer\n"); return false }
        for (i in 0 .. 512) { n.sram[4096 + i] = int(trainer[i]) }
    }
    var data : array<uint8>
    let size = int(h[4]) * 16384
    resize(data, size)
    if (fread(f, data) != size) { print("Truncated PRG ROM\n"); return false }
    for (i in 0 .. 32768) { n.prg[i] = int(data[i % size]) }
    if (!n.chr_ram) {
        resize(data, 8192)
        if (fread(f, data) != 8192) { print("Truncated CHR ROM\n"); return false }
        for (i in 0 .. 8192) { n.chr[i] = int(data[i]) }
    }
    reset(n)
    return true
}






