# 2.5vibeVic 1.0.0

Pipeline 2.5D autonoma e nativa VIC-20, derivata dall'esperimento qualificato
raycast-stock di 3Dvibe64. Non è l'intero engine poligonale 3Dvibe64 e non
richiede né modifica un'installazione di 3Dvibe64.

## Target e grafica

VIC-20, istruzioni documentate del 6502, VIC-I, **espansione da 24 KB nei blocchi
1/2/3**, PAL o NTSC riconosciuto all'avvio. Nessuna accelerazione o elaborazione
esterna. Il VIC-20 senza espansione **non è supportato**.

| Selezione di build | Immagine logica | Pareti | Pavimento |
|---|---:|---|---|
| `mono` | 128×96, 1 bit/pixel | bianco e retino statico bilanciato al 75% di bianco | scacchiera bianca/nera |
| `multicolor` | 64×96, 2 bit/pixel | ciano/ciano chiaro pieni | scacchiera nera/blu |

Entrambe occupano la stessa viewport fisica di 128×96 punti VIC, su 16×12 celle
carattere. I glifi vengono riscritti come un framebuffer: non sono una libreria
fissa di blocchetti. Il multicolor scambia dettaglio orizzontale con quattro
colori; solo il suo pavimento usa un retino. La modalità si sceglie durante la
build, non con un tasto durante l'esecuzione.

## Contenuto

- DDA reale su griglia: 32 raggi prospettici, FOV di 60°, 512 direzioni yaw.
- Rifinitura dei bordi protetta dalle discontinuità fra superfici diverse.
- Mappa binaria 32×32 monolivello, altezza uniforme dei muri e della camera.
- Movimento frazionario, collisioni con scorrimento, simulazione logica a 50 Hz.
- Due buffer schermo/charset; pubblicazione nel bordo di sole viste complete.
- Ambiente a gallerie, demo automatica e interattiva in entrambe le modalità:
  **quattro PRG, assembly generato completo, dati mappa e sorgenti JSON**.
- Builder host portabile, riferimento numerico, regressioni, guide memoria e assembly.

Il percorso delle gallerie dura 100,32 secondi logici e si chiude senza teletrasporti.
Comandi interattivi: **W/S** avanti/indietro, **A/D** rotazione; reset per uscire.
Il codice joystick è presente, ma non qualificato fisicamente. Non sono previsti
testi o FPS a schermo; il contatore delle viste complete è disponibile in RAM.

## Compilazione

Installare Python 3.10+ e 64tass, quindi dalla directory del pacchetto:

```text
python -B build.py --graphics mono --run auto --out ../vic-mono-auto
python -B build.py --graphics multicolor --run interactive --out ../vic-color-interactive
```

Gli output devono essere directory nuove, esterne all'SDK. `TASS64_EXE` può
sostituire l'assembler trovato nel PATH. Le build ordinarie non richiedono
dipendenze Python. Vedere [avvio rapido](QUICKSTART.it.md), [formato scene](docs/SCENE.it.md),
[pipeline](docs/PIPELINE.it.md), [memoria](docs/MEMORY.it.md),
[guida assembly](docs/ASSEMBLY-GUIDE.it.md) e [test](TESTING.it.md).

## Limiti e risultati misurati

Niente texture, mesh poligonali, illuminazione dinamica, muri ad altezze variabili,
porte con architrave, piani sovrapposti, rampe o sguardo verticale. I passaggi sono
varchi a tutta altezza nella mappa. Il contrasto delle pareti dipende dal loro
orientamento, non da una luce mobile.

Percorso automatico delle gallerie, xvic 3.10 stock, 20 secondi emulati dopo
2 secondi di riscaldamento, due ripetizioni: mono **8,15 FPS PAL / 7,40 NTSC**,
multicolor **8,45 PAL / 7,65 NTSC**. Sono medie della finestra misurata, non
un minimo garantito né valori validi per qualsiasi mappa. Vedere la
[qualificazione](docs/QUALIFICATION.it.md). **Hardware reale non ancora testato**;
PAL e NTSC sono qualificati separatamente in emulazione.

## Licenza

Copyright © 2026 librologica.digital. Codice, scene e demo generate:
PolyForm Noncommercial 1.0.0. Documentazione: CC BY-NC 4.0. L'uso commerciale
richiede una licenza separata. Non sono distribuiti strumenti esterni o ROM.
Vedere [LICENSE](LICENSE), [licenza documentazione](LICENSE-DOCUMENTATION.md), [NOTICE](NOTICE.md).
