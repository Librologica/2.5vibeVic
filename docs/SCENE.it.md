# Scene e metriche del mondo

L'esempio completo valido è [galleries.json](../examples/galleries.json).
Non vengono usati file immagine o importatori di texture. La radice deve contenere:

| Campo | Contratto |
|---|---|
| `schema` | `"2.5vibeVic-scene-v1"` |
| `size` | `[32,32]` |
| `grid` | 1.024 interi 0 o 1, array piatto per righe `y*32+x`; tutti i bordi a 1 |
| `initial` | `[xQ8.8,yQ8.8,yaw]`; tre interi, X/Y 0..8191, yaw 0..511 |
| `wallHeight` | intero 2 celle, fisso in questa release |
| `eyeHeight` | intero 1 cella, fisso |
| `fov` | intero 60 gradi, fisso |
| `rays` | intero 32, fisso |
| `autoRoute` | 1..32 comandi `[keys,ticks]`; durata 1..65535 a 50 tick/s |

`keys`: 0 fermo, 1 avanti, 2 indietro, 4 sinistra, 8 destra; combinazioni 5/9/6/10
per muoversi e ruotare insieme. Avanti/indietro o sinistra/destra contemporanei
sono respinti. Il percorso si ripete. È richiesto anche nelle build interattive
(dove non genera l'input automatico), per condividere un unico contratto sorgente.
Il movimento rispetta sempre le collisioni; il builder non garantisce che un
percorso utente sia libero o si chiuda esattamente. Quello incluso verifica entrambi.

X/Y in celle = valore salvato/256. Yaw 0 guarda +Y, 128 +X, 256 -Y, 384 -X.
La riga zero è la prima riga del JSON; nessuna scala metrica implicita o conversione
della vecchia camera 3D. `[1408,1664,0]` significa (5,5; 6,5), direzione +Y.
Il quadrato iniziale con semilato 48/256 deve essere libero. Tutti i muri hanno
altezza 2 e la camera resta ad altezza 1. Una porta è solo un varco a tutta
altezza nella mappa, non una struttura con architrave.

Copiare l'esempio fuori dall'SDK, modificare celle e percorso, usare `--scene`.
Campi sconosciuti, booleani al posto di interi, dimensioni/materiali invalidi,
partenze bloccate e comandi fuori dominio vengono respinti. Nessuna riduzione
silenziosa di precisione/raggi. Anche 64tass respinge le sovrapposizioni del layout.
Il limite di 32 comandi è un budget pubblico deliberato, non la garanzia che
nuovo codice grafico arbitrario entri in RAM. La palette è scelta dal backend
grafico e non è un campo scena in 1.0.0.
