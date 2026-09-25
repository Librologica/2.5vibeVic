# Avvio rapido

## Avviare una demo inclusa

Usare VICE **xvic**, non x64sc. Configurare l'espansione da 24 KB: blocchi RAM
**1, 2 e 3**, $2000–$7FFF. Lasciare disabilitati il blocco da 3 KB e il blocco 5
per riprodurre la configurazione qualificata. Scegliere PAL o NTSC. La pagina
generale del pattern di reset RAM non seleziona l'espansione: usare i controlli
di espansione VIC-20 o la riga di comando seguente.

```text
xvic -default -pal -memory 24k -autostartprgmode 1 demos/galleries-mono-auto.prg
xvic -default -pal -memory 24k -autostartprgmode 1 demos/galleries-multicolor-interactive.prg
```

Per NTSC sostituire `-pal` con `-ntsc`. La visione normale non richiede warp.
Ogni PRG gestisce entrambi gli standard. W/S movimento, A/D rotazione. Reset per
uscire. Le versioni automatiche e interattive partono dalla stessa posa.

Su hardware usare un'espansione che mappi gli stessi tre blocchi da 8 KB,
caricare il PRG al suo indirizzo salvato ($1201) con caricamento binario, quindi
`RUN` (BASIC `SYS8192`). Eseguire reset/ricaricamento dopo cambi di mappatura.
La demo assume il controllo di timer/IRQ VIA2 e dell'area buffer cassetta;
non sono disponibili servizi nastro durante l'esecuzione. Verificare sul proprio
hardware: questa distribuzione è qualificata soltanto in emulazione.

## Compilare e personalizzare

Installare Python 3.10+ e 64tass nel PATH (qualificati: Python 3.13.14 e 64tass
1.60.3243). In alternativa impostare `TASS64_EXE` al percorso dell'assembler.

```text
python -B build.py --graphics mono --run interactive --out ../build-vic-mono
python -B build.py --graphics multicolor --run auto --scene examples/galleries.json --out ../build-vic-color
```

Aprire `vibe20.prg` nella directory di output. Sono prodotti anche `vibe20.asm`,
`map.bin`, `scene.json`, `labels.txt`, `listing.txt`, `memory.map`, `build.json`
e `assembler.log`. Non vengono sovrascritte directory esistenti. Compilare fuori
dall'SDK e copiare il JSON nel proprio progetto per modificare mappa/percorso.
Vedere il [contratto scene](docs/SCENE.it.md).

Per assemblare direttamente il sorgente completo distribuito, copiare una
cartella `demos/source` in una directory di lavoro esterna ed eseguire lì:

```text
64tass -a -B --m6502 -o rebuilt.prg vibe20.asm
```

Tenere `map.bin` accanto all'ASM. Confrontare con il PRG corrispondente incluso.
Non inserire listing generati o artefatti di sviluppo dentro questa release.
