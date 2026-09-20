#Requires -Version 5.1
<#
================================================================================
  DLSS 5 NEURAL RENDERING su AMD Radeon  --  Football Life 2026 / PES 2021
  Installer grafico  /  Graphical installer
--------------------------------------------------------------------------------
  COSA SCARICA DA SOLO / DOWNLOADS BY ITSELF
    - dlss5-neural.addon64   dalla release ufficiale GitHub (licenza MIT)
    - ReShade 6.8.0 Addon    dal sito ufficiale reshade.me (licenza BSD)

  COSA NON SCARICA / WHAT IT DOES NOT DOWNLOAD
    - dlssnr_amd_pass1.dll e dlssnr_on_amd_weights.bin: sono di Daniel Blanco e
      la sua licenza vieta di includerli in altri installer. Questo programma
      lancia il SUO installer ufficiale, che li scarica dal suo canale.
      -> Se l'autore ti autorizza, metti $AutorizzatoDallAutore = $true qui sotto
         e scrivi il download diretto nella funzione Scarica-RuntimeDiretto.
================================================================================
#>

param([switch]$Test, [switch]$Disinstalla, [string]$CartellaProva,
      # solo per le prove: fa leggere l'elenco versioni da un file locale
      # test only: reads the version list from a local file
      [string]$ElencoDiProva)

$ErrorActionPreference = 'Stop'
$PACK = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---- INTERRUTTORE PERMESSO / PERMISSION SWITCH -------------------------------
$AutorizzatoDallAutore = $false
# ------------------------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# =============================================================== COSTANTI =====
$HASH = @{
    'dlss5-neural.addon64'      = '0d0a63f6ac886fafb0d04a0df3c5d4f2908e1a44a966648bba949ad2dcc33cc6'
    'dlssnr_amd_pass1.dll'      = '70af3fb757f83f71ec947ce461970fdecc9636864bc01d952abffb36ae310be6'
    'dlssnr_on_amd_weights.bin' = '6bf8dc931ef3ccffe18c82de26ab374156e7f19539ffcf8eabaa25dca5cf15ab'
    'ReShade64.dll'             = '0cee63f9c9f13f3ac909c5b4903f4dbb4b719a7ab3b4f13b0deaf83c814b94f7'
}
$URL = @{
    addon        = 'https://github.com/zmodelerlover/dlss5-neural-amd/releases/download/v0.5.2/dlss5-neural.addon64'
    reshadeSetup = 'https://reshade.me/downloads/ReShade_Setup_6.8.0_Addon.exe'
    amdnrZip     = 'https://github.com/zmodelerlover/dlss5-neural-amd/releases/download/v0.5.2/AMD-NR-ReShade-Installer-v0.1.1.zip'
    paginaBlanco = 'https://github.com/danielblnc/DLSS-NR-on-AMD/releases'
}
$PREFS = Join-Path $env:APPDATA 'FL26-DLSS-Installer\prefs.txt'
$LAVORO = Join-Path $env:TEMP 'FL26-DLSS-Installer'

# ---- ELENCO VERSIONI ONLINE / ONLINE VERSION LIST ----------------------------
# I valori qui sopra sono quelli "di fabbrica". All'avvio l'installer prova a
# leggere l'elenco delle versioni provate dal gist ufficiale: se ci riesce, usa
# quelle. Se non ci riesce usa l'ultima copia salvata; se non c'e' nemmeno
# quella, resta con i valori di fabbrica. Non si ferma mai per questo.
# The values above are the "factory" ones. At startup the installer tries to
# read the tested-version list from the official gist: if it can, it uses those.
# If it cannot, it falls back to the last saved copy, then to the factory
# values. It never stops because of this.
$URL.manifesto = 'https://gist.githubusercontent.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc/raw/versioni.json'
$CACHE_MANIFESTO = Join-Path $env:APPDATA 'FL26-DLSS-Installer\versioni.json'
if ($Test -and $ElencoDiProva) { $URL.manifesto = $ElencoDiProva; $CACHE_MANIFESTO = Join-Path $env:TEMP 'FL26-DLSS-Installer\versioni-prova.json' }
# domini da cui accettiamo download / domains we accept downloads from
$DOMINI_OK = '^https://(github\.com|reshade\.me)/'

# versioni piu' vecchie ancora accettate (riempite dall'elenco online)
# older versions still accepted (filled in from the online list)
$ACCETTATI = @{
    'dlss5-neural.addon64'      = @()
    'dlssnr_amd_pass1.dll'      = @()
    'dlssnr_on_amd_weights.bin' = @()
    'ReShade64.dll'             = @()
}
$script:VERS = @{
    addon = 'v0.5.2'; runtime = '0.3.0'; reshade = '6.8.0'
    aggiornato = ''; avviso_it = ''; avviso_en = ''; fonte = 'script'
}

$script:LANG = 'IT'
$script:GIOCO = $null
$script:musicaAccesa = $true
$script:player = $null
$script:ultimoStato = $null
$script:soloBenvenuto = $false

function T($it, $en) { if ($script:LANG -eq 'EN') { $en } else { $it } }

# ================================================================= MUSICA =====
function Avvia-Musica {
    $mp3 = Join-Path $PACK 'musica\installer.mp3'
    if (-not (Test-Path $mp3)) { return }
    try {
        Add-Type -AssemblyName PresentationCore
        $script:player = New-Object System.Windows.Media.MediaPlayer
        $script:player.Open([Uri]$mp3)
        $script:player.Volume = 0.55
        $script:player.Add_MediaEnded({ $script:player.Position = [TimeSpan]::Zero; $script:player.Play() })
        $script:player.Play()
    } catch { $script:player = $null }
}
function Ferma-Musica { if ($script:player) { try { $script:player.Stop() } catch {} } }

function Leggi-Prefs {
    if (Test-Path $PREFS) {
        $t = Get-Content $PREFS -Raw
        if ($t -match 'musica=off') { $script:musicaAccesa = $false }
        if ($t -match 'lingua=EN')  { $script:LANG = 'EN' }
    }
}
function Salva-Prefs {
    $d = Split-Path $PREFS -Parent
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    "musica=$(if($script:musicaAccesa){'on'}else{'off'})`nlingua=$($script:LANG)" | Set-Content $PREFS -Encoding UTF8
}

# =================================================================== FORM =====
$NERO    = [Drawing.Color]::FromArgb(10, 10, 16)
$VERDE   = [Drawing.Color]::FromArgb(70, 255, 130)
$MAGENTA = [Drawing.Color]::FromArgb(255, 60, 180)
$GRIGIO  = [Drawing.Color]::FromArgb(150, 150, 165)
$MONO    = New-Object Drawing.Font('Consolas', 9)
$MONO_B  = New-Object Drawing.Font('Consolas', 9, [Drawing.FontStyle]::Bold)

$form = New-Object Windows.Forms.Form
$form.Text = 'DLSS 5 Neural Rendering - AMD Radeon - Football Life 2026 / PES 2021  |  by oLd_pZ'
$form.Size = New-Object Drawing.Size(760, 580)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $NERO
$form.ForeColor = $VERDE
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false

