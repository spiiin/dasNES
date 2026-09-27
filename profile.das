options gen2
require ppu
require daslib/fio
require sdl3
var nes = Nes()

[export]
def main(smoke : bool) : int {
    verify(load_rom(nes, get_env_variable("DASNES_ROM")))
    for (_ in 0 .. 60) { run_frame(nes) }
    var cpu_ns = 0ul
    var apu_ns = 0ul
    var ppu_ns = 0ul
    var audio_hash = 2166136261u
    for (i in 0 .. 120) {
        nes.buttons = i < 2 ? 8 : 128
        clear(nes.apu.pcm)
        let target = nes.frame + 1
        while (nes.frame < target) {
            let start = SDL_GetTicksNS()
            let c = cpu_step(nes)
            let after_cpu = SDL_GetTicksNS()
            tick_apu(nes, c)
            let after_apu = SDL_GetTicksNS()
            tick_ppu(nes, c)
            let after_ppu = SDL_GetTicksNS()
            cpu_ns += after_cpu - start
            apu_ns += after_apu - after_cpu
            ppu_ns += after_ppu - after_apu
        }
        for (b in nes.apu.pcm) { audio_hash = (audio_hash ^ uint(b)) * 16777619u }
    }
    var hash = 2166136261u
    for (b in nes.pixels) { hash = (hash ^ uint(b)) * 16777619u }
    for (b in nes.ram) { hash = (hash ^ uint(b)) * 16777619u }
    print("PROFILE ms/frame CPU={double(cpu_ns)/120000000.0lf} APU={double(apu_ns)/120000000.0lf} PPU={double(ppu_ns)/120000000.0lf}\n")
    print("STATE hash={hash} audio={audio_hash} cycles={nes.cycles} PC={nes.pc}\n")
    return 0
}
