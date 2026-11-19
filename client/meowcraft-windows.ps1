# Meowcraft for Windows  =^.^=
#
#   meowcraft install                 first-time setup: mods, server list, "Play Meowcraft" icon
#   meowcraft play                    what the icon runs: quick update check, then opens the Launcher
#   meowcraft update                  check for new mods right now
#   meowcraft switch normal|fancy     change versions
#   meowcraft reset [--keep_settings] start the Meowcraft folder over (worlds and screenshots are always kept)
#   meowcraft status                  what you have, and whether an update is waiting
#   meowcraft uninstall               remove the icon, the Launcher profile and this command
#
# Lives in %USERPROFILE%\.meowcraft. Keep this file plain ASCII (Windows PowerShell 5.1 reads it as ANSI).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes downloads much faster in Windows PowerShell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ToolVersion = '3.0'
$RepoRaw = 'https://raw.githubusercontent.com/pattyryke/meowcraft/main'

# ---- Built-in lists (only used on a first install if the online list can't be read) ----
$McVersion          = '26.3'
$CoreMods           = @('fabric-api', 'sodium', 'immediatelyfast', 'modmenu', 'xaeros-minimap', 'xaeros-world-map', 'jade', 'appleskin', 'mouse-tweaks', 'zoomify', 'simple-voice-chat', 'emotecraft')
$FancyMods          = @('iris', 'entity-model-features', 'entitytexturefeatures')
$FancyPacks         = @('fresh-animations')
$FancyShaders       = @(@('HVnmMxH1', 'Meowcraft High - Complementary Reimagined.zip'), @('Q1vvjJYV', 'Meowcraft Medium - BSL.zip'), @('makeup-ultra-fast-shaders', 'Meowcraft Low - MakeUp Ultra Fast.zip'))
$FancyDefaultShader = 'Meowcraft Low - MakeUp Ultra Fast.zip'
$KnownPacks         = @('fresh-animations')
# What "reset" always keeps, and what --keep_settings adds
$AlwaysKeep   = @('saves', 'screenshots', '.meowcraft-variant')
$SettingsKeep = @('options.txt', 'config', 'xaero', 'XaeroWaypoints', 'XaeroWorldMap', 'servers.dat')
# ------------------------------------------------------------------------------------------

$Headers  = @{ 'User-Agent' = "pattycakez69/meowcraft/$ToolVersion" }
$McDir    = Join-Path $env:APPDATA '.minecraft'
$GameDir  = Join-Path $McDir 'meowcraft'
$OldDir   = Join-Path $McDir 'meowcraft-old'
$ModsDir  = Join-Path $GameDir 'mods'
$PackDir  = Join-Path $GameDir 'resourcepacks'
$OptFile  = Join-Path $GameDir 'options.txt'
$Owned    = Join-Path $ModsDir '.meowcraft-owned'
$VarFile  = Join-Path $GameDir '.meowcraft-variant'
$ListFile = Join-Path $GameDir '.meowcraft-list.json'
$Stamp    = Join-Path $GameDir '.meowcraft-stamp'
$DlFile   = Join-Path $GameDir '.meowcraft-downloads'
$LpPath   = Join-Path $McDir 'launcher_profiles.json'
$ToolDir  = Join-Path $HOME '.meowcraft'
$ToolPath = Join-Path $ToolDir 'meowcraft-windows.ps1'
$ShimPath = Join-Path $ToolDir 'meowcraft.cmd'
$IcoPath  = Join-Path $ToolDir 'meowcraft.ico'
$OldApp   = Join-Path $env:LOCALAPPDATA 'Meowcraft'   # where version 2 kept its files
$Utf8     = New-Object System.Text.UTF8Encoding $false
$Dot      = [string][char]0x00B7
$IconData = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAABeElEQVR4Xu2aIW/CUBSFW8I0CRL01NwsAmpn+AMY5IIhm52cHeEnIPgDNbNgsPwBNJYEPbNg3rtNerP7wsrhJudTJWnKvZxzXm95zWfDVeaZlufiL7ABNG1ZwPbwVlvP6HEBqdNSDy2Exr0ClQxIdvNu+DhYxmw0nQfp+2oNp1qx3SvABtCoGeg8fIXadvP3RvOg+V7WkGVTZuAucR9iNQMa2v3hGuQ1U3GvABtAo2bg/BPXfguWucVyjsRSAy2Exr0C+VMvzv3XrMe3ZCCeDdwrwAbQmGahyXgU6twX3+H4efMSjtflNqmX/7omLYSGCqChAmjcK9DILFT9Pydime8tcBa6J9xnwDQLdcafST96v3itPf+4SdtrO5cff36vewXYABpTBiz0i7iPpnndck4qtBAa9wrk8n0hba9KknpPSEVb++X8I/eq3SvABtBUMiCx5KFpNN9LaCE07hVQM6Dl4ZZY3k1yrwAbQGN6HrB4EQUthMa9Ar+V1GApTOWmuAAAAABJRU5ErkJggg=='