# --- banner ---
$banner = New-Object Windows.Forms.Label
$banner.Text = @"
  ####   #      ####   ####      ####
  #   #  #     #      #         #
  #   #  #      ###    ###       ###     N E U R A L
  #   #  #         #      #         #    R E N D E R I N G
  ####   ####  ####   ####      ####     on AMD RADEON
"@
$banner.Font = New-Object Drawing.Font('Consolas', 8, [Drawing.FontStyle]::Bold)
$banner.ForeColor = $MAGENTA
$banner.Location = New-Object Drawing.Point(18, 10)
$banner.Size = New-Object Drawing.Size(520, 90)
$form.Controls.Add($banner)

$sottotitolo = New-Object Windows.Forms.Label
$sottotitolo.Font = $MONO
$sottotitolo.ForeColor = $GRIGIO
$sottotitolo.Location = New-Object Drawing.Point(20, 100)
$sottotitolo.Size = New-Object Drawing.Size(700, 34)
$form.Controls.Add($sottotitolo)

# --- firma ---
$firma = New-Object Windows.Forms.Label
$firma.Font = New-Object Drawing.Font('Consolas', 14, [Drawing.FontStyle]::Bold)
$firma.ForeColor = $MAGENTA
$firma.TextAlign = 'MiddleRight'
$firma.Location = New-Object Drawing.Point(545, 48)
$firma.Size = New-Object Drawing.Size(175, 46)
$form.Controls.Add($firma)

# --- lingua ---
$btnIT = New-Object Windows.Forms.Button
$btnIT.Text = 'ITA'; $btnIT.Size = New-Object Drawing.Size(48, 26)
$btnIT.Location = New-Object Drawing.Point(620, 14)
$btnEN = New-Object Windows.Forms.Button
$btnEN.Text = 'ENG'; $btnEN.Size = New-Object Drawing.Size(48, 26)
$btnEN.Location = New-Object Drawing.Point(672, 14)
foreach ($b in @($btnIT, $btnEN)) {
    $b.FlatStyle = 'Flat'; $b.BackColor = $NERO; $b.ForeColor = $GRIGIO; $b.Font = $MONO
    $b.FlatAppearance.BorderColor = $GRIGIO
    $form.Controls.Add($b)
}

# --- log ---
$log = New-Object Windows.Forms.RichTextBox
$log.Location = New-Object Drawing.Point(20, 190)
$log.Size = New-Object Drawing.Size(700, 250)
$log.BackColor = [Drawing.Color]::FromArgb(6, 6, 10)
$log.ForeColor = $VERDE
$log.Font = $MONO
$log.ReadOnly = $true
$log.BorderStyle = 'FixedSingle'
$form.Controls.Add($log)

# --- stato + barra ---
$stato = New-Object Windows.Forms.Label
$stato.Font = $MONO_B
$stato.ForeColor = $VERDE
$stato.Location = New-Object Drawing.Point(20, 148)
$stato.Size = New-Object Drawing.Size(700, 18)
$form.Controls.Add($stato)

$barra = New-Object Windows.Forms.ProgressBar
$barra.Location = New-Object Drawing.Point(20, 168)
$barra.Size = New-Object Drawing.Size(700, 14)
$barra.Style = 'Continuous'
$form.Controls.Add($barra)

# --- pulsanti ---
$btnVai = New-Object Windows.Forms.Button
$btnVai.Size = New-Object Drawing.Size(220, 42)
$btnVai.Location = New-Object Drawing.Point(20, 458)
$btnVai.FlatStyle = 'Flat'
$btnVai.BackColor = [Drawing.Color]::FromArgb(20, 60, 35)
$btnVai.ForeColor = $VERDE
$btnVai.Font = New-Object Drawing.Font('Consolas', 11, [Drawing.FontStyle]::Bold)
$form.Controls.Add($btnVai)

$btnTogli = New-Object Windows.Forms.Button
$btnTogli.Size = New-Object Drawing.Size(180, 42)
$btnTogli.Location = New-Object Drawing.Point(250, 458)
$btnTogli.FlatStyle = 'Flat'
$btnTogli.BackColor = [Drawing.Color]::FromArgb(50, 20, 25)
$btnTogli.ForeColor = [Drawing.Color]::FromArgb(255, 120, 120)
$btnTogli.Font = $MONO
$form.Controls.Add($btnTogli)

$btnMusica = New-Object Windows.Forms.Button
$btnMusica.Size = New-Object Drawing.Size(150, 42)
$btnMusica.Location = New-Object Drawing.Point(570, 458)
$btnMusica.FlatStyle = 'Flat'
$btnMusica.BackColor = $NERO
$btnMusica.ForeColor = $MAGENTA
$btnMusica.Font = $MONO
$btnMusica.FlatAppearance.BorderColor = $MAGENTA
$form.Controls.Add($btnMusica)

# ================================================================ FUNZIONI ====
function Scrivi($testo, $colore) {
    if (-not $colore) { $colore = $VERDE }
    $log.SelectionStart = $log.TextLength
    $log.SelectionColor = $colore
    $log.AppendText("$testo`n")
    $log.ScrollToCaret()
    [Windows.Forms.Application]::DoEvents()
}
function Passo($t)   { Scrivi "  >> $t" $MAGENTA }
function Buono($t)   { Scrivi "     [ok] $t" $VERDE }
function Avviso($t)  { Scrivi "     [!]  $t" ([Drawing.Color]::FromArgb(255, 210, 80)) }
function Guaio($t)   { Scrivi "     [X]  $t" ([Drawing.Color]::FromArgb(255, 110, 110)) }
function Stato($t, $pct) {
    # $t puo' essere una coppia @(it, en): cosi' si ritraduce al cambio lingua
    if ($t -is [array]) { $script:ultimoStato = $t } else { $script:ultimoStato = @($t, $t) }
    $stato.Text = T $script:ultimoStato[0] $script:ultimoStato[1]
    if ($null -ne $pct) { $barra.Value = [Math]::Min(100, [Math]::Max(0, $pct)) }
    [Windows.Forms.Application]::DoEvents()
}

function Aggiorna-Testi {
    $sottotitolo.Text = T @"
Installa il neural rendering DLSS 5 su schede Radeon RX 7000 / RX 9000.
NOTA: fa CALARE gli fps, non li aumenta. Usare solo offline.
"@ @"
Installs DLSS 5 neural rendering on Radeon RX 7000 / RX 9000 cards.
NOTE: it LOWERS your fps, it does not raise them. Offline use only.
"@
    $firma.Text     = T "a cura di`noLd_pZ" "made by`noLd_pZ"
    $btnVai.Text    = T 'INSTALLA' 'INSTALL'
    $btnTogli.Text  = T 'Disinstalla' 'Uninstall'
    $btnMusica.Text = if ($script:musicaAccesa) { T 'MUSICA: ON' 'MUSIC: ON' } else { T 'MUSICA: OFF' 'MUSIC: OFF' }
    if ($script:ultimoStato) { $stato.Text = T $script:ultimoStato[0] $script:ultimoStato[1] }
    if ($script:soloBenvenuto) { Mostra-Benvenuto }
    if ($script:LANG -eq 'IT') { $btnIT.ForeColor = $VERDE; $btnEN.ForeColor = $GRIGIO }
    else                       { $btnEN.ForeColor = $VERDE; $btnIT.ForeColor = $GRIGIO }
}

