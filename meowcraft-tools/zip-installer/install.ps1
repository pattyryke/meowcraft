# Meowcraft client installer: adds a "Meowcraft" profile (Fabric + mods) to the official Minecraft Launcher.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- Built-in lists (used only if the online list in manifest-url.txt can't be read) ----
$McVersion          = '26.3'
$CoreMods           = @('fabric-api', 'sodium', 'immediatelyfast', 'modmenu', 'xaeros-minimap', 'xaeros-world-map', 'jade', 'appleskin', 'mouse-tweaks', 'zoomify', 'simple-voice-chat', 'emotecraft', 'clientsort')
$FancyMods          = @('iris', 'entity-model-features', 'entitytexturefeatures')
$FancyPacks         = @('fresh-animations')
$FancyShaders       = @(@('HVnmMxH1', 'Meowcraft High - Complementary Reimagined.zip'), @('Q1vvjJYV', 'Meowcraft Medium - BSL.zip'), @('makeup-ultra-fast-shaders', 'Meowcraft Low - MakeUp Ultra Fast.zip'))
$FancyDefaultShader = 'Meowcraft Low - MakeUp Ultra Fast.zip'
# -------------------------------------------------------------------------------------------
$KnownPacks = @('fresh-animations')

$Headers = @{ 'User-Agent' = 'pattycakez69/meowcraft-installer/1.3' }
$McDir   = Join-Path $env:APPDATA '.minecraft'
$GameDir = Join-Path $McDir 'meowcraft'
$ModsDir = Join-Path $GameDir 'mods'
$PackDir = Join-Path $GameDir 'resourcepacks'
$OptFile = Join-Path $GameDir 'options.txt'
$Owned   = Join-Path $ModsDir '.meowcraft-owned'
$Utf8    = New-Object System.Text.UTF8Encoding $false
$Here    = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($msg)  { Write-Host "  =^.^=  $msg" -ForegroundColor Magenta }
function Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }
function Get-Json($url) {
    $r = Invoke-RestMethod -Headers $Headers -Uri $url
    $out = @(); foreach ($x in $r) { $out += $x }; return ,$out
}
function Get-Versions($project, $loader) {
    $q = 'loaders=' + [uri]::EscapeDataString("[`"$loader`"]") + '&game_versions=' + [uri]::EscapeDataString("[`"$McVersion`"]")
    try { return ,(Get-Json "https://api.modrinth.com/v2/project/$project/version?$q") } catch { return ,@() }
}
function Get-PrimaryFile($version) {
    $f = $version.files | Where-Object { $_.primary } | Select-Object -First 1
    if (-not $f) { $f = $version.files | Select-Object -First 1 }
    return $f
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

Write-Host ''
# Which set to install: variant.txt says core or fancy
$Variant = 'core'
$vf = Join-Path $Here 'variant.txt'
if (Test-Path $vf) { $Variant = ([IO.File]::ReadAllText($vf)).Trim().ToLower() }
$Mods = @($CoreMods); $Packs = @(); $Shaders = @(); $DefaultShader = ''
if ($Variant -eq 'fancy') { $Mods += $FancyMods; $Packs = @($FancyPacks); $Shaders = $FancyShaders; $DefaultShader = $FancyDefaultShader }

Write-Host "  Meowcraft installer ($Variant)" -ForegroundColor Magenta
Write-Host ''

# Use the online master list (meowcraft.json on GitHub) if one is set up
$muf = Join-Path $Here 'manifest-url.txt'
$ManifestUrl = ''
if (Test-Path $muf) { $ManifestUrl = ([IO.File]::ReadAllText($muf)).Trim() }
if ($ManifestUrl -and -not $ManifestUrl.Contains('YOUR-GITHUB-NAME')) {
    try {
        $man = Invoke-RestMethod -Headers $Headers -Uri $ManifestUrl
        $chain = @(); $cur = $Variant
        while ($cur) { $chain = @($cur) + $chain; $cur = $man.client.$cur.extends }
        $Mods = @(); $Packs = @(); $Shaders = @(); $DefaultShader = ''
        foreach ($c in $chain) {
            $sec = $man.client.$c
            foreach ($m in $sec.mods) { if ($Mods -notcontains $m) { $Mods += $m } }
            foreach ($p in $sec.resourcepacks) { if ($Packs -notcontains $p) { $Packs += $p } }
            foreach ($s in $sec.shaders) { $Shaders += ,@($s.project, $s.file) }
            if ($sec.default_shader) { $DefaultShader = $sec.default_shader }
        }
        if ($man.minecraft) { $McVersion = $man.minecraft }
        Say "Using the Meowcraft mod list from GitHub (Minecraft $McVersion)"
    } catch { Warn "Couldn't read the online mod list - using the built-in one" }
}

if (-not (Test-Path (Join-Path $McDir 'launcher_profiles.json'))) {
    Write-Host '  Open the Minecraft Launcher and log in once, then run this again.' -ForegroundColor Red; exit 1
}
if (Get-Process -Name 'MinecraftLauncher','Minecraft' -ErrorAction SilentlyContinue) {
    Write-Host '  Please close the Minecraft Launcher first, then run this again.' -ForegroundColor Red; exit 1
}

# 1. Fabric loader (same files the official Fabric installer writes)
Say "Finding the latest Fabric loader for Minecraft $McVersion..."
$loaders = Get-Json "https://meta.fabricmc.net/v2/versions/loader/$McVersion"
if ($loaders.Count -eq 0) { throw "Fabric doesn't support Minecraft $McVersion yet." }
$loader = $loaders | Where-Object { $_.loader.stable } | Select-Object -First 1
if (-not $loader) { $loader = $loaders[0] }
$loaderVer = $loader.loader.version
$profileJson = Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri "https://meta.fabricmc.net/v2/versions/loader/$McVersion/$loaderVer/profile/json"
$versionId = ($profileJson.Content | ConvertFrom-Json).id
$verDir = Join-Path (Join-Path $McDir 'versions') $versionId
New-Item -ItemType Directory -Force -Path $verDir | Out-Null
[IO.File]::WriteAllText((Join-Path $verDir "$versionId.json"), $profileJson.Content, $Utf8)
$jar = Join-Path $verDir "$versionId.jar"
if (-not (Test-Path $jar)) { [IO.File]::WriteAllBytes($jar, [byte[]]@()) }
Say "Fabric loader $loaderVer ready"

# 2. Work out the mod list, including required dependencies.
#    Prefers stable releases over betas, and honors exact versions that other mods ask for.
Say 'Checking mods (and anything they need)...'
function Pick-Version($vs, $pinId) {
    if ($pinId) { $p = $vs | Where-Object { $_.id -eq $pinId } | Select-Object -First 1; if ($p) { return $p } }
    $r = $vs | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
    if ($r) { return $r } else { return $vs[0] }
}
$seen   = @{}
$chosen = [ordered]@{}   # project_id -> version
$pins   = @{}            # project_id -> version_id another mod requires
$allVs  = @{}            # project_id -> all versions for this Minecraft version
$slugIds = @{}           # slug -> project_id
$queue  = New-Object System.Collections.Queue
foreach ($m in $Mods) { $queue.Enqueue($m) }
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
        Say "Matched Sodium to Iris: $($chosen[$slugIds['sodium']].version_number)"
    }
}
$want = [ordered]@{}   # filename -> url
foreach ($v in $chosen.Values) { $f = Get-PrimaryFile $v; $want[$f.filename] = $f.url }

