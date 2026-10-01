#Requires -Version 5.1
<#
================================================================================
  IMPRONTE  /  FINGERPRINTS                                          by oLd_pZ

  Serve SOLO A TE, non agli utenti.

  Quando esce una versione nuova (dell'add-on, del runtime di Blanco o di
  ReShade) e l'hai provata, questo script:
    1. legge l'elenco che sta sul gist (versioni-v2.json),
    2. add-on:   scarica amd-nr.addon64 dalla release GitHub che gli dici e ne
                 calcola impronta e dimensione,
    3. runtime:  prende le modifiche per quella versione da runtime-patches.json
                 dell'add-on, scarica il setup ufficiale di Blanco e controlla
                 che il runtime si costruisca davvero con l'impronta giusta,
    4. ReShade:  cerca ReShade64.dll sul PC e ne calcola l'impronta,
    5. sposta le impronte vecchie in "accettati_anche" (cosi' chi ha ancora la
       versione precedente viene riconosciuto come "da aggiornare" e non come
       un'installazione estranea),
    6. scrive "versioni-nuovo.json": quello e' il file da incollare nel gist.

  USO:
      .\_impronte.ps1 -Addon v0.7.2                 solo l'add-on
      .\_impronte.ps1 -Runtime 0.4.4                solo il runtime di Blanco
      .\_impronte.ps1 -Addon v0.7.2 -Runtime 0.4.4  tutti e due
      .\_impronte.ps1 -ReShade 6.9.0 [-Cartella C:\nuovi]
                                                    ReShade (cerca prima in -Cartella)

  ATTENZIONE: il runtime si puo' aggiornare solo quando cLohan ha aggiunto
  quella versione a runtime-patches.json (di solito insieme alla release
  dell'add-on che la supporta). Prima, lo script si ferma e lo dice.

  Dopo: apri il gist, incolla, salva. Gli installer gia' in giro si aggiornano
  da soli al prossimo avvio (il link raw puo' metterci un minuto ad aggiornarsi).
================================================================================
#>

param(
    [string]$Addon,      # tag della release dell'add-on, es. v0.7.2 / add-on release tag
    [string]$Runtime,    # versione del runtime di Blanco, es. 0.4.4 / Blanco runtime version
    [string]$ReShade,    # versione di ReShade, es. 6.9.0 / ReShade version
    [string]$Cartella    # dove cercare prima ReShade64.dll / where to look first for ReShade64.dll
)

$ErrorActionPreference = 'Stop'
$PACK = Split-Path -Parent $MyInvocation.MyCommand.Path
$GIST = 'https://gist.githubusercontent.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc/raw/versioni-v2.json'
$PATCHES = 'https://raw.githubusercontent.com/zmodelerlover/dlss5-neural-amd/master/tools/runtime-patches.json'
$LAVORO = Join-Path $env:TEMP 'FL26-DLSS-Impronte'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

function Titolo($t) { Write-Host ""; Write-Host "  == $t" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "     [OK] $t" -ForegroundColor Green }
function Nota($t)   { Write-Host "     $t" -ForegroundColor Gray }
function Guaio($t)  { Write-Host "     [X]  $t" -ForegroundColor Red }

if (-not ($Addon -or $Runtime -or $ReShade)) {
    Guaio "dimmi cosa e' cambiato: -Addon <tag>, -Runtime <versione> e/o -ReShade <versione>"
    exit 1
}
if (-not (Test-Path $LAVORO)) { New-Item -ItemType Directory -Force -Path $LAVORO | Out-Null }

# le funzioni per costruire il runtime sono le stesse dell'installer: le prendo da li'
# the runtime-building functions are the installer's own: load them from there
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PACK '_installer-gui.ps1'), [ref]$null, [ref]$null)
foreach ($f in $ast.FindAll({ $args[0] -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    if ($f.Name -in 'Sha256-Byte', 'Estrai-Dll') { . ([scriptblock]::Create($f.Extent.Text)) }
}

function Sposta-InAccettati($vecchia, $lista) {
    # la vecchia impronta resta buona: serve a riconoscere chi deve aggiornare
    # the old fingerprint stays valid: it is how we spot who needs an update
    $out = @()
    foreach ($x in @($lista)) { if ($x) { $out += $x } }
    if ($vecchia -and ($out -notcontains $vecchia)) { $out = @($vecchia) + $out }
    return ,$out
}

# --- 1. da dove parto: l'elenco che sta online, o quello nel pack -------------
Titolo "Leggo l'elenco attuale"
$j = $null
try {
    $j = (Invoke-WebRequest -Uri $GIST -UseBasicParsing -TimeoutSec 15).Content.TrimStart([char]0xFEFF) | ConvertFrom-Json
    Ok "preso dal gist (aggiornato al $($j.aggiornato))"
} catch {
    $locale = Join-Path $PACK 'versioni-v2.json'
    if (-not (Test-Path $locale)) { Guaio "non raggiungo il gist e non trovo versioni-v2.json nel pack"; exit 1 }
    $j = (Get-Content $locale -Raw).TrimStart([char]0xFEFF) | ConvertFrom-Json
    Nota "gist non raggiungibile: parto da versioni-v2.json del pack"
}

# --- 2. add-on ------------------------------------------------------------------
if ($Addon) {
    Titolo "Add-on $Addon"
    $url = "https://github.com/zmodelerlover/dlss5-neural-amd/releases/download/$Addon/amd-nr.addon64"
    $f = Join-Path $LAVORO "amd-nr-$Addon.addon64"
    try { Invoke-WebRequest -Uri $url -OutFile $f -UseBasicParsing -TimeoutSec 120 }
    catch { Guaio "non riesco a scaricare $url"; exit 1 }
    $h = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
    if ($h -ne $j.addon.sha256) {
        $j.addon.accettati_anche = Sposta-InAccettati $j.addon.sha256 $j.addon.accettati_anche
        $j.addon.sha256 = $h
        $j.addon.dimensione = (Get-Item $f).Length
        $j.addon.url = $url
        $j.addon.versione = $Addon
        Ok "$h  ($((Get-Item $f).Length) byte)"
    } else { Nota "identico a quello dell'elenco" }
}

# --- 3. runtime di Blanco -------------------------------------------------------
if ($Runtime) {
    Titolo "Runtime $Runtime"
    $spec = (Invoke-WebRequest -Uri $PATCHES -UseBasicParsing -TimeoutSec 15).Content | ConvertFrom-Json
    # cLohan scrive "DLSS-NR-on-AMD v0.4.3" ma anche "DLSS-NR-on-AMD 0.5.1 (supporter
    # build, not distributed)": la versione va riconosciuta con o senza "v" e nota
    # cLohan writes "DLSS-NR-on-AMD v0.4.3" but also "DLSS-NR-on-AMD 0.5.1 (supporter
    # build, not distributed)": match the version with or without the "v" and the note
    $b = @($spec.builds | Where-Object { $_.runtime -match ('^DLSS-NR-on-AMD v?' + [regex]::Escape($Runtime) + '( |$)') })
    if ($b.Count -ne 1) {
        Guaio "runtime-patches.json non ha ancora la v${Runtime}: l'add-on non la supporta ancora."
        Nota  "Versioni che ha: $(($spec.builds | ForEach-Object { $_.runtime }) -join ', ')"
        exit 1
    }
    $b = $b[0]
    $setupUrl = "https://github.com/danielblnc/DLSS-NR-on-AMD/releases/download/v$Runtime/dlssnr_on_amd_setup.exe"
    $setup = Join-Path $LAVORO "dlssnr_on_amd_setup-$Runtime.exe"
    try { Invoke-WebRequest -Uri $setupUrl -OutFile $setup -UseBasicParsing -TimeoutSec 600 }
    catch { Guaio "non riesco a scaricare $setupUrl"; exit 1 }

    # prova che l'installer riuscira' a costruirlo / prove the installer will manage to build it
    $dll = Estrai-Dll ([IO.File]::ReadAllBytes($setup))
    if (-not $dll) { Guaio "nel setup non trovo esattamente una DLL: il formato e' cambiato"; exit 1 }
    if ((Sha256-Byte $dll) -ne $b.original_sha256) { Guaio "la DLL nel setup non e' quella di runtime-patches.json"; exit 1 }
    $patch = @()
    foreach ($c in $b.changes) {
        $o = [Convert]::ToInt32($c.offset.Substring(2), 16)
        for ($k = 0; $k -lt $c.before.Length / 2; $k++) {
            if ($dll[$o + $k] -ne [Convert]::ToByte($c.before.Substring($k * 2, 2), 16)) { Guaio "byte diversi a $($c.offset)"; exit 1 }
            $dll[$o + $k] = [Convert]::ToByte($c.after.Substring($k * 2, 2), 16)
        }
        $patch += [ordered]@{ offset = $c.offset; prima = $c.before; dopo = $c.after }
    }
    if ((Sha256-Byte $dll) -ne $b.patched_sha256) { Guaio "il runtime modificato non torna con patched_sha256"; exit 1 }
    Ok "costruito e verificato: $($b.patched_sha256)"

    if ($b.patched_sha256 -ne $j.runtime.pass1_sha256) {
        $j.runtime.pass1_accettati_anche = Sposta-InAccettati $j.runtime.pass1_sha256 $j.runtime.pass1_accettati_anche
    }
    $j.runtime.versione = $Runtime
    $j.runtime.setup_url = $setupUrl
    $j.runtime.originale_sha256 = $b.original_sha256
    $j.runtime.patch = $patch
    $j.runtime.pass1_sha256 = $b.patched_sha256
    $j.runtime.pass1_dimensione = $dll.Length
    Nota "pesi: invariati ($($j.runtime.pesi_sha256)). Se Blanco li cambia, vanno aggiornati a mano."
}

# --- 4. ReShade -----------------------------------------------------------------
if ($ReShade) {
    Titolo "ReShade $ReShade"
    $posti = @()
    if ($Cartella) { $posti += $Cartella }
    $posti += @("$env:APPDATA\AmdNrInstaller", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop")
    $f = $null
    foreach ($base in $posti) {
        if (-not (Test-Path $base)) { continue }
        $f = Get-ChildItem $base -Recurse -File -Filter 'ReShade64.dll' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f) { break }
    }
    if (-not $f) { Guaio "ReShade64.dll non trovato: passa -Cartella"; exit 1 }
    $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower()
    Nota $f.FullName
    if ($h -ne $j.reshade.sha256) {
        $j.reshade.accettati_anche = Sposta-InAccettati $j.reshade.sha256 $j.reshade.accettati_anche
        $j.reshade.sha256 = $h
        $j.reshade.dimensione = $f.Length
        $j.reshade.url = "https://reshade.me/downloads/ReShade_Setup_${ReShade}_Addon.exe"
        $j.reshade.versione = $ReShade
        Ok "$h  -- controlla che $($j.reshade.url) esista"
    } else { Nota "identico a quello dell'elenco" }
}

$j.aggiornato = (Get-Date -Format 'yyyy-MM-dd')

# --- 5. scrivo il file da incollare ---------------------------------------------
$out = Join-Path $PACK 'versioni-nuovo.json'
$testo = ($j | ConvertTo-Json -Depth 8)
# ConvertTo-Json scrive gli apostrofi come \u0027: li rimetto in chiaro, e' JSON valido
# ConvertTo-Json writes apostrophes as \u0027: put them back, it is still valid JSON
$testo = $testo.Replace('\u0027', "'")
# senza BOM: il BOM manda in errore la lettura dell'elenco negli installer
# no BOM: a BOM breaks the installers when they read the list
[IO.File]::WriteAllText($out, $testo, (New-Object Text.UTF8Encoding($false)))

Titolo "Fatto"
Ok "scritto: $out"
Write-Host ""
Nota "ORA:  1) prova:  .\_installer-gui.ps1 -Test -ElencoDiProva `"$out`""
Nota "      2) apri https://gist.github.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc"
Nota "      3) Edit, file versioni-v2.json: cancella tutto, incolla versioni-nuovo.json, salva"
Nota "      4) controlla:  .\_installer-gui.ps1 -Test  (deve dire 'fonte: gist' e la data di oggi)"
Nota "      5) copia versioni-nuovo.json su versioni-v2.json nel pack"
Write-Host ""
Write-Host (Get-Content $out -Raw)
