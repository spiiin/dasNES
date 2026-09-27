options gen2
module mapper
require state public

// CPU windows are cached; only a changed 8 KiB bank needs copying.
def map_prg(var n : Nes; slot, bank : int) {
    let b = bank % (length(n.prg_rom) / 8192)
    if (n.prg_slots[slot] == b) { return }
    n.prg_slots[slot] = b
    for (i in 0 .. 8192) { n.prg[slot * 8192 + i] = int(n.prg_rom[b * 8192 + i]) }
}
def map_chr(var n : Nes; slot, bank : int) {
    let count = n.chr_ram ? 8 : length(n.chr_rom) / 1024
    n.chr_slots[slot] = bank % count
}
def chr_address(n : Nes; address : int) : int {
    let a = address & 8191
    return n.mapper == 0 ? a : n.chr_slots[a >> 10] * 1024 + (a & 1023)
}
def chr_read(n : Nes; address : int) : int {
    let a = chr_address(n, address)
    return n.chr_ram || n.mapper == 0 ? n.chr[a] : int(n.chr_rom[a])
}
def mapper_sync(var n : Nes) {
    let count = length(n.prg_rom) / 8192
    if (n.mapper == 0 || n.mapper == 3) {
        for (i in 0 .. 4) { map_prg(n, i, i) }
        if (n.mapper == 3) {
            for (i in 0 .. 8) { map_chr(n, i, n.cn_bank * 8 + i) }
        }
    } elif (n.mapper == 42) {
        for (i in 0 .. 4) { map_prg(n, i, count - 4 + i) }
        for (i in 0 .. 8) { map_chr(n, i, n.chr_ram ? i : n.banks[1] * 8 + i) }
    } elif (n.mapper == 2) {
        map_prg(n, 0, n.ux_bank * 2); map_prg(n, 1, n.ux_bank * 2 + 1)
        map_prg(n, 2, count - 2); map_prg(n, 3, count - 1)
    } elif (n.mapper == 1) {
        let mirroring = n.mmc1_control & 3
        n.single_screen = mirroring < 2 ? mirroring : -1
        n.vertical = mirroring == 2
        n.ram_enabled = (n.mmc1_prg & 16) == 0
        let mode = (n.mmc1_control >> 2) & 3
        let bank = (n.mmc1_prg & 15) * 2
        if (mode < 2) {
            for (i in 0 .. 4) { map_prg(n, i, (bank & ~3) + i) }
        } else {
            map_prg(n, 0, mode == 2 ? 0 : bank)
            map_prg(n, 1, mode == 2 ? 1 : bank + 1)
            map_prg(n, 2, mode == 2 ? bank : count - 2)
            map_prg(n, 3, mode == 2 ? bank + 1 : count - 1)
        }
        for (i in 0 .. 8) {
            let bank4 = i < 4 ? n.mmc1_chr0 : n.mmc1_chr1
            map_chr(n, i, (n.mmc1_control & 16) != 0 ? bank4 * 4 + (i & 3) : (n.mmc1_chr0 & 30) * 4 + i)
        }
    } elif (n.mapper == 4) {
        let swap = (n.bank_select & 64) != 0
        map_prg(n, 0, swap ? count - 2 : n.banks[6] & 63)
        map_prg(n, 1, n.banks[7] & 63)
        map_prg(n, 2, swap ? n.banks[6] & 63 : count - 2)
        map_prg(n, 3, count - 1)
        let flip = (n.bank_select & 128) != 0 ? 4 : 0
        for (i in 0 .. 4) {
            map_chr(n, i ^ flip, (n.banks[i / 2] & 254) + (i & 1))
            map_chr(n, (i + 4) ^ flip, n.banks[i + 2])
        }
    }
}
def mapper_init(var n : Nes) {
    for (i in 0 .. 4) { n.prg_slots[i] = -1 }
    for (i in 0 .. 8) { n.chr_slots[i] = i; n.banks[i] = 0 }
    n.mmc1_control = 12; n.mmc1_shift = 16; n.mmc1_last_write = -100l
    n.mmc1_chr0 = 0; n.mmc1_chr1 = 0; n.mmc1_prg = 0
    n.bank_select = 0; n.ux_bank = 0; n.cn_bank = 0; n.single_screen = -1
    n.ram_enabled = true; n.ram_protect = false
    n.irq_enabled = false; n.mapper_irq = false; n.irq_reload = false
    n.irq_counter = 0; n.irq_latch = 0
    mapper_sync(n)
}
def mapper_write(var n : Nes; address, value : int) {
    n.mapper_writes++
    if (n.mapper == 42) {
        let reg = address & 57347 // $E003: register aliases across each window.
        if (reg == 32768) { n.banks[1] = value & 15; mapper_sync(n) }
        elif (reg == 57344) { n.banks[0] = value & 15 }
        elif (reg == 57345) { n.vertical = (value & 8) == 0 }
        elif (reg == 57346) {
            n.irq_enabled = (value & 2) != 0
            if (!n.irq_enabled) { n.irq_counter = 0; n.mapper_irq = false }
        }
    }
    elif (n.mapper == 2) { n.ux_bank = value; mapper_sync(n) }
    elif (n.mapper == 3) {
        // Original CNROM: ROM and CPU drive the bus together (AND conflict).
        n.cn_bank = (value & n.prg[address & 32767]) & 3
        mapper_sync(n)
    }
    elif (n.mapper == 1) {
        // CPU RMW writes share an instruction timestamp; accept the first only.
        if (n.cycles - n.mmc1_last_write <= 1l) { return }
        n.mmc1_last_write = n.cycles
        if ((value & 128) != 0) { n.mmc1_shift = 16; n.mmc1_control |= 12; mapper_sync(n); return }
        let complete = (n.mmc1_shift & 1) != 0
        n.mmc1_shift = (n.mmc1_shift >> 1) | ((value & 1) << 4)
        if (complete) {
            let reg = (address >> 13) & 3
            if (reg == 0) { n.mmc1_control = n.mmc1_shift }
            elif (reg == 1) { n.mmc1_chr0 = n.mmc1_shift }
            elif (reg == 2) { n.mmc1_chr1 = n.mmc1_shift }
            else { n.mmc1_prg = n.mmc1_shift }
            n.mmc1_shift = 16; mapper_sync(n)
        }
    } elif (n.mapper == 4) {
        let reg = address & 57345
        if (reg == 32768) { n.bank_select = value; mapper_sync(n) }
        elif (reg == 32769) { n.banks[n.bank_select & 7] = value; mapper_sync(n) }
        elif (reg == 40960) { if (!n.four_screen) { n.vertical = (value & 1) == 0 } }
        elif (reg == 40961) { n.ram_enabled = (value & 128) != 0; n.ram_protect = (value & 64) != 0 }
        elif (reg == 49152) { n.irq_latch = value }
        elif (reg == 49153) { n.irq_reload = true }
        elif (reg == 57344) { n.irq_enabled = false; n.mapper_irq = false }
        elif (reg == 57345) { n.irq_enabled = true }
    }
}
// Mapper 42's 15-bit M2 counter asserts IRQ during its final 8192 clocks.
def mapper_cpu_clock(var n : Nes; cycles : int) {
    if (n.mapper == 42 && n.irq_enabled) {
        n.irq_counter = (n.irq_counter + cycles) & 32767
        n.mapper_irq = n.irq_counter >= 24576
    }
}

def mapper_irq_clock(var n : Nes) {
    if (n.mapper != 4) { return }
    n.mapper_clocks++
    if (n.irq_counter == 0 || n.irq_reload) { n.irq_counter = n.irq_latch }
    else { n.irq_counter-- }
    n.irq_reload = false
    if (n.irq_counter == 0 && n.irq_enabled) { n.mapper_irq = true }
}
