# DLSS 5 Neural Rendering on AMD Radeon — Football Life 2026 / PES 2021

Guida, impostazioni tarate e installatore per far girare il **DLSS 5 Neural Rendering** su schede **AMD Radeon** in **Football Life 2026** e **PES 2021**, convivendo con **sider** e con tutte le patch attive.

Guide, tuned settings and an installer to run **DLSS 5 Neural Rendering** on **AMD Radeon** cards in **Football Life 2026** and **PES 2021**, living happily next to **sider** and all its patches.

by **oLd_pZ**

---

## ⚠️ Leggi prima / Read this first

- **Questa mod NON aumenta gli fps: LI FA CALARE.** Cambia la resa dell'immagine, non la velocità. Misurato su RX 9070 XT a 2560x1440, nei menu, con la v1.5 del pacchetto (runtime 0.3.0): **~500 fps** a effetto spento, **20-31 fps** con l'effetto acceso. Con la v1.6 (runtime 0.4.3, molto più veloce): **[DA MISURARE]**.
- Serve una **Radeon RX 7000 (RDNA 3)** o **RX 9000 (RDNA 4)**. Su NVIDIA è inutile (hanno il DLSS vero), su AMD più vecchie non funziona.
- **Solo offline.** Prima di myClub o dell'online, disinstalla: spegnere l'effetto non basta.

<!-- -->

- **This mod does NOT raise your fps: it LOWERS them.** It changes how the image looks, not how fast it runs. Measured on an RX 9070 XT at 2560x1440, in the menus, with pack v1.5 (runtime 0.3.0): **~500 fps** with the effect off, **20-31 fps** with it on. With v1.6 (runtime 0.4.3, much faster): **[TO BE MEASURED]**.
- You need a **Radeon RX 7000 (RDNA 3)** or **RX 9000 (RDNA 4)**. Pointless on NVIDIA (they have real DLSS), does not work on older AMD cards.
- **Offline only.** Uninstall before myClub or online play: switching the effect off is not enough.

---

## Installazione / Install

1. Scarica lo zip dalla pagina [Releases](../../releases) ed estrailo dove vuoi.
2. Doppio clic su **`INSTALLA - INSTALL.bat`** e premi INSTALLA.
3. In partita: **HOME** apre il pannello di ReShade, **CTRL+FINE** accende l'effetto (parte spento).

Se preferisci fare tutto a mano, o se l'installatore si ferma, la procedura completa passo per passo è in **`LEGGIMI - ITALIANO.txt`** / **`READ ME - ENGLISH.txt`**.

<!-- -->

1. Download the zip from the [Releases](../../releases) page and extract it anywhere.
2. Double-click **`INSTALLA - INSTALL.bat`** and press INSTALL.
3. In game: **HOME** opens the ReShade panel, **CTRL+END** switches the effect on (it starts off).

Prefer doing it by hand, or the installer stopped? The full step-by-step is in **`READ ME - ENGLISH.txt`**.

---

## Aggiornamenti / Updates

**Hai la v1.5? Scarica una volta il pacchetto v1.6** dalla pagina [Releases](../../releases) e lancia `INSTALLA - INSTALL.bat` da lì. L'add-on ha cambiato nome (`dlss5-neural.addon64` → `amd-nr.addon64`) e il runtime nuovo si prepara in un altro modo, cose che l'installatore della v1.5 non sa fare. Quello nuovo riconosce la v1.5, tiene le tue impostazioni e mette da parte i file vecchi come `*.precedente.bak` (il vecchio add-on non deve restare attivo, o ReShade ne caricherebbe due).

**Dalla v1.6 in poi, per aggiornare rilancia `INSTALLA - INSTALL.bat`.** L'installatore, ogni volta che parte, controlla in rete quali versioni sono state provate su Football Life e installa quelle: se sei indietro ti aggiorna tenendo le tue impostazioni, se sei a posto non tocca niente. Dei file sostituiti tiene una copia `*.precedente.bak` per tornare indietro in dieci secondi.

L'elenco delle versioni provate sta qui:
**https://gist.github.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc**

Dentro ci sono due file: `versioni-v2.json` lo legge l'installatore dalla v1.6 in poi; `versioni.json` lo leggono solo gli installatori fino alla v1.5, resta su una combinazione vecchia che funziona e dice di scaricare la v1.6. Se il gist non è raggiungibile, l'installatore usa l'ultima copia salvata e poi le versioni scritte dentro di sé: funziona comunque. `versioni-v2.json` in questo repo è solo la copia di riserva che viaggia nel pacchetto.

Se l'installatore ti dà una versione più vecchia di quella appena uscita, è voluto: significa che non è ancora stata provata. Runtime e add-on devono andare d'accordo tra loro, e quando non lo fanno l'effetto smette di accendersi.

<!-- -->

**On v1.5? Download the v1.6 pack once** from the [Releases](../../releases) page and run `INSTALLA - INSTALL.bat` from there. The add-on was renamed (`dlss5-neural.addon64` → `amd-nr.addon64`) and the new runtime is prepared differently, which the v1.5 installer cannot do. The new one recognises v1.5, keeps your settings and sets the old files aside as `*.precedente.bak` (the old add-on must not stay active, or ReShade would load two).

