# Qualificazione release 1.0.0 — 2026-09-25

## Esito

**PASS in emulazione VIC-20 stock, PAL e NTSC, +24 KB.** I quattro PRG pubblici
sono byte-identici alle demo gallerie mono/multicolor già qualificate. Il
packaging ha modificato entry point host, percorsi, validazione scena/percorso
e runner pubblico; nessuna modifica all'ASM dei renderer o al comportamento runtime.

Risultati del runner pubblico da build pulite:

| Controllo | Risultato |
|---|---|
| Contratti pubblici / ricompilazione riferimenti | 14/14; tutti e quattro gli SHA-256 esatti |
| 6502 eseguito contro modello fixed | 342 pose, 10.944 raggi, 684 buffer framebuffer; zero differenze |
| Simulazione | 8.000 tick casuali totali; zero differenze |
| Interpolazione bordi | 4.802 coppie di altezze + 20 guardie; zero differenze |
| Viste native | 544 totali: 120 + 16 per backend/standard; zero differenze descriptor/framebuffer |
| Uscita video nativa | 8 catture, entrambi i buffer e standard; zero pixel visibili differenti |
| Calibrazione multicolor indipendente | PAL e NTSC PASS, tutti e quattro i codici a due bit |
| Matrici tastiera native | 20 casi totali PASS |
| Percorso automatico completo | 100,32 secondi, chiusura esatta, nessun moto bloccato, entrambi gli standard |
| Oracolo geometrico continuo | errore massimo non ambiguo 0,0703125 celle, sotto il limite fisso 0,2 |
| Ambiguità corner/lato | 27 casi per backend conservati separatamente nei risultati numerici grezzi |
| Macchina fisica / joystick fisico | **NON TESTATI** |

Le viste native non includono gli snapshot sorgente dell'input o le calibrazioni
colore. Sono test deterministici alle pose corrispondenti, non semplici schermate
di scene simili. I riferimenti precedenti non sono stati modificati per nascondere differenze.

## Prestazioni misurate della demo automatica

xvic 3.10, mappatura 24KB, CPU/VIC-I stock, palette native predefinite, UI assente.
Due prove per voce; ogni finestra misura 20 secondi emulati dopo 2 di riscaldamento.
Il warp accelera solo l'host. Gli FPS contano nuove viste complete pubblicate.

| Modalità | Standard | Viste / 20 s | FPS | Cicli medi/vista | p95 | Peggiore |
|---|---|---:|---:|---:|---:|---:|
| Mono | PAL | 163 | 8,15 | 136445 | 155066 | 155071 |
| Mono | NTSC | 148 | 7,40 | 138013 | 152688 | 153216 |
| Multicolor | PAL | 169 | 8,45 | 131470 | 150846 | 155068 |
| Multicolor | NTSC | 153 | 7,65 | 133170 | 152411 | 152953 |

Tabella della prima ripetizione; nella seconda conteggi pubblicazioni identici,
con piccole differenze di fase IRQ NTSC (p95 multicolor 152420). Sono medie
della finestra del percorso, non minimi garantiti o medie dell'intero giro. PAL
e NTSC usano clock nativi differenti: entrambi stock, non simulazioni a frequenza uguale.

Cicli medi delle fasi PAL (IRQ esclusi dalle fasi rendering):

| Fase | Mono | Multicolor |
|---|---:|---:|
| Geometria | 68709 | 68762 |
| Selezione strisce + setup bordi | 7964 | 6813 |
| Composizione + correzione sparsa bordi | 47983 | 45531 |
| Attesa presentazione | 7081 | 5825 |
| IRQ inclusa simulazione | 4611 | 4443 |

Piccole differenze fra somma fasi e intervalli frame derivano da loop/acquisizione
posa. Latenza media posa acquisita-pubblicazione: circa 123 ms mono PAL e
119 ms multicolor PAL. Non è una misura distinta con input utente iniettato.
Nessuna nuova ottimizzazione introdotta durante il packaging.

## Riproduzione e limiti

Vedere [TESTING](../TESTING.it.md). Strumenti qualificati: Python 3.13.14,
64tass 1.60.3243, VICE 3.10, py65 1.2.0 e Pillow. Dump/trace e controlli degli
inventari originali restano fuori dall'SDK. Il pacchetto contiene gli script
per riprodurli. `PACKAGE-MANIFEST.json` identifica file permanenti, hash builder,
sorgenti e demo; `MANIFEST.sha256` copre tutti i file permanenti escluso se stesso.

Uscite VIC ispezionate: retino bilanciato sui muri e scacchiera pavimento nel mono;
muri multicolor ciano pieni e retino solo sul pavimento. Nessuna dichiarazione
di dettaglio geometrico superiore ai 32 raggi, assenza di quantizzazione o
compatibilità su macchina reale dimostrata fisicamente.
