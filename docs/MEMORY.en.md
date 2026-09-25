# Memory map

Native 6502/VIC-I. Expansion blocks 1/2/3 ($2000–$7FFF) are mandatory. No $A000
expansion or 3 KB low expansion is used. The VIC reads the unexpanded $1000–$1FFF
RAM; expanded RAM contains code, map and tables read by the CPU. No C64-style
$DD00 bank, $D018 pointer or $01 CPU-port assumptions apply here.

| Area | Inclusive address range | Bytes |
|---|---|---:|
| Main/IRQ zero-page state, including gaps | $0020–$0092 | 115 reserved |
| CPU stack | $0100–$01FF | 256 |
| 32 strip pointers, two planes | $0200–$023F | 64 |
| System vectors, including IRQ $0314 | $0300–$0333 | 52 protected |
| Sparse edge queue, repurposed cassette buffer | $0380–$03FF | 128 reserved |
| Charset A | $1000–$15FF | 1536 |
| Screen A | $1600–$17FF | 512, 192 visible |
| Charset B | $1800–$1DFF | 1536 |
| Screen B | $1E00–$1FFF | 512, 192 visible |
| Code + edge tables | $2000–low_end-1 | variant-dependent |
| Ray descriptors and edge state | $3A00–$3BBF | 448 reserved |
| Map | $3C00–$3FFF | 1024 |
| Strips, pointers, movement, multiply LUT, padding | $4000–$6EFF | 12032 |
| Direction reciprocals/signs | $7000–$79FF | 2560 |
| Projection LUT | $7C00–$7FFF | 1024 |
| Color RAM | $9600–$97FF | 512 nibbles |

The PRG loads at $1201, runs `SYS8192` and ends at $7FFF: **28,161 bytes** including
the two-byte load address and padding. Video initialization reclaims the BASIC
stub area inside charset A. This file size is not the runtime code size.

| Variant | Code | Edge LUT | Code+LUT | Gap before $3A00 | Non-contiguous expansion gaps |
|---|---:|---:|---:|---:|---:|
| Mono auto | 5034 | 1028 | 6062 | 594 | 1426 |
| Mono interactive | 5110 | 1028 | 6138 | 518 | 1350 |
| Multicolor auto | 4983 | 706 | 5689 | 967 | 1799 |
| Multicolor interactive | 5059 | 706 | 5765 | 891 | 1723 |

The expansion-gap total includes 64 bytes after descriptor reserve, 256 after the
table segment and 512 after directions. It is not one contiguous allocation.
Multicolor recovers 373 bytes relative to mono, without allocating another buffer.
The gallery table size includes its 16 route commands; longer routes may change padding.

Depth low/high: $3A00/$3A20; side $3A40; steps $3A60; solid flag $3A80; raw
distance low/high $3AA0/$3AC0. Each array has 32 bytes. Face key $3AE0; along-wall
cell $3B00; top $3B20; refined tops $3B40 (128 mono, 64 multicolor).
Only 124/62 edge queue entries can be active. The full reserved areas remain fixed.

Draw-buffer selector $70, complete-frame counter $78/$79, logical ticks $7A/$7B,
video standard $7C (1 PAL, 0 NTSC). Live camera $20/$22/$24; latched pose
$26/$28/$2A. Multi-byte live values must be read atomically if adding diagnostics.
Frame/tick counters wrap at 65536; the public capture tests stay below the wrap.

The assembler checks code/table boundaries; release tests verify labels, final
address and exact reference PRGs. Screen tails remain $FF, Color RAM is initialized
once, and rendering never touches system vectors or the other displayed charset.
There is no self-modifying code. IRQ scratch and main-render scratch are separate.
Do not call KERNAL tape services or assume BASIC workspace survives during the demo.