# ---- Command line: first word is the command, anything starting with - is a flag ----
$Words = @(); $Flags = @{}
foreach ($a in $args) {
    $s = [string]$a
    if ($s -match '^-{1,2}(.+)$') { $Flags[$matches[1].ToLower().Replace('-', '_')] = $true } else { $Words += $s }
}
$Cmd = 'help'
if ($Words.Count -gt 0) { $Cmd = $Words[0].ToLower() }
$Yes = [bool]$Flags['yes']

# ================================ helpers ================================

function Say($msg)  { Write-Host "  =^.^=  $msg" -ForegroundColor Magenta }
function Info($msg) { Write-Host "         $msg" }
function Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Good($msg) { Write-Host "  $msg" -ForegroundColor Green }
function Header {
    Write-Host ''
    Write-Host '  =^.^=  Meowcraft  =^.^=' -ForegroundColor Magenta
    Write-Host ''
}
function Pause-IfIcon { if ($Flags['from_icon']) { Read-Host '  Press Enter to close' | Out-Null } }

function Get-Json($url) {
    $r = Invoke-RestMethod -Headers $Headers -Uri $url
    $out = @(); foreach ($x in $r) { $out += $x }; return ,$out
}
function Save-Url($url, $dest) {
    # Download to a temp name first, so a cut-off download never looks finished
    $part = "$dest.part"
    Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $url -OutFile $part
    Move-Item -Force $part $dest
}
function Get-Versions($project, $loader) {
    $q = 'loaders=' + [uri]::EscapeDataString("[`"$loader`"]") + '&game_versions=' + [uri]::EscapeDataString("[`"$McVersion`"]")
    # A project that doesn't exist gives an empty list. Any other failure (Modrinth down, no internet)
    # stops the update, so a hiccup can never make it look like every mod was removed.
    try { return ,(Get-Json "https://api.modrinth.com/v2/project/$project/version?$q") }
    catch {
        $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
        if ($code -eq 404) { return ,@() }
        throw "Couldn't reach Modrinth - try again in a bit."
    }
}
function Get-PrimaryFile($version) {
    $f = $version.files | Where-Object { $_.primary } | Select-Object -First 1
    if (-not $f) { $f = $version.files | Select-Object -First 1 }
    return $f
}
function Pick-Version($vs, $pinId) {
    if ($pinId) { $p = $vs | Where-Object { $_.id -eq $pinId } | Select-Object -First 1; if ($p) { return $p } }
    $r = $vs | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
    if ($r) { return $r } else { return $vs[0] }
}
function Read-Lines($path) {
    $out = @(); if (Test-Path $path) { foreach ($l in [IO.File]::ReadAllLines($path)) { if ($l) { $out += $l } } }; return ,$out
}
function Get-Hash($text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    return [BitConverter]::ToString($sha.ComputeHash($Utf8.GetBytes($text))).Replace('-', '')
}
function Set-PackEnabled($fileName, [bool]$enabled) {
    $entry = "file/$fileName"
    $lines = @(); if (Test-Path $OptFile) { foreach ($l in [IO.File]::ReadAllLines($OptFile)) { $lines += $l } }
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith('resourcePacks:')) { $idx = $i } }
    $list = @()
    if ($idx -ge 0) { $parsed = $lines[$idx].Substring(14) | ConvertFrom-Json; foreach ($x in $parsed) { $list += [string]$x } }
    else { $list = @('vanilla') }
    $list = @($list | Where-Object { $_ -ne $entry })
    if ($enabled) { $list += $entry }
    $line = 'resourcePacks:["' + ($list -join '","') + '"]'
    if ($idx -ge 0) { $lines[$idx] = $line } else { $lines += $line }
    [IO.File]::WriteAllLines($OptFile, [string[]]$lines, $Utf8)
}
function Get-Variant {
    if (Test-Path $VarFile) { $v = ([IO.File]::ReadAllText($VarFile)).Trim().ToLower(); if ($v -eq 'fancy') { return 'fancy' } }
    return 'core'
}
function Set-Variant($v) {
    New-Item -ItemType Directory -Force -Path $GameDir | Out-Null
    [IO.File]::WriteAllText($VarFile, $v, $Utf8)
}
function Variant-Name($v) { if ($v -eq 'fancy') { return 'Fancy' } else { return 'Normal' } }

