. "$PSScriptRoot\lib\functions.ps1"

# Stopwatch
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try{
    # Default values
    $basePath = "."
    $maxDepth = 4
    $excludedFolders = @()
    $enableClearScreen= $true
    $noParallel=$false
    $executePull=$false
    $executeStatus=$false
    $exit=$false
    $pullDryRun=$false
    # Check pwsh version
    $psMajorVersion = $PSVersionTable.PSVersion.Major
    $isPwshLegacy = $psMajorVersion -lt 6

    # Checks if git is installed
    try {
        git --version | Out-Null
    } catch {
        Exit-Yagw $initialPath
    }
    $appName = App-Name $yagwVersion
    # Config values
    $configPath = Join-Path $PSScriptRoot "config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-json

        $basePath        = $config.basePath
        $maxDepth        = $config.maxDepth
        $excludedFolders = $config.excludedFolders
        $enableClearScreen = $config.enableClearScreen
        $noParallel = $config.noParallel
    }

    if($args.Count -eq 0) { Show-Help ; $exit = $true }
    # Input argument Parsing
    for ($i = 0; $i -lt $args.Count; $i++) {
        # Write-Host "Selected choice $args[$i]"
        switch ($args[$i]) {
            "--maxdepth" {
                $maxDepth = [int]$args[$i + 1]
                $i++
            }
            "--basepath" {
                $basePath = $args[$i + 1]
                $i++
            }
            "pull" { $executePull=$true }
            "status" { $executeStatus=$true }
            "--disable-clear-screen" { $enableClearScreen = $false }
            "-d" { $enableClearScreen = $false }
            "--no-parallel" { $noParallel = $true }
            "-n" { $noParallel = $true }
            "--help" { Show-Help ; $exit = $true }
            "-h" { Show-Help ; $exit = $true }
            "--version" { Show-Version ; $exit = $true }
            "-v" { Show-Version ; $exit = $true }
            "--dry-run" { $pullDryRun=$true }
            default { 
                throw "Unknown option/s"
            }
        }
    }

    if(($executePull -and $executeStatus) -or
        ($executeStatus -and $pullDryRun)){
        throw "Invalid option combination"
    }
    if($exit){
        Exit-Yagw $initialPath
    }       
    
    if($enableClearScreen) { 
        Clear-Host
    }    
    Write-Host $appName -ForegroundColor Cyan  
    
    if($isPwshLegacy) {
        Write-Host "Powershell $psMajorVersion - Script running in Legacy Mode please consider using Powershell 7 or higher for better performances" -ForegroundColor Yellow
    }

    Set-Location $basePath

    $absolutePath = Get-Location

    if($maxDepth -gt 6){
        throw "Maxdepth $maxDepth too high"
    }

    Write-Host "Discovering Repos..."
    if($isPwshLegacy) {
        # -ErrorAction SilentlyContinue compatibility with legacy
        $repos = Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
            $folderName = $_.Name
            $isSymlink = $_.Attributes -match "ReparsePoint"
            $isExcluded = $excludedFolders -contains $folderName
            $isGitRepo = Test-Path "$($_.FullName)\.git"
            $relativePath = $_.FullName.Substring($absolutePath.Path.Length)

            -not $isSymlink -and -not $isExcluded -and $isGitRepo -and ($relativePath.Split('\').Count -le $maxDepth)
        }
    }else{
        $repos = Get-ChildItem -Recurse -Directory -Depth ( $maxDepth - 2 ) | Where-Object {
            $folderName = $_.Name
            $isSymlink = $_.Attributes -match "ReparsePoint"
            $isExcluded = $excludedFolders -contains $folderName
            $isGitRepo = Test-Path "$($_.FullName)\.git"
            $relativePath = $_.FullName.Substring($absolutePath.Path.Length)

            -not $isSymlink -and -not $isExcluded -and $isGitRepo
        } | ForEach-Object {
            # We inject the absPath for the parallel mode
            $_ | Select-Object *, @{Name="AbsolutePath"; Expression={$absolutePath}}
        }

    }
    # Write-Host $repos
    # exit
    $data = New-Object System.Collections.Generic.List[object]
    $pullables = New-Object System.Collections.Generic.List[object]

    # Write-Host "noparallel" $noParallel
    # Write-Host "isPwshLegacy" $isPwshLegacy
    if($isPwshLegacy -or $noParallel){
        # Legacy
        foreach ($repo in $repos) {
            $repoPath = $repo.FullName
            Write-Host "Watching $repoPath"

            Set-Location $repoPath

            git fetch > $null 2>&1

            $repoName = Split-Path -Leaf (git rev-parse --show-toplevel)
            $currentBranch = git rev-parse --abbrev-ref HEAD

            $statusOutput = git status
            
            $status = Get-Repo-Status-Desc $statusOutput

            $changes = Get-Repo-changes-Desc $statusOutput

            $pullable="-"
            if ($statusOutput -match "Your branch is behind" -and $statusOutput -match "nothing to commit, working tree clean") {
                $pullable=$true;
                $pullables.Add([PSCustomObject]@{
                "Path"="."+$repoPath.Substring($absolutePath.Path.Length); "Name"=$repoName; "Current Branch"=$currentBranch;
                "Branch status"=$status; "Changes"=$changes; "Pullable"=$pullable})
            }
            $data.Add([PSCustomObject]@{
                "Path"="."+$repoPath.Substring($absolutePath.Path.Length); "Name"=$repoName; "Current Branch"=$currentBranch;
                "Branch status"=$status; "Changes"=$changes; "Pullable"=$pullable})

            Set-Location $absolutePath
        }
    }else{
        Write-Host "Watching Repos..."
        $results = $repos | ForEach-Object -Parallel {

            $repoPath = $_.FullName
            $absolutePath = $_.absolutePath
            Set-Location $repoPath

            git fetch > $null 2>&1
            $repoName = Split-Path -Leaf (git rev-parse --show-toplevel)
            $currentBranch = git rev-parse --abbrev-ref HEAD
            $statusOutput = git status

            # Functions not applicable here because of context of parallel
            $status = if ($statusOutput -match "Your branch is ahead of") {
                "Ahead Remote"
            } elseif ($statusOutput -match "Your branch is behind") {
                "Behind Remote"
            } elseif ($statusOutput -match "Your branch is up to date with") {
                "Up to date"
            } else {
                "Unmanaged"
            }

            $changes = if ($statusOutput -match "Changes not staged for commit") {
                "Uncommitted changes"
            } elseif ($statusOutput -match "Untracked files") {
                "Untracked files"
            } elseif ($statusOutput -match "Changes to be committed") {
                "Staged changes"
            } elseif ($statusOutput -match "merge conflict" -or $statusOutput -match "both modified") {
                "Merge conflict"
            } elseif ($statusOutput -match "rebase in progress") {
                "Rebase in progress"
            } elseif ($statusOutput -match "You have unmerged paths") {
                "Unmerged paths"
            } elseif ($statusOutput -match "Initial commit") {
                "Initial commit"
            } elseif ($statusOutput -match "nothing to commit, working tree clean") {
                "Tree clean"
            } else {
                "Unmanaged"
            }

            $pullable = "-"
            if ($statusOutput -match "Your branch is behind" -and $statusOutput -match "nothing to commit, working tree clean") {
                $pullable = $true
            }

            Set-Location $absolutePath

            return [PSCustomObject]@{
                Path="."+$repoPath.Substring($absolutePath.Path.Length)
                # AbsPath="."+$absolutePath
                Name = $repoName
                "Current Branch" = $currentBranch
                "Branch status" = $status
                Changes = $changes
                Pullable = $pullable
            }

        }
        $data = $results
        $pullables = $data | Where-Object { $_.Pullable -eq $true }
    }

    if ($data.Count -eq 0) {
        Write-Host "No repositories found while searching with depth $maxDepth in $absolutePath" -ForegroundColor Yellow
    } else {
        if($enableClearScreen) { 
            Clear-Host
            Write-Host $appName -ForegroundColor Cyan  
            Write-Host "Repositories" -ForegroundColor Green
        }
        # Order by path
        $data = $data | Sort-Object -Property Path
        # Table
        $output = $data | Format-Table -AutoSize | Out-String
        # Colors
        $c=0
        $output -split "`n" | ForEach-Object {
            if($c -le 2 -or -not ($_ -match "Behind Remote") ) {
                Write-Host $_
            } else {
                Write-Host $_ -ForegroundColor Yellow
            }
            $c++
        }
        
        $stopwatch.Stop()
        Write-Host $data.Count "repositories found while discovering with depth $maxDepth in $absolutePath in $($stopwatch.Elapsed.TotalSeconds) seconds" -ForegroundColor Green

        if($executePull){
            if($pullables.Count -gt 0){
                Write-Host "Pulls requested"
                if($pullDryRun){
                    Write-Host "Dry run, no 'git pull' command will be executed" -ForegroundColor Cyan
                }else{
                    Write-Host "Are you sure to execute git pull in repositories with pullable=true? (Y/n)" -ForegroundColor Red
                    $confirm = Read-Host
                }

                if ($confirm -eq "Y" -or $pullDryRun) {
                    # Write-Host "Proceeding..."
                    foreach ($p in $pullables) {
                        Set-Location $p.path
                        if($pullDryRun){
                            Write-Host "===>" $p.Path"> git status" -ForegroundColor Blue
                            git status
                        }else{
                            Write-Host "===>" $p.Path"> git pull" -ForegroundColor Yellow
                            git pull
                        }
                        Set-Location $absolutePath
                    }
                } else {
                    Write-Host "Pulls aborted."
                }
            }else{
                Write-Host "Pulls requested but there are no pullable repos." -ForegroundColor Yellow
            }
        }
    }
}catch{
    Write-Host "Graceful Exception: $_" -ForegroundColor Red
}finally{
    # Falling back to cwd
    Set-Location $initialPath
    $stopwatch.Stop()
}