function Mostra-Benvenuto {
    $log.Clear()
    $script:soloBenvenuto = $true
    Scrivi (T '  Pacchetto e installer a cura di oLd_pZ' '  Pack and installer made by oLd_pZ') $MAGENTA
    Scrivi '' $GRIGIO
    Scrivi (T '  Pronto. Premi INSTALLA.' '  Ready. Press INSTALL.') $GRIGIO
    Scrivi (T '  Scarica da solo: ReShade (reshade.me) e l''add-on (GitHub).' `
              '  Downloads by itself: ReShade (reshade.me) and the add-on (GitHub).') $GRIGIO
    Scrivi (T '  Per runtime e pesi apre l''installer ufficiale di Daniel Blanco,' `
              '  For runtime and weights it opens Daniel Blanco''s official installer,') $GRIGIO
    Scrivi (T '  come chiede la sua licenza.' '  as his licence requires.') $GRIGIO
}

function Hash-Ok($percorso, $atteso) {
    if (-not (Test-Path $percorso)) { return $false }
    return ((Get-FileHash $percorso -Algorithm SHA256).Hash.ToLower() -eq $atteso)
}

function Hash-Accettabile($percorso, $nome) {
    # vero se il file e' la versione attuale OPPURE una precedente che l'elenco
    # dichiara ancora buona
    # true if the file is the current version OR an older one the list still accepts
    if (Hash-Ok $percorso $HASH[$nome]) { return $true }
    foreach ($h in $ACCETTATI[$nome]) { if (Hash-Ok $percorso $h) { return $true } }
    return $false
}

