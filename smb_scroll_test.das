options gen2
require ppu
require daslib/fio
var nes = Nes()

[export]
def main(smoke : bool) : int {
    verify(load_rom(nes, get_env_variable("DASNES_ROM")))
    // This optional integration test targets the user's SMB (W) ROM, not arbitrary games.
    if (nes.prg[336] != 173 || nes.prg[337] != 2 || nes.prg[338] != 32 || nes.prg[341] != 240) {
        print("This replay requires Super Mario Bros. (W) [!].nes\n"); return 1
    }
    var max_camera = 0
    var stalled = 0
    var previous_counter = 0
    for (frame in 0 .. 1800) {
        // Start, then right with periodic jumps. No game RAM or ROM is patched.
        nes.buttons = frame >= 180 && frame < 182 ? 8 : (frame >= 182 ? (128 | (frame % 70 < 40 ? 1 : 0)) : 0)
        run_frame(nes)
        if (frame == 1260 && has_env_variable("DASNES_FRAME_DUMP")) {
            let f = fopen(get_env_variable("DASNES_FRAME_DUMP"), "wb")
            verify(f != null)
            fwrite(f, nes.pixels)
            fclose(f)
        }
        let camera = nes.ram[1818] * 256 + nes.ram[1820]
        if (camera > max_camera) { max_camera = camera }
        if (max_camera >= 256 && nes.ram[9] == previous_counter) { stalled++ }
        else { stalled = 0 }
        if (stalled >= 90) {
            print("FAIL: SMB stopped advancing after nametable switch; PC={nes.pc}, camera={camera}\n")
            return 1
        }
        previous_counter = nes.ram[9]
    }
    if (max_camera < 512) { print("FAIL: replay did not cross both nametable boundaries; camera={max_camera}\n"); return 1 }
    print("PASS: SMB replay ran 1800 frames, camera reached {max_camera}, no sprite-zero wait deadlock\n")
    return 0
}
