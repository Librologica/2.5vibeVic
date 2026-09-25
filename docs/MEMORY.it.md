# Mappa memoria

6502/VIC-I nativi. Necessari i blocchi espansione 1/2/3 ($2000–$7FFF). Non viene
usata l'espansione $A000 né quella bassa da 3 KB. Il VIC legge la RAM base
$1000–$1FFF; la RAM espansa contiene codice, mappa e tabelle letti dalla CPU.
Non valgono le assunzioni C64 relative a banca $DD00, puntatore $D018 o porta $01.

| Area | Intervallo inclusivo | Byte |
|---|---|---:|
| Stato zero-page main/IRQ, inclusi vuoti | $0020–$0092 | 115 riservati |
| Stack CPU | $0100–$01FF | 256 |
| 32 puntatori striscia, due piani | $0200–$023F | 64 |
| Vettori sistema, incluso IRQ $0314 | $0300–$0333 | 52 protetti |
| Coda bordi sparsi, buffer cassetta riutilizzato | $0380–$03FF | 128 riservati |
| Charset A | $1000–$15FF | 1536 |
| Schermo A | $1600–$17FF | 512, 192 visibili |
| Charset B | $1800–$1DFF | 1536 |
| Schermo B | $1E00–$1FFF | 512, 192 visibili |
| Codice + tabelle bordi | $2000–low_end-1 | secondo variante |
| Descriptor raggi e stato bordi | $3A00–$3BBF | 448 riservati |
| Mappa | $3C00–$3FFF | 1024 |
| Strisce, puntatori, moto, LUT prodotti, padding | $4000–$6EFF | 12032 |
| Reciproci direzioni/segni | $7000–$79FF | 2560 |
| LUT proiezione | $7C00–$7FFF | 1024 |
| Color RAM | $9600–$97FF | 512 nibble |

Il PRG si carica a $1201, avvia `SYS8192` e termina a $7FFF: **28.161 byte**,
inclusi indirizzo di caricamento a due byte e padding. L'inizializzazione video
riutilizza lo stub BASIC dentro il charset A. La dimensione file non è quella del codice.

| Variante | Codice | LUT bordi | Codice+LUT | Margine prima di $3A00 | Vuoti espansione non contigui |
|---|---:|---:|---:|---:|---:|
| Mono auto | 5034 | 1028 | 6062 | 594 | 1426 |
| Mono interattiva | 5110 | 1028 | 6138 | 518 | 1350 |
| Multicolor auto | 4983 | 706 | 5689 | 967 | 1799 |
| Multicolor interattiva | 5059 | 706 | 5765 | 891 | 1723 |

Il totale dei vuoti include 64 byte dopo i descriptor, 256 dopo le tabelle e
512 dopo le direzioni. Non costituisce un'unica area disponibile. Il multicolor
recupera 373 byte sul mono senza allocare altri buffer. Le tabelle delle gallerie
includono 16 comandi percorso; percorsi più lunghi possono modificare il padding.

Profondità low/high: $3A00/$3A20; lato $3A40; passi $3A60; flag pieno $3A80;
distanza grezza low/high $3AA0/$3AC0. Ogni array ha 32 byte. Chiave parete $3AE0;
cella lungo muro $3B00; top $3B20; top rifiniti $3B40 (128 mono, 64 multicolor).
Solo 124/62 voci della coda bordi possono essere attive. Le riserve restano fisse.

Selettore draw-buffer $70, contatore frame completi $78/$79, tick logici $7A/$7B,
standard video $7C (1 PAL, 0 NTSC). Camera attuale $20/$22/$24; posa acquisita
$26/$28/$2A. Leggere atomicamente i valori live multibyte aggiungendo diagnostica.
Frame e tick fanno wrap a 65536; i test pubblici restano prima del wrap.

L'assembler controlla i confini codice/tabelle; i test verificano label, indirizzo
finale e PRG di riferimento esatti. Le code schermo restano $FF, Color RAM
inizializzata una volta; il renderer non tocca vettori di sistema o charset visualizzato.
Nessun codice automodificante. Scratch IRQ e renderer sono separati. Non chiamare
servizi KERNAL del nastro né presumere conservata l'area di lavoro BASIC durante la demo.
