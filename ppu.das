options gen2
module ppu
require cpu public
require math

// Common 2C02 RGB approximation; emphasis bits are not yet simulated.
let colors = fixed_array(
    0x666666u, 0x002a88u, 0x1412a7u, 0x3b00a4u, 0x5c007eu, 0x6e0040u, 0x6c0600u, 0x561d00u,
    0x333500u, 0x0b4800u, 0x005200u, 0x004f08u, 0x00404du, 0x000000u, 0x000000u, 0x000000u,
    0xadadadu, 0x155fd9u, 0x4240ffu, 0x7527feu, 0xa01accu, 0xb71e7bu, 0xb53120u, 0x994e00u,
    0x6b6d00u, 0x388700u, 0x0c9300u, 0x008f32u, 0x007c8du, 0x000000u, 0x000000u, 0x000000u,
    0xfffeffu, 0x64b0ffu, 0x9290ffu, 0xc676ffu, 0xf36affu, 0xfe6eccu, 0xfe8170u, 0xea9e22u,
    0xbcbe00u, 0x88d800u, 0x5ce430u, 0x45e082u, 0x48cdcdu, 0x4f4f4fu, 0x000000u, 0x000000u,
    0xfffeffu, 0xc0dfffu, 0xd3d2ffu, 0xe8c8ffu, 0xfbc2ffu, 0xfec4eau, 0xfeccc5u, 0xf7d8a5u,
    0xe4e594u, 0xcfef96u, 0xbdf4abu, 0xb3f3ccu, 0xb5ebf2u, 0xb8b8b8u, 0x000000u, 0x000000u)

def pattern(n : Nes; base, tile, x, y : int) : int {
    let a = base + tile * 16 + y
    return ((chr_read(n, a) >> (7 - x)) & 1) | (((chr_read(n, a + 8) >> (7 - x)) & 1) << 1)
}

// Snapshot scroll state and draw whole tile rows before sprite composition.
[unsafe_deref]
def render_line(var n : Nes; y : int) {
    verify(y >= 0 && y < 240 && length(n.pixels) >= 245760)
    var row = unsafe(addr(n.pixels[y * 1024]))
    verify((intptr(row) & 3ul) == 0ul)
    var pixels = unsafe(reinterpret<uint?>(row))
    var endian = 1u
    var little_endian = false
    unsafe { little_endian = *reinterpret<uint8?>(addr(endian)) == uint8(1) }
    n.render_v = n.v; n.render_fine_x = n.fine_x; n.sprite0_dot = -1
    var row_colors : uint[32]
    for (i in 0 .. 32) {
        var index = ppu_read(n, 16128 + i)
        if ((n.mask & 1) != 0) { index &= 48 }
        let rgb = colors[index]
        row_colors[i] = little_endian ? (0xff000000u | ((rgb & 255u) << 16) | (rgb & 65280u) | (rgb >> 16)) : ((rgb << 8) | 255u)
    }
    var packed_colors = unsafe(addr(row_colors[0]))
    // One opacity byte per tile row, including the clipped rightmost tile.
    var background : int[33]
    var bg = unsafe(addr(background[0]))
    let bg_start = (n.mask & 8) == 0 ? 256 : ((n.mask & 2) != 0 ? 0 : 8)
    for (x in 0 .. bg_start) { unsafe { pixels[x] = packed_colors[0] } }
    let wx_start = n.render_fine_x + (n.render_v & 31) * 8
    let ty = (n.render_v >> 5) & 31
    let fine_y = (n.render_v >> 12) & 7
    let pattern_base = (n.ctrl & 16) != 0 ? 4096 : 0
    var x = bg_start
    while (x < 256) {
        let wx = x + wx_start
        let nx = ((n.render_v >> 10) & 1) ^ (wx >> 8)
        let ny = (n.render_v >> 11) & 1
        let tx = (wx & 255) >> 3
        let base = 8192 + (ny * 2 + nx) * 1024
        let tile = ppu_read(n, base + ty * 32 + tx)
        let address = pattern_base + tile * 16 + fine_y
        var lo = chr_read(n, address)
        var hi = chr_read(n, address + 8)
        unsafe { bg[(x + n.render_fine_x) >> 3] = lo | hi }
        lo <<= wx & 7; hi <<= wx & 7
        let attr = ppu_read(n, base + 960 + (ty / 4) * 8 + tx / 4)
        let palette_base = ((attr >> (((ty & 2) << 1) | (tx & 2))) & 3) * 4
        let end_x = min(256, x + 8 - (wx & 7))
        while (x < end_x) {
            let color = ((lo >> 7) & 1) | ((hi >> 6) & 2)
            unsafe { pixels[x] = packed_colors[color == 0 ? 0 : palette_base + color] }
            lo <<= 1; hi <<= 1; x++
        }
    }
    // Only visit each sprite's eight pixels, in OAM order. A hidden sprite
    // still claims its pixels: lower-priority sprites cannot show through it.
    var occupied : int[256]
    var claimed = unsafe(addr(occupied[0]))
    let height = (n.ctrl & 32) != 0 ? 16 : 8
    let fg_start = (n.mask & 4) != 0 ? 0 : 8
    var count = 0
    for (s in 0 .. 64) {
        let o = s * 4
        let sy = n.oam[o] + 1
        if (y < sy || y >= sy + height) { continue }
        if (count == 8) { if ((n.mask & 24) != 0) { n.status |= 32 }; break }
        count++
        if ((n.mask & 16) == 0) { continue }
        let attr = n.oam[o + 2]
        var py = y - sy
        if ((attr & 128) != 0) { py = height - 1 - py }
        var tile = n.oam[o + 1]
        var base = (n.ctrl & 8) != 0 ? 4096 : 0
        if (height == 16) { base = (tile & 1) * 4096; tile = (tile & 254) + py / 8 }
        let address = base + tile * 16 + (py & 7)
        let lo = chr_read(n, address); let hi = chr_read(n, address + 8)
        let palette_base = 16 + (attr & 3) * 4
        for (px in 0 .. 8) {
            let sx = n.oam[o + 3] + px
            if (sx >= 256) { break }
            if (sx < fg_start) { continue }
            let shift = (attr & 64) != 0 ? px : 7 - px
            let color = ((lo >> shift) & 1) | (((hi >> shift) & 1) << 1)
            if (color == 0) { continue }
            unsafe {
                if (claimed[sx] != 0) { continue }
                claimed[sx] = 1
                let bx = sx + n.render_fine_x
                let opaque = sx >= bg_start && ((bg[bx >> 3] >> (7 - (bx & 7))) & 1) != 0
                if (s == 0 && opaque && sx < 255 && n.sprite0_dot < 0) { n.sprite0_dot = sx + 1 }
                if (!opaque || (attr & 32) == 0) { pixels[sx] = packed_colors[palette_base + color] }
            }
        }
    }
    if (n.zapper && abs(y - n.zapper_y) <= 4) {
        for (sx in max(0, n.zapper_x - 4) .. min(256, n.zapper_x + 5)) {
            let p = sx * 4
            var brightness = 0
            unsafe { brightness = int(row[p]) + int(row[p + 1]) + int(row[p + 2]) }
            if (brightness > 500) { n.zapper_light_until = n.cycles + 2500l; break }
        }
    }
}

