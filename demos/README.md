# Demo PRGs / Demo PRG

All four require VIC-20 +24 KB, blocks 1/2/3. Each supports PAL and NTSC.
Tutte richiedono VIC-20 +24 KB, blocchi 1/2/3. Ciascuna supporta PAL e NTSC.

| Graphics / Grafica | Automatic / Automatica | Interactive / Interattiva |
|---|---|---|
| Mono 128×96 | [PRG](galleries-mono-auto.prg) | [PRG](galleries-mono-interactive.prg) |
| Multicolor 64×96 | [PRG](galleries-multicolor-auto.prg) | [PRG](galleries-multicolor-interactive.prg) |

W/S forward/back, A/D turn; reset exits. Automatic tour: 100.32 logical seconds.
W/S avanti/indietro, A/D rotazione; reset per uscire. Giro automatico: 100,32 secondi logici.

`source/<demo-name>/` contains the complete generated `vibe20.asm`, `map.bin`
and `scene.json`. Copy a folder outside the SDK and assemble with 64tass;
see [Quick start](../QUICKSTART.md). Runtime hashes: [REFERENCE.json](../tests/REFERENCE.json).

`source/<nome-demo>/` contiene `vibe20.asm` completo, `map.bin` e `scene.json`.
Copiare una cartella fuori dall'SDK e assemblare con 64tass; vedere la guida rapida.
Le demo rappresentano lo stato qualificato attuale, non gli esperimenti superati.
