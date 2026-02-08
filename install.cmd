@echo off
:: PATAPIM Installer for Windows CMD
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
    "  $r = Invoke-RestMethod 'https://api.github.com/repos/G3dar/patapim-releases/releases/latest' -Headers @{'User-Agent'='PATAPIM-Installer'}; " ^
    "  $v = $r.tag_name; " ^
    "  Write-Host \"  Found version: $v\"; " ^
    "  $a = $r.assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1; " ^
    "  if (-not $a) { Write-Host '  Error: No installer found.' -ForegroundColor Red; exit 1 }; " ^
    "  $f = Join-Path $env:TEMP $a.name; " ^
    "  $mb = [math]::Round($a.size / 1MB, 1); " ^
    "  Write-Host \"  Downloading $($a.name) ($mb MB)...\"; " ^
    "  Invoke-WebRequest $a.browser_download_url -OutFile $f -UseBasicParsing; " ^
    "  Write-Host '  Running installer...'; " ^
    "  $p = Start-Process $f -Wait -PassThru; " ^
    "  Remove-Item $f -Force -ErrorAction SilentlyContinue; " ^
    "  if ($p.ExitCode -eq 0) { " ^
    "    Write-Host ''; Write-Host \"  PATAPIM $v installed successfully!\" -ForegroundColor Green; Write-Host ''; " ^
    "    $mp = Join-Path $env:LOCALAPPDATA 'Programs\PATAPIM\resources\app\src\mcp\patapim-browser-server.js'; " ^
    "    if (-not (Test-Path $mp)) { $mp = Join-Path $env:LOCALAPPDATA 'Programs\patapim\resources\app\src\mcp\patapim-browser-server.js' }; " ^
    "    if (Test-Path $mp) { " ^
    "      $sp = $mp -replace '\\\\', '/'; " ^
    "      Write-Host '  Registering MCP server in AI coding tools...' -ForegroundColor Yellow; " ^
    "      try { " ^
    "        $cc = Join-Path $HOME '.claude.json'; " ^
    "        if (Test-Path $cc) { " ^
    "          $cfg = Get-Content $cc -Raw | ConvertFrom-Json; " ^
    "          if (-not $cfg.mcpServers) { $cfg | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{}) -Force }; " ^
    "          $e = [PSCustomObject]@{ type='stdio'; command='node'; args=@($sp) }; " ^
    "          $cfg.mcpServers | Add-Member -NotePropertyName 'patapim-browser' -NotePropertyValue $e -Force; " ^
    "          if ($cfg.mcpServers.PSObject.Properties['frame-browser']) { $cfg.mcpServers.PSObject.Properties.Remove('frame-browser') }; " ^
    "          $cfg | ConvertTo-Json -Depth 20 | Set-Content $cc -Encoding UTF8; " ^
    "          Write-Host '    Claude Code: registered' -ForegroundColor Green " ^
    "        } else { Write-Host '    Claude Code: not installed, skipped' -ForegroundColor DarkGray } " ^
    "      } catch { Write-Host \"    Claude Code: registration failed ($($_.Exception.Message))\" -ForegroundColor Yellow }; " ^
    "      try { " ^
    "        $gd = Join-Path $HOME '.gemini'; " ^
    "        if (Test-Path $gd) { " ^
    "          $gs = Join-Path $gd 'settings.json'; " ^
    "          if (Test-Path $gs) { $cfg = Get-Content $gs -Raw | ConvertFrom-Json } else { $cfg = [PSCustomObject]@{} }; " ^
    "          if (-not $cfg.mcpServers) { $cfg | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{}) -Force }; " ^
    "          $e = [PSCustomObject]@{ command='node'; args=@($sp) }; " ^
    "          $cfg.mcpServers | Add-Member -NotePropertyName 'patapim-browser' -NotePropertyValue $e -Force; " ^
    "          $cfg | ConvertTo-Json -Depth 20 | Set-Content $gs -Encoding UTF8; " ^
    "          Write-Host '    Gemini CLI: registered' -ForegroundColor Green " ^
    "        } else { Write-Host '    Gemini CLI: not installed, skipped' -ForegroundColor DarkGray } " ^
    "      } catch { Write-Host \"    Gemini CLI: registration failed ($($_.Exception.Message))\" -ForegroundColor Yellow }; " ^
    "      try { " ^
    "        $cd = Join-Path $HOME '.codex'; " ^
    "        if (Test-Path $cd) { " ^
    "          $cf = Join-Path $cd 'config.toml'; " ^
    "          $ct = ''; " ^
    "          if (Test-Path $cf) { $ct = Get-Content $cf -Raw }; " ^
    "          if ($ct -notmatch '\[mcp_servers\.patapim-browser\]') { " ^
    "            $ts = \"`n[mcp_servers.patapim-browser]`ncommand = `\"node`\"`nargs = [`\"$sp`\"]`n\"; " ^
    "            $ct = $ct.TrimEnd() + \"`n\" + $ts; " ^
    "            Set-Content $cf -Value $ct -Encoding UTF8; " ^
    "            Write-Host '    Codex CLI: registered' -ForegroundColor Green " ^
    "          } else { Write-Host '    Codex CLI: already registered' -ForegroundColor DarkGray } " ^
    "        } else { Write-Host '    Codex CLI: not installed, skipped' -ForegroundColor DarkGray } " ^
    "      } catch { Write-Host \"    Codex CLI: registration failed ($($_.Exception.Message))\" -ForegroundColor Yellow }; " ^
    "      Write-Host '' " ^
    "    } " ^
    "  } " ^
    "  else { Write-Host ''; Write-Host '  Installation may have been cancelled.' -ForegroundColor Yellow }; " ^
    "} catch { " ^
    "  Write-Host '  Error: Could not fetch release. Check your internet connection.' -ForegroundColor Red; " ^
    "  exit 1 " ^
    "}"

:: Self-cleanup
del "%~f0" >nul 2>&1

endlocal