def tick_ppu(var n : Nes; cpu_cycles : int) {
    var remaining = cpu_cycles * 3
    while (remaining > 0) {
        // Skip spans with no observable event in this scanline-based PPU.
        let odd_short = n.line == 261 && (n.frame & 1) != 0 && (n.mask & 24) != 0
        var next_dot = odd_short && n.dot < 340 ? 340 : 341
        if ((n.line < 240 || n.line == 241 || n.line == 261) && n.dot < 1) { next_dot = 1 }
        elif (n.line < 240 || n.line == 261) {
            if (n.dot < 256) { next_dot = 256 }
            elif (n.dot < 257) { next_dot = 257 }
            elif (n.line == 261 && n.dot < 280) { next_dot = 280 }
            elif (n.line == 261 && n.dot < 304) { next_dot = n.dot + 1 }
        }
        // Approximate filtered A12 using the sprite/background fetch phases.
        let irq_dot = (n.ctrl & 16) != 0 ? 324 : 260
        if (n.mapper == 4 && (n.line < 240 || n.line == 261) && (n.mask & 24) != 0 && n.dot < irq_dot && next_dot > irq_dot) { next_dot = irq_dot }
        if (n.line < 240 && n.sprite0_dot > n.dot && n.sprite0_dot < next_dot) { next_dot = n.sprite0_dot }
        let distance = next_dot - n.dot
        if (remaining < distance) { n.dot += remaining; return }
        n.dot = next_dot
        remaining -= distance
        if (n.line == 241 && n.dot == 1) { n.status |= 128; if ((n.ctrl & 128) != 0) { n.nmi = true } }
        if (n.line == 261 && n.dot == 1) { n.status &= 31; n.sprite0_dot = -1 }
        if (n.line < 240 && n.dot == 1) { render_line(n, n.line) }
        if (n.line < 240 && n.dot == n.sprite0_dot && (n.mask & 24) == 24) { n.status |= 64 }
        if ((n.mask & 24) != 0 && (n.line < 240 || n.line == 261)) {
            if (n.dot == 256) { n.v = scroll_increment_y(n.v) }
            if (n.dot == 257) { n.v = (n.v & ~1055) | (n.t & 1055) }
            if (n.line == 261 && n.dot >= 280 && n.dot <= 304) { n.v = (n.v & ~31712) | (n.t & 31712) }
        }
        if (n.mapper == 4 && (n.line < 240 || n.line == 261) && (n.mask & 24) != 0 && n.dot == irq_dot && ((n.ctrl & 24) != 0 || (n.ctrl & 32) != 0)) { mapper_irq_clock(n) }
        let skip = odd_short && n.dot == 340
        if (n.dot >= 341 || skip) {
            n.dot = 0; n.line++
            if (n.line == 262) { n.line = 0; n.frame++ }
        }
    }
}
def run_frame(var n : Nes) {
    clear(n.apu.pcm)
    let target = n.frame + 1
    while (n.frame < target) { let c = cpu_step(n); tick_apu(n, c); tick_ppu(n, c) }
}
