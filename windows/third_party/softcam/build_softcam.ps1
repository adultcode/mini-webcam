<#
Builds softcam.dll (the DirectShow virtual camera) from the official
tshino/softcam source (MIT), branded as "Mini Webcam".

Changes from upstream:
  - camera name "Mini Webcam" and its own CLSID, so it never clashes with
    other softcam-based apps installed on the same PC
  - its own shared-memory / mutex names for the same reason
  - static C runtime (/MT), so regsvr32 works on PCs without the VC++ redist

Usage:  powershell -ExecutionPolicy Bypass -File build_softcam.ps1
Output: softcam.dll next to this script (picked up by windows/CMakeLists.txt)
#>
param(
  [string]$OutDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

$Repo = 'https://github.com/tshino/softcam'
$Tag = 'v1.8.1'
$Commit = 'afb424c2415b04da627fa1a7b4706575c2ba3010'
$CameraName = 'Mini Webcam'
# {0EED1CAD-BF0F-405D-B669-0EDD286EDA0E}
$Clsid = '0x0eed1cad, 0xbf0f, 0x405d, 0xb6, 0x69, 0x0e, 0xdd, 0x28, 0x6e, 0xda, 0x0e'

$work = Join-Path ([IO.Path]::GetTempPath()) "mini-webcam-softcam-$PID"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }

git -c advice.detachedHead=false clone --quiet --depth 1 --branch $Tag $Repo $work
if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
$head = (git -C $work rev-parse HEAD).Trim()
if ($head -ne $Commit) { throw "Tag $Tag resolved to $head, expected $Commit" }

function Patch([string]$file, [string]$from, [string]$to) {
  $path = Join-Path $work $file
  $text = [IO.File]::ReadAllText($path)
  if (-not $text.Contains($from)) { throw "Patch anchor not found in ${file}: $from" }
  [IO.File]::WriteAllText($path, $text.Replace($from, $to))
}

Patch 'src\softcam\softcam.cpp' `
  '0xaef3b972, 0x5fa5, 0x4647, 0x95, 0x71, 0x35, 0x8e, 0xb4, 0x72, 0xbc, 0x9e' $Clsid
Patch 'src\softcam\softcam.cpp' 'L"DirectShow Softcam"' "L`"$CameraName`""
Patch 'src\softcamcore\DShowSoftcam.cpp' 'NAME("DirectShow Softcam")' "NAME(`"$CameraName`")"
Patch 'src\softcamcore\DShowSoftcam.cpp' 'L"DirectShow Softcam Stream"' "L`"$CameraName Stream`""
Patch 'src\softcamcore\FrameBuffer.cpp' '"DirectShow Softcam/NamedMutex"' "`"$CameraName/NamedMutex`""
Patch 'src\softcamcore\FrameBuffer.cpp' '"DirectShow Softcam/SharedMemory"' "`"$CameraName/SharedMemory`""

# Static runtime: drop the explicit dynamic CRT import lib from the link line;
# /MT itself is forced through _CL_ below.
$proj = Join-Path $work 'src\softcam\softcam.vcxproj'
$xml = [IO.File]::ReadAllText($proj)
if (-not $xml.Contains('msvcrt.lib;')) { throw 'msvcrt.lib not found in softcam.vcxproj' }
[IO.File]::WriteAllText($proj, $xml.Replace('msvcrtd.lib;', '').Replace('msvcrt.lib;', ''))

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -format json | ConvertFrom-Json | Select-Object -First 1
if (-not $vs) { throw 'Visual Studio with C++ tools not found' }
$msbuild = Join-Path $vs.installationPath 'MSBuild\Current\Bin\MSBuild.exe'
$toolset = switch ([int]$vs.installationVersion.Split('.')[0]) {
  17 { 'v143' }
  18 { 'v145' }
  default { throw "Unsupported Visual Studio $($vs.installationVersion)" }
}

# _CL_ is appended after the project's own flags, so /MT wins everywhere.
$env:_CL_ = '/MT'
& $msbuild $proj /m /nologo /verbosity:minimal `
  /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=$toolset `
  /p:WindowsTargetPlatformVersion=10.0
$code = $LASTEXITCODE
Remove-Item Env:_CL_
if ($code -ne 0) { throw 'msbuild failed' }

$dll = Get-ChildItem -Recurse $work -Filter softcam.dll |
  Where-Object { $_.FullName -match '\\x64\\Release\\' } | Select-Object -First 1
if (-not $dll) { throw 'softcam.dll not produced' }
New-Item -ItemType Directory -Force $OutDir | Out-Null
Copy-Item $dll.FullName (Join-Path $OutDir 'softcam.dll') -Force
Copy-Item (Join-Path $work 'LICENSE') (Join-Path $OutDir 'LICENSE.softcam.txt') -Force
Remove-Item -Recurse -Force $work
Write-Host "Built $(Join-Path $OutDir 'softcam.dll') ($toolset, camera '$CameraName')"