function Salva-Precedente($gioco, $nome, $hashAtteso) {
    # prima di sovrascrivere un file diverso da quello atteso ne tiene una copia:
    # se la versione nuova non va, si torna indietro rinominando il .bak
    # before overwriting a file that differs from the expected one, keep a copy:
    # if the new version misbehaves, rename the .bak back
    $p = Join-Path $gioco $nome
    if (-not (Test-Path -LiteralPath $p)) { return }
    if (Hash-Ok $p $hashAtteso) { return }
    $bak = "$p.precedente.bak"
    try {
        if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force }
        Move-Item -LiteralPath $p -Destination $bak -Force
        Avviso (T "versione precedente tenuta da parte: $nome.precedente.bak" `
                  "previous version kept as $nome.precedente.bak")
    } catch {
        Avviso (T "non sono riuscito a tenere la copia di $nome" "could not keep a copy of $nome")
    }
}

function Url-Sicuro($u) {
    return (($u -is [string]) -and ($u -match $DOMINI_OK))
}
function Hash-Valido($h) {
    return (($h -is [string]) -and ($h -match '^[0-9a-f]{64}$'))
}

function Applica-Manifesto($m) {
    # accetta l'elenco solo se TUTTI i campi che servono ci sono e sono sensati:
    # impronte di 64 cifre esadecimali e link solo verso github.com o reshade.me.
    # Cosi' un elenco manomesso non puo' far scaricare altro.
    # accepts the list only if EVERY required field is there and sane: 64-hex-digit
    # fingerprints and links only to github.com or reshade.me. This way a tampered
    # list cannot make us download something else.
    if (-not $m) { return $false }
    if (-not $m.addon -or -not $m.runtime -or -not $m.reshade) { return $false }
    if (-not (Hash-Valido $m.addon.sha256))         { return $false }
    if (-not (Hash-Valido $m.reshade.sha256))       { return $false }
    if (-not (Hash-Valido $m.runtime.pass1_sha256)) { return $false }
    if (-not (Hash-Valido $m.runtime.pesi_sha256))  { return $false }
    if (-not (Url-Sicuro $m.addon.url))             { return $false }
    if (-not (Url-Sicuro $m.reshade.url))           { return $false }
    if ($m.amdnr_zip -and $m.amdnr_zip.url -and -not (Url-Sicuro $m.amdnr_zip.url)) { return $false }

    $HASH['dlss5-neural.addon64']      = $m.addon.sha256
    $HASH['ReShade64.dll']             = $m.reshade.sha256
    $HASH['dlssnr_amd_pass1.dll']      = $m.runtime.pass1_sha256
    $HASH['dlssnr_on_amd_weights.bin'] = $m.runtime.pesi_sha256
    $URL.addon        = $m.addon.url
    $URL.reshadeSetup = $m.reshade.url
    if ($m.amdnr_zip -and $m.amdnr_zip.url) { $URL.amdnrZip = $m.amdnr_zip.url }
    if ($m.runtime.pagina -and (Url-Sicuro $m.runtime.pagina)) { $URL.paginaBlanco = $m.runtime.pagina }

    foreach ($c in @(
        ,@('dlss5-neural.addon64',      $m.addon.accettati_anche)
        ,@('ReShade64.dll',             $m.reshade.accettati_anche)
        ,@('dlssnr_amd_pass1.dll',      $m.runtime.pass1_accettati_anche)
        ,@('dlssnr_on_amd_weights.bin', $m.runtime.pesi_accettati_anche))) {
        $buoni = @()
        foreach ($h in @($c[1])) { if (Hash-Valido $h) { $buoni += $h } }
        $ACCETTATI[$c[0]] = $buoni
    }

    if ($m.addon.versione)   { $script:VERS.addon   = [string]$m.addon.versione }
    if ($m.runtime.versione) { $script:VERS.runtime = [string]$m.runtime.versione }
    if ($m.reshade.versione) { $script:VERS.reshade = [string]$m.reshade.versione }
    if ($m.aggiornato)       { $script:VERS.aggiornato = [string]$m.aggiornato }
    if ($m.avviso_it)        { $script:VERS.avviso_it  = [string]$m.avviso_it }
    if ($m.avviso_en)        { $script:VERS.avviso_en  = [string]$m.avviso_en }
    return $true
}

function Leggi-Manifesto {
    # non blocca mai l'installazione: al massimo resta con i valori di fabbrica
    # never blocks the install: at worst it stays with the factory values
    $testo = $null
    $fonte = 'script'
    if ($Test -and $ElencoDiProva) {
        # modalita' prova: l'elenco arriva da un file locale
        # test mode: the list comes from a local file
        try { $testo = Get-Content -LiteralPath $ElencoDiProva -Raw; $fonte = 'gist' } catch { $testo = $null }
    }
    if (-not $testo) {
    try {
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-WebRequest -Uri $URL.manifesto -UseBasicParsing -TimeoutSec 10
        $testo = $r.Content
        $fonte = 'gist'
    } catch { $testo = $null }
    }

    if (-not $testo -and (Test-Path -LiteralPath $CACHE_MANIFESTO)) {
        try { $testo = Get-Content -LiteralPath $CACHE_MANIFESTO -Raw; $fonte = 'cache' } catch { $testo = $null }
    }
    if (-not $testo) { return }

    $m = $null
    try { $m = $testo | ConvertFrom-Json } catch { $m = $null }
    if (-not $m) { return }
    if (-not (Applica-Manifesto $m)) { return }

    $script:VERS.fonte = $fonte
    if ($fonte -eq 'gist') {
        try {
            $d = Split-Path $CACHE_MANIFESTO -Parent
            if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
            $testo | Set-Content -LiteralPath $CACHE_MANIFESTO -Encoding UTF8
        } catch { }
    }
}

function Mostra-Versioni {
    $v = $script:VERS
    Passo (T 'Controllo quali versioni sono quelle buone' 'Checking which versions are the good ones')
    Scrivi ("     add-on $($v.addon)  |  runtime $($v.runtime)  |  ReShade $($v.reshade)") $GRIGIO
    switch ($v.fonte) {
        'gist'  { Buono (T "elenco aggiornato al $($v.aggiornato)" "list updated on $($v.aggiornato)") }
        'cache' { Avviso (T "sono offline: uso l'ultimo elenco salvato ($($v.aggiornato))" `
                            "offline: using the last saved list ($($v.aggiornato))") }
        default { Avviso (T 'elenco online non raggiungibile: uso le versioni di fabbrica' `
                            'online list unreachable: using the factory versions') }
    }
    $av = T $v.avviso_it $v.avviso_en
    if ($av) { Avviso $av }
}

function Cerca-Ovunque($nome, $atteso) {
    $posti = @(
        $(if ($script:GIOCO) { Join-Path $script:GIOCO $nome } else { $null }),
        (Join-Path $PACK "files\$nome"),
        (Join-Path $LAVORO $nome)
    )
    foreach ($p in $posti) { if ($p -and (Hash-Ok $p $atteso)) { return $p } }
    foreach ($base in $LAVORO, "$env:APPDATA\AmdNrInstaller", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents") {
        if (Test-Path $base) {
            $trovati = Get-ChildItem $base -Recurse -File -Filter $nome -ErrorAction SilentlyContinue | Select-Object -First 6
            foreach ($f in $trovati) { if (Hash-Ok $f.FullName $atteso) { return $f.FullName } }
        }
    }
    return $null
}

function Scarica($url, $dest, $etichetta) {
    Passo (T "Scarico $etichetta" "Downloading $etichetta")
    $d = Split-Path $dest -Parent
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 600
        Buono ("{0}  ({1:N1} MB)" -f $etichetta, ((Get-Item $dest).Length / 1MB))
        return $true
    } catch {
        Guaio (T "Download fallito: $($_.Exception.Message)" "Download failed: $($_.Exception.Message)")
        return $false
    }
}

function Exe-Gioco($cartella) {
    # Football Life 2026 usa FL_2026.exe; PES 2021 (e chi l'ha rinominato) usa PES2021.exe.
    # Stesso gioco: ReShade si carica dalla cartella, il nome dell'eseguibile non conta.
    # Football Life 2026 uses FL_2026.exe; PES 2021 (and renamed installs) use PES2021.exe.
    # Same game: ReShade loads from the folder, the executable name does not matter.
    if (-not $cartella) { return $null }
    foreach ($n in 'FL_2026.exe', 'PES2021.exe') {
        $p = Join-Path $cartella $n
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

function Candidati-Gioco {
    # Restituisce le cartelle con FL_2026.exe o PES2021.exe, dalla piu' affidabile.
    # Returns the folders holding FL_2026.exe or PES2021.exe, most reliable first.
    $trovate = New-Object System.Collections.Generic.List[string]
    function Aggiungi($cartella) {
        if (-not $cartella) { return }
        $cartella = $cartella.Trim().Trim('"').TrimEnd('\')
        if ($cartella -and (Exe-Gioco $cartella) -and -not $trovate.Contains($cartella)) {
            $trovate.Add($cartella)
        }
    }

    # 1. Registro di Windows (installer di FL26, PES 2021 di Steam...), in qualsiasi cartella
    # 1. Windows registry (FL26 installer, Steam PES 2021...), whatever the folder
    $chiavi = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    foreach ($v in (Get-ItemProperty $chiavi -ErrorAction SilentlyContinue)) {
        if ("$($v.DisplayName)" -notmatch 'Football Life|PES ?2021|eFootball PES') { continue }
        Aggiungi $v.InstallLocation
        foreach ($campo in $v.UninstallString, $v.DisplayIcon) {
            if ($campo -match '^\s*"?([A-Za-z]:\\[^"]+?\.exe)') { Aggiungi (Split-Path $Matches[1] -Parent) }
        }
    }

    # 2. Cartelle solite su tutti i dischi / usual folders on every drive
    foreach ($d in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Root)) {
        foreach ($sub in 'Games\FL26','Games\SP Football Life 2026','Games\Football Life 2026',
                         'SP Football Life 2026','Football Life 2026','FL26','Games\PES 2021') {
            Aggiungi (Join-Path $d $sub)
        }
    }

    # 3. Librerie di Steam / Steam libraries
    $steam = (Get-ItemProperty 'HKCU:\SOFTWARE\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steam) {
        $librerie = @($steam -replace '/', '\')
        $vdf = Join-Path $librerie[0] 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $librerie += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
        foreach ($lib in ($librerie | Select-Object -Unique)) {
            $common = Join-Path $lib 'steamapps\common'
            if (Test-Path -LiteralPath $common) {
                Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue | ForEach-Object { Aggiungi $_.FullName }
            }
        }
    }
    return $trovate.ToArray()
}

function Trova-Gioco {
    Passo (T 'Cerco la cartella del gioco' 'Looking for the game folder')
    if ($CartellaProva -and (Exe-Gioco $CartellaProva)) { Buono $CartellaProva; return $CartellaProva }

    foreach ($c in (Candidati-Gioco)) {
        $r = [Windows.Forms.MessageBox]::Show(
            (T "Ho trovato il gioco qui:`n`n$c`n`nInstallo in questa cartella?" "I found the game here:`n`n$c`n`nInstall into this folder?"),
            'Football Life 2026 / PES 2021', 'YesNoCancel', 'Question')
        if ($r -eq 'Yes') { Buono $c; return $c }
        if ($r -eq 'Cancel') { Guaio (T 'Annullato.' 'Cancelled.'); return $null }
    }

    Avviso (T 'Scegli tu il gioco: seleziona FL_2026.exe (Football Life) o PES2021.exe' 'Pick the game yourself: select FL_2026.exe (Football Life) or PES2021.exe')
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Title = T 'Seleziona FL_2026.exe (Football Life 2026) o PES2021.exe (PES 2021)' 'Select FL_2026.exe (Football Life 2026) or PES2021.exe (PES 2021)'
    $dlg.Filter = 'FL_2026.exe / PES2021.exe|FL_2026.exe;PES2021.exe'
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -eq 'OK') {
        $c = Split-Path $dlg.FileName -Parent
        if (Exe-Gioco $c) { Buono $c; return $c }
    }
    Guaio (T 'Nessuna cartella valida scelta.' 'No valid folder chosen.')
    return $null
}

function Controlli {
    Passo (T 'Controllo il computer' 'Checking your PC')
    $ok = $true
    $gpu = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'Radeon' })
    if ($gpu.Count -eq 0) { Guaio (T 'Nessuna Radeon trovata.' 'No Radeon found.'); $ok = $false }
    elseif ($gpu[0].Name -match 'RX\s*9\d{3}|RX\s*7\d{3}') { Buono $gpu[0].Name }
    else { Avviso ($gpu[0].Name + (T '  (serve RX 7000 o 9000)' '  (RX 7000 or 9000 needed)')) }

    if (Test-Path "$env:WINDIR\System32\amdhip64_7.dll") { Buono 'HIP 7' }
    else { Guaio (T 'Manca amdhip64_7.dll: aggiorna i driver Adrenalin.' 'amdhip64_7.dll missing: update Adrenalin drivers.'); $ok = $false }

    if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'PES2021|FL_2026|sider' }) {
        Guaio (T 'Chiudi il gioco (e sider, se lo usi), poi riprova.' 'Close the game (and sider, if you use it), then retry.'); $ok = $false
    } else { Buono (T 'Gioco chiuso' 'Game closed') }
    return $ok
}

function Prendi-Addon {
    $p = Cerca-Ovunque 'dlss5-neural.addon64' $HASH['dlss5-neural.addon64']
    if ($p) { Buono 'dlss5-neural.addon64'; return $p }
    $dest = Join-Path $LAVORO 'dlss5-neural.addon64'
    if (-not (Scarica $URL.addon $dest 'dlss5-neural.addon64')) { return $null }
    if (Hash-Ok $dest $HASH['dlss5-neural.addon64']) { Buono (T 'impronta verificata' 'fingerprint verified'); return $dest }
    Guaio (T 'Impronta sbagliata: file scartato.' 'Wrong fingerprint: file discarded.')
    return $null
}

function Prendi-ReShade($gioco) {
    $p = Cerca-Ovunque 'ReShade64.dll' $HASH['ReShade64.dll']
    if (-not $p) {
        foreach ($n in 'dxgi.dll','d3d11.dll') {
            $q = Join-Path $gioco $n
            if (Hash-Ok $q $HASH['ReShade64.dll']) { $p = $q; break }
        }
    }
    if ($p) { Buono 'ReShade 6.8.0 Addon'; return $p }

    $setup = Join-Path $LAVORO 'ReShade_Setup_6.8.0_Addon.exe'
    if (-not (Test-Path $setup)) {
        if (-not (Scarica $URL.reshadeSetup $setup (T 'ReShade 6.8.0 (sito ufficiale)' 'ReShade 6.8.0 (official site)'))) { return $null }
    }
    Avviso (T 'Si apre il programma ufficiale di ReShade.' 'The official ReShade setup will open.')
    $exe = Exe-Gioco $gioco
    Avviso (T "Scegli il gioco $(Split-Path $exe -Leaf), poi Direct3D 10/11/12, poi nessun effetto." `
              "Pick $(Split-Path $exe -Leaf), then Direct3D 10/11/12, then no effect packages.")
    Start-Process -FilePath $setup -ArgumentList "`"$exe`"" -Wait
    foreach ($n in 'dxgi.dll','d3d11.dll','ReShade64.dll') {
        $q = Join-Path $gioco $n
        if (Hash-Ok $q $HASH['ReShade64.dll']) { Buono (T "ReShade installato come $n" "ReShade installed as $n"); return $q }
    }
    Guaio (T 'ReShade non risulta installato nel gioco.' 'ReShade does not appear to be installed.')
    return $null
}

function Prendi-Runtime {
    $r = @{}
    foreach ($n in 'dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
        $p = Cerca-Ovunque $n $HASH[$n]
        if ($p) { Buono $n; $r[$n] = $p }
    }
    if ($r.Count -eq 2) { return $r }

    if ($AutorizzatoDallAutore) {
        Avviso (T 'Permesso attivo: qui va il download diretto (da scrivere).' `
                  'Permission enabled: direct download goes here (to be written).')
    }

    Passo (T 'Servono i file di Daniel Blanco: uso il suo installer ufficiale' `
              'Daniel Blanco''s files are needed: using his official installer')
    Avviso (T 'La sua licenza chiede di passare dal suo canale: e'' quello che facciamo.' `
              'His licence asks to go through his own channel: that is what we do.')
    $zip = Join-Path $LAVORO 'AMD-NR-ReShade-Installer.zip'
    if (-not (Test-Path $zip)) {
        if (-not (Scarica $URL.amdnrZip $zip (T 'AMD-NR ReShade Installer (ufficiale)' 'AMD-NR ReShade Installer (official)'))) { return $null }
    }
    $cartella = Join-Path $LAVORO 'amdnr'
    if (-not (Test-Path $cartella)) { Expand-Archive -LiteralPath $zip -DestinationPath $cartella -Force }
    $exe = Get-ChildItem $cartella -Recurse -Filter '*.exe' | Select-Object -First 1
    if (-not $exe) { Guaio (T 'Installer ufficiale non trovato nello zip.' 'Official installer not found in the zip.'); return $null }

    Avviso (T 'Si apre l''installer ufficiale: arriva al passo 3 (download) e chiudilo.' `
              'The official installer opens: go to step 3 (download) and close it.')
    [Windows.Forms.MessageBox]::Show(
        (T "Ora si apre l'installer ufficiale di AMD-NR.`n`n1. Scegli la lingua`n2. Fai il controllo della scheda`n3. Scarica i file (circa 165 MB)`n4. CHIUDILO: al resto pensiamo noi" `
           "The official AMD-NR installer will open now.`n`n1. Pick a language`n2. Run the machine check`n3. Download the files (about 165 MB)`n4. CLOSE IT: we do the rest"),
        'AMD-NR', 'OK', 'Information') | Out-Null
    Start-Process -FilePath $exe.FullName -Wait

    foreach ($n in 'dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
        if (-not $r.ContainsKey($n)) {
            $p = Cerca-Ovunque $n $HASH[$n]
            if ($p) { Buono $n; $r[$n] = $p } else { Guaio (T "$n non trovato." "$n not found.") }
        }
    }
    if ($r.Count -eq 2) { return $r }
    return $null
}

