# Storing current path
$initialPath = Get-Location
# Determines the version
$yagwVersion = "v.1"
$yagwGitPath = Join-Path $PSScriptRoot "/../.git"
if (Test-Path $yagwGitPath) {
    Set-Location $PSScriptRoot
    $yagwVersion = git describe --tags --abbrev=0
    Set-Location $initialPath
}

function Get-Ascii-Art{
    return @"
  _   _  __ _  __ ___      __
 | | | |/ _` |/ _` \ \ /\ / /
 | |_| | (_| | (_| |\ V  V / 
  \__, |\__,_|\__, | \_/\_/  
  |___/       |___/          
"@

}
function App-Name{
    param (
        [Parameter(Mandatory=$true)]
        [string]$version
    )
    return "yagw $yagwVersion - Yet Another Git Watcher"
}

function Show-Help{
    $appName = App-Name $yagwVersion
    $asciiArt = Get-Ascii-Art
    Write-Host @"
$asciiArt
$appName

Options:
  status                It will discover Git repositories, recursively from the basepath, and display their status.
  pull                  Will discover repositories, detect pullables and prompt for confirm before proceeding
  --maxdepth <n>        Max depth of the discovery (default: 4)
  --basepath "<path>"   Starting folder for the discovery (default: .)
  --disable-clear, -d   Prevent the script from clearing the screen
  --no-parallel, -n     Prevent the script from using parallel fetching (only pwsh 7+)
  --dry-run             Prevent the script from using "git pull" (only for yagw pull), instead it will echo the git status for the pullables
  --version, -v         Show the version of yagw
  --help, -h            This
  
You can use config.json or CLI options to change default settings.
!!! CLI Options > config.json > default !!!
"@
}

function Show-Version{
    Write-Host "yagw - $yagwVersion"
}

function Exit-Yagw{
    param (
        [Parameter(Mandatory=$true)]
        [string]$initialPath
    )
    Set-Location $initialPath
    exit
}

function Get-Repo-Status-Desc {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$statusOutput
    )
    $status = "Unmanaged"

    if ($statusOutput -match "Your branch is ahead of") {
        $status = "Ahead Remote"
    } elseif ($statusOutput -match "Your branch is behind") {
        $status = "Behind Remote"
    } elseif ($statusOutput -match "Your branch is up to date with"){
        $status = "Up to date"
    }
    return $status
}

function Get-Repo-Changes-Desc {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$statusOutput
    )
    $changes = "Unmanaged"
    if ($statusOutput -match "Changes not staged for commit") {
        $changes = "Uncommitted changes"
    } elseif ($statusOutput -match "Untracked files") {
        $changes = "Untracked files"
    } elseif ($statusOutput -match "Changes to be committed") {
        $changes = "Staged changes"
    } elseif ($statusOutput -match "merge conflict" -or $statusOutput -match "both modified") {
        $changes = "Merge conflict"
    } elseif ($statusOutput -match "rebase in progress") {
        $changes = "Rebase in progress"
    } elseif ($statusOutput -match "You have unmerged paths") {
        $changes = "Unmerged paths"
    } elseif ($statusOutput -match "Initial commit") {
        $changes = "Initial commit"
    } elseif ($statusOutput -match "nothing to commit, working tree clean") {
        $changes = "Tree clean"
    }
    return $changes
}