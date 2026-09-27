options gen2
require ppu
require daslib/fio
var nes = Nes()

[export]
def main(smoke : bool) : int {
    verify(load_rom(nes, get_env_variable("DASNES_ROM")))
    for (_ in 0 .. 5) { run_frame(nes) }
    verify(nes.frame == 5 && nes.ram[0] >= 3 && nes.ram[0] <= 4)
    verify(nes.pal[1] == nes.ram[0])
    verify(nes.pixels[3] == 255 && nes.pixels[7] == 255)
    verify(nes.pixels[0] != nes.pixels[4] || nes.pixels[1] != nes.pixels[5] || nes.pixels[2] != nes.pixels[6])
    print("PASS: demo cartridge boots, renders a pattern and animates through NMI\n")
    return 0
}