function Test-LauncherRunning { return [bool](Get-Process -Name 'MinecraftLauncher', 'Minecraft' -ErrorAction SilentlyContinue) }
function Test-GameRunning {
    try {
        $p = Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" -ErrorAction Stop |
             Where-Object { $_.CommandLine -and $_.CommandLine -like '*\.minecraft\meowcraft*' }
        return [bool]$p
    } catch { return $false }
}
function Wait-ForClosedMinecraft {
    while ((Test-GameRunning) -or (Test-LauncherRunning)) {
        Write-Host '  Please close Minecraft and the Minecraft Launcher first.' -ForegroundColor Yellow
        $r = Read-Host '  Close them, then press Enter here (or type q to quit)'
        if ($r.Trim().ToLower() -eq 'q') { exit 1 }
    }
}
function Start-Launcher {
    try {
        $a = Get-StartApps | Where-Object { $_.Name -like 'Minecraft Launcher*' } | Select-Object -First 1
        if ($a) { Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$($a.AppID)"; return $true }
    } catch {}
    foreach ($p in @("${env:ProgramFiles(x86)}\Minecraft Launcher\MinecraftLauncher.exe",
                     "$env:ProgramFiles\Minecraft Launcher\MinecraftLauncher.exe",
                     "$env:LOCALAPPDATA\Programs\Minecraft Launcher\MinecraftLauncher.exe")) {
        if (Test-Path $p) { Start-Process $p; return $true }
    }
    return $false
}
function Open-LauncherAndExit {
    if (Start-Launcher) {
        Say 'Opening the Minecraft Launcher - pick "Meowcraft" and press Play!'
        Start-Sleep -Seconds 3
    } else {
        Warn "Couldn't find the Minecraft Launcher - please open it yourself and pick Meowcraft."
        Read-Host '  Press Enter to close' | Out-Null
    }
    exit 0
}
function Require-Launcher {
    if (-not (Test-Path $LpPath)) {
        Write-Host '  Open the Minecraft Launcher and log in once, close it, then try again.' -ForegroundColor Red
        Read-Host '  Press Enter to close' | Out-Null
        exit 1
    }
}
function Require-Installed {
    if (-not (Test-Path $VarFile)) {
        Warn "Meowcraft isn't set up on this computer yet. Run:  meowcraft install"
        exit 1
    }
}

# Grab the newest copy of this command. If it changed, run the new copy instead and stop here.
function Update-Self {
    if ($env:MEOWCRAFT_FRESH -or $PSCommandPath -ne $ToolPath) { return }
    $new = $null
    try { $new = [string](Invoke-WebRequest -UseBasicParsing -TimeoutSec 15 -Headers $Headers -Uri "$RepoRaw/client/meowcraft-windows.ps1").Content } catch { return }
    if (-not $new -or -not $new.Contains('MEOWCRAFT-TOOL-END')) { return }   # only use a complete file
    if ($new -eq [IO.File]::ReadAllText($ToolPath)) { return }
    [IO.File]::WriteAllText($ToolPath, $new, $Utf8)
    $env:MEOWCRAFT_FRESH = '1'
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $ps -NoProfile -ExecutionPolicy Bypass -File $ToolPath @args
    exit $LASTEXITCODE
}

# ================================ the sync ================================
# Makes the Meowcraft folder match meowcraft.json on GitHub. Only touches files it put there itself.
# -Quick: skip everything if the list hasn't changed in the last 12 hours (used by the icon).
# Returns $false if it couldn't check at all (no internet); throws if it started and something broke.
function Invoke-Sync([switch]$Quick) {
    $variant = Get-Variant
    $manText = $null; $man = $null
    try {
        $manText = [string](Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri "$RepoRaw/meowcraft.json" -TimeoutSec 20).Content
        $man = $manText | ConvertFrom-Json
        [IO.File]::WriteAllText($ListFile, $manText, $Utf8)
    } catch {
        $man = $null
        if (-not $Quick -and (Test-Path $ListFile)) {
            Warn "Couldn't read the mod list from GitHub - using the last good copy."
            $manText = [IO.File]::ReadAllText($ListFile); $man = $manText | ConvertFrom-Json
        }
    }
    if (-not $man -and $Quick) { return $false }

    $mods = @($CoreMods); $packs = @(); $shaders = @(); $defaultShader = ''; $pack = $null
    if ($variant -eq 'fancy') { $mods += $FancyMods; $packs = @($FancyPacks); $shaders = $FancyShaders; $defaultShader = $FancyDefaultShader }
    if ($man) {
        $chain = @(); $cur = $variant
        while ($cur) { $chain = @($cur) + $chain; $cur = $man.client.$cur.extends }
        $mods = @(); $packs = @(); $shaders = @(); $defaultShader = ''
        foreach ($c in $chain) {
            $sec = $man.client.$c
            foreach ($m in $sec.mods) { if ($mods -notcontains $m) { $mods += $m } }
            foreach ($p in $sec.resourcepacks) { if ($packs -notcontains $p) { $packs += $p } }
            foreach ($s in $sec.shaders) { $shaders += ,@($s.project, $s.file) }
            if ($sec.default_shader) { $defaultShader = $sec.default_shader }
        }
        if ($man.minecraft) { $script:McVersion = $man.minecraft }
        if ($man.pack) { $pack = $man.pack }
    } else { Warn "Couldn't read the online mod list - using the built-in one" }
    $packText = ''; if ($pack) { $packText = " $Dot pack $pack" }
    Say "$(Variant-Name $variant) version, Minecraft $McVersion$packText"

    # Quick start: nothing changed since the last check a little while ago
    $sig = Get-Hash ("$variant|$manText")
    if ($Quick -and (Test-Path $Stamp)) {
        $st = Read-Lines $Stamp
        $fresh = $false
        if ($st.Count -ge 2 -and $st[0] -eq $sig) {
            try { $fresh = ((Get-Date).ToUniversalTime() - [datetime]::Parse($st[1]).ToUniversalTime()).TotalHours -lt 12 } catch {}
        }
        $allThere = $true
        foreach ($f in (Read-Lines $Owned)) { if (-not (Test-Path (Join-Path $ModsDir $f))) { $allThere = $false } }
        if ($fresh -and $allThere) { Say 'Everything is up to date.'; return $true }
    }

    # 1. Fabric loader (same files the official Fabric installer writes)
    Say "Checking the Fabric loader for Minecraft $McVersion..."
    $loaders = Get-Json "https://meta.fabricmc.net/v2/versions/loader/$McVersion"
    if ($loaders.Count -eq 0) { throw "Fabric doesn't support Minecraft $McVersion yet." }
    $loader = $loaders | Where-Object { $_.loader.stable } | Select-Object -First 1
    if (-not $loader) { $loader = $loaders[0] }
    $loaderVer = $loader.loader.version
    $profileJson = [string](Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri "https://meta.fabricmc.net/v2/versions/loader/$McVersion/$loaderVer/profile/json").Content
    $versionId = ($profileJson | ConvertFrom-Json).id
    $verDir = Join-Path (Join-Path $McDir 'versions') $versionId
    New-Item -ItemType Directory -Force -Path $verDir | Out-Null
    [IO.File]::WriteAllText((Join-Path $verDir "$versionId.json"), $profileJson, $Utf8)
    $jar = Join-Path $verDir "$versionId.jar"
    if (-not (Test-Path $jar)) { [IO.File]::WriteAllBytes($jar, [byte[]]@()) }

    # 2. Work out the mod list, including required dependencies.
    #    Prefers stable releases over betas, and honors exact versions that other mods ask for.
    Say 'Checking mods...'
    $seen = @{}; $chosen = [ordered]@{}; $pins = @{}; $allVs = @{}; $slugIds = @{}
    $queue = New-Object System.Collections.Queue
    foreach ($m in $mods) { $queue.Enqueue($m) }
    while ($queue.Count -gt 0) {
        $p = $queue.Dequeue()
        if ($seen.ContainsKey($p)) { continue }
        $seen[$p] = $true
        $vs = Get-Versions $p 'fabric'
        if ($vs.Count -eq 0) { Warn "$p has no Fabric build for $McVersion yet - skipping"; continue }
        $projId = $vs[0].project_id
        if ($chosen.Contains($projId)) { continue }
        $seen[$projId] = $true
        $v = Pick-Version $vs $pins[$projId]
        $chosen[$projId] = $v
        $allVs[$projId] = $vs
        $slugIds[$p] = $projId
        foreach ($d in $v.dependencies) {
            if ($d.dependency_type -ne 'required') { continue }
            $depProj = $d.project_id
            if ($d.version_id) {
                $pv = Invoke-RestMethod -Headers $Headers -Uri "https://api.modrinth.com/v2/version/$($d.version_id)"
                $depProj = $pv.project_id
                $pins[$depProj] = $d.version_id
                if ($chosen.Contains($depProj) -and $chosen[$depProj].id -ne $d.version_id) { $chosen[$depProj] = $pv }
            }
            if ($depProj) { $queue.Enqueue($depProj) }
        }
    }
    # Sodium often ships betas that the current Iris doesn't support yet.
    # If both are present, use the newest Sodium that came out before the chosen Iris.
    if ($slugIds['iris'] -and $slugIds['sodium'] -and -not $pins.ContainsKey($slugIds['sodium'])) {
        $irisDate = [datetime]$chosen[$slugIds['iris']].date_published
        $sodiumOk = @($allVs[$slugIds['sodium']] | Where-Object { [datetime]$_.date_published -le $irisDate })
        if ($sodiumOk.Count -gt 0) {
            $rel = $sodiumOk | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
            if ($rel) { $chosen[$slugIds['sodium']] = $rel } else { $chosen[$slugIds['sodium']] = $sodiumOk[0] }
        }
    }
    $want = [ordered]@{}   # filename -> url
    foreach ($v in $chosen.Values) { $f = Get-PrimaryFile $v; $want[$f.filename] = $f.url }

    # 3. Sync the mods folder
    New-Item -ItemType Directory -Force -Path $ModsDir | Out-Null
    $keep = @()   # old files we couldn't delete yet - try again next time
    foreach ($old in (Read-Lines $Owned)) {
        if ($want.Contains($old)) { continue }
        $op = Join-Path $ModsDir $old
        Remove-Item -Force -ErrorAction SilentlyContinue $op
        if (Test-Path $op) { $keep += $old; Warn "Couldn't remove $old yet (is Minecraft open?)" } else { Say "Removed $old" }
    }
    $changed = 0
    foreach ($name in $want.Keys) {
        $dest = Join-Path $ModsDir $name
        if (Test-Path $dest) { continue }
        Save-Url $want[$name] $dest
        Say "Downloaded $name"; $changed++
    }
    [IO.File]::WriteAllLines($Owned, [string[]](@($want.Keys) + $keep), $Utf8)
    if ($changed -eq 0) { Say 'Mods are up to date.' }

    # Remembers which pack/shader download each file came from, so they're only downloaded when they change
    $dl = @{}; foreach ($l in (Read-Lines $DlFile)) { $i = $l.IndexOf('|'); if ($i -gt 0) { $dl[$l.Substring(0, $i)] = $l.Substring($i + 1) } }

    # 4. Resource packs
    New-Item -ItemType Directory -Force -Path $PackDir | Out-Null
    foreach ($rp in $KnownPacks) {
        if ($packs -notcontains $rp) {
            $pf = Join-Path $PackDir "$rp.zip"
            if (Test-Path $pf) { Remove-Item -Force $pf; Set-PackEnabled "$rp.zip" $false; Say "Removed resource pack $rp" }
        }
    }
    foreach ($rp in $packs) {
        $vs = Get-Versions $rp 'minecraft'
        if ($vs.Count -eq 0) { Warn "$rp has no version for $McVersion yet - skipping"; continue }
        $f = Get-PrimaryFile $vs[0]
        $dest = Join-Path $PackDir "$rp.zip"
        if (-not ((Test-Path $dest) -and $dl["pack:$rp"] -eq $f.url)) {
            Save-Url $f.url $dest; $dl["pack:$rp"] = $f.url
            Set-PackEnabled "$rp.zip" $true
            Say "Installed resource pack $rp"
        }
    }

    # 4b. Shader packs (Iris)
    if ($shaders.Count -gt 0) {
        $shDir = Join-Path $GameDir 'shaderpacks'
        New-Item -ItemType Directory -Force -Path $shDir | Out-Null
        foreach ($s in $shaders) {
            $slug = $s[0]; $fname = $s[1]
            $vs = Get-Versions $slug 'iris'
            if ($vs.Count -eq 0) {   # shader packs usually work across versions, so fall back to the newest one
                try { $vs = Get-Json ("https://api.modrinth.com/v2/project/$slug/version?loaders=" + [uri]::EscapeDataString('["iris"]')) } catch { $vs = @() }
            }
            if ($vs.Count -eq 0) { Warn "Couldn't find shader pack $slug - skipping"; continue }
            $f = Get-PrimaryFile (Pick-Version $vs $null)
            $dest = Join-Path $shDir $fname
            if (-not ((Test-Path $dest) -and $dl["shader:$fname"] -eq $f.url)) {
                Save-Url $f.url $dest; $dl["shader:$fname"] = $f.url
                Say "Installed shader pack: $fname"
            }
        }
        $cfgDir = Join-Path $GameDir 'config'
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        $irisCfg = Join-Path $cfgDir 'iris.properties'
        $lines = @(); if (Test-Path $irisCfg) { foreach ($l in [IO.File]::ReadAllLines($irisCfg)) { $lines += $l } }
        if (-not ($lines | Where-Object { $_ -match '^shaderPack=.+' })) {
            $lines = @($lines | Where-Object { $_ -notmatch '^(shaderPack|enableShaders)=' })
            $lines += "shaderPack=$defaultShader"; $lines += 'enableShaders=true'
            [IO.File]::WriteAllLines($irisCfg, [string[]]$lines, $Utf8)
            Say "Turned on shaders: $defaultShader"
        }
    }
    [IO.File]::WriteAllLines($DlFile, [string[]]@($dl.Keys | ForEach-Object { "$_|$($dl[$_])" }), $Utf8)

    # 5. Server list (only if they don't have one yet)
    $serversDat = Join-Path $GameDir 'servers.dat'
    if (-not (Test-Path $serversDat)) {
        Save-Url "$RepoRaw/installer/servers.dat" $serversDat
        Say 'Added Meowcraft to your server list'
    }

    # 6. Launcher profile (skipped if the Launcher is open, since it would overwrite our change)
    if (Test-LauncherRunning) {
        Warn 'The Minecraft Launcher is open, so the profile will update next time.'
    } else {
        Copy-Item $LpPath "$LpPath.meowcraft-backup" -Force
        $lp = Get-Content -Raw -Encoding UTF8 -Path $LpPath | ConvertFrom-Json
        $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $created = $now
        if ($lp.profiles.PSObject.Properties['meowcraft'] -and $lp.profiles.meowcraft.created) { $created = $lp.profiles.meowcraft.created }
        $mcProfile = [ordered]@{
            name = "Meowcraft$packText"; type = 'custom'; created = $created; lastUsed = $now
            lastVersionId = $versionId; gameDir = $GameDir; icon = $IconData
        }
        if ($lp.profiles.PSObject.Properties['meowcraft']) { $lp.profiles.PSObject.Properties.Remove('meowcraft') }
        $lp.profiles | Add-Member -NotePropertyName 'meowcraft' -NotePropertyValue ([pscustomobject]$mcProfile)
        [IO.File]::WriteAllText($LpPath, ($lp | ConvertTo-Json -Depth 32), $Utf8)
    }

    [IO.File]::WriteAllLines($Stamp, [string[]]@($sig, (Get-Date).ToUniversalTime().ToString('o')), $Utf8)
    return $true
}

function Run-Sync([switch]$Quick) {
    try { return (Invoke-Sync -Quick:$Quick) }
    catch {
        Write-Host ''
        Write-Host "  Something went wrong while updating: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  Take a picture of this window and send it to Patrick.' -ForegroundColor Red
        Write-Host ''
        return $null
    }
}

# ================================ setup pieces ================================

function Install-Command {
    New-Item -ItemType Directory -Force -Path $ToolDir | Out-Null
    if ($PSCommandPath -and $PSCommandPath -ne $ToolPath) { Copy-Item -Force $PSCommandPath $ToolPath }
    elseif (-not (Test-Path $ToolPath)) { Save-Url "$RepoRaw/client/meowcraft-windows.ps1" $ToolPath }
    $shim = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0meowcraft-windows.ps1`" %*`r`n"
    [IO.File]::WriteAllText($ShimPath, $shim, (New-Object System.Text.ASCIIEncoding))
    if (-not (Test-Path $IcoPath)) { try { Save-Url "$RepoRaw/client/meowcraft.ico" $IcoPath } catch {} }
    # Let "meowcraft" work in any new Command Prompt or PowerShell window
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @(); if ($userPath) { $parts = @($userPath.Split(';') | Where-Object { $_ }) }
    if ($parts -notcontains $ToolDir) { [Environment]::SetEnvironmentVariable('Path', (@($parts) + $ToolDir) -join ';', 'User') }
}
function Make-Icons {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
        if (-not $folder) { continue }
        $lnk = $ws.CreateShortcut((Join-Path $folder 'Play Meowcraft.lnk'))
        $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ToolPath`" play --from_icon"
        $lnk.WorkingDirectory = $ToolDir
        if (Test-Path $IcoPath) { $lnk.IconLocation = "$IcoPath,0" }
        $lnk.Description = 'Update Meowcraft mods and open Minecraft'
        $lnk.Save()
    }
    if (Test-Path $OldApp) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $OldApp }   # version 2 leftovers
}
function Ask-Variant {
    if ($Flags['fancy']) { return 'fancy' }
    if ($Flags['normal'] -or $Flags['core']) { return 'core' }
    Write-Host '  Which version do you want?' -ForegroundColor Cyan
    Write-Host '    N = Normal: fast and smooth on any computer (pick this if you are not sure)'
    Write-Host '    F = Fancy:  shaders and smoother animations - needs a good graphics card'
    $r = Read-Host '  Type N or F, then press Enter'
    if ($r.Trim().ToLower().StartsWith('f')) { return 'fancy' } else { return 'core' }
}

