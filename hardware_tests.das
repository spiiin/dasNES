options gen2
require ppu
require math
var n = Nes()
var tone = Apu()

def serial(address, value : int) {
    for (i in 0 .. 5) { n.cycles += 3l; write(n, address, (value >> i) & 1) }
}
[export]
def main(smoke : bool) : int {
    resize(n.prg_rom, 131072); resize(n.chr_rom, 32768); resize(n.pixels, 245760)
    for (i in 0 .. 131072) { n.prg_rom[i] = uint8(i / 8192) }
    for (i in 0 .. 32768) { n.chr_rom[i] = uint8(i / 1024) }
    n.mapper = 2; n.chr_ram = true; mapper_init(n)
    verify(read(n, 32768) == 0 && read(n, 49152) == 14)
    write(n, 32768, 3); verify(read(n, 32768) == 6 && read(n, 49152) == 14)
    write(n, 32768, 11); verify(read(n, 32768) == 6)
    ppu_write(n, 42, 173); verify(ppu_read(n, 42) == 173)
    n.mapper = 1; n.chr_ram = false; mapper_init(n)
    serial(32768, 28); serial(40960, 3); serial(49152, 5); serial(57344, 2)
    verify(read(n, 32768) == 4 && read(n, 49152) == 14)
    verify(ppu_read(n, 0) == 12 && ppu_read(n, 4096) == 20)
    serial(32768, 10); verify(read(n, 32768) == 0 && read(n, 49152) == 4 && n.vertical)
    serial(32768, 1); verify(read(n, 32768) == 4 && read(n, 57344) == 7)
    verify(nt_index(n, 8192) == 1024 && nt_index(n, 11264) == 1024)
    serial(57344, 16); write(n, 24576, 55); verify(read(n, 24576) == 255)
    n.cycles += 3l; write(n, 32768, 128); verify(n.mmc1_shift == 16 && (n.mmc1_control & 12) == 12)
    n.cycles += 3l; write(n, 32768, 1); write(n, 32768, 0); verify(n.mmc1_shift == 24)
    n.mapper = 4; mapper_init(n)
    write(n, 32768, 6); write(n, 32769, 3)
    verify(read(n, 32768) == 3 && read(n, 49152) == 14)
    write(n, 32768, 70); verify(read(n, 32768) == 14 && read(n, 49152) == 3)
    write(n, 32768, 0); write(n, 32769, 5)
    verify(ppu_read(n, 0) == 4 && ppu_read(n, 1024) == 5)
    write(n, 32768, 128); verify(ppu_read(n, 4096) == 4)
    n.chr_ram = true; ppu_write(n, 4096, 83); write(n, 32768, 0)
    verify(ppu_read(n, 0) == 83) // Physical CHR RAM survives bank remapping.
    write(n, 40961, 192); write(n, 24576, 71); verify(read(n, 24576) == 0)
    write(n, 40961, 128); write(n, 24576, 71); verify(read(n, 24576) == 71)
    write(n, 49152, 2); write(n, 49153, 0); write(n, 57345, 0)
    mapper_irq_clock(n); verify(n.irq_counter == 2 && !n.mapper_irq)
    mapper_irq_clock(n); verify(n.irq_counter == 1 && !n.mapper_irq)
    mapper_irq_clock(n); verify(n.mapper_irq)
    n.prg[32766] = 0; n.prg[32767] = 144; n.p = 32; n.sp = 253
    verify(cpu_step(n) == 7 && n.pc == 36864 && (n.ram[507] & 16) == 0)
    write(n, 57344, 0); verify(!n.mapper_irq)
    write(n, 16384, 159); write(n, 16405, 15); write(n, 16386, 253); write(n, 16387, 8)
    verify(n.apu.pulse[0].length == 254 && n.apu.pulse[0].period == 253)
    quarter_frame(n.apu); verify(n.apu.pulse[0].envelope == 15)
    half_frame(n.apu); verify(n.apu.pulse[0].length == 253)
    n.apu.pulse[0].period = 100; n.apu.pulse[0].sweep = 137
    n.apu.pulse[1].period = 100; n.apu.pulse[1].sweep = 137
    half_frame(n.apu); verify(n.apu.pulse[0].period == 49 && n.apu.pulse[1].period == 50)
    write(n, 16392, 5); write(n, 16395, 8); quarter_frame(n.apu)
    verify(n.apu.linear == 5 && !n.apu.linear_reload)
    quarter_frame(n.apu); verify(n.apu.linear == 4)
    write(n, 16407, 128); tick_apu(n, 4); verify(n.apu.five_step && n.apu.reset_delay == 0)
    write(n, 16407, 0); tick_apu(n, 4); tick_apu(n, 29830)
    verify(n.apu.frame_irq); verify((read(n, 16405) & 64) != 0 && !n.apu.frame_irq)
    n.apu.dmc_current = 65535; n.apu.dmc_remaining = 1; n.apu.dmc_empty = true; n.apu.dmc_control = 128
    n.apu.quiet_cycles = 0 // This fixture edits registers directly, bypassing apu_write.
    n.prg[32767] = 165; tick_apu(n, 1)
    verify(n.apu.dmc_buffer == 165 && n.apu.dmc_current == 32768 && n.apu.dmc_irq && n.stall == 4)
    verify((read(n, 16405) & 128) != 0 && n.apu.dmc_irq)
    write(n, 16405, 0); verify(!n.apu.dmc_irq && n.apu.pulse[0].length == 0 && n.apu.triangle.length == 0)
    let before = n.apu.samples; let phase = n.apu.sample_phase
    clear(n.apu.pcm); tick_apu(n, 1789773)
    verify(n.apu.samples - before == 48000l && n.apu.sample_phase == phase && length(n.apu.pcm) == 96000)
    // Measured PCM pitch, not just register state: ~440.4 Hz at timer 253.
    apu_write(tone, 16405, 1); apu_write(tone, 16384, 159)
    apu_write(tone, 16386, 253); apu_write(tone, 16387, 8)
    for (i in 0 .. 1789773) { apu_cycle(tone) }
    var crossings, previous, peak : int
    for (i in 0 .. 48000) {
        let raw = int(tone.pcm[i * 2]) | (int(tone.pcm[i * 2 + 1]) << 8)
        let sample = raw >= 32768 ? raw - 65536 : raw
        if (previous <= 0 && sample > 0) { crossings++ }
        peak = max(peak, abs(sample)); previous = sample
    }
    verify(crossings >= 439 && crossings <= 443 && peak > 1000 && peak < 32767)
    print("PCM tone: {crossings} positive crossings/second, peak {peak}\n")
    n.zapper = true; n.zapper_trigger = true; n.zapper_light_until = n.cycles + 20l
    verify(read(n, 16407) == 80); n.cycles += 20l; verify(read(n, 16407) == 88)
    print("PASS: UxROM/MMC1/MMC3 banks, CHR RAM, mirroring, RAM protection, IRQ; APU envelopes, sweep, linear/frame counter, DMC, 48 kHz; Zapper bus\n")
    return 0
}
