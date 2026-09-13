$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modsDir = Join-Path $scriptDir "mods"
$filesDir = Join-Path $scriptDir "files"
$metaFile = Join-Path $scriptDir "meta.xml"
$configFile = Join-Path $scriptDir "shared\config.lua"

$modFiles = Get-ChildItem -Path $modsDir -Recurse -File | Where-Object { $_.Extension -match '^\.(dff|txd|col)$' }
$extraFiles = Get-ChildItem -Path $filesDir -Recurse -File -ErrorAction SilentlyContinue

$relFiles = @()
$groups = @{}

foreach ($f in $modFiles) {
    $full = $f.FullName
    $rel = $full.Substring($scriptDir.Length + 1).Replace("\", "/")
    $relFiles += $rel

    $parentDir = $f.Directory.Name.ToLower()
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name).ToLower()
    $ext = $f.Extension.ToLower().TrimStart('.')

    $modelName = if ($parentDir -ne "vehicles" -and $parentDir -ne "weapons" -and $parentDir -ne "skins" -and $parentDir -ne "mods") { $parentDir } else { $baseName }
    $key = $f.Directory.FullName

    if (-not $groups.ContainsKey($key)) {
        $groups[$key] = @{
            model = $modelName
            dir = $parentDir
            dff = $null
            txd = $null
            col = $null
        }
    }

    if ($ext -eq "dff") { $groups[$key].dff = $rel }
    elseif ($ext -eq "txd") { $groups[$key].txd = $rel }
    elseif ($ext -eq "col") { $groups[$key].col = $rel }
}

if ($extraFiles) {
    foreach ($ef in $extraFiles) {
        $relEf = $ef.FullName.Substring($scriptDir.Length + 1).Replace("\", "/")
        $relFiles += $relEf
    }
}

$metaLines = @()
$metaLines += '<meta>'
$metaLines += '    <info author="GZL Roleplay" type="script" name="GZL Mod Loader" version="1.0.0" description="High-performance automated vehicle, weapon and skin mod loader" />'
$metaLines += ''
$metaLines += '    <min_mta_version client="1.6.0" server="1.6.0" />'
$metaLines += '    <oop>true</oop>'
$metaLines += ''
$metaLines += '    <script src="shared/config.lua" type="shared" cache="false" />'
$metaLines += '    <script src="client/main.lua" type="client" cache="false" />'
$metaLines += '    <script src="server/main.lua" type="server" />'
$metaLines += ''
$metaLines += '    <export function="reloadModLoader" type="server" />'
$metaLines += ''

foreach ($rel in ($relFiles | Sort-Object -Unique)) {
    $metaLines += "    <file src=`"$rel`" />"
}
$metaLines += '</meta>'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($metaFile, $metaLines, $utf8NoBom)

$luaLines = @()
$luaLines += 'Config = {}'
$luaLines += ''
$luaLines += 'Config.LoadBatchDelayMs = 50'
$luaLines += 'Config.EnableAlphaTransparency = false'
$luaLines += ''
$luaLines += 'Config.Mods = {'

foreach ($k in ($groups.Keys | Sort-Object)) {
    $item = $groups[$k]
    $m = $item.model
    $t = if ($item.txd) { "`"$($item.txd)`"" } else { "nil" }
    $d = if ($item.dff) { "`"$($item.dff)`"" } else { "nil" }
    $c = if ($item.col) { "`"$($item.col)`"" } else { "nil" }

    $type = "vehicle"
    if ($item.dir -match "weapon") { $type = "weapon" }
    elseif ($item.dir -match "skin") { $type = "skin" }

    $luaLines += "    {"
    $luaLines += "        type = `"$type`","
    $luaLines += "        model = `"$m`","
    $luaLines += "        txd = $t,"
    $luaLines += "        dff = $d,"
    $luaLines += "        col = $c"
    $luaLines += "    },"
}

$luaLines += '}'

[System.IO.File]::WriteAllLines($configFile, $luaLines, $utf8NoBom)

Write-Host "Basarili! Toplam $($relFiles.Count) dosya ve $($groups.Count) model meta.xml ve config.lua dosyasina islendi." -ForegroundColor Green
