#Requires -Version 5.1
<#
================================================================================
  DLSS 5 Neural Rendering su AMD Radeon  --  Football Life 2026 / PES 2021
  Installatore automatico  /  Automatic installer

  NON contiene i file della mod: li cerca dove li hai scaricati, ne verifica
  l'impronta SHA-256 e li mette al posto giusto con i nomi giusti.
  Does NOT contain the mod files: it finds where you downloaded them, verifies
  their SHA-256 fingerprint, and puts them in the right place under the right
  names.
================================================================================
#>

param(
    [switch]$Disinstalla,
    # Parametri facoltativi: servono per l'uso non interattivo e per i test.
    # Optional parameters: for non-interactive use and for testing.
    [string]$Gioco,                 # percorso della cartella del gioco / game folder path
    [ValidateSet('IT','EN')]
    [string]$Lingua,                # IT oppure EN / IT or EN
    [switch]$SenzaDomande           # non chiede nulla e non aspetta INVIO / no prompts, no final ENTER
)

$ErrorActionPreference = 'Stop'
$PACK = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------- impronte ---
# Valori pubblicati dai progetti ufficiali (payload.json / SHA256SUMS.txt).
# Fingerprints published by the official projects.
$ATTESI = @{
    'dlss5-neural.addon64'      = '0d0a63f6ac886fafb0d04a0df3c5d4f2908e1a44a966648bba949ad2dcc33cc6'
    'dlssnr_amd_pass1.dll'      = '70af3fb757f83f71ec947ce461970fdecc9636864bc01d952abffb36ae310be6'
    'dlssnr_on_amd_weights.bin' = '6bf8dc931ef3ccffe18c82de26ab374156e7f19539ffcf8eabaa25dca5cf15ab'
}
$RESHADE_HASH = '0cee63f9c9f13f3ac909c5b4903f4dbb4b719a7ab3b4f13b0deaf83c814b94f7'  # ReShade 6.8.0 Addon
$DIMENSIONI = @{
    'dlss5-neural.addon64'      = 552960
    'dlssnr_amd_pass1.dll'      = 7290880
    'dlssnr_on_amd_weights.bin' = 147689451
}
$RESHADE_SIZE = 5592064

# ---- ELENCO VERSIONI ONLINE / ONLINE VERSION LIST ----------------------------
# I valori qui sopra sono quelli "di fabbrica". All'avvio si prova a leggere
# l'elenco delle versioni provate dal gist ufficiale; se non si raggiunge si usa
# l'ultima copia salvata, e in mancanza di tutto restano i valori di fabbrica.
# The values above are the "factory" ones. At startup we try to read the list of
# tested versions from the official gist; if it cannot be reached we use the last
# saved copy, and failing that the factory values stay.
$URL_MANIFESTO = 'https://gist.githubusercontent.com/oLdpZ/b99deca59ef76cc5fb7895b786fe36dc/raw/versioni.json'
$CACHE_MANIFESTO = Join-Path $env:APPDATA 'FL26-DLSS-Installer\versioni.json'
$DOMINI_OK = '^https://(github\.com|reshade\.me)/'
$ACCETTATI = @{
    'dlss5-neural.addon64'      = @()
    'dlssnr_amd_pass1.dll'      = @()
    'dlssnr_on_amd_weights.bin' = @()
    'ReShade64.dll'             = @()
}
$VERS = @{ addon = 'v0.5.2'; runtime = '0.3.0'; reshade = '6.8.0'; aggiornato = ''
           avviso_it = ''; avviso_en = ''; fonte = 'script' }

# ------------------------------------------------------------------ lingua ---
function Chiedi-Lingua {
    Write-Host ""
    Write-Host "  ============================================================"
    Write-Host "   DLSS 5 Neural Rendering su AMD Radeon"
    Write-Host "   Football Life 2026 / PES 2021"
    Write-Host "   by oLd_pZ" -ForegroundColor Magenta
    Write-Host "  ============================================================"
    Write-Host ""
    if ($Lingua) { return $Lingua }
    if ($SenzaDomande) { return 'IT' }
    Write-Host "   1) Italiano"
    Write-Host "   2) English"
    Write-Host ""
    $s = Read-Host "   Scegli / Choose [1]"
    if ($s -eq '2') { return 'EN' } else { return 'IT' }
}
$LANG = Chiedi-Lingua

