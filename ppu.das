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

// Snapshot the live scroll address at the start of a scanline. The fetch
// pipeline is approximated; t/v transfers and sprite-zero timing are scheduled.
def render_line(var n : Nes; y : int) {
    n.render_v = n.v
    n.render_fine_x = n.fine_x
    n.sprite0_dot = -1
    var sprites : int[8]
    var count = 0
    let height = (n.ctrl & 32) != 0 ? 16 : 8
    for (s in 0 .. 64) {
        let sy = n.oam[s * 4] + 1
        if (y >= sy && y < sy + height) {
            if (count < 8) { sprites[count] = s; count++ }
            else { if ((n.mask & 24) != 0) { n.status |= 32 }; break }
        }
    }
    // Decode each selected sprite row once. Reverse OAM order preserves the
    // first opaque sprite even when it is behind the background.
    var foreground : int[256]
    if ((n.mask & 16) != 0) {
        for (i in 0 .. count) {
            let s = sprites[count - 1 - i]; let o = s * 4
            let attr = n.oam[o + 2]
            var py = y - n.oam[o] - 1
            if ((attr & 128) != 0) { py = height - 1 - py }
            var tile = n.oam[o + 1]
            var base = (n.ctrl & 8) != 0 ? 4096 : 0
            if (height == 16) { base = (tile & 1) * 4096; tile = (tile & 254) + py / 8 }
            let address = base + tile * 16 + (py & 7)
            let lo = chr_read(n, address); let hi = chr_read(n, address + 8)
            let flags = 16 + (attr & 3) * 4 + (attr & 32) + (s == 0 ? 64 : 0)
            for (px in 0 .. 8) {
                let x = n.oam[o + 3] + px
                if (x >= 256) { break }
                let shift = (attr & 64) != 0 ? px : 7 - px
                let fg = ((lo >> shift) & 1) | (((hi >> shift) & 1) << 1)
                if (fg != 0) { foreground[x] = flags | fg }
            }
        }
    }
    // Palette and pattern memory cannot change during this scanline renderer.
    var row_colors : uint[32]
    for (i in 0 .. 32) {
        var index = ppu_read(n, 16128 + i)
        if ((n.mask & 1) != 0) { index &= 48 }
        row_colors[i] = colors[index]
    }
    let bg_start = (n.mask & 8) == 0 ? 256 : ((n.mask & 2) != 0 ? 0 : 8)
    let fg_start = (n.mask & 16) == 0 ? 256 : ((n.mask & 4) != 0 ? 0 : 8)
    let wx_start = n.render_fine_x + (n.render_v & 31) * 8
    let ty = (n.render_v >> 5) & 31
    let fine_y = (n.render_v >> 12) & 7
    let pattern_base = (n.ctrl & 16) != 0 ? 4096 : 0
    var last_tile = -1
    var lo = 0; var hi = 0; var palette_base = 0
    var p = y * 1024
    for (x in 0 .. 256) {
        var bg = 0
        var palette = 0
        if (x >= bg_start) {
            let wx = x + wx_start
            if ((wx >> 3) != last_tile) {
                last_tile = wx >> 3
                let nx = ((n.render_v >> 10) & 1) ^ (wx >> 8)
                let ny = (n.render_v >> 11) & 1
                let tx = (wx & 255) >> 3
                let base = 8192 + (ny * 2 + nx) * 1024
                let tile = ppu_read(n, base + ty * 32 + tx)
                let address = pattern_base + tile * 16 + fine_y
                lo = chr_read(n, address); hi = chr_read(n, address + 8)
                let attr = ppu_read(n, base + 960 + (ty / 4) * 8 + tx / 4)
                palette_base = ((attr >> (((ty & 2) << 1) | (tx & 2))) & 3) * 4
            }
            let shift = 7 - (wx & 7)
            bg = ((lo >> shift) & 1) | (((hi >> shift) & 1) << 1)
            if (bg != 0) { palette = palette_base + bg }
        }
        if (x >= fg_start) {
            let fg = foreground[x]
            if (fg != 0) {
                if ((fg & 64) != 0 && bg != 0 && x < 255 && n.sprite0_dot < 0) { n.sprite0_dot = x + 1 }
                if (bg == 0 || (fg & 32) == 0) { palette = fg & 31 }
            }
        }
        let rgb = row_colors[palette]
        n.pixels[p] = uint8((rgb >> 16) & 255u)
        n.pixels[p + 1] = uint8((rgb >> 8) & 255u)
        n.pixels[p + 2] = uint8(rgb & 255u)
        n.pixels[p + 3] = uint8(255)
        p += 4
        if (n.zapper && abs(x - n.zapper_x) <= 4 && abs(y - n.zapper_y) <= 4 && int((rgb >> 16) & 255u) + int((rgb >> 8) & 255u) + int(rgb & 255u) > 500) { n.zapper_light_until = n.cycles + 2500l }
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
