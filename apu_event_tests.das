options gen2
require ppu
require math
// Frozen pre-optimization cycle step for differential regression tests.
def apu_cycle_reference(var a : Apu) {
    a.clock++; a.frame_cycle++
    if (a.reset_delay > 0) {
        a.reset_delay--
        if (a.reset_delay == 0) { a.frame_cycle = 0; if (a.five_step) { quarter_frame(a); half_frame(a) } }
    }
    let f = a.frame_cycle
    if (f == 7457 || f == 14913 || f == 22371 || (!a.five_step && f == 29829) || (a.five_step && f == 37281)) { quarter_frame(a) }
    if (f == 14913 || (!a.five_step && f == 29829) || (a.five_step && f == 37281)) { half_frame(a) }
    if (!a.five_step && f >= 29828 && !a.irq_inhibit) { a.frame_irq = true }
    if ((!a.five_step && f >= 29830) || (a.five_step && f >= 37282)) { a.frame_cycle = 0 }
    if ((a.clock & 1l) == 0l) {
        // The NES has exactly two pulse channels; keep their indices constant.
        if (a.pulse[0].timer == 0) { a.pulse[0].timer = a.pulse[0].period; a.pulse[0].phase = (a.pulse[0].phase + 1) & 7 }
        else { a.pulse[0].timer-- }
        if (a.pulse[1].timer == 0) { a.pulse[1].timer = a.pulse[1].period; a.pulse[1].phase = (a.pulse[1].phase + 1) & 7 }
        else { a.pulse[1].timer-- }
    }
    if (a.triangle.timer == 0) {
        a.triangle.timer = a.triangle.period
        if (a.triangle.length > 0 && a.linear > 0 && a.triangle.period > 1) { a.triangle.phase = (a.triangle.phase + 1) & 31 }
    } else { a.triangle.timer-- }
    if (a.noise.timer == 0) {
        a.noise.timer = noise_period[a.noise.period & 15] - 1
        let tap = (a.noise.period & 128) != 0 ? 6 : 1
        let feedback = (a.noise_shift ^ (a.noise_shift >> tap)) & 1
        a.noise_shift = (a.noise_shift >> 1) | (feedback << 14)
    } else { a.noise.timer-- }
    if (a.dmc_timer == 0) {
        a.dmc_timer = dmc_period[a.dmc_control & 15] - 1
        if (!a.dmc_silent) {
            if ((a.dmc_shift & 1) != 0) { if (a.dmc_output <= 125) { a.dmc_output += 2 } }
            elif (a.dmc_output >= 2) { a.dmc_output -= 2 }
        }
        a.dmc_shift >>= 1; a.dmc_bits--
        if (a.dmc_bits == 0) {
            a.dmc_bits = 8; a.dmc_silent = a.dmc_empty
            if (!a.dmc_empty) { a.dmc_shift = a.dmc_buffer; a.dmc_empty = true }
        }
    } else { a.dmc_timer-- }
    let p = pulse_output(a.pulse[0], true) + pulse_output(a.pulse[1], false)
    let t = a.triangle.phase < 16 ? 15 - a.triangle.phase : a.triangle.phase - 16
    let noise = a.noise.length > 0 && (a.noise_shift & 1) == 0 ? envelope_output(a.noise) : 0
    a.pulse_sum += float(p)
    a.mix_sum += float(t) / 8227.0 + float(noise) / 12241.0 + float(a.dmc_output) / 22638.0
    a.mix_count++; a.sample_phase += 48000
    if (a.sample_phase >= 1789773) { a.sample_phase -= 1789773; apu_sample(a) }
}
def tick_apu_reference(var n : Nes; cycles : int) {
    for (i in 0 .. cycles) {
        if (n.apu.dmc_empty && n.apu.dmc_remaining > 0) {
            n.apu.dmc_buffer = n.prg[n.apu.dmc_current - 32768]
            n.apu.dmc_empty = false; n.stall += 4
            n.apu.dmc_current = n.apu.dmc_current == 65535 ? 32768 : n.apu.dmc_current + 1
            n.apu.dmc_remaining--
            if (n.apu.dmc_remaining == 0) {
                if ((n.apu.dmc_control & 64) != 0) { dmc_restart(n.apu) }
                elif ((n.apu.dmc_control & 128) != 0) { n.apu.dmc_irq = true }
            }
        }
        apu_cycle_reference(n.apu)
    }
}
def compare_apu(a, b : Nes) {
    if (a.apu.pulse[0].control != b.apu.pulse[0].control) { panic("APU mismatch: apu.pulse[0].control at clock={a.apu.clock} actual={a.apu.pulse[0].control} reference={b.apu.pulse[0].control}") }
    if (a.apu.pulse[0].sweep != b.apu.pulse[0].sweep) { panic("APU mismatch: apu.pulse[0].sweep at clock={a.apu.clock} actual={a.apu.pulse[0].sweep} reference={b.apu.pulse[0].sweep}") }
    if (a.apu.pulse[0].period != b.apu.pulse[0].period) { panic("APU mismatch: apu.pulse[0].period at clock={a.apu.clock} actual={a.apu.pulse[0].period} reference={b.apu.pulse[0].period}") }
    if (a.apu.pulse[0].timer != b.apu.pulse[0].timer) { panic("APU mismatch: apu.pulse[0].timer at clock={a.apu.clock} actual={a.apu.pulse[0].timer} reference={b.apu.pulse[0].timer}") }
    if (a.apu.pulse[0].phase != b.apu.pulse[0].phase) { panic("APU mismatch: apu.pulse[0].phase at clock={a.apu.clock} actual={a.apu.pulse[0].phase} reference={b.apu.pulse[0].phase}") }
    if (a.apu.pulse[0].length != b.apu.pulse[0].length) { panic("APU mismatch: apu.pulse[0].length at clock={a.apu.clock} actual={a.apu.pulse[0].length} reference={b.apu.pulse[0].length}") }
    if (a.apu.pulse[0].envelope != b.apu.pulse[0].envelope) { panic("APU mismatch: apu.pulse[0].envelope at clock={a.apu.clock} actual={a.apu.pulse[0].envelope} reference={b.apu.pulse[0].envelope}") }
    if (a.apu.pulse[0].envelope_divider != b.apu.pulse[0].envelope_divider) { panic("APU mismatch: apu.pulse[0].envelope_divider at clock={a.apu.clock} actual={a.apu.pulse[0].envelope_divider} reference={b.apu.pulse[0].envelope_divider}") }
    if (a.apu.pulse[0].sweep_divider != b.apu.pulse[0].sweep_divider) { panic("APU mismatch: apu.pulse[0].sweep_divider at clock={a.apu.clock} actual={a.apu.pulse[0].sweep_divider} reference={b.apu.pulse[0].sweep_divider}") }
    if (a.apu.pulse[0].envelope_start != b.apu.pulse[0].envelope_start) { panic("APU mismatch: apu.pulse[0].envelope_start at clock={a.apu.clock} actual={a.apu.pulse[0].envelope_start} reference={b.apu.pulse[0].envelope_start}") }
    if (a.apu.pulse[0].sweep_reload != b.apu.pulse[0].sweep_reload) { panic("APU mismatch: apu.pulse[0].sweep_reload at clock={a.apu.clock} actual={a.apu.pulse[0].sweep_reload} reference={b.apu.pulse[0].sweep_reload}") }
    if (a.apu.pulse[1].control != b.apu.pulse[1].control) { panic("APU mismatch: apu.pulse[1].control at clock={a.apu.clock} actual={a.apu.pulse[1].control} reference={b.apu.pulse[1].control}") }
    if (a.apu.pulse[1].sweep != b.apu.pulse[1].sweep) { panic("APU mismatch: apu.pulse[1].sweep at clock={a.apu.clock} actual={a.apu.pulse[1].sweep} reference={b.apu.pulse[1].sweep}") }
    if (a.apu.pulse[1].period != b.apu.pulse[1].period) { panic("APU mismatch: apu.pulse[1].period at clock={a.apu.clock} actual={a.apu.pulse[1].period} reference={b.apu.pulse[1].period}") }
    if (a.apu.pulse[1].timer != b.apu.pulse[1].timer) { panic("APU mismatch: apu.pulse[1].timer at clock={a.apu.clock} actual={a.apu.pulse[1].timer} reference={b.apu.pulse[1].timer}") }
    if (a.apu.pulse[1].phase != b.apu.pulse[1].phase) { panic("APU mismatch: apu.pulse[1].phase at clock={a.apu.clock} actual={a.apu.pulse[1].phase} reference={b.apu.pulse[1].phase}") }
    if (a.apu.pulse[1].length != b.apu.pulse[1].length) { panic("APU mismatch: apu.pulse[1].length at clock={a.apu.clock} actual={a.apu.pulse[1].length} reference={b.apu.pulse[1].length}") }
    if (a.apu.pulse[1].envelope != b.apu.pulse[1].envelope) { panic("APU mismatch: apu.pulse[1].envelope at clock={a.apu.clock} actual={a.apu.pulse[1].envelope} reference={b.apu.pulse[1].envelope}") }
    if (a.apu.pulse[1].envelope_divider != b.apu.pulse[1].envelope_divider) { panic("APU mismatch: apu.pulse[1].envelope_divider at clock={a.apu.clock} actual={a.apu.pulse[1].envelope_divider} reference={b.apu.pulse[1].envelope_divider}") }
    if (a.apu.pulse[1].sweep_divider != b.apu.pulse[1].sweep_divider) { panic("APU mismatch: apu.pulse[1].sweep_divider at clock={a.apu.clock} actual={a.apu.pulse[1].sweep_divider} reference={b.apu.pulse[1].sweep_divider}") }
    if (a.apu.pulse[1].envelope_start != b.apu.pulse[1].envelope_start) { panic("APU mismatch: apu.pulse[1].envelope_start at clock={a.apu.clock} actual={a.apu.pulse[1].envelope_start} reference={b.apu.pulse[1].envelope_start}") }
    if (a.apu.pulse[1].sweep_reload != b.apu.pulse[1].sweep_reload) { panic("APU mismatch: apu.pulse[1].sweep_reload at clock={a.apu.clock} actual={a.apu.pulse[1].sweep_reload} reference={b.apu.pulse[1].sweep_reload}") }
    if (a.apu.triangle.control != b.apu.triangle.control) { panic("APU mismatch: apu.triangle.control at clock={a.apu.clock} actual={a.apu.triangle.control} reference={b.apu.triangle.control}") }
    if (a.apu.triangle.sweep != b.apu.triangle.sweep) { panic("APU mismatch: apu.triangle.sweep at clock={a.apu.clock} actual={a.apu.triangle.sweep} reference={b.apu.triangle.sweep}") }
    if (a.apu.triangle.period != b.apu.triangle.period) { panic("APU mismatch: apu.triangle.period at clock={a.apu.clock} actual={a.apu.triangle.period} reference={b.apu.triangle.period}") }
    if (a.apu.triangle.timer != b.apu.triangle.timer) { panic("APU mismatch: apu.triangle.timer at clock={a.apu.clock} actual={a.apu.triangle.timer} reference={b.apu.triangle.timer}") }
    if (a.apu.triangle.phase != b.apu.triangle.phase) { panic("APU mismatch: apu.triangle.phase at clock={a.apu.clock} actual={a.apu.triangle.phase} reference={b.apu.triangle.phase}") }
    if (a.apu.triangle.length != b.apu.triangle.length) { panic("APU mismatch: apu.triangle.length at clock={a.apu.clock} actual={a.apu.triangle.length} reference={b.apu.triangle.length}") }
    if (a.apu.triangle.envelope != b.apu.triangle.envelope) { panic("APU mismatch: apu.triangle.envelope at clock={a.apu.clock} actual={a.apu.triangle.envelope} reference={b.apu.triangle.envelope}") }
    if (a.apu.triangle.envelope_divider != b.apu.triangle.envelope_divider) { panic("APU mismatch: apu.triangle.envelope_divider at clock={a.apu.clock} actual={a.apu.triangle.envelope_divider} reference={b.apu.triangle.envelope_divider}") }
    if (a.apu.triangle.sweep_divider != b.apu.triangle.sweep_divider) { panic("APU mismatch: apu.triangle.sweep_divider at clock={a.apu.clock} actual={a.apu.triangle.sweep_divider} reference={b.apu.triangle.sweep_divider}") }
    if (a.apu.triangle.envelope_start != b.apu.triangle.envelope_start) { panic("APU mismatch: apu.triangle.envelope_start at clock={a.apu.clock} actual={a.apu.triangle.envelope_start} reference={b.apu.triangle.envelope_start}") }
    if (a.apu.triangle.sweep_reload != b.apu.triangle.sweep_reload) { panic("APU mismatch: apu.triangle.sweep_reload at clock={a.apu.clock} actual={a.apu.triangle.sweep_reload} reference={b.apu.triangle.sweep_reload}") }
    if (a.apu.noise.control != b.apu.noise.control) { panic("APU mismatch: apu.noise.control at clock={a.apu.clock} actual={a.apu.noise.control} reference={b.apu.noise.control}") }
    if (a.apu.noise.sweep != b.apu.noise.sweep) { panic("APU mismatch: apu.noise.sweep at clock={a.apu.clock} actual={a.apu.noise.sweep} reference={b.apu.noise.sweep}") }
    if (a.apu.noise.period != b.apu.noise.period) { panic("APU mismatch: apu.noise.period at clock={a.apu.clock} actual={a.apu.noise.period} reference={b.apu.noise.period}") }
    if (a.apu.noise.timer != b.apu.noise.timer) { panic("APU mismatch: apu.noise.timer at clock={a.apu.clock} actual={a.apu.noise.timer} reference={b.apu.noise.timer}") }
    if (a.apu.noise.phase != b.apu.noise.phase) { panic("APU mismatch: apu.noise.phase at clock={a.apu.clock} actual={a.apu.noise.phase} reference={b.apu.noise.phase}") }
    if (a.apu.noise.length != b.apu.noise.length) { panic("APU mismatch: apu.noise.length at clock={a.apu.clock} actual={a.apu.noise.length} reference={b.apu.noise.length}") }
    if (a.apu.noise.envelope != b.apu.noise.envelope) { panic("APU mismatch: apu.noise.envelope at clock={a.apu.clock} actual={a.apu.noise.envelope} reference={b.apu.noise.envelope}") }
    if (a.apu.noise.envelope_divider != b.apu.noise.envelope_divider) { panic("APU mismatch: apu.noise.envelope_divider at clock={a.apu.clock} actual={a.apu.noise.envelope_divider} reference={b.apu.noise.envelope_divider}") }
    if (a.apu.noise.sweep_divider != b.apu.noise.sweep_divider) { panic("APU mismatch: apu.noise.sweep_divider at clock={a.apu.clock} actual={a.apu.noise.sweep_divider} reference={b.apu.noise.sweep_divider}") }
    if (a.apu.noise.envelope_start != b.apu.noise.envelope_start) { panic("APU mismatch: apu.noise.envelope_start at clock={a.apu.clock} actual={a.apu.noise.envelope_start} reference={b.apu.noise.envelope_start}") }
    if (a.apu.noise.sweep_reload != b.apu.noise.sweep_reload) { panic("APU mismatch: apu.noise.sweep_reload at clock={a.apu.clock} actual={a.apu.noise.sweep_reload} reference={b.apu.noise.sweep_reload}") }
    if (a.apu.enabled != b.apu.enabled) { panic("APU mismatch: apu.enabled at clock={a.apu.clock} actual={a.apu.enabled} reference={b.apu.enabled}") }
    if (a.apu.linear != b.apu.linear) { panic("APU mismatch: apu.linear at clock={a.apu.clock} actual={a.apu.linear} reference={b.apu.linear}") }
    if (a.apu.linear_reload != b.apu.linear_reload) { panic("APU mismatch: apu.linear_reload at clock={a.apu.clock} actual={a.apu.linear_reload} reference={b.apu.linear_reload}") }
    if (a.apu.noise_shift != b.apu.noise_shift) { panic("APU mismatch: apu.noise_shift at clock={a.apu.clock} actual={a.apu.noise_shift} reference={b.apu.noise_shift}") }
    if (a.apu.dmc_control != b.apu.dmc_control) { panic("APU mismatch: apu.dmc_control at clock={a.apu.clock} actual={a.apu.dmc_control} reference={b.apu.dmc_control}") }
    if (a.apu.dmc_output != b.apu.dmc_output) { panic("APU mismatch: apu.dmc_output at clock={a.apu.clock} actual={a.apu.dmc_output} reference={b.apu.dmc_output}") }
    if (a.apu.dmc_address != b.apu.dmc_address) { panic("APU mismatch: apu.dmc_address at clock={a.apu.clock} actual={a.apu.dmc_address} reference={b.apu.dmc_address}") }
    if (a.apu.dmc_length != b.apu.dmc_length) { panic("APU mismatch: apu.dmc_length at clock={a.apu.clock} actual={a.apu.dmc_length} reference={b.apu.dmc_length}") }
    if (a.apu.dmc_current != b.apu.dmc_current) { panic("APU mismatch: apu.dmc_current at clock={a.apu.clock} actual={a.apu.dmc_current} reference={b.apu.dmc_current}") }
    if (a.apu.dmc_remaining != b.apu.dmc_remaining) { panic("APU mismatch: apu.dmc_remaining at clock={a.apu.clock} actual={a.apu.dmc_remaining} reference={b.apu.dmc_remaining}") }
    if (a.apu.dmc_buffer != b.apu.dmc_buffer) { panic("APU mismatch: apu.dmc_buffer at clock={a.apu.clock} actual={a.apu.dmc_buffer} reference={b.apu.dmc_buffer}") }
    if (a.apu.dmc_shift != b.apu.dmc_shift) { panic("APU mismatch: apu.dmc_shift at clock={a.apu.clock} actual={a.apu.dmc_shift} reference={b.apu.dmc_shift}") }
    if (a.apu.dmc_timer != b.apu.dmc_timer) { panic("APU mismatch: apu.dmc_timer at clock={a.apu.clock} actual={a.apu.dmc_timer} reference={b.apu.dmc_timer}") }
    if (a.apu.dmc_bits != b.apu.dmc_bits) { panic("APU mismatch: apu.dmc_bits at clock={a.apu.clock} actual={a.apu.dmc_bits} reference={b.apu.dmc_bits}") }
    if (a.apu.dmc_empty != b.apu.dmc_empty) { panic("APU mismatch: apu.dmc_empty at clock={a.apu.clock} actual={a.apu.dmc_empty} reference={b.apu.dmc_empty}") }
    if (a.apu.dmc_silent != b.apu.dmc_silent) { panic("APU mismatch: apu.dmc_silent at clock={a.apu.clock} actual={a.apu.dmc_silent} reference={b.apu.dmc_silent}") }
    if (a.apu.dmc_irq != b.apu.dmc_irq) { panic("APU mismatch: apu.dmc_irq at clock={a.apu.clock} actual={a.apu.dmc_irq} reference={b.apu.dmc_irq}") }
    if (a.apu.frame_irq != b.apu.frame_irq) { panic("APU mismatch: apu.frame_irq at clock={a.apu.clock} actual={a.apu.frame_irq} reference={b.apu.frame_irq}") }
    if (a.apu.five_step != b.apu.five_step) { panic("APU mismatch: apu.five_step at clock={a.apu.clock} actual={a.apu.five_step} reference={b.apu.five_step}") }
    if (a.apu.irq_inhibit != b.apu.irq_inhibit) { panic("APU mismatch: apu.irq_inhibit at clock={a.apu.clock} actual={a.apu.irq_inhibit} reference={b.apu.irq_inhibit}") }
    if (a.apu.frame_cycle != b.apu.frame_cycle) { panic("APU mismatch: apu.frame_cycle at clock={a.apu.clock} actual={a.apu.frame_cycle} reference={b.apu.frame_cycle}") }
    if (a.apu.reset_delay != b.apu.reset_delay) { panic("APU mismatch: apu.reset_delay at clock={a.apu.clock} actual={a.apu.reset_delay} reference={b.apu.reset_delay}") }
    if (a.apu.sample_phase != b.apu.sample_phase) { panic("APU mismatch: apu.sample_phase at clock={a.apu.clock} actual={a.apu.sample_phase} reference={b.apu.sample_phase}") }
    if (a.apu.clock != b.apu.clock) { panic("APU mismatch: apu.clock at clock={a.apu.clock} actual={a.apu.clock} reference={b.apu.clock}") }
    if (a.apu.samples != b.apu.samples) { panic("APU mismatch: apu.samples at clock={a.apu.clock} actual={a.apu.samples} reference={b.apu.samples}") }
    if (a.apu.mix_sum != b.apu.mix_sum) { panic("APU mismatch: apu.mix_sum at clock={a.apu.clock} actual={a.apu.mix_sum} reference={b.apu.mix_sum}") }
    if (a.apu.pulse_sum != b.apu.pulse_sum) { panic("APU mismatch: apu.pulse_sum at clock={a.apu.clock} actual={a.apu.pulse_sum} reference={b.apu.pulse_sum}") }
    if (a.apu.mix_count != b.apu.mix_count) { panic("APU mismatch: apu.mix_count at clock={a.apu.clock} actual={a.apu.mix_count} reference={b.apu.mix_count}") }
    if (a.apu.filter_input != b.apu.filter_input) { panic("APU mismatch: apu.filter_input at clock={a.apu.clock} actual={a.apu.filter_input} reference={b.apu.filter_input}") }
    if (a.apu.filter_high != b.apu.filter_high) { panic("APU mismatch: apu.filter_high at clock={a.apu.clock} actual={a.apu.filter_high} reference={b.apu.filter_high}") }
    if (a.apu.filter_low != b.apu.filter_low) { panic("APU mismatch: apu.filter_low at clock={a.apu.clock} actual={a.apu.filter_low} reference={b.apu.filter_low}") }
    if (a.stall != b.stall) { panic("APU mismatch: stall at clock={a.apu.clock} actual={a.stall} reference={b.stall}") }
    verify(length(a.apu.pcm) == length(b.apu.pcm))
    for (i in 0 .. length(a.apu.pcm)) { verify(a.apu.pcm[i] == b.apu.pcm[i]) }
}
var current = Nes()
var reference = Nes()
var seed = 123456789u
def random_value() : int {
    seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
    return int(seed & 255u)
}
def set_register(address, value : int) {
    apu_write(current.apu, address, value)
    apu_write(reference.apu, address, value)
}
def advance(clocks : int) {
    clear(current.apu.pcm); clear(reference.apu.pcm)
    tick_apu(current, clocks)
    tick_apu_reference(reference, clocks)
    compare_apu(current, reference)
}
[export]
def main(smoke : bool) : int {
    for (i in 0 .. 32768) { let value = random_value(); current.prg[i] = value; reference.prg[i] = value }
    // Silent timers still advance; cross both frame sequences and sample edges.
    advance(90000)
    for (mode in 0 .. 2) {
        set_register(16407, mode == 0 ? 0 : 128)
        set_register(16405, 31)
        set_register(16384, 191); set_register(16386, 40); set_register(16387, 248)
        set_register(16388, 127); set_register(16390, 97); set_register(16391, 248)
        set_register(16392, 255); set_register(16394, 13); set_register(16395, 248)
        set_register(16396, 63); set_register(16398, 0); set_register(16399, 248)
        set_register(16400, 143); set_register(16402, 255); set_register(16403, 4)
        for (i in 0 .. 400) {
            advance(i % 5 == 0 ? 513 : (i % 5 == 1 ? 514 : 7))
            verify(apu_status(current.apu) == apu_status(reference.apu))
        }
    }
    let registers = fixed_array(16384, 16385, 16386, 16387, 16388, 16389, 16390, 16391, 16392, 16394, 16395, 16396, 16398, 16399, 16400, 16401, 16402, 16403, 16405, 16407)
    for (i in 0 .. 12000) {
        if (i % 11 == 0) { set_register(registers[random_value() % 20], random_value()) }
        advance(i % 13 == 0 ? 514 : 1 + random_value() % 8)
        if (i % 17 == 0) { verify(apu_status(current.apu) == apu_status(reference.apu)) }
    }
    print("PASS: event APU matches cycle reference, all channel state, timers, IRQ/DMC stalls and exact PCM\n")
    return 0
}