function T($it, $en) { if ($LANG -eq 'EN') { return $en } else { return $it } }
function Titolo($t) { Write-Host ""; Write-Host "  == $t" -ForegroundColor Cyan }
function Ok($t)     { Write-Host "     [OK] $t" -ForegroundColor Green }
function Attenzione($t) { Write-Host "     [!]  $t" -ForegroundColor Yellow }
function Errore($t) { Write-Host "     [X]  $t" -ForegroundColor Red }
function Info($t)   { Write-Host "     $t" }

function Esci($codice) {
    Write-Host ""
    Write-Host "  ------------------------------------------------------------"
    if (-not $SenzaDomande) {
        Read-Host (T "  Premi INVIO per chiudere" "  Press ENTER to close") | Out-Null
    }
    exit $codice
}

# ============================================================ CARTELLA GIOCO ==
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
    Titolo (T "Cerco la cartella del gioco" "Looking for the game folder")

    # Percorso passato da riga di comando / path given on the command line
    if ($Gioco) {
        if (Exe-Gioco $Gioco) { Ok $Gioco; return $Gioco }
        Errore (T "In '$Gioco' non c'e' ne' FL_2026.exe ne' PES2021.exe." "There is no FL_2026.exe or PES2021.exe in '$Gioco'.")
        Esci 1
    }

    $candidate = @(Candidati-Gioco)

    if ($candidate.Count -eq 1) {
        Ok $candidate[0]
        return $candidate[0]
    }
    if ($candidate.Count -gt 1) {
        Info (T "Ne ho trovate piu' di una:" "I found more than one:")
        for ($i=0; $i -lt $candidate.Count; $i++) { Info "  $($i+1)) $($candidate[$i])" }
        if ($SenzaDomande) { Ok $candidate[0]; return $candidate[0] }
        $s = Read-Host (T "     Quale? [1]" "     Which one? [1]")
        $n = 0
        if (-not [int]::TryParse("$s", [ref]$n) -or $n -lt 1 -or $n -gt $candidate.Count) { $n = 1 }
        Ok $candidate[$n - 1]
        return $candidate[$n - 1]
    }

    Attenzione (T "Non l'ho trovata da solo." "I could not find it on my own.")
    Info (T "Apri la cartella del gioco (quella con FL_2026.exe o PES2021.exe), copia il percorso" `
            "Open your game folder (the one with FL_2026.exe or PES2021.exe), copy the path")
    Info (T "dalla barra degli indirizzi e incollalo qui sotto." `
            "from the address bar and paste it below.")
    Write-Host ""
    $p = (Read-Host (T "     Percorso" "     Path")).Trim('"',' ')
    if (-not (Exe-Gioco $p)) {
        Errore (T "In quella cartella non c'e' ne' FL_2026.exe ne' PES2021.exe." "There is no FL_2026.exe or PES2021.exe in that folder.")
        Esci 1
    }
    Ok $p
    return $p
}

# ================================================================ REQUISITI ==
function Controlla-Requisiti {
    Titolo (T "Controllo il computer" "Checking your PC")
    $problemi = 0

    $gpu = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'Radeon' })
    if ($gpu.Count -eq 0) {
        Errore (T "Nessuna scheda AMD Radeon trovata. Questa mod funziona solo su Radeon RX 7000/9000." `
                  "No AMD Radeon card found. This mod only works on Radeon RX 7000/9000.")
        $problemi++
    } else {
        $nome = $gpu[0].Name
        if ($nome -match 'RX\s*9\d{3}|RX\s*7\d{3}') { Ok $nome }
        else {
            Attenzione (T "Scheda trovata: $nome" "Card found: $nome")
            Attenzione (T "Servono RX 7000 (RDNA3) o RX 9000 (RDNA4). Potrebbe non funzionare." `
                          "RX 7000 (RDNA3) or RX 9000 (RDNA4) are required. This may not work.")
        }
    }

    if (Test-Path "$env:WINDIR\System32\amdhip64_7.dll") {
        Ok (T "Runtime HIP 7 presente" "HIP 7 runtime present")
    } else {
        Errore (T "Manca amdhip64_7.dll: aggiorna i driver AMD Adrenalin all'ultima versione." `
                  "amdhip64_7.dll is missing: update your AMD Adrenalin driver to the latest version.")
        $problemi++
    }

    $proc = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'PES2021|FL_2026|sider' }
    if ($proc) {
        Errore (T "Il gioco (o sider, se lo usi) e' aperto. Chiudilo e rilancia questo installatore." `
                  "The game (or sider, if you use it) is running. Close it and start this installer again.")
        $problemi++
    } else { Ok (T "Gioco chiuso" "Game is closed") }

    if ($problemi -gt 0) { Esci 1 }
}