# 3. Sync the mods folder (only touches files this installer put there)
New-Item -ItemType Directory -Force -Path $ModsDir | Out-Null
$ownedList = @(); if (Test-Path $Owned) { foreach ($l in [IO.File]::ReadAllLines($Owned)) { if ($l) { $ownedList += $l } } }
foreach ($old in $ownedList) {
    if (-not $want.Contains($old)) { Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $ModsDir $old); Say "Removed $old" }
}
foreach ($name in $want.Keys) {
    $dest = Join-Path $ModsDir $name
    if (Test-Path $dest) { Say "Up to date: $name"; continue }
    Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $want[$name] -OutFile $dest
    Say "Downloaded $name"
}
[IO.File]::WriteAllLines($Owned, [string[]]@($want.Keys), $Utf8)

# 4. Resource packs
New-Item -ItemType Directory -Force -Path $PackDir | Out-Null
foreach ($pack in $KnownPacks) {
    if ($Packs -notcontains $pack) {
        $pf = Join-Path $PackDir "$pack.zip"
        if (Test-Path $pf) { Remove-Item -Force $pf; Set-PackEnabled "$pack.zip" $false; Say "Removed resource pack $pack" }
    }
}
foreach ($pack in $Packs) {
    $vs = Get-Versions $pack 'minecraft'
    if ($vs.Count -eq 0) { Warn "$pack has no version for $McVersion yet - skipping"; continue }
    $f = Get-PrimaryFile $vs[0]
    Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $f.url -OutFile (Join-Path $PackDir "$pack.zip")
    Set-PackEnabled "$pack.zip" $true
    Say "Installed and turned on resource pack $pack"
}

