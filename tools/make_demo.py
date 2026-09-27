from pathlib import Path

# Original NROM demo, no commercial assets. Writes a checkerboard CHR tile,
# palette, enables rendering, then changes background color in every NMI.
code = bytearray()
def emit(*bs): code.extend(bs)
def lda(v): emit(0xa9, v)
def sta(a): emit(0x8d, a & 255, a >> 8)
emit(0x78, 0xd8, 0xa2, 0xff, 0x9a) # SEI CLD LDX #$ff TXS
lda(0); sta(0x2000); sta(0x2001)
sta(0x2006); sta(0x2006)
for b in [0xaa,0x55]*4 + [0]*8:
    lda(b); sta(0x2007)
lda(0x3f); sta(0x2006); lda(0); sta(0x2006)
for b in [0x0f,0x21,0x16,0x30]: lda(b); sta(0x2007)
lda(0); sta(0x2005); sta(0x2005)
lda(0x80); sta(0x2000); lda(0x0a); sta(0x2001)
loop = 0x8000 + len(code)
emit(0x4c, loop & 255, loop >> 8)
nmi = 0x8000 + len(code)
emit(0x48,0xe6,0x00) # PHA INC $00
lda(0x3f); sta(0x2006); lda(1); sta(0x2006)
emit(0xa5,0x00,0x29,0x3f); sta(0x2007)
lda(0); sta(0x2005); sta(0x2005)
emit(0x68,0x40)
prg = code + bytes(16384-len(code))
for off, address in [(16378,nmi),(16380,0x8000),(16382,nmi)]:
    prg[off:off+2] = address.to_bytes(2,'little')
target = Path(__file__).resolve().parents[1] / 'demo.nes'
target.write_bytes(b'NES\x1a'+bytes([1,0])+bytes(10)+prg)
print(target)
