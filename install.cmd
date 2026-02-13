@echo off
:: PATAPIM Installer for Windows CMD (Silent ZIP-based install)
:: Usage: curl -fsSL https://raw.githubusercontent.com/G3dar/patapim-releases/main/install.cmd -o "%TEMP%\patapim-install.cmd" && "%TEMP%\patapim-install.cmd"
setlocal

echo.
echo   ____   _  _____  _   ____ ___ __  __
echo  ^|  _ \ / \^|_   _^|/ \ ^|  _ \_ _^|  \/  ^|
echo  ^| ^|_) / _ \ ^| ^| / _ \^| ^|_) ^| ^|^| ^|\/^| ^|
echo  ^|  __/ ___ \^| ^|/ ___ \  __/^| ^|^| ^|  ^| ^|
echo  ^|_^| /_/   \_\_/_/   \_\_^| ^|___^|_^|  ^|_^|
echo.
echo   Project Management IDE for Claude Code
echo.

echo   Fetching latest release...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; " ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "try { " ^
    "  $info = Invoke-RestMethod 'https://patapim.ai/api/download/info' -Headers @{'User-Agent'='PATAPIM-Installer'}; " ^
    "  $v = $info.version; " ^
    "  $zf = $info.zipFile; " ^
    "  if (-not $zf) { Write-Host '  Error: ZIP distribution not available.' -ForegroundColor Red; exit 1 }; " ^
    "  Write-Host \"  Found version: v$v\" -ForegroundColor Green; " ^
    "  $tmp = Join-Path $env:TEMP $zf; " ^
    "  $installDir = Join-Path $env:LOCALAPPDATA 'Programs\PATAPIM'; " ^
    "  Write-Host \"  Downloading $zf...\"; " ^
    "  Invoke-WebRequest 'https://patapim.ai/api/download/latest-zip' -OutFile $tmp -UseBasicParsing; " ^
    "  $procs = Get-Process -Name 'PATAPIM' -ErrorAction SilentlyContinue; " ^
    "  if ($procs) { Write-Host '  Closing running PATAPIM...' -ForegroundColor Yellow; $procs | Stop-Process -Force; Start-Sleep 1 }; " ^
    "  Write-Host \"  Installing to $installDir...\" -ForegroundColor Yellow; " ^
    "  if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }; " ^
    "  New-Item -ItemType Directory -Path $installDir -Force | Out-Null; " ^
    "  Expand-Archive -Path $tmp -DestinationPath $installDir -Force; " ^
    "  $items = Get-ChildItem $installDir; " ^
    "  if ($items.Count -eq 1 -and $items[0].PSIsContainer) { " ^
    "    $inner = $items[0].FullName; " ^
    "    Get-ChildItem $inner | Move-Item -Destination $installDir -Force; " ^
    "    Remove-Item $inner -Force " ^
    "  }; " ^
    "  Write-Host '  Creating shortcuts...' -ForegroundColor Yellow; " ^
    "  $exe = Join-Path $installDir 'PATAPIM.exe'; " ^
    "  $sh = New-Object -ComObject WScript.Shell; " ^
    "  try { " ^
    "    $lnk = $sh.CreateShortcut((Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\PATAPIM.lnk')); " ^
    "    $lnk.TargetPath = $exe; $lnk.WorkingDirectory = $installDir; $lnk.Save(); " ^
    "    Write-Host '    Start Menu: created' -ForegroundColor Green " ^
    "  } catch { Write-Host '    Start Menu: failed' -ForegroundColor Yellow }; " ^
    "  try { " ^
    "    $lnk = $sh.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'PATAPIM.lnk')); " ^
    "    $lnk.TargetPath = $exe; $lnk.WorkingDirectory = $installDir; $lnk.Save(); " ^
    "    Write-Host '    Desktop: created' -ForegroundColor Green " ^
    "  } catch { Write-Host '    Desktop: failed' -ForegroundColor Yellow }; " ^
    "  try { " ^
    "    $up = [Environment]::GetEnvironmentVariable('PATH','User'); " ^
    "    if ($up -notlike \"*$installDir*\") { " ^
    "      [Environment]::SetEnvironmentVariable('PATH',\"$up;$installDir\",'User'); " ^
    "      Write-Host '    PATH: added' -ForegroundColor Green " ^
    "    } else { Write-Host '    PATH: already set' -ForegroundColor DarkGray } " ^
    "  } catch { Write-Host '    PATH: failed' -ForegroundColor Yellow }; " ^
    "  Remove-Item $tmp -Force -ErrorAction SilentlyContinue; " ^
    "  Write-Host ''; Write-Host \"  PATAPIM v$v installed successfully!\" -ForegroundColor Green; Write-Host ''; " ^
    "  $mp = Join-Path $installDir 'resources\app\src\mcp\patapim-browser-server.js'; " ^
    "  if (Test-Path $mp) { " ^
    "    $sp = $mp -replace '\\\\', '/'; " ^
    "    Write-Host '  Registering MCP server in AI coding tools...' -ForegroundColor Yellow; " ^
    "    try { " ^
    "      $cc = Join-Path $HOME '.claude.json'; " ^
    "      if (Test-Path $cc) { " ^
    "        $cfg = Get-Content $cc -Raw | ConvertFrom-Json; " ^
    "        if (-not $cfg.mcpServers) { $cfg | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{}) -Force }; " ^
    "        $e = [PSCustomObject]@{ type='stdio'; command='node'; args=@($sp) }; " ^
    "        $cfg.mcpServers | Add-Member -NotePropertyName 'patapim-browser' -NotePropertyValue $e -Force; " ^
    "        if ($cfg.mcpServers.PSObject.Properties['frame-browser']) { $cfg.mcpServers.PSObject.Properties.Remove('frame-browser') }; " ^
    "        $cfg | ConvertTo-Json -Depth 20 | Set-Content $cc -Encoding UTF8; " ^
    "        Write-Host '    Claude Code: registered' -ForegroundColor Green " ^
    "      } else { Write-Host '    Claude Code: not installed, skipped' -ForegroundColor DarkGray } " ^
    "    } catch { Write-Host \"    Claude Code: registration failed ($($_.Exception.Message))\" -ForegroundColor Yellow }; " ^
    "    try { " ^
    "      $gd = Join-Path $HOME '.gemini'; " ^
    "      if (Test-Path $gd) { " ^
    "        $gs = Join-Path $gd 'settings.json'; " ^
    "        if (Test-Path $gs) { $cfg = Get-Content $gs -Raw | ConvertFrom-Json } else { $cfg = [PSCustomObject]@{} }; " ^
    "        if (-not $cfg.mcpServers) { $cfg | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{}) -Force }; " ^
    "        $e = [PSCustomObject]@{ command='node'; args=@($sp) }; " ^
    "        $cfg.mcpServers | Add-Member -NotePropertyName 'patapim-browser' -NotePropertyValue $e -Force; " ^
    "        $cfg | ConvertTo-Json -Depth 20 | Set-Content $gs -Encoding UTF8; " ^
    "        Write-Host '    Gemini CLI: registered' -ForegroundColor Green " ^
    "      } else { Write-Host '    Gemini CLI: not installed, skipped' -ForegroundColor DarkGray } " ^
    "    } catch { Write-Host \"    Gemini CLI: registration failed ($($_.Exception.Message))\" -ForegroundColor Yellow }; " ^
    "    try { " ^
    "      $cd = Join-Path $HOME '.codex'; " ^
    "      if (Test-Path $cd) { " ^
    "        $cf = Join-Path $cd 'config.toml'; " ^
    "        $ct = ''; " ^
    "        if (Test-Path $cf) { $ct = Get-Content $cf -Raw }; " ^
    "        if ($ct -notmatch '\[mcp_servers\.patapim-browser\]') { " ^
    "          $ts = \"`n[mcp_servers.patapim-browser]`ncommand = `\"node`\"`nargs = [`\"$sp`\"]`n\"; " ^
    "          $ct = $ct.TrimEnd() + \"`n\" + $ts; " ^
    "          Set-Content $cf -Value $ct -Encoding UTF8; " ^
    "          Write-Host '    Codex CLI: registered' -ForegroundColor Green " ^
    "        } else { Write-Host '    Codex CLI: already registered' -ForegroundColor DarkGray } " ^
    "      } else { Write-Host '    Codex CLI: not installed, skipped' -ForegroundColor DarkGray } " ^
    "    } catch { Write-Host \"    Codex CLI: registration failed ($($_.Exception.Message))\" -ForegroundColor Yellow }; " ^
    "    Write-Host '' " ^
    "  } " ^
    "} catch { " ^
    "  Write-Host \"  Error: $($_.Exception.Message)\" -ForegroundColor Red; " ^
    "  exit 1 " ^
    "}"

:: Self-cleanup
del "%~f0" >nul 2>&1

endlocal
