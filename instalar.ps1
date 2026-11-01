<#
  Kit MSD-ONE para Bitfocus Companion
  Instala o modulo "Mars Gaming MSD-ONE" (.tgz desta pasta) no Companion desta maquina,
  reinicia o Companion e abre a pagina das integracoes.
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Fail($msg) { Say ''; Say $msg 'Red'; Say ''; Read-Host 'Carrega Enter para fechar'; exit 1 }

Say ''
Say '=== Kit MSD-ONE para Companion ===' 'Cyan'

# 1. Pacote do modulo
$tgz = Get-ChildItem -Path $here -Filter 'mars-msd-one*.tgz' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $tgz) { Fail 'Nao encontrei o ficheiro mars-msd-one-*.tgz nesta pasta. Copia-o para aqui e tenta outra vez.' }
Say "Pacote: $($tgz.Name)"

# 2. Pasta de configuracao do Companion (tem sempre o ficheiro "machid")
$candidates = @("$env:USERPROFILE\companion")
foreach ($base in @($env:APPDATA, $env:LOCALAPPDATA)) {
  if ($base -and (Test-Path $base)) {
    Get-ChildItem -Path $base -Directory -Filter 'companion*' -ErrorAction SilentlyContinue | ForEach-Object {
      $candidates += $_.FullName
      $candidates += (Join-Path $_.FullName 'Config')
    }
  }
}
$configDir = $candidates | Where-Object { Test-Path (Join-Path $_ 'machid') } | Select-Object -First 1
if (-not $configDir) {
  Fail ('Nao encontrei o Companion nesta maquina.' + "`n" +
        'Instala o Companion (companion.free), abre-o uma vez e volta a correr este kit.')
}
$surfacesDir = Join-Path $configDir 'surfaces'
New-Item -ItemType Directory -Force -Path $surfacesDir | Out-Null
Say "Companion: $configDir"

# 3. Desempacotar e ler o manifest
$tmp = Join-Path $env:TEMP ('msdone-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
& "$env:SystemRoot\System32\tar.exe" -xzf $tgz.FullName -C $tmp
if ($LASTEXITCODE -ne 0) { Fail 'Nao consegui abrir o ficheiro .tgz.' }

$manifestFile = Get-ChildItem -Path $tmp -Recurse -Filter 'manifest.json' |
  Where-Object { $_.Directory.Name -eq 'companion' } | Select-Object -First 1
if (-not $manifestFile) { Fail 'O .tgz nao tem companion/manifest.json.' }
$manifest = Get-Content -Raw $manifestFile.FullName | ConvertFrom-Json
$pkgRoot = $manifestFile.Directory.Parent.FullName
$target = Join-Path $surfacesDir ("$($manifest.id)-$($manifest.version)")

$installed = $false
if (Test-Path $target) {
  Say "O modulo $($manifest.id) v$($manifest.version) ja esta instalado." 'Green'
} else {
  Copy-Item -Path $pkgRoot -Destination $target -Recurse
  Say "Modulo instalado em $target" 'Green'
  $installed = $true
}
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

# 4. Software da Mars Gaming nao pode estar aberto (ocupa o teclado)
$mars = Get-Process -ErrorAction SilentlyContinue | Where-Object {
  try { $_.Path -and ($_.Path -match '(?i)mars') -and ($_.Path -notmatch '(?i)companion') } catch { $false }
}
if ($mars) {
  Say ''
  Say 'O software da Mars Gaming esta aberto e vai bloquear o teclado:' 'Yellow'
  $mars | ForEach-Object { Say "  - $($_.ProcessName)  ($($_.Path))" 'Yellow' }
  $ans = Read-Host 'Fechar agora? (S/N)'
  if ($ans -match '^[sSyY]') { $mars | Stop-Process -Force -ErrorAction SilentlyContinue; Say 'Fechado.' 'Green' }
}

# 5. (Re)iniciar o Companion para carregar o modulo
$comp = Get-Process -Name 'Companion' -ErrorAction SilentlyContinue | Select-Object -First 1
$exe = $null
if ($comp) { try { $exe = $comp.Path } catch { } }
if (-not $exe) {
  $exe = @("$env:ProgramFiles\Companion\Companion.exe", "${env:ProgramFiles(x86)}\Companion\Companion.exe",
           "$env:LOCALAPPDATA\Programs\Companion\Companion.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

if ($comp -and $installed) {
  Say 'A reiniciar o Companion...'
  Get-Process -Name 'Companion' -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 3
  if ($exe) { Start-Process $exe }
} elseif (-not $comp) {
  if ($exe) { Say 'A abrir o Companion...'; Start-Process $exe }
  else { Say 'Abre o Companion manualmente.' 'Yellow' }
}

# 6. Abrir a pagina das integracoes
Say 'A aguardar que o Companion arranque...'
$url = 'http://127.0.0.1:8000/surfaces/integrations'
for ($i = 0; $i -lt 30; $i++) {
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri 'http://127.0.0.1:8000/' | Out-Null; break } catch { Start-Sleep -Seconds 1 }
}
Start-Process $url

Say ''
Say 'Falta so um passo (uma vez por maquina):' 'Cyan'
Say '  Surfaces > Integrations > Add Surface Integration > Mars Gaming MSD-ONE'
Say '  (se ja o fizeste antes nesta maquina, nao precisas de repetir)'
Say ''
Say 'Se o Companion usar outra porta que nao a 8000, abre-o pelo icone e vai a essa pagina.'
Say ''
Read-Host 'Carrega Enter para fechar'
