options gen2
require ppu
require daslib/fio
require math
var n = Nes()

[export]
def main(smoke : bool) : int {
    if (!load_rom(n, get_env_variable("DASNES_ROM"))) { return 1 }
    let prefix = get_env_variable("DASNES_REPLAY_OUT")
    let profile = get_env_variable("DASNES_REPLAY_PROFILE")
    var inputs : array<uint8>
    let input_path = get_env_variable("DASNES_REPLAY_INPUT")
    if (input_path != "") {
        resize(inputs, 3600)
        let f = fopen(input_path, "rb")
        verify(f != null)
        let count = fread(f, inputs); fclose(f); verify(count == 3600)
    }
    var audio : array<uint8>
    var peak, changes : int
    var previous = 0u
    for (frame in 0 .. 3600) {
        n.buttons = 0
        if (frame == 180 || frame == 181) { n.buttons = 8 }
        if ((profile == "darkwing" || profile == "megaman" || profile == "tmnt") && (frame == 600 || frame == 601 || frame == 900 || frame == 901)) { n.buttons = 8 }
        if (frame > 1000) { n.buttons = 128 | ((frame % 90) < 40 ? 1 : 0) | ((frame % 12) < 6 ? 2 : 0) }
        if (length(inputs) > 0) { n.buttons = int(inputs[frame]) }
        n.zapper_x = 128; n.zapper_y = 100; n.zapper_trigger = frame > 900 && frame % 120 < 5
        run_frame(n)
        for (i in 0 .. length(n.apu.pcm) / 2) {
            let raw = int(n.apu.pcm[i * 2]) | (int(n.apu.pcm[i * 2 + 1]) << 8)
            let sample = raw >= 32768 ? raw - 65536 : raw
            if (frame > 60) { peak = max(peak, abs(sample)) }
        }
        if (frame >= 600 && frame < 900 && prefix != "") { for (b in n.apu.pcm) { push(audio, b) } }
        if ((frame % 60) == 0) {
            var hash = 2166136261u
            for (b in n.pixels) { hash = (hash ^ uint(b)) * 16777619u }
            if (hash != previous) { changes++ }; previous = hash
        }
        if (prefix != "" && (frame == 179 || frame == 599 || frame == 1199 || frame == 1799 || frame == 2399 || frame == 3599)) {
            let f = fopen("{prefix}-{frame}.rgba", "wb")
            if (f != null) { fwrite(f, n.pixels); fclose(f) }
        }
    }
    if (prefix != "") {
        let f = fopen("{prefix}.pcm", "wb")
        if (f != null) { fwrite(f, audio); fclose(f) }
    }
    print("Replay: 3600 frames, image changes {changes}, audio peak {peak}, samples {n.apu.samples}, bank writes {n.mapper_writes}, mapper clocks {n.mapper_clocks}, IRQ {n.irq_taken}, PC {n.pc}\n")
    verify(n.frame == 3600 && changes >= 3 && peak > 100)
    print("PASS replay\n")
    return 0
}
