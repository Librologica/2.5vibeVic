# Qualificazione riproducibile

Usare un SDK estratto pulito e una **nuova directory di output esterna**. L'SDK
non deve cambiare. Gli entry point disabilitano i bytecode Python; per comandi
diretti usare `-B`. Dipendenze opzionali: `pip install -r requirements-tests.txt`.

```text
python -B scripts/verify_package.py
python -B scripts/run_tests.py --out ../vic-host-tests
python -B scripts/run_tests.py --out ../vic-native-tests --native --tour
```

`--graphics mono` o `--graphics multicolor` limita i test numerici/nativi; il
contratto pubblico ricompila comunque tutti e quattro i riferimenti. Senza
`--native` i test nativi risultano esplicitamente NOT RUN. `--tour` aggiunge
catture PAL/NTSC dell'intero percorso. Servono 64tass per le build e xvic per i
test nativi. `TASS64_EXE`/`XVIC_EXE` sostituiscono gli eseguibili nel PATH.
Dipendenze mancanti/errori producono un codice d'uscita non zero, mai un PASS.
La sintassi monitor è qualificata su VICE 3.10.

La suite esegue:

- 14 contratti pubblici: schema, valori invalidi, rifiuto output dentro i sorgenti,
  quattro hash PRG esatti e confini della memoria generata.
- Per modalità: 171 pose / 5.472 raggi / 342 buffer charset eseguendo le reali
  istruzioni assemblate con py65; 4.000 tick di simulazione casuale.
- Tutte le 2.401 coppie di altezze e 10 controlli di discontinuità per modalità.
- Verifica indipendente per campione di 98 strisce e 63 pose del giro; connessione
  della mappa, moto senza collisioni e chiusura esatta dopo 5.016 tick.
- Per modalità/standard: 120 viste complete consecutive e 16 campioni dell'intero
  percorso, se richiesti. Confronto descriptor, profondità, posa acquisita, schermo,
  charset, Color RAM, registri VIC e traiettoria della simulazione.
- Quattro uscite video per modalità (entrambi i buffer, PAL/NTSC); due calibrazioni
  multicolor indipendenti con bande codice. Pixel visibili completi, non sola Screen RAM.
- Cinque stati tastiera per standard/modalità: nessuno, W, S, A, D, tramite matrici native.

Benchmark automatico, VIC-20 stock +24KB, 2 secondi di riscaldamento e 20 secondi
misurati, due ripetizioni per modalità/standard. Il warp accelera solo il test host;
gli FPS usano pubblicazioni complete e clock emulati. I trace non aggiungono codice
profiler nel guest. Record duplicati trace/break del monitor vengono deduplicati.
Il conteggio IRQ include prologo/epilogo nativi. Trace, dump, snapshot, catture e
metriche JSON restano esclusivamente nella directory esterna dei test.

Criterio numerico: assembly/modello fixed esatti; errore continuo di profondità
fuori dai corner inferiore a 0,2 celle (massimo osservato 0,0703125). Ambiguità di
corner/lato sono elencate separatamente, mai nascoste in una tolleranza. I contatori
frame/tick fanno wrap a 65536; i test inclusi terminano prima.

Su hardware verificare separatamente: mappatura/caricamento 24KB, entrambi gli
standard disponibili, entrambe le modalità, giro completo compreso riavvio,
tastiera/joystick, assenza di tearing e stabilità del pavimento. Registrare
macchina, video, espansione e foto/catture. Il PASS emulato non è un PASS hardware.