function Descrivi-Dll($p) {
    $vi = (Get-Item -LiteralPath $p).VersionInfo
    $nome = ("$($vi.ProductName) $($vi.ProductVersion)").Trim()
    if (-not $nome) { $nome = ("$($vi.FileDescription)").Trim() }
    if (-not $nome) { $nome = T 'programma sconosciuto' 'unknown program' }
    return $nome
}

function Controlla-Conflitti($gioco) {
    # Un altro dxgi.dll (di solito un preset ReShade) insieme al nostro d3d11.dll vuol dire
    # due ReShade caricati insieme: il gioco puo' non partire. Si chiede prima di toccarlo.
    # Another dxgi.dll (usually a ReShade preset) next to our d3d11.dll means two ReShades
    # loaded at once: the game may not start. Ask before touching it.
    $script:spostaDxgi = $false
    $dx = Join-Path $gioco 'dxgi.dll'
    if (-not (Test-Path -LiteralPath $dx)) { return $true }
    if (Hash-Ok $dx $HASH['ReShade64.dll']) { return $true }
    $nome = Descrivi-Dll $dx
    Avviso (T "Nel gioco c'e' gia' un dxgi.dll: $nome" "There is already a dxgi.dll in the game: $nome")
    $r = [Windows.Forms.MessageBox]::Show(
        (T "Nella cartella del gioco c'e' gia' un dxgi.dll:`n$nome`n`nDi solito e' un altro ReShade (un preset grafico). Due ReShade insieme possono impedire al gioco di partire.`n`nSI' = lo metto da parte (dxgi.dll.prima-del-dlss.bak) e continuo. Il preset resta disattivato: Disinstalla lo rimette com'era.`n`nNO = mi fermo e non tocco niente." `
           "There is already a dxgi.dll in the game folder:`n$nome`n`nIt is usually another ReShade (a graphics preset). Two ReShades together can stop the game from starting.`n`nYES = I set it aside (dxgi.dll.prima-del-dlss.bak) and carry on. The preset stays disabled: Uninstall puts it back.`n`nNO = I stop and touch nothing."),
        'dxgi.dll', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { Guaio (T 'Fermato: non ho toccato niente.' 'Stopped: nothing was touched.'); return $false }
    $script:spostaDxgi = $true
    return $true
}

function Metti-DaParte($gioco, $nome, [switch]$Sempre) {
    $p = Join-Path $gioco $nome
    if (-not (Test-Path -LiteralPath $p)) { return }
    $bak = "$p.prima-del-dlss.bak"
    if (Test-Path -LiteralPath $bak) {
        if (-not $Sempre) { return }
        $bak = "$p.prima-del-dlss.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    }
    Move-Item -LiteralPath $p -Destination $bak -Force
    Avviso (T "$nome messo da parte come $(Split-Path $bak -Leaf)" "$nome set aside as $(Split-Path $bak -Leaf)")
}

function Risolvi-Conflitti($gioco) {
    if (-not $script:spostaDxgi) { return $false }
    Passo (T 'Metto da parte il ReShade che c''era prima' 'Setting the previous ReShade aside')
    Metti-DaParte $gioco 'dxgi.dll' -Sempre
    Metti-DaParte $gioco 'ReShade.ini'
    Metti-DaParte $gioco 'ReShadePreset.ini'
    $script:spostaDxgi = $false
    return $true
}

function Installa {
    $log.Clear(); $barra.Value = 0; $script:soloBenvenuto = $false
    Scrivi (T '=== INSTALLAZIONE ===' '=== INSTALLATION ===') $MAGENTA

    Stato @('Controllo le versioni...', 'Checking versions...') 3
    Leggi-Manifesto
    Mostra-Versioni

    Stato @('Cerco il gioco...', 'Looking for the game...') 5
    $gioco = Trova-Gioco
    if (-not $gioco) { Stato @('Interrotto.', 'Aborted.') 0; return }
    $script:GIOCO = $gioco

    Stato @('Controlli...', 'Checks...') 12
    if (-not (Controlli)) { Stato @('Interrotto.', 'Aborted.') 0; return }
    if (-not (Controlla-Conflitti $gioco)) { Stato @('Interrotto.', 'Aborted.') 0; return }

    # --- gia' installato? allora non tocchiamo niente -------------------------
    $giaFatto = (Hash-Ok (Join-Path $gioco 'd3d11.dll') $HASH['ReShade64.dll'])
    foreach ($n in 'dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
        if (-not (Hash-Ok (Join-Path $gioco $n) $HASH[$n])) { $giaFatto = $false }
    }
    # --- non e' l'ultima versione, ma e' roba nostra? allora e' un aggiornamento
    # --- not the latest version, but ours? then this is an update
    $aggiornamento = $false
    if (-not $giaFatto) {
        $tuttiNostri = (Hash-Accettabile (Join-Path $gioco 'd3d11.dll') 'ReShade64.dll')
        foreach ($n in 'dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
            if (-not (Hash-Accettabile (Join-Path $gioco $n) $n)) { $tuttiNostri = $false }
        }
        $aggiornamento = $tuttiNostri
    }
    if ($aggiornamento) {
        Passo (T 'Trovata una versione precedente: la aggiorno' 'An older version is installed: updating it')
        Scrivi (T "     passo a: add-on $($script:VERS.addon), runtime $($script:VERS.runtime), ReShade $($script:VERS.reshade)" `
                  "     moving to: add-on $($script:VERS.addon), runtime $($script:VERS.runtime), ReShade $($script:VERS.reshade)") $GRIGIO
        Scrivi (T '     le tue impostazioni (dlss5-neural.ini, ReShade.ini) non si toccano' `
                  '     your settings (dlss5-neural.ini, ReShade.ini) are left alone') $GRIGIO
        Scrivi (T '     dei file sostituiti tengo una copia .precedente.bak' `
                  '     a .precedente.bak copy of each replaced file is kept') $GRIGIO
    }

    if ($giaFatto) {
        Passo (T 'Controllo i file gia'' presenti nel gioco' 'Checking the files already in the game')
        foreach ($n in 'd3d11.dll','dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') { Buono $n }
        if (Risolvi-Conflitti $gioco) {
            Stato @('Conflitto con dxgi.dll risolto.', 'dxgi.dll conflict fixed.') 100
            Scrivi '' $VERDE
            Scrivi (T '=== CONFLITTO RISOLTO ===' '=== CONFLICT FIXED ===') $MAGENTA
            Scrivi (T '  La mod era gia'' installata: ho solo messo da parte il dxgi.dll' '  The mod was already installed: I only set aside the dxgi.dll') $VERDE
            Scrivi (T '  che andava in conflitto. Ora il gioco dovrebbe partire.' '  that was clashing with it. The game should start now.') $VERDE
        } else {
        Stato @('Gia'' installato: nessuna modifica.', 'Already installed: nothing changed.') 100
        Scrivi '' $VERDE
        Scrivi (T '=== GIA'' INSTALLATO ===' '=== ALREADY INSTALLED ===') $MAGENTA
        Scrivi (T '  Tutti i file sono gia'' al loro posto e sono quelli giusti.' '  All files are already in place and correct.') $VERDE
        Scrivi (T '  Non ho toccato nulla: le tue impostazioni restano come sono.' '  Nothing was touched: your settings stay as they are.') $VERDE
        }
        Scrivi '' $VERDE
        Scrivi (T '  Buon divertimento!  -- oLd_pZ' '  Have fun!  -- oLd_pZ') $MAGENTA
        return
    }

    Stato @('Add-on...', 'Add-on...') 25
    $addon = Prendi-Addon
    if (-not $addon) { Stato @('Interrotto.', 'Aborted.') 0; return }

    Stato @('Runtime e pesi...', 'Runtime and weights...') 45
    $rt = Prendi-Runtime
    if (-not $rt) { Stato @('Interrotto.', 'Aborted.') 0; return }

    [void](Risolvi-Conflitti $gioco)

    Stato @('ReShade...', 'ReShade...') 70
    $rs = Prendi-ReShade $gioco
    if (-not $rs) { Stato @('Interrotto.', 'Aborted.') 0; return }

    Stato @('Copio nel gioco...', 'Copying into the game...') 85
    Passo (T 'Metto tutto al suo posto' 'Putting everything in place')
    $messi = @()

    $destRs = Join-Path $gioco 'd3d11.dll'
    if ($rs -ne $destRs) {
        if ((Test-Path $destRs) -and -not (Hash-Ok $destRs $HASH['ReShade64.dll'])) {
            if (Hash-Accettabile $destRs 'ReShade64.dll') {
                # e' il NOSTRO ReShade, solo di una versione precedente: lo aggiorno
                # e lascio stare ReShade.ini, che sono le impostazioni dell'utente
                # it is OUR ReShade, just an older version: update it and leave
                # ReShade.ini alone, those are the user's settings
                Salva-Precedente $gioco 'd3d11.dll' $HASH['ReShade64.dll']
                Avviso (T 'Aggiorno ReShade: le tue impostazioni restano.' 'Updating ReShade: your settings are kept.')
            } else {
                if ((Descrivi-Dll $destRs) -match 'ReShade') { Metti-DaParte $gioco 'ReShade.ini'; Metti-DaParte $gioco 'ReShadePreset.ini' }
                Move-Item -LiteralPath $destRs -Destination "$destRs.prima-del-dlss.bak" -Force
                Avviso (T 'Il d3d11.dll precedente e'' stato messo da parte.' 'The previous d3d11.dll was set aside.')
            }
        }
        Copy-Item -LiteralPath $rs -Destination $destRs -Force
        if ($rs -like (Join-Path $gioco 'dxgi.dll')) {
            Remove-Item -LiteralPath $rs -Force
            Avviso (T 'Tolto dxgi.dll: con sider si usa d3d11.dll.' 'Removed dxgi.dll: with sider we use d3d11.dll.')
        }
    }
    Buono 'd3d11.dll'; $messi += 'd3d11.dll'
    # vecchie copie del nostro ReShade rinominate a mano (con le estensioni nascoste diventa .off.dll)
    # old copies of our ReShade renamed by hand (with hidden extensions it becomes .off.dll)
    foreach ($n in 'd3d11.dll.off','d3d11.dll.off.dll') {
        $q = Join-Path $gioco $n
        if ((Test-Path -LiteralPath $q) -and (Hash-Ok $q $HASH['ReShade64.dll'])) {
            Remove-Item -LiteralPath $q -Force
            Avviso (T "tolto $n (vecchia copia rinominata, non serve piu')" "removed $n (old renamed copy, no longer needed)")
        }
    }

    $destAddon = Join-Path $gioco 'dlss5-neural.addon64'
    if ($addon -ne $destAddon) {
        Salva-Precedente $gioco 'dlss5-neural.addon64' $HASH['dlss5-neural.addon64']
        Copy-Item -LiteralPath $addon -Destination $destAddon -Force
    }
    Buono 'dlss5-neural.addon64'; $messi += 'dlss5-neural.addon64'
    foreach ($n in $rt.Keys) {
        $destN = Join-Path $gioco $n
        if ($rt[$n] -ne $destN) {
            Salva-Precedente $gioco $n $HASH[$n]
            Copy-Item -LiteralPath $rt[$n] -Destination $destN -Force
        }
        Buono $n; $messi += $n
    }
    $ini = Join-Path $PACK 'dlss5-neural.ini'
    $destIni = Join-Path $gioco 'dlss5-neural.ini'
    if ((Test-Path $ini) -and -not (Test-Path $destIni)) {
        Copy-Item -LiteralPath $ini -Destination $destIni -Force
        Buono (T 'dlss5-neural.ini (Scale=0.60)' 'dlss5-neural.ini (Scale=0.60)'); $messi += 'dlss5-neural.ini'
    }

    Stato @('Verifica finale...', 'Final check...') 95
    Passo (T 'Ricontrollo le impronte dei file copiati' 'Re-checking the copied files')
    $errori = 0
    foreach ($n in 'dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
        if (Hash-Ok (Join-Path $gioco $n) $HASH[$n]) { Buono $n } else { Guaio $n; $errori++ }
    }
    if (Hash-Ok (Join-Path $gioco 'd3d11.dll') $HASH['ReShade64.dll']) { Buono 'd3d11.dll' } else { Guaio 'd3d11.dll'; $errori++ }

    $reg = @()
    $reg += "Installato il / installed on $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
    $reg += 'Pacchetto di / pack by oLd_pZ'
    $reg += 'File aggiunti / files added:'
    $reg += $messi
    $reg | Set-Content -LiteralPath (Join-Path $gioco '_dlss5-installato.txt') -Encoding UTF8

    if ($errori -gt 0) { Stato @('Finito con errori.', 'Finished with errors.') 100; return }

    Stato @('FATTO!', 'DONE!') 100
    Scrivi '' $VERDE
    Scrivi (T '=== INSTALLATO ===' '=== INSTALLED ===') $MAGENTA
    Scrivi (T '  1. Avvia il gioco come al solito:' '  1. Start the game as usual:') $VERDE
    Scrivi (T '     Football Life / patch con sider -> il .bat che lancia sider' `
              '     Football Life / patches with sider -> the .bat that launches sider') $VERDE
    Scrivi (T '     PES 2021 senza sider -> da Steam' '     PES 2021 without sider -> from Steam') $VERDE
    Scrivi (T '  2. HOME apre il pannello di ReShade' '  2. HOME opens the ReShade panel') $VERDE
    Scrivi (T '  3. CTRL+FINE accende l''effetto (parte spento)' '  3. CTRL+END switches the effect on (starts off)') $VERDE
    Scrivi (T '     Se non succede nulla, chiudi prima il pannello con HOME' `
              '     If nothing happens, close the panel with HOME first') $GRIGIO
    Scrivi '' $VERDE
    Scrivi (T '  Ricorda: FA CALARE gli fps. Solo offline.' '  Remember: it LOWERS fps. Offline only.') ([Drawing.Color]::FromArgb(255,210,80))
    Scrivi (T '  Mai in myClub o online: prima lancia DISINSTALLA - UNINSTALL.bat' `
              '  Never in myClub or online: run DISINSTALLA - UNINSTALL.bat first') ([Drawing.Color]::FromArgb(255,210,80))
    Scrivi '' $VERDE
    Scrivi (T '  Buon divertimento!  -- oLd_pZ' '  Have fun!  -- oLd_pZ') $MAGENTA
    Scrivi (T '  Se condividi il pacchetto, cita l''autore. Grazie!' '  If you share this pack, please credit the author. Thanks!') $GRIGIO
}

function Rimuovi {
    $log.Clear(); $barra.Value = 0; $script:soloBenvenuto = $false
    Scrivi (T '=== DISINSTALLAZIONE ===' '=== UNINSTALL ===') $MAGENTA
    # serve anche qui: se l'utente ha installato una versione piu' nuova presa
    # dall'elenco online, le impronte di fabbrica non la riconoscerebbero
    # needed here too: if the user installed a newer version from the online
    # list, the factory fingerprints would not recognise it
    Leggi-Manifesto
    $gioco = if ($script:GIOCO) { $script:GIOCO } else { Trova-Gioco }
    if (-not $gioco) { return }
    if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'PES2021|FL_2026|sider' }) {
        Guaio (T 'Chiudi il gioco, poi riprova.' 'Close the game, then retry.'); return
    }
    $tolti = 0
    $nostroReShade = $false
    # d3d11.dll solo se e' il NOSTRO ReShade: se e' di un'altra mod non si tocca
    # d3d11.dll only if it is OUR ReShade: if it belongs to another mod, leave it
    foreach ($n in 'd3d11.dll','d3d11.dll.off','d3d11.dll.off.dll') {
        $p = Join-Path $gioco $n
        if (Test-Path -LiteralPath $p) {
            if (Hash-Accettabile $p 'ReShade64.dll') { Remove-Item -LiteralPath $p -Force; Buono $n; $tolti++; $nostroReShade = $true }
            else { Avviso (T "$n non e' il nostro ReShade: lo lascio stare" "$n is not our ReShade: leaving it alone") }
        }
    }
    # i file ReShade.* si tolgono solo insieme al nostro ReShade, altrimenti sono dell'altra mod
    # ReShade.* files go only together with our ReShade, otherwise they belong to the other mod
    $daTogliere = @('dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin',
                    'dlss5-neural.ini','dlssnr_on_amd.ini','dlssnr_on_amd.log','dlss5-neural.log','_dlss5-installato.txt')
    # copie tenute dagli aggiornamenti / copies kept by the updates
    foreach ($n in 'd3d11.dll','dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
        $daTogliere += "$n.precedente.bak"
    }
    if ($nostroReShade) { $daTogliere += 'ReShade.ini','ReShade.log','ReShadePreset.ini' }
    foreach ($n in $daTogliere) {
        $p = Join-Path $gioco $n
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Force; Buono $n; $tolti++ }
    }
    # rimette a posto quello che l'installer aveva messo da parte
    # puts back what the installer had set aside
    foreach ($n in 'd3d11.dll','dxgi.dll','ReShade.ini','ReShadePreset.ini') {
        $p = Join-Path $gioco $n
        $bak = "$p.prima-del-dlss.bak"
        if (Test-Path -LiteralPath $bak) {
            if (Test-Path -LiteralPath $p) { Avviso (T "$n esiste gia': lascio $n.prima-del-dlss.bak com'e'" "$n already exists: leaving $n.prima-del-dlss.bak as it is") }
            else { Move-Item -LiteralPath $bak -Destination $p -Force; Buono (T "ripristinato $n di prima" "previous $n restored") }
        }
    }
    Stato @("Rimossi $tolti file.", "$tolti files removed.") 100
    Scrivi (T '  Il gioco e'' tornato com''era.' '  The game is back as it was.') $VERDE
}

# ================================================================= EVENTI =====
$btnIT.Add_Click({ $script:LANG = 'IT'; Aggiorna-Testi; Salva-Prefs })
$btnEN.Add_Click({ $script:LANG = 'EN'; Aggiorna-Testi; Salva-Prefs })
$btnMusica.Add_Click({
    $script:musicaAccesa = -not $script:musicaAccesa
    if ($script:musicaAccesa) { if ($script:player) { $script:player.Play() } else { Avvia-Musica } } else { Ferma-Musica }
    Aggiorna-Testi; Salva-Prefs
})
$btnVai.Add_Click({ $btnVai.Enabled = $false; $btnTogli.Enabled = $false
                    try { Installa } catch { Guaio $_.Exception.Message }
                    $btnVai.Enabled = $true; $btnTogli.Enabled = $true })
$btnTogli.Add_Click({ $btnVai.Enabled = $false; $btnTogli.Enabled = $false
                      try { Rimuovi } catch { Guaio $_.Exception.Message }
                      $btnVai.Enabled = $true; $btnTogli.Enabled = $true })
$form.Add_FormClosing({ Ferma-Musica; Salva-Prefs })

# =================================================================== AVVIO ====
Leggi-Prefs
Aggiorna-Testi
if (-not (Test-Path $LAVORO)) { New-Item -ItemType Directory -Force -Path $LAVORO | Out-Null }
Mostra-Benvenuto
Stato @('Pronto', 'Ready') 0
if ($script:musicaAccesa) { Avvia-Musica }

if ($Test) {
    Leggi-Manifesto
    Write-Host "fonte        : $($script:VERS.fonte)"
    Write-Host "versioni     : addon $($script:VERS.addon) | runtime $($script:VERS.runtime) | reshade $($script:VERS.reshade)"
    Write-Host "aggiornato   : $($script:VERS.aggiornato)"
    Write-Host "avviso_it    : $($script:VERS.avviso_it)"
    Write-Host "hash addon   : $($HASH['dlss5-neural.addon64'])"
    Write-Host "hash reshade : $($HASH['ReShade64.dll'])"
    Write-Host "hash pass1   : $($HASH['dlssnr_amd_pass1.dll'])"
    Write-Host "hash pesi    : $($HASH['dlssnr_on_amd_weights.bin'])"
    Write-Host "url addon    : $($URL.addon)"
    Write-Host "url reshade  : $($URL.reshadeSetup)"
    Write-Host "accettati    : addon=$($ACCETTATI['dlss5-neural.addon64'].Count) reshade=$($ACCETTATI['ReShade64.dll'].Count) pass1=$($ACCETTATI['dlssnr_amd_pass1.dll'].Count) pesi=$($ACCETTATI['dlssnr_on_amd_weights.bin'].Count)"
    Scrivi (T '  [modalita'' test: chiudo]' '  [test mode: closing]') $GRIGIO
    $form.Show(); Start-Sleep -Milliseconds 300; $form.Close()
} elseif ($Disinstalla) {
    $form.Add_Shown({ Rimuovi })
    [void]$form.ShowDialog()
} else {
    [void]$form.ShowDialog()
}
