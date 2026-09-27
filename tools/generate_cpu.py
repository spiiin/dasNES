from pathlib import Path
import re

# Official NMOS 6502 opcodes. Modes: implied, accumulator, immediate, zero
# page, zp X/Y, absolute, abs X/Y, indexed indirect, indirect indexed, relative.
rows = '''
00 BRK imp 7;01 ORA izx 6;05 ORA zp 3;06 ASL zp 5;08 PHP imp 3;09 ORA imm 2;0A ASL acc 2;0D ORA abs 4;0E ASL abs 6
10 BPL rel 2;11 ORA izy 5;15 ORA zpx 4;16 ASL zpx 6;18 CLC imp 2;19 ORA aby 4;1D ORA abx 4;1E ASL abx 7
20 JSR abs 6;21 AND izx 6;24 BIT zp 3;25 AND zp 3;26 ROL zp 5;28 PLP imp 4;29 AND imm 2;2A ROL acc 2;2C BIT abs 4;2D AND abs 4;2E ROL abs 6
30 BMI rel 2;31 AND izy 5;35 AND zpx 4;36 ROL zpx 6;38 SEC imp 2;39 AND aby 4;3D AND abx 4;3E ROL abx 7
40 RTI imp 6;41 EOR izx 6;45 EOR zp 3;46 LSR zp 5;48 PHA imp 3;49 EOR imm 2;4A LSR acc 2;4C JMP abs 3;4D EOR abs 4;4E LSR abs 6
50 BVC rel 2;51 EOR izy 5;55 EOR zpx 4;56 LSR zpx 6;58 CLI imp 2;59 EOR aby 4;5D EOR abx 4;5E LSR abx 7
60 RTS imp 6;61 ADC izx 6;65 ADC zp 3;66 ROR zp 5;68 PLA imp 4;69 ADC imm 2;6A ROR acc 2;6C JMP ind 5;6D ADC abs 4;6E ROR abs 6
70 BVS rel 2;71 ADC izy 5;75 ADC zpx 4;76 ROR zpx 6;78 SEI imp 2;79 ADC aby 4;7D ADC abx 4;7E ROR abx 7
81 STA izx 6;84 STY zp 3;85 STA zp 3;86 STX zp 3;88 DEY imp 2;8A TXA imp 2;8C STY abs 4;8D STA abs 4;8E STX abs 4
90 BCC rel 2;91 STA izy 6;94 STY zpx 4;95 STA zpx 4;96 STX zpy 4;98 TYA imp 2;99 STA aby 5;9A TXS imp 2;9D STA abx 5
A0 LDY imm 2;A1 LDA izx 6;A2 LDX imm 2;A4 LDY zp 3;A5 LDA zp 3;A6 LDX zp 3;A8 TAY imp 2;A9 LDA imm 2;AA TAX imp 2;AC LDY abs 4;AD LDA abs 4;AE LDX abs 4
B0 BCS rel 2;B1 LDA izy 5;B4 LDY zpx 4;B5 LDA zpx 4;B6 LDX zpy 4;B8 CLV imp 2;B9 LDA aby 4;BA TSX imp 2;BC LDY abx 4;BD LDA abx 4;BE LDX aby 4
C0 CPY imm 2;C1 CMP izx 6;C4 CPY zp 3;C5 CMP zp 3;C6 DEC zp 5;C8 INY imp 2;C9 CMP imm 2;CA DEX imp 2;CC CPY abs 4;CD CMP abs 4;CE DEC abs 6
D0 BNE rel 2;D1 CMP izy 5;D5 CMP zpx 4;D6 DEC zpx 6;D8 CLD imp 2;D9 CMP aby 4;DD CMP abx 4;DE DEC abx 7
E0 CPX imm 2;E1 SBC izx 6;E4 CPX zp 3;E5 SBC zp 3;E6 INC zp 5;E8 INX imp 2;E9 SBC imm 2;EA NOP imp 2;EC CPX abs 4;ED SBC abs 4;EE INC abs 6
F0 BEQ rel 2;F1 SBC izy 5;F5 SBC zpx 4;F6 INC zpx 6;F8 SED imp 2;F9 SBC aby 4;FD SBC abx 4;FE INC abx 7
'''
entries = [e.split() for e in rows.replace('\n', ';').split(';') if e.strip()]
assert len(entries) == 151
modes = {
 'imp':'', 'acc':'', 'imm':'let addr = n.pc; n.pc = (n.pc + 1) & 65535',
 'zp':'let addr = fetch(n)', 'zpx':'let addr = (fetch(n) + n.x) & 255', 'zpy':'let addr = (fetch(n) + n.y) & 255',
 'abs':'let addr = fetch_word(n)',
 'abx':'let base = fetch_word(n); let addr = (base + n.x) & 65535',
 'aby':'let base = fetch_word(n); let addr = (base + n.y) & 65535',
 'izx':'let zp = (fetch(n) + n.x) & 255; let lo = read(n, zp); let addr = lo | (read(n, (zp + 1) & 255) << 8)',
 'izy':'let zp = fetch(n); let lo = read(n, zp); let base = lo | (read(n, (zp + 1) & 255) << 8); let addr = (base + n.y) & 65535',
 'ind':'let ptr = fetch_word(n); let lo = read(n, ptr); let addr = lo | (read(n, (ptr & 0xff00) | ((ptr + 1) & 255)) << 8)',
 'rel':'let offset = fetch(n); let addr = (n.pc + (offset < 128 ? offset : offset - 256)) & 65535'
}
ops = {
'BRK':'n.pc = (n.pc + 1) & 65535; interrupt(n, 0xfffe, true)',
'PHP':'push(n, n.p | 48)', 'PLP':'n.p = (pop(n) & 239) | 32',
'PHA':'push(n, n.a)', 'PLA':'n.a = nz(n, pop(n))',
'JSR':'let ret = (n.pc - 1) & 65535; push(n, ret >> 8); push(n, ret & 255); n.pc = addr',
'JMP':'n.pc = addr', 'RTS':'let lo = pop(n); n.pc = ((pop(n) << 8) + lo + 1) & 65535',
'RTI':'n.p = (pop(n) & 239) | 32; let lo = pop(n); n.pc = lo | (pop(n) << 8)',
'BIT':'flag(n, 2, (n.a & b) == 0); n.p = (n.p & 63) | (b & 192)',
'ADC':'adc(n, b)', 'SBC':'adc(n, b ^ 255)',
'ORA':'n.a = nz(n, n.a | b)', 'AND':'n.a = nz(n, n.a & b)', 'EOR':'n.a = nz(n, n.a ^ b)',
'ASL':'flag(n, 1, (b & 128) != 0); let value = nz(n, b << 1)',
'LSR':'flag(n, 1, (b & 1) != 0); let value = nz(n, b >> 1)',
'ROL':'let carry = n.p & 1; flag(n, 1, (b & 128) != 0); let value = nz(n, (b << 1) | carry)',
'ROR':'let carry = (n.p & 1) << 7; flag(n, 1, (b & 1) != 0); let value = nz(n, (b >> 1) | carry)',
'INC':'let value = nz(n, b + 1)', 'DEC':'let value = nz(n, b - 1)', 'NOP':''
}
for name,mask in [('C',1),('I',4),('D',8),('V',64)]:
 ops['CL'+name]=f'n.p &= ~{mask}'
 ops['SE'+name]=f'n.p |= {mask}'
