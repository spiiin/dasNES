options gen2
require cpu
require daslib/fio
var nes = Nes()

[export]
def main(smoke : bool) : int {
    if (!load_rom(nes, get_env_variable("DASNES_ROM"))) { return 1 }
    nes.pc = 49152
    for (i in 0 .. 5003) {
        print("TRACE {nes.pc} {nes.a} {nes.x} {nes.y} {nes.p} {nes.sp} {nes.cycles}\n")
        cpu_step(nes)
    }
    return 0
}