# ========================================================= ELENCO VERSIONI ===
function Hash-Valido($h) { (($h -is [string]) -and ($h -match '^[0-9a-f]{64}$')) }
function Url-Sicuro($u)  { (($u -is [string]) -and ($u -match $DOMINI_OK)) }

function Hash-Accettabile($percorso, $nome) {
    # vero se il file e' la versione attuale o una precedente ancora accettata
    # true if the file is the current version or an older accepted one
    if (-not (Test-Path -LiteralPath $percorso)) { return $false }
    $h = (Get-FileHash -LiteralPath $percorso -Algorithm SHA256).Hash.ToLower()
    $atteso = if ($nome -eq 'ReShade64.dll') { $RESHADE_HASH } else { $ATTESI[$nome] }
    if ($h -eq $atteso) { return $true }
    foreach ($v in $ACCETTATI[$nome]) { if ($h -eq $v) { return $true } }
    return $false
}

function Salva-Precedente($gioco, $nome, $hashAtteso) {
    # tiene una copia della versione precedente prima di sovrascriverla
    # keeps a copy of the previous version before overwriting it
    $p = Join-Path $gioco $nome
    if (-not (Test-Path -LiteralPath $p)) { return }
    if ((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() -eq $hashAtteso) { return }
    $bak = "$p.precedente.bak"
    try {
        if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force }
        Move-Item -LiteralPath $p -Destination $bak -Force
        Attenzione (T "versione precedente tenuta da parte: $nome.precedente.bak" `
                      "previous version kept as $nome.precedente.bak")
    } catch {
        Attenzione (T "non sono riuscito a tenere la copia di $nome" "could not keep a copy of $nome")
    }
}

function Applica-Manifesto($m) {
    if (-not $m) { return $false }
    if (-not $m.addon -or -not $m.runtime -or -not $m.reshade) { return $false }
    if (-not (Hash-Valido $m.addon.sha256))         { return $false }
    if (-not (Hash-Valido $m.reshade.sha256))       { return $false }
    if (-not (Hash-Valido $m.runtime.pass1_sha256)) { return $false }
    if (-not (Hash-Valido $m.runtime.pesi_sha256))  { return $false }
    if (-not (Url-Sicuro $m.addon.url))             { return $false }
    if (-not (Url-Sicuro $m.reshade.url))           { return $false }

    $ATTESI['dlss5-neural.addon64']      = $m.addon.sha256
    $ATTESI['dlssnr_amd_pass1.dll']      = $m.runtime.pass1_sha256
    $ATTESI['dlssnr_on_amd_weights.bin'] = $m.runtime.pesi_sha256
    $script:RESHADE_HASH = $m.reshade.sha256
    # le dimensioni servono solo a cercare piu' in fretta: se non ci sono, non si filtra
    # sizes only speed up the search: if they are missing, no size filter is applied
    $DIMENSIONI['dlss5-neural.addon64']      = [int]$m.addon.dimensione
    $DIMENSIONI['dlssnr_amd_pass1.dll']      = [int]$m.runtime.pass1_dimensione
    $DIMENSIONI['dlssnr_on_amd_weights.bin'] = [int]$m.runtime.pesi_dimensione
    $script:RESHADE_SIZE = [int]$m.reshade.dimensione

    foreach ($c in @(
        ,@('dlss5-neural.addon64',      $m.addon.accettati_anche)
        ,@('ReShade64.dll',             $m.reshade.accettati_anche)
        ,@('dlssnr_amd_pass1.dll',      $m.runtime.pass1_accettati_anche)
        ,@('dlssnr_on_amd_weights.bin', $m.runtime.pesi_accettati_anche))) {
        $buoni = @()
        foreach ($h in @($c[1])) { if (Hash-Valido $h) { $buoni += $h } }
        $ACCETTATI[$c[0]] = $buoni
    }
    if ($m.addon.versione)   { $VERS.addon   = [string]$m.addon.versione }
    if ($m.runtime.versione) { $VERS.runtime = [string]$m.runtime.versione }
    if ($m.reshade.versione) { $VERS.reshade = [string]$m.reshade.versione }
    if ($m.aggiornato)       { $VERS.aggiornato = [string]$m.aggiornato }
    if ($m.avviso_it)        { $VERS.avviso_it  = [string]$m.avviso_it }
    if ($m.avviso_en)        { $VERS.avviso_en  = [string]$m.avviso_en }
    return $true
}

function Leggi-Manifesto {
    $testo = $null
    $fonte = 'script'
    try {
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $testo = (Invoke-WebRequest -Uri $URL_MANIFESTO -UseBasicParsing -TimeoutSec 10).Content
        $fonte = 'gist'
    } catch { $testo = $null }
    if (-not $testo -and (Test-Path -LiteralPath $CACHE_MANIFESTO)) {
        try { $testo = Get-Content -LiteralPath $CACHE_MANIFESTO -Raw; $fonte = 'cache' } catch { $testo = $null }
    }
    if (-not $testo) { return }
    $m = $null
    try { $m = $testo | ConvertFrom-Json } catch { $m = $null }
    if (-not $m) { return }
    if (-not (Applica-Manifesto $m)) { return }
    $VERS.fonte = $fonte
    if ($fonte -eq 'gist') {
        try {
            $d = Split-Path $CACHE_MANIFESTO -Parent
            if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
            $testo | Set-Content -LiteralPath $CACHE_MANIFESTO -Encoding UTF8
        } catch { }
    }
}

function Mostra-Versioni {
    Titolo (T "Controllo quali versioni sono quelle buone" "Checking which versions are the good ones")
    Info ("   add-on $($VERS.addon)  |  runtime $($VERS.runtime)  |  ReShade $($VERS.reshade)")
    switch ($VERS.fonte) {
        'gist'  { Ok (T "elenco aggiornato al $($VERS.aggiornato)" "list updated on $($VERS.aggiornato)") }
        'cache' { Attenzione (T "sono offline: uso l'ultimo elenco salvato ($($VERS.aggiornato))" `
                                "offline: using the last saved list ($($VERS.aggiornato))") }
        default { Attenzione (T "elenco online non raggiungibile: uso le versioni di fabbrica" `
                                "online list unreachable: using the factory versions") }
    }
    $av = T $VERS.avviso_it $VERS.avviso_en
    if ($av) { Attenzione $av }
}

# ============================================================== TROVA FILE ===
function Trova-File($nome, $hashAtteso, $dimensione) {
    # 1) nella cartella "files" accanto a questo pacchetto
    $locale = Join-Path $PACK "files\$nome"
    if (Test-Path $locale) { return $locale }

    # 2) nella cache dell'installer ufficiale
    $cache = "$env:APPDATA\AmdNrInstaller"
    if (Test-Path $cache) {
        $f = Get-ChildItem $cache -Recurse -File -Filter $nome -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }

    # 3) in Download, Desktop e Documenti (anche nelle sottocartelle)
    foreach ($base in "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents") {
        if (Test-Path $base) {
            $f = Get-ChildItem $base -Recurse -File -Filter $nome -ErrorAction SilentlyContinue |
                 Where-Object { -not $dimensione -or $_.Length -eq $dimensione } | Select-Object -First 1
            if ($f) { return $f.FullName }
        }
    }
    return $null
}

function Trova-ReShade {
    foreach ($nome in 'ReShade64.dll','dxgi.dll','d3d11.dll') {
        $locale = Join-Path $PACK "files\$nome"
        if (Test-Path $locale) {
            if ((Get-FileHash $locale -Algorithm SHA256).Hash.ToLower() -eq $RESHADE_HASH) { return $locale }
        }
    }
    foreach ($base in "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:APPDATA\AmdNrInstaller") {
        if (Test-Path $base) {
            $trovati = Get-ChildItem $base -Recurse -File -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -match '^(ReShade64|dxgi|d3d11)\.dll$' -and (-not $RESHADE_SIZE -or $_.Length -eq $RESHADE_SIZE) }
            foreach ($f in $trovati) {
                if ((Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower() -eq $RESHADE_HASH) { return $f.FullName }
            }
        }
    }
    return $null
}

function Hash-Di($p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() }

function Descrivi-Dll($p) {
    $vi = (Get-Item -LiteralPath $p).VersionInfo
    $nome = ("$($vi.ProductName) $($vi.ProductVersion)").Trim()
    if (-not $nome) { $nome = ("$($vi.FileDescription)").Trim() }
    if (-not $nome) { $nome = T "programma sconosciuto" "unknown program" }
    return $nome
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
    Attenzione (T "$nome messo da parte come $(Split-Path $bak -Leaf)" "$nome set aside as $(Split-Path $bak -Leaf)")
}

function Controlla-Conflitti($gioco) {
    # Un altro dxgi.dll (di solito un preset ReShade) = due ReShade insieme: il gioco puo' non partire.
    # Another dxgi.dll (usually a ReShade preset) = two ReShades at once: the game may not start.
    $dx = Join-Path $gioco 'dxgi.dll'
    if (-not (Test-Path -LiteralPath $dx)) { return $false }
    if ((Hash-Di $dx) -eq $RESHADE_HASH) { return $false }
    Titolo (T "Controllo conflitti" "Checking for conflicts")
    Attenzione (T "Nel gioco c'e' gia' un dxgi.dll: $(Descrivi-Dll $dx)" "There is already a dxgi.dll in the game: $(Descrivi-Dll $dx)")
    Info (T "Di solito e' un altro ReShade (un preset grafico). Due ReShade insieme" `
            "It is usually another ReShade (a graphics preset). Two ReShades together")
    Info (T "possono impedire al gioco di partire." "can stop the game from starting.")
    Info (T "Se lo metto da parte il preset resta disattivato; Disinstalla lo rimette." `
            "If I set it aside the preset stays disabled; Uninstall puts it back.")
    if ($SenzaDomande) {
        Errore (T "Modalita' senza domande: mi fermo e non tocco niente." "No-prompt mode: stopping, nothing touched.")
        Esci 1
    }
    $s = Read-Host (T "     Lo metto da parte e continuo? [S/N]" "     Set it aside and carry on? [Y/N]")
    if ($s -notmatch '^\s*[SsYy]') {
        Errore (T "Fermato: non ho toccato niente." "Stopped: nothing was touched.")
        Esci 1
    }
    return $true
}

function Risolvi-Conflitti($gioco) {
    Metti-DaParte $gioco 'dxgi.dll' -Sempre
    Metti-DaParte $gioco 'ReShade.ini'
    Metti-DaParte $gioco 'ReShadePreset.ini'
}

# =============================================================== INSTALLA ====
function Installa {
    Leggi-Manifesto
    Mostra-Versioni
    $gioco = Trova-Gioco
    Controlla-Requisiti
    $spostaDxgi = Controlla-Conflitti $gioco

    # --- gia' installato? allora non tocchiamo niente -------------------------
    $giaFatto = $true
    foreach ($nome in @($ATTESI.Keys) + 'd3d11.dll') {
        $atteso = if ($nome -eq 'd3d11.dll') { $RESHADE_HASH } else { $ATTESI[$nome] }
        $q = Join-Path $gioco $nome
        if (-not (Test-Path $q) -or (Get-FileHash $q -Algorithm SHA256).Hash.ToLower() -ne $atteso) { $giaFatto = $false }
    }
    # --- non e' l'ultima versione ma e' roba nostra? allora e' un aggiornamento
    # --- not the latest version but ours? then this is an update
    $aggiornamento = $false
    if (-not $giaFatto) {
        $tuttiNostri = (Hash-Accettabile (Join-Path $gioco 'd3d11.dll') 'ReShade64.dll')
        foreach ($nome in $ATTESI.Keys) {
            if (-not (Hash-Accettabile (Join-Path $gioco $nome) $nome)) { $tuttiNostri = $false }
        }
        $aggiornamento = $tuttiNostri
    }
    if ($aggiornamento) {
        Write-Host ""
        Titolo (T "Trovata una versione precedente: la aggiorno" "An older version is installed: updating it")
        Info (T "   vado a: add-on $($VERS.addon), runtime $($VERS.runtime), ReShade $($VERS.reshade)" `
                "   moving to: add-on $($VERS.addon), runtime $($VERS.runtime), ReShade $($VERS.reshade)")
        Info (T "   le tue impostazioni non si toccano; dei file sostituiti tengo una copia .precedente.bak" `
                "   your settings are left alone; a .precedente.bak copy of each replaced file is kept")
    }

    if ($giaFatto) {
        Write-Host ""
        Ok (T "E' gia' tutto installato e i file sono quelli giusti." "Everything is already installed and the files are correct.")
        if ($spostaDxgi) {
            Risolvi-Conflitti $gioco
            Ok (T "Ho solo messo da parte il dxgi.dll in conflitto: ora il gioco dovrebbe partire." `
                  "I only set aside the clashing dxgi.dll: the game should start now.")
        } else {
            Info (T "Non ho toccato nulla: le tue impostazioni restano come sono." "Nothing was touched: your settings stay as they are.")
        }
        Write-Host (T "   Buon divertimento!  -- oLd_pZ" "   Have fun!  -- oLd_pZ") -ForegroundColor Magenta
        Esci 0
    }

    Titolo (T "Cerco i file della mod" "Looking for the mod files")
    Info (T "(devono essere gia' stati scaricati con il programma ufficiale)" `
            "(they must already have been downloaded with the official tool)")

    $daCopiare = @{}
    $mancanti = @()

    foreach ($nome in $ATTESI.Keys) {
        $p = Trova-File $nome $ATTESI[$nome] $DIMENSIONI[$nome]
        if ($p) {
            Info (T "Verifico $nome ..." "Checking $nome ...")
            $h = (Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
            if ($h -eq $ATTESI[$nome]) { Ok "$nome"; $daCopiare[$nome] = $p }
            else {
                Errore (T "$nome trovato ma NON corrisponde all'originale: non lo installo." `
                          "$nome found but it does NOT match the original: not installing it.")
                Info "   $p"
                $mancanti += $nome
            }
        } else { $mancanti += $nome }
    }

    $reshade = Trova-ReShade
    if ($reshade) { Ok (T "ReShade 6.8.0 (versione con add-on)" "ReShade 6.8.0 (add-on build)") }
    else { $mancanti += 'ReShade64.dll' }

    if ($mancanti.Count -gt 0) {
        Write-Host ""
        Errore (T "Mancano questi file:" "These files are missing:")
        foreach ($m in $mancanti) { Info "   - $m" }
        Write-Host ""
        Info (T "COSA FARE:" "WHAT TO DO:")
        Info (T " 1. Scarica il programma ufficiale da:" " 1. Download the official tool from:")
        Info "    https://github.com/zmodelerlover/dlss5-neural-amd/releases"
        Info (T " 2. Estrailo e avvialo, arriva fino al passo 3 (scaricamento) e chiudilo." `
                " 2. Extract it, run it, go as far as step 3 (download) and close it.")
        Info (T " 3. Per ReShade: scarica da https://reshade.me la versione" `
                " 3. For ReShade: get the 'with full add-on support' build from")
        Info (T "    'with full add-on support'." "    https://reshade.me")
        Info (T " 4. Rilancia questo installatore." " 4. Run this installer again.")
        Write-Host ""
        Info (T "In alternativa metti i file in questa cartella e rilancia:" `
                "Alternatively put the files in this folder and run again:")
        Info "   $PACK\files\"
        Esci 1
    }

    # --- copia ---------------------------------------------------------------
    Titolo (T "Installo nel gioco" "Installing into the game")
    $registro = @()

    if ($spostaDxgi) { Risolvi-Conflitti $gioco }

    $dest = Join-Path $gioco 'd3d11.dll'
    if ((Test-Path $dest) -and (Get-FileHash $dest -Algorithm SHA256).Hash.ToLower() -ne $RESHADE_HASH) {
        if (Hash-Accettabile $dest 'ReShade64.dll') {
            # e' il NOSTRO ReShade, solo piu' vecchio: aggiorno e lascio ReShade.ini
            # it is OUR ReShade, just older: update it and leave ReShade.ini alone
            Salva-Precedente $gioco 'd3d11.dll' $RESHADE_HASH
            Attenzione (T "Aggiorno ReShade: le tue impostazioni restano." "Updating ReShade: your settings are kept.")
        } else {
            if ((Descrivi-Dll $dest) -match 'ReShade') { Metti-DaParte $gioco 'ReShade.ini'; Metti-DaParte $gioco 'ReShadePreset.ini' }
            $bak = "$dest.prima-del-dlss.bak"
            Attenzione (T "C'e' gia' un d3d11.dll: lo metto da parte come .prima-del-dlss.bak" `
                          "A d3d11.dll is already there: saving it as .prima-del-dlss.bak")
            Move-Item -LiteralPath $dest -Destination $bak -Force
        }
    }
    if ($reshade -ne $dest) { Copy-Item -LiteralPath $reshade -Destination $dest -Force }
    Ok "d3d11.dll  (ReShade)"
    $registro += 'd3d11.dll'
    # vecchie copie del nostro ReShade rinominate a mano / old renamed copies of our ReShade
    foreach ($n in 'd3d11.dll.off','d3d11.dll.off.dll') {
        $q = Join-Path $gioco $n
        if ((Test-Path -LiteralPath $q) -and ((Hash-Di $q) -eq $RESHADE_HASH)) {
            Remove-Item -LiteralPath $q -Force
            Attenzione (T "tolto $n (vecchia copia rinominata, non serve piu')" "removed $n (old renamed copy, no longer needed)")
        }
    }

    foreach ($nome in $daCopiare.Keys) {
        $destN = Join-Path $gioco $nome
        if ($daCopiare[$nome] -ne $destN) {
            Salva-Precedente $gioco $nome $ATTESI[$nome]
            Copy-Item -LiteralPath $daCopiare[$nome] -Destination $destN -Force
        }
        Ok $nome
        $registro += $nome
    }

    $ini = Join-Path $PACK 'dlss5-neural.ini'
    if (Test-Path $ini) {
        $destIni = Join-Path $gioco 'dlss5-neural.ini'
        if (Test-Path $destIni) {
            Attenzione (T "dlss5-neural.ini esiste gia': lascio le TUE impostazioni." `
                          "dlss5-neural.ini already exists: keeping YOUR settings.")
        } else {
            Copy-Item -LiteralPath $ini -Destination $destIni -Force
            Ok (T "dlss5-neural.ini  (impostazioni consigliate, Scale=0.60)" `
                  "dlss5-neural.ini  (recommended settings, Scale=0.60)")
            $registro += 'dlss5-neural.ini'
        }
    }

    # --- verifica dopo la copia ---------------------------------------------
    Titolo (T "Verifica finale" "Final check")
    $errori = 0
    foreach ($nome in $ATTESI.Keys) {
        $h = (Get-FileHash (Join-Path $gioco $nome) -Algorithm SHA256).Hash.ToLower()
        if ($h -eq $ATTESI[$nome]) { Ok $nome } else { Errore "$nome"; $errori++ }
    }
    $h = (Get-FileHash (Join-Path $gioco 'd3d11.dll') -Algorithm SHA256).Hash.ToLower()
    if ($h -eq $RESHADE_HASH) { Ok 'd3d11.dll' } else { Errore 'd3d11.dll'; $errori++ }

    # --- registro per la disinstallazione ------------------------------------
    $reg = Join-Path $gioco '_dlss5-installato.txt'
    $testo = @()
    $testo += "Installato il $(Get-Date -Format 'dd/MM/yyyy HH:mm') da INSTALLA - INSTALL.bat"
    $testo += "Installed on $(Get-Date -Format 'yyyy-MM-dd HH:mm') by INSTALLA - INSTALL.bat"
    $testo += "Pacchetto di / pack by oLd_pZ"
    $testo += ""
    $testo += "File aggiunti / files added:"
    $testo += $registro
    $testo | Set-Content -LiteralPath $reg -Encoding UTF8

    if ($errori -gt 0) {
        Errore (T "Qualcosa non torna: vedi sopra." "Something is off: see above.")
        Esci 1
    }

    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host (T "   FATTO. Installato in:" "   DONE. Installed into:") -ForegroundColor Green
    Write-Host "   $gioco" -ForegroundColor Green
    Write-Host "  ============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host (T "   Buon divertimento!  -- oLd_pZ" "   Have fun!  -- oLd_pZ") -ForegroundColor Magenta
    Write-Host ""
    Info (T "ORA:" "NOW:")
    Info (T " 1. Avvia il gioco COME FAI SEMPRE: con il .bat di sider (Football Life)," `
            " 1. Start the game THE WAY YOU ALWAYS DO: the sider .bat (Football Life),")
    Info (T "    oppure da Steam se hai PES 2021 senza sider." `
            "    or from Steam if you have PES 2021 without sider.")
    Info (T " 2. Nel gioco premi HOME per il pannello di ReShade." `
            " 2. In game press HOME for the ReShade panel.")
    Info (T " 3. Premi CTRL+FINE per accendere l'effetto (parte spento)." `
            " 3. Press CTRL+END to switch the effect on (it starts off).")
    Info (T "    Se non succede niente, chiudi prima il pannello con HOME." `
            "    If nothing happens, close the panel with HOME first.")
    Write-Host ""
    Attenzione (T "Ricorda: questa mod FA CALARE gli fps. Non e' un acceleratore." `
                  "Remember: this mod LOWERS your fps. It is not a booster.")
    Attenzione (T "Usala solo OFFLINE, mai in partite online." `
                  "Use it OFFLINE only, never in online matches.")
    Attenzione (T "Prima di myClub o dell'online: lancia DISINSTALLA - UNINSTALL.bat" `
                  "Before myClub or online: run DISINSTALLA - UNINSTALL.bat")
    Esci 0
}

