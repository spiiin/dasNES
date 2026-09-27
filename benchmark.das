options gen2
require ppu
require daslib/fio
require sdl3
var nes = Nes()

[export]
def main(smoke : bool) : int {
    verify(load_rom(nes, get_env_variable("DASNES_ROM")))
    for (_ in 0 .. 60) { run_frame(nes) }
    let started = SDL_GetTicksNS()
    for (i in 0 .. 120) {
        nes.buttons = i < 2 ? 8 : 128
        run_frame(nes)
    }
    let elapsed = SDL_GetTicksNS() - started
    var hash = 2166136261u
    for (b in nes.pixels) { hash = (hash ^ uint(b)) * 16777619u }
    for (b in nes.ram) { hash = (hash ^ uint(b)) * 16777619u }
    print("BENCH frames=120 ms/frame={double(elapsed) / 120000000.0lf} uncapped_fps={120000000000.0lf / double(elapsed)}\n")
    print("STATE hash={hash} PC={nes.pc} A={nes.a} X={nes.x} Y={nes.y} P={nes.p} SP={nes.sp} cycles={nes.cycles} dot={nes.dot} line={nes.line}\n")
    return 0
}