# 4b. Shader packs (Iris)
if ($Shaders.Count -gt 0) {
    $ShDir = Join-Path $GameDir 'shaderpacks'
    New-Item -ItemType Directory -Force -Path $ShDir | Out-Null
    foreach ($s in $Shaders) {
        $slug = $s[0]; $fname = $s[1]
        $vs = Get-Versions $slug 'iris'
        if ($vs.Count -eq 0) {   # shader packs usually work across versions, so fall back to the newest one
            try { $vs = Get-Json ("https://api.modrinth.com/v2/project/$slug/version?loaders=" + [uri]::EscapeDataString('["iris"]')) } catch { $vs = @() }
        }
        if ($vs.Count -eq 0) { Warn "Couldn't find shader pack $slug - skipping"; continue }
        $f = Get-PrimaryFile (Pick-Version $vs $null)
        Invoke-WebRequest -UseBasicParsing -Headers $Headers -Uri $f.url -OutFile (Join-Path $ShDir $fname)
        Say "Installed shader pack: $fname"
    }
    $cfgDir = Join-Path $GameDir 'config'
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    $irisCfg = Join-Path $cfgDir 'iris.properties'
    $lines = @(); if (Test-Path $irisCfg) { foreach ($l in [IO.File]::ReadAllLines($irisCfg)) { $lines += $l } }
    if (-not ($lines | Where-Object { $_ -match '^shaderPack=.+' })) {
        $lines = @($lines | Where-Object { $_ -notmatch '^(shaderPack|enableShaders)=' })
        $lines += "shaderPack=$DefaultShader"; $lines += 'enableShaders=true'
        [IO.File]::WriteAllLines($irisCfg, [string[]]$lines, $Utf8)
        Say "Turned on shaders: $DefaultShader"
    }
}

# 5. Server list (only if they don't have one yet)
$serversDat = Join-Path $GameDir 'servers.dat'
if (-not (Test-Path $serversDat)) { Copy-Item (Join-Path $Here 'servers.dat') $serversDat; Say 'Added Meowcraft to your server list' }

# 6. Launcher profile
$lpPath = Join-Path $McDir 'launcher_profiles.json'
Copy-Item $lpPath "$lpPath.meowcraft-backup" -Force
$lp = Get-Content -Raw -Path $lpPath | ConvertFrom-Json
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
$mcProfile = [ordered]@{
    name = 'Meowcraft'; type = 'custom'; created = $now; lastUsed = $now
    lastVersionId = $versionId; gameDir = $GameDir
    icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAABeElEQVR4Xu2aIW/CUBSFW8I0CRL01NwsAmpn+AMY5IIhm52cHeEnIPgDNbNgsPwBNJYEPbNg3rtNerP7wsrhJudTJWnKvZxzXm95zWfDVeaZlufiL7ABNG1ZwPbwVlvP6HEBqdNSDy2Exr0ClQxIdvNu+DhYxmw0nQfp+2oNp1qx3SvABtCoGeg8fIXadvP3RvOg+V7WkGVTZuAucR9iNQMa2v3hGuQ1U3GvABtAo2bg/BPXfguWucVyjsRSAy2Exr0C+VMvzv3XrMe3ZCCeDdwrwAbQmGahyXgU6twX3+H4efMSjtflNqmX/7omLYSGCqChAmjcK9DILFT9Pydime8tcBa6J9xnwDQLdcafST96v3itPf+4SdtrO5cff36vewXYABpTBiz0i7iPpnndck4qtBAa9wrk8n0hba9KknpPSEVb++X8I/eq3SvABtBUMiCx5KFpNN9LaCE07hVQM6Dl4ZZY3k1yrwAbQGN6HrB4EQUthMa9Ar+V1GApTOWmuAAAAABJRU5ErkJggg=='
}
if ($lp.profiles.PSObject.Properties['meowcraft']) { $lp.profiles.PSObject.Properties.Remove('meowcraft') }
$lp.profiles | Add-Member -NotePropertyName 'meowcraft' -NotePropertyValue ([pscustomobject]$mcProfile)
[IO.File]::WriteAllText($lpPath, ($lp | ConvertTo-Json -Depth 32), $Utf8)
Say 'Meowcraft profile added to the Minecraft Launcher'

Write-Host ''
Write-Host '  All done! Open the Minecraft Launcher, pick "Meowcraft" next to the Play button, and hit Play.' -ForegroundColor Green
Write-Host '  In game: Multiplayer -> Meowcraft is already in your list. Press V for voice chat.' -ForegroundColor Green
Write-Host ''
