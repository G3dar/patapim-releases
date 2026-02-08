# PATAPIM Installer for Windows PowerShell
# Usage: irm https://raw.githubusercontent.com/G3dar/patapim-releases/main/install.ps1 | iex
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ____   _  _____  _   ____ ___ __  __ " -ForegroundColor Cyan
Write-Host " |  _ \ / \|_   _|/ \ |  _ \_ _|  \/  |" -ForegroundColor Cyan
Write-Host " | |_) / _ \ | | / _ \| |_) | || |\/| |" -ForegroundColor Cyan
Write-Host " |  __/ ___ \| |/ ___ \  __/| || |  | |" -ForegroundColor Cyan
Write-Host " |_| /_/   \_\_/_/   \_\_| |___|_|  |_|" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project Management IDE for Claude Code" -ForegroundColor DarkGray
Write-Host ""

$repo = "G3dar/patapim-releases"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

Write-Host "  Fetching latest release..." -ForegroundColor Yellow

try {
    $release = Invoke-RestMethod -Uri $apiUrl -Headers @{
        "User-Agent" = "PATAPIM-Installer"
        "Accept"     = "application/vnd.github.v3+json"
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  Error: No releases found." -ForegroundColor Red
        Write-Host "  Visit https://github.com/$repo/releases for updates." -ForegroundColor Red
    } else {
        Write-Host "  Error: Could not connect to GitHub." -ForegroundColor Red
        Write-Host "  Check your internet connection and try again." -ForegroundColor Red
    }
    exit 1
}

$version = $release.tag_name
Write-Host "  Found version: $version" -ForegroundColor Green

# Find the Windows installer (.exe NSIS installer)
$asset = $release.assets | Where-Object {
    $_.name -match "\.exe$" -and $_.name -match "win"
} | Select-Object -First 1

if (-not $asset) {
    # Fallback: try any .exe
    $asset = $release.assets | Where-Object {
        $_.name -match "\.exe$"
    } | Select-Object -First 1
}

if (-not $asset) {
    Write-Host "  Error: No Windows installer found in this release." -ForegroundColor Red
    Write-Host "  Available assets:" -ForegroundColor Red
    $release.assets | ForEach-Object { Write-Host "    - $($_.name)" -ForegroundColor DarkGray }
    exit 1
}

$downloadUrl = $asset.browser_download_url
$fileName = $asset.name
$fileSize = [math]::Round($asset.size / 1MB, 1)
$tempPath = Join-Path $env:TEMP $fileName

Write-Host "  Downloading $fileName ($fileSize MB)..." -ForegroundColor Yellow

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing
} catch {
    Write-Host "  Error: Download failed." -ForegroundColor Red
    exit 1
}

Write-Host "  Running installer..." -ForegroundColor Yellow
Write-Host ""

$process = Start-Process -FilePath $tempPath -Wait -PassThru

# Cleanup
Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue

if ($process.ExitCode -eq 0) {
    Write-Host ""
    Write-Host "  PATAPIM $version installed successfully!" -ForegroundColor Green
    Write-Host ""

    # --- MCP Registration ---
    # Detect installed PATAPIM path and register MCP server in AI coding tools
    $patapimPath = Join-Path $env:LOCALAPPDATA "Programs\PATAPIM\resources\app\src\mcp\patapim-browser-server.js"
    if (-not (Test-Path $patapimPath)) {
        # Fallback: try common install path
        $patapimPath = Join-Path $env:LOCALAPPDATA "Programs\patapim\resources\app\src\mcp\patapim-browser-server.js"
    }

    if (Test-Path $patapimPath) {
        $mcpServerPath = $patapimPath -replace '\\', '/'
        Write-Host "  Registering MCP server in AI coding tools..." -ForegroundColor Yellow

        # Claude Code: ~/.claude.json
        try {
            $claudeConfig = Join-Path $HOME ".claude.json"
            if (Test-Path $claudeConfig) {
                $cfg = Get-Content $claudeConfig -Raw | ConvertFrom-Json
                if (-not $cfg.mcpServers) {
                    $cfg | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
                }
                $entry = [PSCustomObject]@{ type = "stdio"; command = "node"; args = @($mcpServerPath) }
                $cfg.mcpServers | Add-Member -NotePropertyName "patapim-browser" -NotePropertyValue $entry -Force
                # Remove stale frame-browser
                if ($cfg.mcpServers.PSObject.Properties["frame-browser"]) {
                    $cfg.mcpServers.PSObject.Properties.Remove("frame-browser")
                }
                $cfg | ConvertTo-Json -Depth 20 | Set-Content $claudeConfig -Encoding UTF8
                Write-Host "    Claude Code: registered" -ForegroundColor Green
            } else {
                Write-Host "    Claude Code: not installed, skipped" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    Claude Code: registration failed ($($_.Exception.Message))" -ForegroundColor Yellow
        }

        # Gemini CLI: ~/.gemini/settings.json
        try {
            $geminiDir = Join-Path $HOME ".gemini"
            if (Test-Path $geminiDir) {
                $geminiSettings = Join-Path $geminiDir "settings.json"
                if (Test-Path $geminiSettings) {
                    $cfg = Get-Content $geminiSettings -Raw | ConvertFrom-Json
                } else {
                    $cfg = [PSCustomObject]@{}
                }
                if (-not $cfg.mcpServers) {
                    $cfg | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
                }
                $entry = [PSCustomObject]@{ command = "node"; args = @($mcpServerPath) }
                $cfg.mcpServers | Add-Member -NotePropertyName "patapim-browser" -NotePropertyValue $entry -Force
                $cfg | ConvertTo-Json -Depth 20 | Set-Content $geminiSettings -Encoding UTF8
                Write-Host "    Gemini CLI: registered" -ForegroundColor Green
            } else {
                Write-Host "    Gemini CLI: not installed, skipped" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    Gemini CLI: registration failed ($($_.Exception.Message))" -ForegroundColor Yellow
        }

        # Codex CLI: ~/.codex/config.toml
        try {
            $codexDir = Join-Path $HOME ".codex"
            if (Test-Path $codexDir) {
                $codexConfig = Join-Path $codexDir "config.toml"
                $content = ""
                if (Test-Path $codexConfig) {
                    $content = Get-Content $codexConfig -Raw
                }
                if ($content -notmatch '\[mcp_servers\.patapim-browser\]') {
                    $tomlSection = "`n[mcp_servers.patapim-browser]`ncommand = `"node`"`nargs = [`"$mcpServerPath`"]`n"
                    $content = $content.TrimEnd() + "`n" + $tomlSection
                    Set-Content $codexConfig -Value $content -Encoding UTF8
                    Write-Host "    Codex CLI: registered" -ForegroundColor Green
                } else {
                    Write-Host "    Codex CLI: already registered" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "    Codex CLI: not installed, skipped" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    Codex CLI: registration failed ($($_.Exception.Message))" -ForegroundColor Yellow
        }

        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "  Installation may have been cancelled." -ForegroundColor Yellow
    Write-Host ""
}
