<#
.SYNOPSIS
    Windoze image creator.
.DESCRIPTION
    Glamorous shell script to create your very own Windows image.
.PARAMETER Source
    Path of the image that should be altered.
    If not specified, will be prompted interactively.
.PARAMETER Index
    The index of the Windows image that should be altered
    If not specified, will be prompted interactively.
.PARAMETER Name
    The name of the Windows image that should be altered
    If not specified, will be prompted interactively.
.EXAMPLE
    ./windoze.ps1 -s ./my/image.iso -n "Windows 11 Home"
#>
[CmdletBinding(DefaultParametersetName = "Default")]
Param(
    [Parameter(Position = 0)]
    [Alias("S", "Image", "Input")]
    [string]
    $Source = $null,
    [Parameter(ParameterSetName = "ByIndex")]
    [Alias("I", "Index")]
    [uint]
    $ImageIndex = $null,
    [Parameter(ParameterSetName = "ByName")]
    [Alias("N", "Name")]
    [string]
    $ImageName = $null
)

$env:WINDOZE_OSCDIMG = Join-Path ${env:Programfiles(x86)} "Windows Kits/*/Assessment and Deployment Kit/Deployment Tools/*/Oscdimg/oscdimg.exe"

# Load style functions.
. "./style.ps1"

# Load actions.
. "./actions.ps1"

# Print welcome screen.
Write-Output "`nWelcome to the $(Format-Highlight "Windoze") image creator!`n"

# Get source.
do {
    if (-Not $Source) {
        $Source = Read-Input "Enter the path of the image that should be altered."
    }
    $Source = $Source -replace '^"|"$'
    $Source = Resolve-Path $Source

    if (-Not (Test-Path $Source -PathType Leaf)) {
        Write-Fail "The provided path does not contain a file."
        $Source = $null
    }
} until ($Source)
$SourceName = Split-Path $Source -Leaf

$SourceEdit = Join-Path $PWD "disc-images" $SourceName
$ImagePath = Join-Path $SourceEdit "sources/install.wim"
if (Test-Path (Join-Path $SourceEdit "*")) {
    Write-Success "Using existing disc image directory $(Format-Highlight $SourceEdit)."
}
else {
    # Mount source.
    $SourceDisk = Write-Spin "Mounting source $(Format-Highlight $Source)." {
        Mount-DiskImage -ImagePath $using:Source
    }
    $SourceVolume = Get-Volume -DiskImage $SourceDisk
    $SourceDir = "$($SourceVolume.DriveLetter):"
    $SourceBoot = Join-Path $SourceDir "sources/boot.wim"
    $SourceImage = Join-Path $SourceDir "sources/install.wim"

    # Check WIM files.
    if (-Not (Test-Path $SourceBoot)) {
        Write-Fail "Couldn't find Windows boot file $(Format-Secondary $SourceBoot)."
    }
    if (-Not (Test-Path $SourceImage) ) {
        Write-Fail "Couldn't find Windows installation file $(Format-Secondary $SourceImage)."
    }

    # Copy source.
    Write-Spin "Creating disc image directory $(Format-Highlight $SourceEdit)." {
        New-Item $using:SourceEdit -ItemType "Directory"
    } | Out-Null
    Write-Spin "Copying source to disc image directory." {
        Copy-Item (Join-Path $using:SourceDir "*") $using:SourceEdit -Force -Recurse
    }
    Write-Spin "Making disc image directory writable." {
        Get-ChildItem $using:SourceEdit -Recurse -File `
        | ForEach-Object { Set-ItemProperty $_ IsReadOnly $false }
    } | Out-Null

    # Dismount source.
    Write-Spin "Dismounting source $(Format-Highlight $SourceVolume.DriveLetter)." {
        Dismount-DiskImage -InputObject $using:SourceDisk
    } | Out-Null
}


# Get Windows image.
if (-Not $ImageName) {
    $ImageInfo = Write-Spin "Receiving information about the image." {
        Get-WindowsImage -ImagePath $using:ImagePath
    }
    $ImageNames = ($ImageInfo | ForEach-Object { $_.ImageName })

    if ($ImageIndex) {
        $ImageIndexes = ($ImageInfo | ForEach-Object { $_.ImageIndex })
        $ImageName = $ImageNames[$ImageIndexes.IndexOf($ImageIndex)]
    }
    else {
        $ImageName = Read-Choice "Select an image" $ImageNames
    }
}

# Mount Windows image.
$ImageEdit = Join-Path $PWD "windows-images" $SourceName $ImageName
if (Test-Path (Join-Path $ImageEdit "*")) {
    Write-Success "Using existing Windows image directory $(Format-Highlight $ImageEdit)."
}
else {
    Write-Spin "Creating Windows image directory $(Format-Highlight $ImageEdit)." {
        New-Item -Path $using:ImageEdit -ItemType "Directory"
    } | Out-Null
    Write-Spin "Mounting Windows image of $(Format-Highlight $ImageName)." {
        Mount-WindowsImage -Path $using:ImageEdit -ImagePath $using:ImagePath -Name $using:ImageName
    } | Out-Null
}

$Actions = "Select features", "Remove preinstalled apps", "Remove system packages", "Save & exit", "Discard & exit", "Exit"
while ($true) {
    $Action = Read-Choice "Select an action." $Actions
    switch ($Action) {
        "Select features" { Start-SelectFeatures $ImageEdit }
        "Remove preinstalled apps" { Start-RemoveAppxPackages $ImageEdit }
        "Remove system packages" { Start-RemoveSystemPackages $ImageEdit }
        "Save & exit" { Start-Save $ImageEdit; exit 0 }
        "Discard & exit" { Start-Discard $ImageEdit; exit 0 }
        "Exit" { exit 0 }
    }
}