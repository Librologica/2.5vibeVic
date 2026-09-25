# Pipeline nativa VIC-20

## Flusso di un frame

1. Copia atomica della camera attuale in una posa separata per il rendering.
2. Lancio di 32 raggi attraverso la mappa binaria mediante DDA fixed-point.
3. Correzione della distanza perpendicolare al piano camera; scelta di altezza e lato.
4. Selezione delle strisce generate sull'host; rifinitura bordi solo sulla stessa parete.
5. Composizione dei 1.536 byte del charset inattivo e correzioni sparse dei bordi.
6. Attesa del bordo inferiore, cambio di $9005 e incremento del contatore viste complete.

L'IRQ aggiorna la camera durante il rendering, ma mai la posa acquisita, i
puntatori video o lo scratch del renderer. Nessuna vista con pose miste, colonne
alternate, ricostruzione temporale o accelerazione. È raycasting, non fill di triangoli.

## Geometria e contratto numerico

Mappa 32×32, un byte per cella: 0 libero, 1 pieno. Ogni raggio avanza al prossimo
confine X/Y più vicino. In caso di parità esatta viene scelto prima X. I raggi
assiali usano la sentinella reciproca $FFFF sull'asse inattivo. Le somme saturano,
non fanno wrap. L'attraversamento termina al primo muro, al bordo della mappa
o dopo 64 passi; il fallimento produce materiale zero e distanza satura, non una
lettura fuori mappa. Il parser richiede bordi pieni e una partenza libera dalle collisioni.

| Quantità | Rappresentazione / dominio |
|---|---|
| Camera X/Y | Q8.8 unsigned in celle; posizione scena 0..8191, mappa 0..31 |
| Collisione giocatore | quadrato con semilato 48/256 cella, verificato separatamente su X e Y |
| Yaw | angolo a 9 bit 0..511; 0 = +Y; rotazione positiva verso +X |
| Movimento | delta tabulati signed arrotondati, massimo 6/256 cella per tick; rotazione ±2 unità |
| Delta DDA e distanza | Q8.8 unsigned a 16 bit, saturazione a 65535 |
| Proiezione | distanza>>4, intervalli da 1/16 cella, 1.024 voci campionate al centro |
| Bordo superiore proiettato | intero 0..48; confine inferiore 96-top |

Per il raggio c, l'host calcola `round(atan(((2*c+1)/32-1)*tan(30°))*512/(2*pi))`.
I raggi usano quindi un piano camera prospettico, non angoli equidistanti. I
reciproci delle direzioni sono arrotondati sull'host. I prodotti usano la
moltiplicazione esatta quarter-square ereditata; la correzione della distanza usa
il coseno precalcolato e troncamento intero. Il modello fixed corrisponde al 6502
eseguito, mentre un oracolo geometrico separato enumera le intersezioni con i piani
della griglia. Quantizzazione e ambiguità dei corner sono riportate separatamente:
non si dichiara equivalenza esatta con la geometria continua.

L'altezza viene tabulata dall'host usando focale orizzontale `64/tan(30°)`,
semialtezza muro di 1 cella e centro dell'intervallo di distanza. Sono presenti
49 altezze per lato. I muri vicini vengono ritagliati simmetricamente nella viewport;
non viene stirata una texture. Oltre la tabella viene usata l'ultima voce. La
scala della mappa rientra nel dominio utile. Il byte materiale indica qui solo
pieno/libero. Non vengono emessi calcoli di texture U/V, mesh o luce dinamica.

## Rifinitura dei bordi e strisce

Ogni raggio conserva una chiave `(hitPlane*4)|(side*2)|normalSign` e la cella lungo
la parete. Due raggi adiacenti interpolano solo se entrambi colpiscono, le chiavi
coincidono e le celle lungo la parete differiscono al massimo di uno. Il controllo
evita di fondere piani diversi, lati opposti e molte discontinuità nei passaggi;
non recupera geometria che i 32 raggi non hanno intercettato.

Il mono assegna inizialmente quattro pixel/raggio e interpola con pesi 1/8, 3/8,
5/8, 7/8 fra i centri dei raggi. Il multicolor assegna due campioni/raggio e usa
1/4, 3/4. Le altezze superiori sono arrotondate all'intero più vicino, con parità
verso +infinito; quelle inferiori sono speculari. Le LUT coprono differenze -48..48.
Solo i campioni modificati entrano nella coda di patch (massimo 124 mono / 62
multicolor). I campioni estremi mantengono il risultato del raggio. Le silhouette
verticali di occlusione restano limitate dal numero dei raggi.

