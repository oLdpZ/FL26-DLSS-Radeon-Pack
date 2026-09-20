#Requires -Version 5.1
<#
================================================================================
  IMPRONTE  /  FINGERPRINTS                                          by oLd_pZ

  Serve SOLO A TE, non agli utenti.

  Quando esce una versione nuova (dell'add-on, del runtime di Blanco o di
  ReShade) e l'hai provata, questo script:
    1. cerca i file nuovi,
    2. ne calcola le impronte SHA-256 e le dimensioni,
    3. legge l'elenco che sta sul gist,
    4. sposta le impronte vecchie in "accettati_anche" (cosi' chi ha ancora la
       versione precedente viene riconosciuto come "da aggiornare" e non come
       un'installazione estranea),
    5. scrive "versioni-nuovo.json": quello e' il file da incollare nel gist.

  USO:
      .\_impronte.ps1                       cerca da solo i file
      .\_impronte.ps1 -Cartella C:\nuovi    cerca prima li'
      .\_impronte.ps1 -Addon v0.6.0 -Runtime 0.2.0 -ReShade 6.9.0
                                            scrive anche i numeri di versione

  Dopo: apri il gist, incolla, salva. Gli installer gia' in giro si aggiornano
  da soli al prossimo avvio (il link raw puo' metterci un minuto ad aggiornarsi).
================================================================================
#>

param(
    [string]$Cartella,
    [string]$Addon,      # numero di versione dell'add-on / add-on version number
    [string]$Runtime,    # numero di versione del runtime di Blanco / Blanco runtime version
    [string]$ReShade     # numero di versione di ReShade / ReShade version
)

$ErrorActionPreference = 'Stop'
$PACK = Split-Path -Parent $MyInvocation.MyCommand.Path
$GIST = 'https://gist.githubusercontent.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc/raw/versioni.json'

function Titolo($t) { Write-Host ""; Write-Host "  == $t" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "     [OK] $t" -ForegroundColor Green }
function Nota($t)   { Write-Host "     $t" -ForegroundColor Gray }
function Guaio($t)  { Write-Host "     [X]  $t" -ForegroundColor Red }

# --- 1. da dove parto: l'elenco che sta online, o quello nel pack -------------
Titolo "Leggo l'elenco attuale"
$j = $null
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $j = (Invoke-WebRequest -Uri $GIST -UseBasicParsing -TimeoutSec 15).Content | ConvertFrom-Json
    Ok "preso dal gist (aggiornato al $($j.aggiornato))"
} catch {
    $locale = Join-Path $PACK 'versioni.json'
    if (-not (Test-Path $locale)) { Guaio "non raggiungo il gist e non trovo versioni.json nel pack"; exit 1 }
    $j = Get-Content $locale -Raw | ConvertFrom-Json
    Nota "gist non raggiungibile: parto da versioni.json del pack"
}

# --- 2. cerco i file ----------------------------------------------------------
$NOMI = 'dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin','ReShade64.dll'
$posti = @()
if ($Cartella) { $posti += $Cartella }
$posti += @("$env:APPDATA\AmdNrInstaller", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")

Titolo "Cerco i file nuovi"
$trovati = @{}
foreach ($n in $NOMI) {
    foreach ($base in $posti) {
        if (-not (Test-Path $base)) { continue }
        $f = Get-ChildItem $base -Recurse -File -Filter $n -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f) { $trovati[$n] = $f; break }
    }
    if ($trovati.ContainsKey($n)) {
        $f = $trovati[$n]
        $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower()
        Ok ("{0}  {1:N0} byte" -f $n, $f.Length)
        Nota "   $h"
        Nota "   $($f.FullName)"
        # la cache dell'installer ufficiale tiene i file in cartelle che si
        # chiamano come la versione: cache\runtime\0.3.0\... -> me la prendo da li'
        # the official installer's cache keeps files in folders named after the
        # version: cache\runtime\0.3.0\... -> read it from there
        $vers = Split-Path (Split-Path $f.FullName -Parent) -Leaf
        if ($vers -notmatch '^v?\d+(\.\d+)+$') { $vers = $null } else { Nota "   versione a giudicare dalla cartella: $vers" }
        $trovati[$n] = @{ file = $f; hash = $h; vers = $vers }
    } else {
        Nota "$n : non trovato, lascio quello che c'e' nell'elenco"
    }
}
if ($trovati.Count -eq 0) { Guaio "nessun file trovato: passa -Cartella con il percorso giusto"; exit 1 }

# --- 3. aggiorno l'elenco -----------------------------------------------------
function Sposta-InAccettati($vecchia, $lista) {
    # la vecchia impronta resta buona: serve a riconoscere chi deve aggiornare
    # the old fingerprint stays valid: it is how we spot who needs an update
    $out = @()
    foreach ($x in @($lista)) { if ($x) { $out += $x } }
    if ($vecchia -and ($out -notcontains $vecchia)) { $out = @($vecchia) + $out }
    return $out
}

Titolo "Aggiorno l'elenco"
$cambiati = 0

if ($trovati.ContainsKey('dlss5-neural.addon64')) {
    $t = $trovati['dlss5-neural.addon64']
    if ($t.hash -ne $j.addon.sha256) {
        $j.addon.accettati_anche = @(Sposta-InAccettati $j.addon.sha256 $j.addon.accettati_anche)
        $j.addon.sha256 = $t.hash
        $j.addon.dimensione = $t.file.Length
        if ($Addon) {
            $j.addon.url = $j.addon.url -replace '/download/[^/]+/', "/download/$Addon/"
            $j.addon.versione = $Addon
        } else {
            if ($t.vers) { $j.addon.versione = $t.vers }
            Nota "ATTENZIONE: il LINK di download non l'ho toccato. Rilancia con -Addon <tag>"
            Nota "            (il tag e' quello della release GitHub, es. v0.6.0) o correggilo a mano."
        }
        Ok "add-on aggiornato"; $cambiati++
    } else { Nota "add-on: identico a quello dell'elenco" }
}

if ($trovati.ContainsKey('dlssnr_amd_pass1.dll')) {
    $t = $trovati['dlssnr_amd_pass1.dll']
    if ($t.hash -ne $j.runtime.pass1_sha256) {
        $j.runtime.pass1_accettati_anche = @(Sposta-InAccettati $j.runtime.pass1_sha256 $j.runtime.pass1_accettati_anche)
        $j.runtime.pass1_sha256 = $t.hash
        $j.runtime.pass1_dimensione = $t.file.Length
        if (-not $Runtime -and $t.vers) { $j.runtime.versione = $t.vers }
        Ok "runtime (pass1) aggiornato"; $cambiati++
    } else { Nota "runtime (pass1): identico" }
}

if ($trovati.ContainsKey('dlssnr_on_amd_weights.bin')) {
    $t = $trovati['dlssnr_on_amd_weights.bin']
    if ($t.hash -ne $j.runtime.pesi_sha256) {
        $j.runtime.pesi_accettati_anche = @(Sposta-InAccettati $j.runtime.pesi_sha256 $j.runtime.pesi_accettati_anche)
        $j.runtime.pesi_sha256 = $t.hash
        $j.runtime.pesi_dimensione = $t.file.Length
        Ok "runtime (pesi) aggiornato"; $cambiati++
    } else { Nota "runtime (pesi): identico" }
}
if ($Runtime) { $j.runtime.versione = $Runtime }

if ($trovati.ContainsKey('ReShade64.dll')) {
    $t = $trovati['ReShade64.dll']
    if ($t.hash -ne $j.reshade.sha256) {
        $j.reshade.accettati_anche = @(Sposta-InAccettati $j.reshade.sha256 $j.reshade.accettati_anche)
        $j.reshade.sha256 = $t.hash
        $j.reshade.dimensione = $t.file.Length
        if ($ReShade) {
            $j.reshade.url = "https://reshade.me/downloads/ReShade_Setup_${ReShade}_Addon.exe"
            $j.reshade.versione = $ReShade
        } else {
            if ($t.vers) {
                $j.reshade.versione = $t.vers
                $j.reshade.url = "https://reshade.me/downloads/ReShade_Setup_$($t.vers)_Addon.exe"
                Nota "   link messo a: $($j.reshade.url)  -- controlla che esista"
            } else {
                Nota "ATTENZIONE: passa -ReShade <versione> per aggiornare anche il link di download"
            }
        }
        Ok "ReShade aggiornato"; $cambiati++
    } else { Nota "ReShade: identico" }
}

$j.aggiornato = (Get-Date -Format 'yyyy-MM-dd')

# --- 4. scrivo il file da incollare ------------------------------------------
$out = Join-Path $PACK 'versioni-nuovo.json'
$testo = ($j | ConvertTo-Json -Depth 8)
# ConvertTo-Json scrive gli apostrofi come \u0027: li rimetto in chiaro, e' JSON valido
# ConvertTo-Json writes apostrophes as \u0027: put them back, it is still valid JSON
$testo = $testo.Replace('\u0027', "'")
$testo | Set-Content -LiteralPath $out -Encoding UTF8

Titolo "Fatto"
if ($cambiati -eq 0) { Nota "niente da cambiare: le impronte erano gia' queste" }
Ok "scritto: $out"
Write-Host ""
Nota "ORA:  1) apri https://gist.github.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc"
Nota "      2) Edit, cancella tutto, incolla il contenuto di versioni-nuovo.json, salva"
Nota "      3) controlla che i link nel file siano veri (aprili nel browser)"
Nota "      4) prova: .\_installer-gui.ps1 -Test  (deve dire 'elenco aggiornato al ...')"
Nota "      5) se la versione nuova va bene, copia versioni-nuovo.json su versioni.json"
Write-Host ""
Write-Host (Get-Content $out -Raw)
