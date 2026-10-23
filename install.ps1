# ai-interview-self-discovery —— Windows 一键安装 / 更新（PowerShell，重复执行即更新）
#
#   安装 / 更新：irm https://raw.githubusercontent.com/sophiayuan1984-jpg/ai-interview-self-discovery/main/install.ps1 | iex
#   卸载：      $env:SKILL_UNINSTALL=1; irm https://raw.githubusercontent.com/sophiayuan1984-jpg/ai-interview-self-discovery/main/install.ps1 | iex
#
# 可选环境变量：SKILL_REPO / SKILL_BRANCH / SKILL_DIR（含义同 install.sh）
$ErrorActionPreference = 'Stop'

$Name   = 'ai-interview-self-discovery'
$Repo   = if ($env:SKILL_REPO)   { $env:SKILL_REPO }   else { 'sophiayuan1984-jpg/ai-interview-self-discovery' }
$Branch = if ($env:SKILL_BRANCH) { $env:SKILL_BRANCH } else { 'main' }
$Items  = @('SKILL.md', 'README.md', 'VERSION', 'LICENSE', 'references', 'tests')

# 1. 安装目标
$Targets = @()
if ($env:SKILL_DIR) {
  $Targets = @($env:SKILL_DIR)
} else {
  foreach ($a in @('.workbuddy', '.codebuddy', '.claude', '.codex', '.cursor')) {
    if (Test-Path (Join-Path $HOME $a)) { $Targets += (Join-Path (Join-Path $HOME $a) 'skills') }
  }
  if ($Targets.Count -eq 0) { $Targets = @(Join-Path (Join-Path $HOME '.claude') 'skills') }
}

# 2. 卸载
if ($env:SKILL_UNINSTALL -eq '1') {
  foreach ($t in $Targets) {
    $d = Join-Path $t $Name
    if (Test-Path (Join-Path $d 'SKILL.md')) { Remove-Item $d -Recurse -Force; Write-Host "✓ 已卸载 $d" }
  }
  Remove-Item Env:SKILL_UNINSTALL -ErrorAction SilentlyContinue
  return
}

# 3. 下载
if ($Repo -eq ('__' + 'REPO__')) { throw '仓库地址尚未设置：请设置 $env:SKILL_REPO = "owner/repo"' }
$tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $zip = Join-Path $tmp 'src.zip'
  Write-Host "→ 下载 $Repo@$Branch ..."
  Invoke-WebRequest "https://codeload.github.com/$Repo/zip/refs/heads/$Branch" -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp
  $src = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
  if (-not (Test-Path (Join-Path $src 'SKILL.md'))) { throw '仓库根目录没有 SKILL.md' }
  $newVer = (Get-Content (Join-Path $src 'VERSION') -Raw).Trim()

  # 4. 替换安装
  foreach ($t in $Targets) {
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    $dest = Join-Path $t $Name
    $old = ''
    if (Test-Path (Join-Path $dest 'VERSION')) { $old = (Get-Content (Join-Path $dest 'VERSION') -Raw).Trim() }
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    New-Item -ItemType Directory -Path $dest | Out-Null
    foreach ($i in $Items) {
      $p = Join-Path $src $i
      if (Test-Path $p) { Copy-Item $p -Destination $dest -Recurse -Force }
    }
    if (-not $old)            { Write-Host "✓ 已安装 v$newVer → $dest" }
    elseif ($old -eq $newVer) { Write-Host "✓ 已是最新 v$newVer（已重新同步）→ $dest" }
    else                      { Write-Host "✓ 已更新 v$old → v$newVer → $dest" }
  }
  Write-Host ''
  Write-Host '新开一个对话，说「面试我」或「我想看看自己适不适合做 XX 岗位」即可开始。'
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