Le strisce host contengono soffitto, muro e pavimento per 96 scanline:
49×2×96 = 9.408 byte. Per ogni colonna carattere il compositore svolto prende
il nibble alto di una striscia e quello basso della successiva, li combina con OR
e scrive un byte di glifo. Le due destinazioni hanno percorsi generati distinti.
La correzione sparsa interviene poi soltanto sui campioni di bordo modificati.

## Rappresentazione VIC-I

Le 16×12 celle usano i codici carattere 0..191. Un'immagine occupa 192×8 = 1.536
byte di charset. I codici schermo restano fissi; i glifi sono dinamici. Le due
coppie schermo/charset vengono pubblicate con $9005=$DC/$FE. La Color RAM è
inizializzata una volta. È un framebuffer software realizzato con caratteri,
**non una modalità bitmap VIC-II**.

Il mono usa caratteri hires normali, Color RAM 1 e $900F=$08. I colori reali
sono nero e bianco. L'orientamento in ombra usa il retino bilanciato 8×8
`77 DD 7B EE BB ED B7 DE`: 75% bianco, due pixel neri per riga e colonna,
nessuna adiacenza nera orizzontale/verticale anche ai confini della tessera.
Il pavimento alterna $AA/$55. Retini statici, ancorati alle coordinate schermo.

Il multicolor usa Color RAM $0B, $900E=$B0 e $900F=$68:

| Codice | Registro/origine | Colore VIC |
|---|---|---|
| 00 | sfondo | blu 6 |
| 01 | bordo | nero 0 |
| 10 | colore individuale del carattere | ciano 3 |
| 11 | colore ausiliario | ciano chiaro 11 |

Ogni campione a due bit occupa due punti fisici orizzontali. I muri usano solo
10/11 senza retino. Il pavimento alterna 00/01 (scanline $44/$11). Bordo e
colore individuale accettano 0..7; sfondo e ausiliario 0..15. La palette pubblica
1.0.0 è fissa. La resa dipende dal modello VIC/palette dell'emulatore; il blu PAL
può apparire violetto. Il VIC-I non dispone di grigi neutri intermedi. I bit di
volume del registro ausiliario rimangono zero.

## Temporizzazione, input e pubblicazione

L'avvio misura il wrap raster soltanto dopo essere uscito dalla riga zero.
Il timer VIA2 produce circa 50 tick logici/s: PAL 1.108.405 Hz con reload 22.166;
NTSC 1.022.727 Hz con reload 20.453. Ogni tick legge l'input ed esegue un singolo
movimento limitato e verificato dalle collisioni. La velocità non dipende dagli
FPS, entro la precisione del timer.

L'entrata IRQ del KERNAL salva i registri; il gestore personalizzato attraverso
$0314 li ripristina e ritorna senza il tick KERNAL normale. La scansione tastiera
VIA è trasposta rispetto al codice CIA originario. W/S/A/D sono qualificati con
le matrici tastiera native di VICE. Il joystick fisico resta da verificare.

La pubblicazione attende $9004≥126 (raster 252 o successivo). L'IRQ non modifica
i puntatori VIC. $9005 cambia soltanto quando l'immagine inattiva è completa.
Nessun limite FPS artificiale oltre alla presentazione sicura. A bassi FPS la
latenza posa-schermo comprende un intero intervallo di rendering. Non sono
presenti overlay FPS o split testuali.

## Provenienza e limiti

`reference/raycast.asm`, `simulation.asm`, `multiply.asm` conservano le routine
standalone originarie. L'emettitore elimina l'output UV/texture a 80 raggi e
adatta indirizzi/input al VIC-I. Video/IRQ/bordi nativi sono in `asm/runtime.asm`
ed `edges.asm`. I sorgenti mono e multicolor restano separati deliberatamente
per conservare i byte qualificati. L'ASM completo delle demo è il codice
effettivamente assemblato: i nomi UV inutilizzati nei template originari non
indicano supporto texture nel PRG.

Niente altezze programmabili, architravi, visibilità multilivello, portali,
clipping poligonale, luci dinamiche, texture, sprite, superfici perspective-correct
o riproduzione audio. Nessun cambio di modalità grafica runtime. Il margine RAM
è ridotto: estensioni del renderer richiedono una nuova qualificazione, non
soltanto l'aumento delle costanti della scena.
