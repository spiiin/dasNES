options gen2
require ppu
require math
// Frozen per-pixel renderer, retained as an independent optimization oracle.
def render_line_reference(var n : Nes; y : int) {
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
    for (x in 0 .. 256) {
        var bg = 0
        var palette = 0
        if ((n.mask & 8) != 0 && (x >= 8 || (n.mask & 2) != 0)) {
            let wx = x + n.render_fine_x + (n.render_v & 31) * 8
            let nx = ((n.render_v >> 10) & 1) ^ (wx / 256)
            let ny = (n.render_v >> 11) & 1
            let tx = (wx & 255) / 8; let ty = (n.render_v >> 5) & 31
            let base = 8192 + (ny * 2 + nx) * 1024
            let tile = ppu_read(n, base + ty * 32 + tx)
            bg = pattern(n, (n.ctrl & 16) != 0 ? 4096 : 0, tile, wx & 7, (n.render_v >> 12) & 7)
            let attr = ppu_read(n, base + 960 + (ty / 4) * 8 + tx / 4)
            palette = ((attr >> (((ty & 2) << 1) | (tx & 2))) & 3) * 4 + bg
            if (bg == 0) { palette = 0 }
        }
        if ((n.mask & 16) != 0 && (x >= 8 || (n.mask & 4) != 0)) {
            for (i in 0 .. count) {
                let s = sprites[i]; let o = s * 4
                var px = x - n.oam[o + 3]
                if (px < 0 || px >= 8) { continue }
                let attr = n.oam[o + 2]
                var py = y - n.oam[o] - 1
                if ((attr & 64) != 0) { px = 7 - px }
                if ((attr & 128) != 0) { py = height - 1 - py }
                var tile = n.oam[o + 1]
                var base = (n.ctrl & 8) != 0 ? 4096 : 0
                if (height == 16) { base = (tile & 1) * 4096; tile = (tile & 254) + py / 8 }
                let fg = pattern(n, base, tile, px, py & 7)
                if (fg == 0) { continue }
                if (s == 0 && bg != 0 && x < 255 && n.sprite0_dot < 0) { n.sprite0_dot = x + 1 }
                if (bg == 0 || (attr & 32) == 0) { palette = 16 + (attr & 3) * 4 + fg }
                break
            }
        }
        var index = ppu_read(n, 16128 + palette)
        if ((n.mask & 1) != 0) { index &= 48 }
        let rgb = colors[index]
        let p = (y * 256 + x) * 4
        n.pixels[p] = uint8((rgb >> 16) & 255u)
        n.pixels[p + 1] = uint8((rgb >> 8) & 255u)
        n.pixels[p + 2] = uint8(rgb & 255u)
        n.pixels[p + 3] = uint8(255)
        if (n.zapper && abs(x - n.zapper_x) <= 4 && abs(y - n.zapper_y) <= 4 && int((rgb >> 16) & 255u) + int((rgb >> 8) & 255u) + int(rgb & 255u) > 500) { n.zapper_light_until = n.cycles + 2500l }
    }
}
var rng = 123456789u
var n = Nes()
def random_byte() : int {
    rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
    return int(rng & 255u)
}

[export]
def main(smoke : bool) : int {
    resize(n.pixels, 245760)
    resize(n.chr_rom, 32768)
    for (i in 0 .. 8192) { n.chr[i] = random_byte() }
    for (i in 0 .. 32768) { n.chr_rom[i] = uint8(random_byte()) }
    for (i in 0 .. 4096) { n.nt[i] = random_byte() }
    var expected : uint8[1024]
    for (test in 0 .. 2048) {
        let y = random_byte() % 240
        n.mapper = test % 4 == 3 ? 4 : test % 4
        n.chr_ram = (test & 4) != 0
        n.vertical = (test & 8) != 0
        n.four_screen = (test & 16) != 0
        n.single_screen = test % 3 - 1
        for (i in 0 .. 8) { n.chr_slots[i] = random_byte() % (n.chr_ram ? 8 : 32) }
        n.ctrl = random_byte(); n.mask = test & 31
        n.v = (random_byte() | (random_byte() << 8)) & 32767
        n.fine_x = test & 7
        n.status = random_byte()
        n.zapper = (test & 1) != 0
        n.zapper_x = random_byte(); n.zapper_y = y
        n.cycles = int64(test) * 100l; n.zapper_light_until = 0l
        for (i in 0 .. 32) { n.pal[i] = random_byte() & 63 }
        for (s in 0 .. 64) {
            let o = s * 4
            n.oam[o] = s < 10 ? max(0, y - 1 - (random_byte() & 7)) : random_byte()
            n.oam[o + 1] = random_byte(); n.oam[o + 2] = random_byte()
            // Repeated X values exercise overlapping sprites and OAM priority.
            n.oam[o + 3] = s < 4 ? test & 255 : random_byte()
        }
        let status = n.status
        render_line_reference(n, y)
        let expected_status = n.status
        let expected_dot = n.sprite0_dot
        let expected_light = n.zapper_light_until
        for (i in 0 .. 1024) { expected[i] = n.pixels[y * 1024 + i] }
        n.status = status; n.zapper_light_until = 0l
        render_line(n, y)
        verify(n.status == expected_status && n.sprite0_dot == expected_dot && n.zapper_light_until == expected_light)
        for (i in 0 .. 1024) { verify(n.pixels[y * 1024 + i] == expected[i]) }
    }
    print("Renderer: 2048 reference comparisons passed (pixels, sprite zero, overflow, Zapper)\n")
    return 0
}
