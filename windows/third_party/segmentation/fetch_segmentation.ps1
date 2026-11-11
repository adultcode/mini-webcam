<#
Downloads what the background blur / replacement effect needs:
  - ONNX Runtime (MIT), CPU build: onnxruntime.dll and its C API header
  - MediaPipe selfie segmentation models (Apache-2.0), ONNX exports from
    huggingface.co/onnx-community, in a landscape (256x144) and a square
    (256x256) variant

Every download is pinned to an immutable version and checked against its
SHA-256, so a changed or tampered file fails the build.

Usage:  powershell -ExecutionPolicy Bypass -File fetch_segmentation.ps1
Output: files next to this script (picked up by windows/CMakeLists.txt)
#>
param(
  [string]$OutDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Invoke-WebRequest is very slow with it

$OrtVersion = '1.20.1'
$OrtUrl = "https://github.com/microsoft/onnxruntime/releases/download/v$OrtVersion/onnxruntime-win-x64-$OrtVersion.zip"
$OrtSha = '78D447051E48BD2E1E778BBA378BEC4ECE11191C9E538CF7B2C4A4565E8F5581'

$Models = @(
  @{
    File = 'selfie_landscape.onnx'
    Url = 'https://huggingface.co/onnx-community/mediapipe_selfie_segmentation_landscape/resolve/2497d5bec26c626c7b3c4edc6e1fefc21b64f6c3/onnx/model.onnx'
    Sha = '7A0ADCFDB1715D3B0FF0F61486D8A181C33F4A208343A5ABFCCBC6540E872D24'
  },
  @{
    File = 'selfie_square.onnx'
    Url = 'https://huggingface.co/onnx-community/mediapipe_selfie_segmentation/resolve/be49485c8e027524be38591817fc5cd31bd9d00e/onnx/model.onnx'
    Sha = '3241AC4AD8AA35BDAF33946776DB29F7C283A413AA0B0DACB9483594B4531AAD'
  }
)

function Get-Verified([string]$url, [string]$path, [string]$sha) {
  Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
  $hash = (Get-FileHash $path -Algorithm SHA256).Hash
  if ($hash -ne $sha) { throw "Checksum mismatch for ${url}: $hash" }
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$work = Join-Path ([IO.Path]::GetTempPath()) "mini-webcam-segmentation-$PID"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force $work | Out-Null

try {
  # ONNX Runtime: take only the DLL, the C API header and the notices.
  $zip = Join-Path $work 'ort.zip'
  Get-Verified $OrtUrl $zip $OrtSha
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $root = "onnxruntime-win-x64-$OrtVersion/"
    $wanted = @{
      "${root}lib/onnxruntime.dll" = 'onnxruntime.dll'
      "${root}include/onnxruntime_c_api.h" = 'onnxruntime_c_api.h'
      "${root}LICENSE" = 'LICENSE.onnxruntime.txt'
      "${root}ThirdPartyNotices.txt" = 'ThirdPartyNotices.onnxruntime.txt'
    }
    foreach ($entry in $wanted.Keys) {
      $item = $archive.GetEntry($entry)
      if (-not $item) { throw "$entry not found in the ONNX Runtime archive" }
      [IO.Compression.ZipFileExtensions]::ExtractToFile(
        $item, (Join-Path $OutDir $wanted[$entry]), $true)
    }
  } finally {
    $archive.Dispose()
  }

  foreach ($m in $Models) {
    $tmp = Join-Path $work $m.File
    Get-Verified $m.Url $tmp $m.Sha
    Copy-Item $tmp (Join-Path $OutDir $m.File) -Force
  }

  @'
MediaPipe Selfie Segmentation models (selfie_landscape.onnx, selfie_square.onnx)

Copyright Google LLC. Licensed under the Apache License, Version 2.0:
https://www.apache.org/licenses/LICENSE-2.0

Original models: https://github.com/google-ai-edge/mediapipe
ONNX exports: https://huggingface.co/onnx-community/mediapipe_selfie_segmentation
              https://huggingface.co/onnx-community/mediapipe_selfie_segmentation_landscape
'@ | Out-File -Encoding ascii (Join-Path $OutDir 'NOTICE.selfie_segmentation.txt')
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

Write-Host "Fetched ONNX Runtime $OrtVersion and the selfie segmentation models into $OutDir"
