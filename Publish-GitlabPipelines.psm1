Function Test-Command{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $CmdName
    )
    If (Get-Command $CmdName -errorAction SilentlyContinue) { Return $true } Else { Return $false }
}

Function Test-FileInSubPath{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.IO.DirectoryInfo] $Directory,
        [Parameter(Mandatory=$true, Position=1)]
        [System.IO.FileInfo] $File
    )

    $File.FullName.StartsWith($Directory.FullName)
}

Function Test-FilesInSubPath{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.IO.DirectoryInfo] $Directory,
        [Parameter(Mandatory=$true, Position=1)]
        [System.IO.FileInfo[]] $Files
    )

    $isInPath = $false
    foreach ($file in $Files) {
        $isInPath = Test-FileInSubPath -Directory $Directory -File $file
        If ($true -Eq $isInPath) { Return $true };
    }

    Return $false
}

Function Test-Projects{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.IO.DirectoryInfo[]] $Directories,
        [Parameter(Mandatory=$true, Position=1)]
        [System.IO.FileInfo[]] $Files
    )
    $changedProjects = @()

    foreach ($dir in $Directories) {
        If (-Not (Test-FilesInSubPath -Directory $dir -Files $Files)) { Continue }
        If ($changedProjects -Contains $dir) { Continue };

        $changedProjects += $dir
    }

    Return $changedProjects
}

Function Get-Changes{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $RootDir
    )

    $changes = @()
    $rawChanges = git diff --name-only
    
    foreach ($change in $rawChanges)
    {
        $detail = [PSCustomObject]@{
            Value = $change
            Path = Get-Item $change
            Child = Get-ChildItem -Directory (Convert-Path $change)
        }
        
        $changes += $detail
    }

    Return $changes | Where-Object Value -Match "$RootDir*"   
}

Function Write-Pipeline{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.IO.DirectoryInfo[]] $Projects,
        [Parameter(Position=1)]
        [string] $RootDir,
        [Parameter(Position=2)]
        [string[]] $Commands,
        [Parameter(Position=3)]
        [string] $Image
    )

    $yaml = @"
stages:
  - release

.release-base:
  interruptible: false
  allow_failure: false
  retry:
    max: 2
    when: 
    - runner_system_failure

"@

    foreach ($project in $projects) {
        $projectName = $project | Split-Path -Leaf
        $imageTag = If ($null -Eq $Image -Or "" -Eq $Image) { "" } Else { "`r`n  image: $Image" }
        $jobScript = ""

        foreach ($command in $Commands) {
            $sanitisedCommand = $command -Replace "__PROJECT_PATH__", "$RootDir/$projectName"
            $jobScript += "    - $sanitisedCommand`r`n"
        }

        $job = @"

release-$($projectName):
  extends: .release-base$imageTag
  stage: release
  variables:
    PROJECT_NAME: $projectName 
  script:
    - echo $projectName 
$jobScript
"@
        $yaml = $yaml + $job
    }

    $yaml | Out-File -FilePath ./release-gitlab-ci.yml
}

Function Publish-GitlabPipelines{
    Param(
        [Parameter(Position=0)]
        [string] $RootDir,
        [Parameter(Position=1)]
        [string[]] $Commands,
        [Parameter(Position=2)]
        [string] $Image
    )

    Write-Host "Checking for system dependencies"
    If (-Not (Test-Command -CmdName git)) {
        Write-Host "Git is not installed"
        Exit -1
    }

    Write-Host "Finding changes"
    $targetPath = If ($null -Eq $RootDir) { "./" } Else { $RootDir }
    $targetPath = If ($targetPath.StartsWith("./")) { $targetPath } Else { "./" + $targetPath }
    $changes = Get-Changes -RootDir $RootDir
    [System.IO.FileInfo[]] $changedFiles = $changes.Path
    [System.IO.DirectoryInfo[]]$projects = Get-ChildItem -Directory $targetPath

    $changedProjects = Test-Projects -Directories $projects -Files $changedFiles

    Write-Host "Generating pipeline yaml"
    Write-Pipeline -Projects $changedProjects -Commands $Commands -Image $Image -RootDir $RootDir
}   

Export-ModuleMember -Function 'Publish-GitlabPipelines'