**From v1.6 on, to update, run `INSTALLA - INSTALL.bat` again.** Every time it starts, the installer checks online which versions have been tested on Football Life and installs those: if you are behind it updates you while keeping your settings, if you are up to date it touches nothing. Each replaced file is kept as `*.precedente.bak` so rolling back takes ten seconds.

The tested-version list lives in the gist linked above, as two files: `versioni-v2.json` is read by installers from v1.6 on; `versioni.json` is read only by installers up to v1.5, stays on an older combination that works and tells people to download v1.6. If the gist cannot be reached, the installer falls back to the last saved copy and then to the versions written inside it.

---

## Cosa c'è in questo repo / What is in here

| | |
|---|---|
| `INIZIA QUI - START HERE.txt` | il riassunto: leggi questo per primo / read this first |
| `LEGGIMI - ITALIANO.txt`, `READ ME - ENGLISH.txt` | la guida completa / the full guide |
| `INSTALLA - INSTALL.bat`, `DISINSTALLA - UNINSTALL.bat` | installa / disinstalla |
| `_installer-gui.ps1`, `_installa.ps1` | l'installatore (finestra e versione testuale di riserva) |
| `amd-nr.ini` | le impostazioni già tarate (`Scale=0.50`) / the pre-tuned settings |
| `versioni-v2.json` | copia di riserva dell'elenco versioni usato dalla v1.6 in poi / backup copy of the version list used by v1.6+ |
| `versioni.json` | l'elenco per gli installatori fino alla v1.5 / the list for installers up to v1.5 |
| `RIPRISTINO - RESTORE.txt` | come togliere tutto a mano / how to undo it by hand |
| `_impronte.ps1`, `COME AGGIORNARE - HOW TO UPDATE.txt` | servono solo a chi pubblica il pacchetto / only for whoever publishes the pack |
| `_licenze/` | le licenze dei progetti usati / the licences of the projects used |

---

## I file della mod NON sono qui, e non ci saranno / The mod files are NOT here

`dlssnr_amd_pass1.dll` e `dlssnr_on_amd_weights.bin` contengono dati derivati da NVIDIA e la licenza del progetto originale **vieta** di ridistribuirli, di includerli in altri pacchetti e di ricaricarli altrove: chiede di linkare la pagina ufficiale, che è esattamente ciò che fa questo pacchetto. Nessuno dei due viaggia nel pacchetto: `dlssnr_amd_pass1.dll` l'installatore lo ricava sul tuo PC dal setup ufficiale di Daniel Blanco, scaricato dalla sua pagina GitHub (non lo esegue: ne estrae il runtime, gli applica le due modifiche che l'add-on richiede e ne verifica l'impronta prima e dopo). I pesi, se non li hai già, li scarica l'installatore ufficiale dell'add-on (AMD-NR ReShade Installer) dal suo canale. Niente viene ridistribuito. Nessun uso commerciale, nessun link a pagamento.

`dlssnr_amd_pass1.dll` and `dlssnr_on_amd_weights.bin` contain NVIDIA-derived data and the original project's licence **forbids** redistributing them, bundling them into other packages and re-uploading them: it asks you to link to the official release page instead, which is what this pack does. Neither ships in the pack: the installer builds `dlssnr_amd_pass1.dll` on your PC from Daniel Blanco's official setup, downloaded from his GitHub page (it is not run: the runtime is lifted out of it, given the two changes the add-on needs, and its fingerprint is checked before and after). The weights, if you do not have them yet, are downloaded by the add-on's official installer (AMD-NR ReShade Installer) through its own channel. Nothing is redistributed. No commercial use, no paid or ad-gated links.

---

## Crediti / Credits

- **Guida, impostazioni, installatore e musica / guide, settings, installer and music:** oLd_pZ
- **Rete neurale e runtime / neural network and runtime:** [danielblnc — DLSS-NR-on-AMD](https://github.com/danielblnc/DLSS-NR-on-AMD)
- **Add-on ReShade (AMD Neural Rendering), modifiche al runtime / runtime patches, installatore AMD-NR:** [cLohan (zmodelerlover) — dlss5-neural-amd](https://github.com/zmodelerlover/dlss5-neural-amd), [AMD-NR-ReShade-Installer](https://github.com/zmodelerlover/AMD-NR-ReShade-Installer)
- **ReShade:** [crosire (Patrick Mours)](https://reshade.me)

## Licenza / Licence

| Cosa / What | Licenza / Licence |
|---|---|
| Guida, impostazioni, musica / guide, settings, music | [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) — condividi e modifica **citando oLd_pZ**, **mai per soldi** (niente link a pagamento o download dietro pubblicità), stessa licenza per le versioni modificate |
| Installatore (`*.ps1`, `*.bat`) | [MIT](https://opensource.org/license/mit) — riusalo pure nel tuo installer, mantenendo la nota di copyright |
| Rete neurale, runtime, add-on, ReShade | le licenze dei loro autori, testi completi in `_licenze/` / their authors' licences, full texts in `_licenze/` |

Dettagli nel file [`LICENSE`](LICENSE). / Details in [`LICENSE`](LICENSE).
