. "$PSScriptRoot\lib\functions.ps1"
try{
    $asciiArt = Get-Ascii-Art
    Write-host $asciiArt
    $appName = App-Name $yagwVersion
    Write-host "Installing $appName..."
    # Default values
    $basePath = "."
    $maxDepth = 4
    $excludedFolders = @()
    $enableClearScreen= $true
    $noParallel=$false
    $executePull=$false
    $executeStatus=$false
    $exit=$false

    # Check pwsh version
    $psMajorVersion = $PSVersionTable.PSVersion.Major
    $isPwshLegacy = $psMajorVersion -lt 6
    if($isPwshLegacy){
        Write-Host "Powershell $psMajorVersion - yagw will work but please consider using Powershell 7 or higher for better performances" -ForegroundColor Yellow
    }
    
    # Checks if git is installed
    try {
        git --version | Out-Null
    } catch {
        throw "Git not found, please install it before proceeding"
    }

    Write-Host ""
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (Test-Path $configPath) {
        Write-Host("> config.json found...") -ForegroundColor Cyan
    }else{
        Write-Host("> Creating config.json") -ForegroundColor Cyan
        Copy-Item "config.json-example" "config.json"
    }

    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    $scriptPath = Join-Path $PSScriptRoot "\yagw.ps1"
    Add-Content $PROFILE "Set-Alias yagw '$scriptPath'"
    Write-Host("> Adding 'yagw' command as alias for Powershell $psMajorVersion...") -ForegroundColor Cyan
    Write-Host "> If it's not the first time you run this installation please check for duplicates your profile with: notepad `$PROFILE"

    Write-Host("Install Successful") -ForegroundColor Green
}catch{
    Write-Host "Graceful Exception: $_" -ForegroundColor Red
}