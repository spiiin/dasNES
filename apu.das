options gen2
module apu
require state public
require math

let length_table = fixed_array(10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14, 12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30)
let noise_period = fixed_array(4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068)
let dmc_period = fixed_array(428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54)
let duties = fixed_array(2, 6, 30, 249)

def envelope_clock(var c : SoundChannel) {
    if (c.envelope_start) { c.envelope_start = false; c.envelope = 15; c.envelope_divider = c.control & 15 }
    elif (c.envelope_divider > 0) { c.envelope_divider-- }
    else {
        c.envelope_divider = c.control & 15
        if (c.envelope > 0) { c.envelope-- }
        elif ((c.control & 32) != 0) { c.envelope = 15 }
    }
}
def envelope_output(c : SoundChannel) : int { return (c.control & 16) != 0 ? c.control & 15 : c.envelope }
def sweep_target(c : SoundChannel; first : bool) : int {
    let delta = c.period >> (c.sweep & 7)
    return (c.sweep & 8) != 0 ? c.period - delta - (first ? 1 : 0) : c.period + delta
}
def quarter_frame(var a : Apu) {
    envelope_clock(a.pulse[0]); envelope_clock(a.pulse[1]); envelope_clock(a.noise)
    if (a.linear_reload) { a.linear = a.triangle.control & 127 }
    elif (a.linear > 0) { a.linear-- }
    if ((a.triangle.control & 128) == 0) { a.linear_reload = false }
}
def half_frame(var a : Apu) {
    for (i in 0 .. 2) {
        if (a.pulse[i].length > 0 && (a.pulse[i].control & 32) == 0) { a.pulse[i].length-- }
        let target = sweep_target(a.pulse[i], i == 0)
        if (a.pulse[i].sweep_divider == 0 && (a.pulse[i].sweep & 128) != 0 && (a.pulse[i].sweep & 7) != 0 && a.pulse[i].period >= 8 && target <= 2047) { a.pulse[i].period = target }
        if (a.pulse[i].sweep_divider == 0 || a.pulse[i].sweep_reload) { a.pulse[i].sweep_divider = (a.pulse[i].sweep >> 4) & 7; a.pulse[i].sweep_reload = false }
        else { a.pulse[i].sweep_divider-- }
    }
    if (a.triangle.length > 0 && (a.triangle.control & 128) == 0) { a.triangle.length-- }
    if (a.noise.length > 0 && (a.noise.control & 32) == 0) { a.noise.length-- }
}
def dmc_restart(var a : Apu) { a.dmc_current = 49152 + a.dmc_address * 64; a.dmc_remaining = a.dmc_length * 16 + 1 }
def apu_write(var a : Apu; address, b : int) {
    let reg = address - 16384
    if (reg < 8) {
        let i = reg / 4
        let r = reg & 3
        if (r == 0) { a.pulse[i].control = b }
        elif (r == 1) { a.pulse[i].sweep = b; a.pulse[i].sweep_reload = true }
        elif (r == 2) { a.pulse[i].period = (a.pulse[i].period & 1792) | b }
        else {
            a.pulse[i].period = (a.pulse[i].period & 255) | ((b & 7) << 8)
            if ((a.enabled & (1 << i)) != 0) { a.pulse[i].length = length_table[b >> 3] }
            a.pulse[i].phase = 0; a.pulse[i].envelope_start = true
        }
    } elif (reg == 8) { a.triangle.control = b }
    elif (reg == 10) { a.triangle.period = (a.triangle.period & 1792) | b }
    elif (reg == 11) {
        a.triangle.period = (a.triangle.period & 255) | ((b & 7) << 8)
        if ((a.enabled & 4) != 0) { a.triangle.length = length_table[b >> 3] }
        a.linear_reload = true
    } elif (reg == 12) { a.noise.control = b }
    elif (reg == 14) { a.noise.period = b }
    elif (reg == 15) {
        if ((a.enabled & 8) != 0) { a.noise.length = length_table[b >> 3] }
        a.noise.envelope_start = true
    } elif (reg == 16) { a.dmc_control = b; if ((b & 128) == 0) { a.dmc_irq = false } }
    elif (reg == 17) { a.dmc_output = b & 127 }
    elif (reg == 18) { a.dmc_address = b }
    elif (reg == 19) { a.dmc_length = b }
    elif (reg == 21) {
        a.enabled = b & 31
        for (i in 0 .. 2) { if ((b & (1 << i)) == 0) { a.pulse[i].length = 0 } }
        if ((b & 4) == 0) { a.triangle.length = 0 }
        if ((b & 8) == 0) { a.noise.length = 0 }
        if ((b & 16) == 0) { a.dmc_remaining = 0 }
        elif (a.dmc_remaining == 0) { dmc_restart(a) }
        a.dmc_irq = false
    } elif (reg == 23) {
        a.five_step = (b & 128) != 0; a.irq_inhibit = (b & 64) != 0
        if (a.irq_inhibit) { a.frame_irq = false }
        a.reset_delay = (a.clock & 1l) == 0l ? 3 : 4
    }
}
def apu_status(var a : Apu) : int {
    let result = (a.pulse[0].length > 0 ? 1 : 0) | (a.pulse[1].length > 0 ? 2 : 0) | (a.triangle.length > 0 ? 4 : 0) | (a.noise.length > 0 ? 8 : 0) | (a.dmc_remaining > 0 ? 16 : 0) | (a.frame_irq ? 64 : 0) | (a.dmc_irq ? 128 : 0)
    a.frame_irq = false
    return result
}
def pulse_output(c : SoundChannel; first : bool) : int {
    if (c.length == 0 || c.period < 8 || sweep_target(c, first) > 2047) { return 0 }
    return ((duties[c.control >> 6] >> c.phase) & 1) != 0 ? envelope_output(c) : 0
}
def apu_sample(var a : Apu) {
    let pulse = a.pulse_sum / float(a.mix_count)
    let tnd = a.mix_sum / float(a.mix_count)
    let mixed = (pulse > 0.0 ? 95.88 / (8128.0 / pulse + 100.0) : 0.0) + (tnd > 0.0 ? 159.79 / (1.0 / tnd + 100.0) : 0.0)
    // Integrate over CPU clocks before resampling; remove DC, low-pass at ~14 kHz.
    a.filter_high = 0.9883 * (a.filter_high + mixed - a.filter_input)
    a.filter_input = mixed
    a.filter_low += 0.84 * (a.filter_high - a.filter_low)
    let sample = clamp(int(a.filter_low * 26000.0), -32768, 32767)
    if (length(a.pcm) < 96000) { push(a.pcm, uint8(sample & 255)); push(a.pcm, uint8((sample >> 8) & 255)) }
    a.samples++; a.mix_sum = 0.0; a.pulse_sum = 0.0; a.mix_count = 0
}
def apu_cycle(var a : Apu) {
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
        for (i in 0 .. 2) {
            if (a.pulse[i].timer == 0) { a.pulse[i].timer = a.pulse[i].period; a.pulse[i].phase = (a.pulse[i].phase + 1) & 7 }
            else { a.pulse[i].timer-- }
        }
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
def tick_apu(var n : Nes; cycles : int) {
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
        apu_cycle(n.apu)
    }
}