for op,reg in [('LDA','a'),('LDX','x'),('LDY','y')]: ops[op]=f'n.{reg} = nz(n, b)'
for op,reg in [('STA','a'),('STX','x'),('STY','y')]: ops[op]=f'write(n, addr, n.{reg})'
for op,reg in [('CMP','a'),('CPX','x'),('CPY','y')]: ops[op]=f'compare(n, n.{reg}, b)'
for op,dest,src in [('TAX','x','a'),('TAY','y','a'),('TXA','a','x'),('TYA','a','y'),('TSX','x','sp')]: ops[op]=f'n.{dest} = nz(n, n.{src})'
ops['TXS']='n.sp = n.x'
for op,reg,d in [('INX','x',1),('INY','y',1),('DEX','x',-1),('DEY','y',-1)]: ops[op]=f'n.{reg} = nz(n, n.{reg} + ({d}))'
for op,mask,on in [('BPL',128,False),('BMI',128,True),('BVC',64,False),('BVS',64,True),('BCC',1,False),('BCS',1,True),('BNE',2,False),('BEQ',2,True)]:
 ops[op]=f'if ((n.p & {mask}) {"!=" if on else "=="} 0) {{ cost += 1 + ((n.pc & 0xff00) != (addr & 0xff00) ? 1 : 0); n.pc = addr }}'
text='''options gen2
module cpu
require core public

// Generated from the checked-in official opcode table in tools/generate_cpu.py.
// Unsupported opcodes fail explicitly instead of silently corrupting state.
def cpu_step(var n : Nes) : int {
    if (n.stall > 0) { let c = n.stall; n.stall = 0; n.cycles += c; return c }
    if (n.nmi) { n.nmi = false; interrupt(n, 0xfffa, false); n.cycles += 7; return 7 }
    let op_pc = n.pc
    let op = fetch(n)
    var cost = 0
'''
reads={'ORA','AND','EOR','ADC','SBC','BIT','LDA','LDX','LDY','CMP','CPX','CPY','ASL','LSR','ROL','ROR','INC','DEC'}
rmw={'ASL','LSR','ROL','ROR','INC','DEC'}
handlers = {}
for code,op,mode,cycles in entries:
 lines=[f'cost = {cycles}']
 if modes[mode]: lines.append(modes[mode])
 if mode in ('abx','aby','izy') and op in reads-rmw: lines.append('if ((base & 0xff00) != (addr & 0xff00)) { cost++ }')
 if op in reads: lines.append('let b = n.a' if mode=='acc' else 'let b = read(n, addr)')
 if op in rmw and mode!='acc': lines.append('write(n, addr, b) // NMOS read-modify-write dummy write')
 if ops[op]: lines.append(ops[op])
 if op in rmw: lines.append('n.a = value' if mode=='acc' else 'write(n, addr, value)')
 handlers[int(code, 16)] = [f'// {op} {mode}'] + lines

def dispatch(low, high, indent):
    pad = ' ' * indent
    if high - low == 1:
        return ''.join(pad + line + '\n' for line in handlers.get(low, ['panic("Unsupported opcode {op} at PC {op_pc}")']))
    middle = (low + high) // 2
    return (pad + f'if (op < {middle}) {{\n' + dispatch(low, middle, indent + 4)
            + pad + '} else {\n' + dispatch(middle, high, indent + 4) + pad + '}\n')

text += dispatch(0, 256, 4)
text+='''
    n.cycles += cost
    return cost
}
'''
text = re.sub(r'0x[0-9a-fA-F]+', lambda m: str(int(m[0], 16)), text)
text = text.replace('addr', 'ea').replace('n.cycles += c;', 'n.cycles += int64(c);').replace('n.cycles += cost', 'n.cycles += int64(cost)')
Path(__file__).resolve().parents[1].joinpath('cpu.das').write_text(text, encoding='utf-8')