# ================================ commands ================================

function Cmd-Install {
    Header
    Require-Launcher
    Wait-ForClosedMinecraft
    Install-Command
    $v = Ask-Variant
    Set-Variant $v
    if ($null -eq (Run-Sync)) { Read-Host '  Press Enter to close' | Out-Null; exit 1 }
    Make-Icons
    Write-Host ''
    Good 'All done!  From now on, just double-click "Play Meowcraft" on your desktop.'
    Good 'It keeps your mods up to date and opens the Launcher - pick Meowcraft and press Play.'
    Good 'In game: Multiplayer -> Meowcraft is already in your list. V = voice chat, B = emotes.'
    Write-Host ''
    if (-not $Flags['no_pause']) { Read-Host '  Press Enter to close' | Out-Null }
}

function Cmd-Play {
    Update-Self @args
    Header
    Require-Launcher
    Require-Installed
    if (Test-GameRunning) { Say 'Minecraft is already running - no updates while you play.'; Open-LauncherAndExit }
    $r = Run-Sync -Quick
    if ($r -eq $false) { Warn "Couldn't check for updates (no internet?). Playing with what you have." }
    if ($null -eq $r) { Read-Host '  Press Enter to open Minecraft anyway' | Out-Null }
    Open-LauncherAndExit
}

