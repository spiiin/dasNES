options gen2
module cpu
require core public

// Generated from the checked-in official opcode table in tools/generate_cpu.py.
// Unsupported opcodes fail explicitly instead of silently corrupting state.
def cpu_step(var n : Nes) : int {
    if (n.stall > 0) { let c = n.stall; n.stall = 0; n.cycles += int64(c); return c }
    if (n.nmi) { n.nmi = false; interrupt(n, 65530, false); n.cycles += 7; return 7 }
    if ((n.mapper_irq || n.apu.frame_irq || n.apu.dmc_irq) && (n.p & 4) == 0) { interrupt(n, 65534, false); n.cycles += 7; n.irq_taken++; return 7 }
    let op_pc = n.pc
    let op = fetch(n)
    var cost = 0
    if (op < 128) {
        if (op < 64) {
            if (op < 32) {
                if (op < 16) {
                    if (op < 8) {
                        if (op < 4) {
                            if (op < 2) {
                                if (op < 1) {
                                    // BRK imp
                                    cost = 7
                                    n.pc = (n.pc + 1) & 65535; interrupt(n, 65534, true)
                                } else {
                                    // ORA izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 3) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 6) {
                                if (op < 5) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ORA zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 7) {
                                    // ASL zp
                                    cost = 5
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 128) != 0); let value = nz(n, b << 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 12) {
                            if (op < 10) {
                                if (op < 9) {
                                    // PHP imp
                                    cost = 3
                                    push(n, n.p | 48)
                                } else {
                                    // ORA imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 11) {
                                    // ASL acc
                                    cost = 2
                                    let b = n.a
                                    flag(n, 1, (b & 128) != 0); let value = nz(n, b << 1)
                                    n.a = value
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 14) {
                                if (op < 13) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ORA abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 15) {
                                    // ASL abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 128) != 0); let value = nz(n, b << 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 24) {
                        if (op < 20) {
                            if (op < 18) {
                                if (op < 17) {
                                    // BPL rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 128) == 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // ORA izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 19) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 22) {
                                if (op < 21) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ORA zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 23) {
                                    // ASL zpx
                                    cost = 6
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 128) != 0); let value = nz(n, b << 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 28) {
                            if (op < 26) {
                                if (op < 25) {
                                    // CLC imp
                                    cost = 2
                                    n.p &= ~1
                                } else {
                                    // ORA aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 27) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 30) {
                                if (op < 29) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ORA abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a | b)
                                }
                            } else {
                                if (op < 31) {
                                    // ASL abx
                                    cost = 7
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 128) != 0); let value = nz(n, b << 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            } else {
                if (op < 48) {
                    if (op < 40) {
                        if (op < 36) {
                            if (op < 34) {
                                if (op < 33) {
                                    // JSR abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let ret = (n.pc - 1) & 65535; push(n, ret >> 8); push(n, ret & 255); n.pc = ea
                                } else {
                                    // AND izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 35) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 38) {
                                if (op < 37) {
                                    // BIT zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    flag(n, 2, (n.a & b) == 0); n.p = (n.p & 63) | (b & 192)
                                } else {
                                    // AND zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 39) {
                                    // ROL zp
                                    cost = 5
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = n.p & 1; flag(n, 1, (b & 128) != 0); let value = nz(n, (b << 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 44) {
                            if (op < 42) {
                                if (op < 41) {
                                    // PLP imp
                                    cost = 4
                                    n.p = (pop(n) & 239) | 32
                                } else {
                                    // AND imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 43) {
                                    // ROL acc
                                    cost = 2
                                    let b = n.a
                                    let carry = n.p & 1; flag(n, 1, (b & 128) != 0); let value = nz(n, (b << 1) | carry)
                                    n.a = value
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 46) {
                                if (op < 45) {
                                    // BIT abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    flag(n, 2, (n.a & b) == 0); n.p = (n.p & 63) | (b & 192)
                                } else {
                                    // AND abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 47) {
                                    // ROL abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = n.p & 1; flag(n, 1, (b & 128) != 0); let value = nz(n, (b << 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 56) {
                        if (op < 52) {
                            if (op < 50) {
                                if (op < 49) {
                                    // BMI rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 128) != 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // AND izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 51) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 54) {
                                if (op < 53) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // AND zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 55) {
                                    // ROL zpx
                                    cost = 6
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = n.p & 1; flag(n, 1, (b & 128) != 0); let value = nz(n, (b << 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 60) {
                            if (op < 58) {
                                if (op < 57) {
                                    // SEC imp
                                    cost = 2
                                    n.p |= 1
                                } else {
                                    // AND aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 59) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 62) {
                                if (op < 61) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // AND abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a & b)
                                }
                            } else {
                                if (op < 63) {
                                    // ROL abx
                                    cost = 7
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = n.p & 1; flag(n, 1, (b & 128) != 0); let value = nz(n, (b << 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if (op < 96) {
                if (op < 80) {
                    if (op < 72) {
                        if (op < 68) {
                            if (op < 66) {
                                if (op < 65) {
                                    // RTI imp
                                    cost = 6
                                    n.p = (pop(n) & 239) | 32; let lo = pop(n); n.pc = lo | (pop(n) << 8)
                                } else {
                                    // EOR izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 67) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 70) {
                                if (op < 69) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // EOR zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 71) {
                                    // LSR zp
                                    cost = 5
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 1) != 0); let value = nz(n, b >> 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 76) {
                            if (op < 74) {
                                if (op < 73) {
                                    // PHA imp
                                    cost = 3
                                    push(n, n.a)
                                } else {
                                    // EOR imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 75) {
                                    // LSR acc
                                    cost = 2
                                    let b = n.a
                                    flag(n, 1, (b & 1) != 0); let value = nz(n, b >> 1)
                                    n.a = value
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 78) {
                                if (op < 77) {
                                    // JMP abs
                                    cost = 3
                                    let ea = fetch_word(n)
                                    n.pc = ea
                                } else {
                                    // EOR abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 79) {
                                    // LSR abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 1) != 0); let value = nz(n, b >> 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 88) {
                        if (op < 84) {
                            if (op < 82) {
                                if (op < 81) {
                                    // BVC rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 64) == 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // EOR izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 83) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 86) {
                                if (op < 85) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // EOR zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 87) {
                                    // LSR zpx
                                    cost = 6
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 1) != 0); let value = nz(n, b >> 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 92) {
                            if (op < 90) {
                                if (op < 89) {
                                    // CLI imp
                                    cost = 2
                                    n.p &= ~4
                                } else {
                                    // EOR aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 91) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 94) {
                                if (op < 93) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // EOR abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, n.a ^ b)
                                }
                            } else {
                                if (op < 95) {
                                    // LSR abx
                                    cost = 7
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    flag(n, 1, (b & 1) != 0); let value = nz(n, b >> 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            } else {
                if (op < 112) {
                    if (op < 104) {
                        if (op < 100) {
                            if (op < 98) {
                                if (op < 97) {
                                    // RTS imp
                                    cost = 6
                                    let lo = pop(n); n.pc = ((pop(n) << 8) + lo + 1) & 65535
                                } else {
                                    // ADC izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 99) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 102) {
                                if (op < 101) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ADC zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 103) {
                                    // ROR zp
                                    cost = 5
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = (n.p & 1) << 7; flag(n, 1, (b & 1) != 0); let value = nz(n, (b >> 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 108) {
                            if (op < 106) {
                                if (op < 105) {
                                    // PLA imp
                                    cost = 4
                                    n.a = nz(n, pop(n))
                                } else {
                                    // ADC imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 107) {
                                    // ROR acc
                                    cost = 2
                                    let b = n.a
                                    let carry = (n.p & 1) << 7; flag(n, 1, (b & 1) != 0); let value = nz(n, (b >> 1) | carry)
                                    n.a = value
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 110) {
                                if (op < 109) {
                                    // JMP ind
                                    cost = 5
                                    let ptr = fetch_word(n); let lo = read(n, ptr); let ea = lo | (read(n, (ptr & 65280) | ((ptr + 1) & 255)) << 8)
                                    n.pc = ea
                                } else {
                                    // ADC abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 111) {
                                    // ROR abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = (n.p & 1) << 7; flag(n, 1, (b & 1) != 0); let value = nz(n, (b >> 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 120) {
                        if (op < 116) {
                            if (op < 114) {
                                if (op < 113) {
                                    // BVS rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 64) != 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // ADC izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 115) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 118) {
                                if (op < 117) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ADC zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 119) {
                                    // ROR zpx
                                    cost = 6
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = (n.p & 1) << 7; flag(n, 1, (b & 1) != 0); let value = nz(n, (b >> 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 124) {
                            if (op < 122) {
                                if (op < 121) {
                                    // SEI imp
                                    cost = 2
                                    n.p |= 4
                                } else {
                                    // ADC aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 123) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 126) {
                                if (op < 125) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // ADC abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    adc(n, b)
                                }
                            } else {
                                if (op < 127) {
                                    // ROR abx
                                    cost = 7
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let carry = (n.p & 1) << 7; flag(n, 1, (b & 1) != 0); let value = nz(n, (b >> 1) | carry)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            }
        }
    } else {
        if (op < 192) {
            if (op < 160) {
                if (op < 144) {
                    if (op < 136) {
                        if (op < 132) {
                            if (op < 130) {
                                if (op < 129) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // STA izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 131) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 134) {
                                if (op < 133) {
                                    // STY zp
                                    cost = 3
                                    let ea = fetch(n)
                                    write(n, ea, n.y)
                                } else {
                                    // STA zp
                                    cost = 3
                                    let ea = fetch(n)
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 135) {
                                    // STX zp
                                    cost = 3
                                    let ea = fetch(n)
                                    write(n, ea, n.x)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 140) {
                            if (op < 138) {
                                if (op < 137) {
                                    // DEY imp
                                    cost = 2
                                    n.y = nz(n, n.y + (-1))
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            } else {
                                if (op < 139) {
                                    // TXA imp
                                    cost = 2
                                    n.a = nz(n, n.x)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 142) {
                                if (op < 141) {
                                    // STY abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    write(n, ea, n.y)
                                } else {
                                    // STA abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 143) {
                                    // STX abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    write(n, ea, n.x)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 152) {
                        if (op < 148) {
                            if (op < 146) {
                                if (op < 145) {
                                    // BCC rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 1) == 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // STA izy
                                    cost = 6
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 147) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 150) {
                                if (op < 149) {
                                    // STY zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    write(n, ea, n.y)
                                } else {
                                    // STA zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 151) {
                                    // STX zpy
                                    cost = 4
                                    let ea = (fetch(n) + n.y) & 255
                                    write(n, ea, n.x)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 156) {
                            if (op < 154) {
                                if (op < 153) {
                                    // TYA imp
                                    cost = 2
                                    n.a = nz(n, n.y)
                                } else {
                                    // STA aby
                                    cost = 5
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 155) {
                                    // TXS imp
                                    cost = 2
                                    n.sp = n.x
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 158) {
                                if (op < 157) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // STA abx
                                    cost = 5
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    write(n, ea, n.a)
                                }
                            } else {
                                if (op < 159) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            } else {
                if (op < 176) {
                    if (op < 168) {
                        if (op < 164) {
                            if (op < 162) {
                                if (op < 161) {
                                    // LDY imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    n.y = nz(n, b)
                                } else {
                                    // LDA izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 163) {
                                    // LDX imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    n.x = nz(n, b)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 166) {
                                if (op < 165) {
                                    // LDY zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    n.y = nz(n, b)
                                } else {
                                    // LDA zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 167) {
                                    // LDX zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    n.x = nz(n, b)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 172) {
                            if (op < 170) {
                                if (op < 169) {
                                    // TAY imp
                                    cost = 2
                                    n.y = nz(n, n.a)
                                } else {
                                    // LDA imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 171) {
                                    // TAX imp
                                    cost = 2
                                    n.x = nz(n, n.a)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 174) {
                                if (op < 173) {
                                    // LDY abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    n.y = nz(n, b)
                                } else {
                                    // LDA abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 175) {
                                    // LDX abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    n.x = nz(n, b)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 184) {
                        if (op < 180) {
                            if (op < 178) {
                                if (op < 177) {
                                    // BCS rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 1) != 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // LDA izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 179) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 182) {
                                if (op < 181) {
                                    // LDY zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    n.y = nz(n, b)
                                } else {
                                    // LDA zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 183) {
                                    // LDX zpy
                                    cost = 4
                                    let ea = (fetch(n) + n.y) & 255
                                    let b = read(n, ea)
                                    n.x = nz(n, b)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 188) {
                            if (op < 186) {
                                if (op < 185) {
                                    // CLV imp
                                    cost = 2
                                    n.p &= ~64
                                } else {
                                    // LDA aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 187) {
                                    // TSX imp
                                    cost = 2
                                    n.x = nz(n, n.sp)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 190) {
                                if (op < 189) {
                                    // LDY abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.y = nz(n, b)
                                } else {
                                    // LDA abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.a = nz(n, b)
                                }
                            } else {
                                if (op < 191) {
                                    // LDX aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    n.x = nz(n, b)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if (op < 224) {
                if (op < 208) {
                    if (op < 200) {
                        if (op < 196) {
                            if (op < 194) {
                                if (op < 193) {
                                    // CPY imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    compare(n, n.y, b)
                                } else {
                                    // CMP izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 195) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 198) {
                                if (op < 197) {
                                    // CPY zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    compare(n, n.y, b)
                                } else {
                                    // CMP zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 199) {
                                    // DEC zp
                                    cost = 5
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b - 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 204) {
                            if (op < 202) {
                                if (op < 201) {
                                    // INY imp
                                    cost = 2
                                    n.y = nz(n, n.y + (1))
                                } else {
                                    // CMP imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 203) {
                                    // DEX imp
                                    cost = 2
                                    n.x = nz(n, n.x + (-1))
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 206) {
                                if (op < 205) {
                                    // CPY abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    compare(n, n.y, b)
                                } else {
                                    // CMP abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 207) {
                                    // DEC abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b - 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 216) {
                        if (op < 212) {
                            if (op < 210) {
                                if (op < 209) {
                                    // BNE rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 2) == 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // CMP izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 211) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 214) {
                                if (op < 213) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // CMP zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 215) {
                                    // DEC zpx
                                    cost = 6
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b - 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 220) {
                            if (op < 218) {
                                if (op < 217) {
                                    // CLD imp
                                    cost = 2
                                    n.p &= ~8
                                } else {
                                    // CMP aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 219) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 222) {
                                if (op < 221) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // CMP abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    compare(n, n.a, b)
                                }
                            } else {
                                if (op < 223) {
                                    // DEC abx
                                    cost = 7
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b - 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            } else {
                if (op < 240) {
                    if (op < 232) {
                        if (op < 228) {
                            if (op < 226) {
                                if (op < 225) {
                                    // CPX imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    compare(n, n.x, b)
                                } else {
                                    // SBC izx
                                    cost = 6
                                    let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let ea = lo | (read(n, (zp + 1) & 255) << 8)
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 227) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 230) {
                                if (op < 229) {
                                    // CPX zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    compare(n, n.x, b)
                                } else {
                                    // SBC zp
                                    cost = 3
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 231) {
                                    // INC zp
                                    cost = 5
                                    let ea = fetch(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b + 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 236) {
                            if (op < 234) {
                                if (op < 233) {
                                    // INX imp
                                    cost = 2
                                    n.x = nz(n, n.x + (1))
                                } else {
                                    // SBC imm
                                    cost = 2
                                    let ea = n.pc; n.pc = (n.pc + 1) & 65535
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 235) {
                                    // NOP imp
                                    cost = 2
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 238) {
                                if (op < 237) {
                                    // CPX abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    compare(n, n.x, b)
                                } else {
                                    // SBC abs
                                    cost = 4
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 239) {
                                    // INC abs
                                    cost = 6
                                    let ea = fetch_word(n)
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b + 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                } else {
                    if (op < 248) {
                        if (op < 244) {
                            if (op < 242) {
                                if (op < 241) {
                                    // BEQ rel
                                    cost = 2
                                    let offset = fetch(n); let ea = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535
                                    if ((n.p & 2) != 0) { cost += 1 + ((n.pc & 65280) != (ea & 65280) ? 1 : 0); n.pc = ea }
                                } else {
                                    // SBC izy
                                    cost = 5
                                    let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 243) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 246) {
                                if (op < 245) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // SBC zpx
                                    cost = 4
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 247) {
                                    // INC zpx
                                    cost = 6
                                    let ea = (fetch(n) + n.x) & 255
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b + 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    } else {
                        if (op < 252) {
                            if (op < 250) {
                                if (op < 249) {
                                    // SED imp
                                    cost = 2
                                    n.p |= 8
                                } else {
                                    // SBC aby
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.y) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 251) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        } else {
                            if (op < 254) {
                                if (op < 253) {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                } else {
                                    // SBC abx
                                    cost = 4
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    if ((base & 65280) != (ea & 65280)) { cost++ }
                                    let b = read(n, ea)
                                    adc(n, b ^ 255)
                                }
                            } else {
                                if (op < 255) {
                                    // INC abx
                                    cost = 7
                                    let base = fetch_word(n); let ea = (base + n.x) & 65535
                                    let b = read(n, ea)
                                    write(n, ea, b) // NMOS read-modify-write dummy write
                                    let value = nz(n, b + 1)
                                    write(n, ea, value)
                                } else {
                                    panic("Unsupported opcode {op} at PC {op_pc}")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    n.cycles += int64(cost)
    return cost
}