# ============================================================ DISINSTALLA ====
function Rimuovi {
    # serve anche qui: se e' stata installata una versione presa dall'elenco
    # online, le impronte di fabbrica non la riconoscerebbero
    # needed here too: a version installed from the online list would not be
    # recognised by the factory fingerprints
    Leggi-Manifesto
    $gioco = Trova-Gioco

    $proc = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'PES2021|FL_2026|sider' }
    if ($proc) {
        Errore (T "Il gioco e' aperto. Chiudilo e riprova." "The game is running. Close it and try again.")
        Esci 1
    }

    Titolo (T "Rimuovo i file" "Removing the files")
    $tolti = 0
    $nostroReShade = $false
    # d3d11.dll solo se e' il NOSTRO ReShade / d3d11.dll only if it is OUR ReShade
    foreach ($n in 'd3d11.dll','d3d11.dll.off','d3d11.dll.off.dll') {
        $p = Join-Path $gioco $n
        if (Test-Path -LiteralPath $p) {
            if (Hash-Accettabile $p 'ReShade64.dll') { Remove-Item -LiteralPath $p -Force; Ok $n; $tolti++; $nostroReShade = $true }
            else { Attenzione (T "$n non e' il nostro ReShade: lo lascio stare" "$n is not our ReShade: leaving it alone") }
        }
    }
    $daTogliere = @(
        'dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin',
        'dlss5-neural.ini','dlssnr_on_amd.ini','dlssnr_on_amd.log','dlss5-neural.log','_dlss5-installato.txt'
    )
    # copie tenute dagli aggiornamenti / copies kept by the updates
    foreach ($n in 'd3d11.dll','dlss5-neural.addon64','dlssnr_amd_pass1.dll','dlssnr_on_amd_weights.bin') {
        $daTogliere += "$n.precedente.bak"
    }
    # ReShade.* solo insieme al nostro ReShade / ReShade.* only together with our ReShade
    if ($nostroReShade) { $daTogliere += 'ReShade.ini','ReShade.log','ReShadePreset.ini' }
    foreach ($n in $daTogliere) {
        $p = Join-Path $gioco $n
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Force; Ok $n; $tolti++ }
    }

    # rimette a posto quello che era stato messo da parte / puts back what was set aside
    foreach ($n in 'd3d11.dll','dxgi.dll','ReShade.ini','ReShadePreset.ini') {
        $p = Join-Path $gioco $n
        $bak = "$p.prima-del-dlss.bak"
        if (Test-Path -LiteralPath $bak) {
            if (Test-Path -LiteralPath $p) { Attenzione (T "$n esiste gia': lascio $n.prima-del-dlss.bak com'e'" "$n already exists: leaving $n.prima-del-dlss.bak as it is") }
            else { Move-Item -LiteralPath $bak -Destination $p -Force; Ok (T "Ripristinato $n di prima" "Restored the previous $n") }
        }
    }

    Write-Host ""
    if ($tolti -eq 0) { Attenzione (T "Non c'era niente da rimuovere." "There was nothing to remove.") }
    else {
        Write-Host "  ============================================================" -ForegroundColor Green
        Write-Host (T "   FATTO. Rimossi $tolti file. Il gioco e' tornato com'era." `
                      "   DONE. $tolti files removed. The game is back as it was.") -ForegroundColor Green
        Write-Host "  ============================================================" -ForegroundColor Green
    }
    Info (T "Nessun file originale del gioco e' stato toccato." "No original game file was ever touched.")
    Esci 0
}

# ===================================================================== MAIN ==
if ($Disinstalla) { Rimuovi } else { Installa }
