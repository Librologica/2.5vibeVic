# Guida sorgenti e assembly

`build.py` è l'entry point pubblico. Verifica il contratto scena e l'output esterno,
poi carica un solo emettitore. La build richiede solo libreria standard Python
e 64tass; il runtime è interamente codice 6502.

| Sorgente, sotto `src/mono` o `src/multicolor` | Ruolo |
|---|---|
| `host/model.py` | riferimento fixed, oracolo continuo indipendente, tabelle proiezione/direzioni/strisce |
| `host/build.py` | specializzazione ASM, adattamento codice ereditato, assembler e controlli dimensione |
| `asm/runtime.asm` | boot, video nativo, timer IRQ VIA, presentazione e selezione strisce |
| `asm/edges.asm` | controlli stessa superficie, interpolazione, patch sparse dei bordi |
| `reference/raycast.asm` | template DDA originario, adattato prima dell'emissione |
| `reference/simulation.asm` | template movimento/collisioni, input sostituito con quello nativo |
| `reference/multiply.asm` | prodotti unsigned esatti quarter-square |
| `host/test_*.py`, `qualify.py`, `vice.py` | test CPU e nativi richiamati dal runner pubblico |

I due alberi duplicano deliberatamente le piccole parti condivise, evitando
refactoring del codice qualificato durante il packaging. Non sono engine con
metriche diverse. I test pubblici provano l'identità delle funzioni geometria e
simulazione. Non importare entrambi i moduli `model` nello stesso processo Python:
i runner li isolano in processi distinti.

Entry point generati principali: `entry`, `detect_standard`, `init_video`,
`irq`, `simulation_tick`, `latch_pose`, `raycast_all`, `select_strips`,
`prepare_edges`, `compose`, `refine_edges`, `presentation_done`.
`labels.txt` e `listing.txt` espongono gli indirizzi della singola build.

La generazione rimuove prodotti/output UV ereditati, riduce a 32 i descriptor,
emette caricamento nativo delle direzioni e sostituisce input CIA con VIA.
`composer()` genera un corpo svolto di 96 righe per ciascun buffer. È intenzionale:
i reference ASM sono input, non programmi VIC-20 direttamente assemblabili.
Il sorgente completo delle demo è autonomo, salvo `map.bin` adiacente.
Assemblarlo con `64tass -a -B --m6502`.

Nessuna istruzione non documentata, SMC o patch ROM. Il PRG usa la convenzione
IRQ del KERNAL nativo, ma non chiama BASIC durante il rendering. Il codice deve
restare 6502: abilitare opcode 65C02 non è un'opzione di ottimizzazione.
L'engine assume il controllo delle aree zero page/video/IRQ documentate. È un SDK
renderer/demo, non un'ABI applicativa rientrante né un game engine completo.

Per sperimentare creare una copia separata. Modifiche a renderer/tabelle possono
invalidare hash e contratti numerici/nativi: non riscrivere gli hash congelati
per nascondere differenze. Cambiare mappa/percorso è una variazione intenzionale
della scena, ma richiede controlli collisioni, limiti, resa e tempi per quella scena.
Nessuna dipendenza da un SDK C64 installato. Non modificare le altre release native.