function Cmd-Update {
    Update-Self @args
    Header
    Require-Launcher
    Require-Installed
    if (Test-GameRunning) { Warn 'Minecraft is running - close it first, then try again.'; exit 1 }
    $r = Run-Sync
    if ($r) { Good "`n  You're up to date. =^.^="; Write-Host '' } else { exit 1 }
}

function Cmd-Switch {
    $to = ''
    if ($Words.Count -gt 1) { $to = $Words[1].ToLower() }
    if ($to -eq 'normal' -or $to -eq 'core') { $to = 'core' } elseif ($to -ne 'fancy') {
        Write-Host '  Use:  meowcraft switch normal   or   meowcraft switch fancy'; exit 1
    }
    Header
    Require-Launcher
    Require-Installed
    Wait-ForClosedMinecraft
    Set-Variant $to
    Say "Switching to $(Variant-Name $to)..."
    $r = Run-Sync
    if ($r) { Good "`n  Done - you're on $(Variant-Name $to) now."; Write-Host '' } else { exit 1 }
}

function Cmd-Reset {
    $keepSettings = [bool]$Flags['keep_settings']
    Header
    Require-Launcher
    Require-Installed
    Wait-ForClosedMinecraft
    Write-Host '  This starts your Meowcraft folder over with a fresh copy of every mod.' -ForegroundColor Cyan
    Write-Host '  Always kept: your worlds and screenshots.'
    if ($keepSettings) { Write-Host '  Also kept (--keep_settings): game settings + keybinds, mod settings, minimap waypoints, server list.' }
    else { Write-Host '  Game settings, keybinds, mod settings, minimap waypoints and the server list go back to default.'
           Write-Host '  (Add --keep_settings to keep those.)' }
    Write-Host '  Everything else is moved to .minecraft\meowcraft-old, in case you need something back.'
    if (-not $Yes) {
        $r = Read-Host '  Type yes to reset'
        if ($r.Trim().ToLower() -ne 'yes') { Write-Host '  Nothing changed.'; exit 0 }
    }
    if (Test-Path $OldDir) { Remove-Item -Recurse -Force $OldDir }
    try { Move-Item $GameDir $OldDir }
    catch { Warn "Couldn't move the Meowcraft folder - is Minecraft (or a file in that folder) still open?"; exit 1 }
    New-Item -ItemType Directory -Force -Path $GameDir | Out-Null
    $keep = @($AlwaysKeep); if ($keepSettings) { $keep += $SettingsKeep }
    foreach ($k in $keep) {
        $src = Join-Path $OldDir $k
        if (Test-Path $src) { Move-Item $src (Join-Path $GameDir $k); if ($k -notlike '.*') { Info "kept $k" } }
    }
    if (-not (Test-Path $VarFile)) { Set-Variant 'core' }
    Say 'Reinstalling everything fresh...'
    $r = Run-Sync
    if ($r) { Good "`n  Reset done! Old files are in $OldDir until the next reset."; Write-Host '' } else { exit 1 }
}

