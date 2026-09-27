options gen2
module state

struct SoundChannel {
    control, sweep, period, timer, phase, length : int
    envelope, envelope_divider, sweep_divider : int
    envelope_start, sweep_reload : bool
}
struct Apu {
    pulse : SoundChannel[2]
    triangle, noise : SoundChannel
    enabled, linear : int
    linear_reload : bool
    noise_shift : int = 1
    dmc_control, dmc_output, dmc_address, dmc_length : int
    dmc_current, dmc_remaining, dmc_buffer, dmc_shift, dmc_timer : int
    dmc_bits : int = 8
    dmc_empty, dmc_silent : bool = true
    dmc_irq, frame_irq, five_step, irq_inhibit : bool
    frame_cycle, reset_delay, sample_phase : int
    clock : int64
    pcm : array<uint8>
    samples : int64
    mix_sum, pulse_sum : float
    mix_count : int
    filter_input, filter_high, filter_low : float
}

// NTSC machine. CPU registers are int, explicitly masked to bus width.
struct Nes {
    ram : int[2048]
    prg : int[32768]
    chr : int[8192]
    sram : int[8192]
    nt : int[4096]
    pal : int[32]
    oam : int[256]
    pixels : array<uint8>
    a, x, y, pc : int
    sp : int = 253
    p : int = 36
    ctrl, mask, status, oa, v, t, fine_x, buffer, bus : int
    latch, vertical, four_screen, chr_ram, nmi, strobe : bool
    buttons, shift, scroll_x, scroll_y : int
    render_v, render_fine_x : int
    sprite0_dot : int = -1
    dot : int
    line : int = 261
    frame, stall : int
    mapper : int
    prg_rom, chr_rom : array<uint8>
    prg_slots : int[4]
    chr_slots : int[8]
    single_screen : int = -1
    bank_select, ux_bank : int
    banks : int[8]
    mmc1_shift : int = 16
    mmc1_control : int = 12
    mmc1_chr0, mmc1_chr1, mmc1_prg : int
    mmc1_last_write : int64 = -100l
    ram_enabled : bool = true
    ram_protect : bool
    irq_latch, irq_counter : int
    irq_reload, irq_enabled, mapper_irq : bool
    mapper_writes, mapper_clocks, irq_taken : int
    zapper : bool
    zapper_x, zapper_y : int = -1
    zapper_trigger : bool
    zapper_light_until : int64
    apu : Apu = Apu()
    cycles : int64
}