function Cmd-Status {
    Header
    if (-not (Test-Path $VarFile)) { Warn "Meowcraft isn't set up on this computer yet. Run:  meowcraft install"; exit 0 }
    $variant = Get-Variant
    $local = $null; if (Test-Path $ListFile) { try { $local = [IO.File]::ReadAllText($ListFile) | ConvertFrom-Json } catch {} }
    $mods = Read-Lines $Owned
    $when = 'never'
    $st = Read-Lines $Stamp
    if ($st.Count -ge 2) { try { $when = [datetime]::Parse($st[1]).ToLocalTime().ToString('ddd MMM d, h:mm tt') } catch {} }
    Info "Version:       $(Variant-Name $variant)"
    if ($local) { Info "Minecraft:     $($local.minecraft)"; if ($local.pack) { Info "Pack:          $($local.pack)" } }
    Info "Mods:          $($mods.Count) installed"
    Info "Last updated:  $when"
    Info "Game folder:   $GameDir"
    Info "Command:       $ToolPath (v$ToolVersion)"
    Write-Host ''
    $onlineText = $null
    try { $onlineText = [string](Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri "$RepoRaw/meowcraft.json" -TimeoutSec 20).Content } catch {}
    if (-not $onlineText) { Warn "Couldn't check GitHub for updates right now."; return }
    $sig = Get-Hash ("$variant|$onlineText")
    if ($st.Count -ge 1 -and $st[0] -eq $sig) { Good "Up to date. =^.^=" }
    else {
        $online = $onlineText | ConvertFrom-Json
        $msg = 'An update is waiting'
        if ($online.pack) { $msg += " (pack $($online.pack))" }
        Warn "$msg - run:  meowcraft update   (or just click Play Meowcraft)"
    }
    Write-Host ''
}

function Cmd-Uninstall {
    Header
    Write-Host '  This removes the Play Meowcraft icon, the Meowcraft profile in the Launcher and this command.'
    Write-Host "  Your Meowcraft game folder stays, in case you come back: $GameDir"
    if (-not $Yes) {
        $r = Read-Host '  Type yes to uninstall'
        if ($r.Trim().ToLower() -ne 'yes') { Write-Host '  Nothing changed.'; exit 0 }
    }
    while (Test-LauncherRunning) { Read-Host '  Please close the Minecraft Launcher, then press Enter' | Out-Null }
    foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
        if ($folder) { Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $folder 'Play Meowcraft.lnk') }
    }
    if (Test-Path $LpPath) {
        $lp = Get-Content -Raw -Encoding UTF8 -Path $LpPath | ConvertFrom-Json
        if ($lp.profiles.PSObject.Properties['meowcraft']) {
            Copy-Item $LpPath "$LpPath.meowcraft-backup" -Force
            $lp.profiles.PSObject.Properties.Remove('meowcraft')
            [IO.File]::WriteAllText($LpPath, ($lp | ConvertTo-Json -Depth 32), $Utf8)
        }
    }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) { [Environment]::SetEnvironmentVariable('Path', (@($userPath.Split(';') | Where-Object { $_ -and $_ -ne $ToolDir }) -join ';'), 'User') }
    if (Test-Path $OldApp) { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $OldApp }
    # This command is still running from that folder, so delete it a moment after we exit
    Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c timeout /t 3 /nobreak >nul & rmdir /s /q `"$ToolDir`""
    Good 'Meowcraft is uninstalled. Bye for now =^.^='
    Write-Host ''
}

function Cmd-Help {
    Header
    Write-Host '  meowcraft install                  set up Meowcraft (Normal or Fancy) and the Play Meowcraft icon'
    Write-Host '  meowcraft play                     check for updates, then open the Launcher (what the icon does)'
    Write-Host '  meowcraft update                   check for new mods right now'
    Write-Host '  meowcraft switch normal|fancy      change versions'
    Write-Host '  meowcraft reset                    start over with fresh mods (worlds + screenshots are kept)'
    Write-Host '  meowcraft reset --keep_settings    same, but also keep settings, keybinds, waypoints and server list'
    Write-Host '  meowcraft status                   what you have, and whether an update is waiting'
    Write-Host '  meowcraft uninstall                remove the icon, the Launcher profile and this command'
    Write-Host ''
}

switch ($Cmd) {
    'install'   { Cmd-Install }
    'setup'     { Cmd-Install }
    'play'      { Cmd-Play @args }
    'update'    { Cmd-Update @args }
    'switch'    { Cmd-Switch }
    'reset'     { Cmd-Reset }
    'status'    { Cmd-Status }
    'uninstall' { Cmd-Uninstall }
    default     { Cmd-Help }
}
# MEOWCRAFT-TOOL-END (the updater only accepts a downloaded copy that ends with this line)
