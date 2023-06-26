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

$env:WINDOZE_OSCDIMG = Join-Path ${env:Programfiles(x86)} "Windows Kits" "*" "Assessment and Deployment Kit" "Deployment Tools" "*" "Oscdimg"

# Load style functions.
. "./style.ps1"

# Print welcome screen.
Write-Output "`nWelcome to the $(Format-Highlight "Windoze") image creator!`n"

# Get source.
do {
    if (-Not $Source) {
        $Source = Read-Input "Enter the path of the image that should be altered."
    }
    $Source = $Source -replace '^"|"$'

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

while ($true) {
    $Action = Read-Choice "Select an action." "Select features", "Save & Exit", "Discard & Exit", "Exit"
    switch ($Action) {
        "Select features" {
            $Features = Write-Spin "Getting features." {
                Get-WindowsOptionalFeature -Path $using:ImageEdit
            }
            $Selected = $Features | Where-Object { $_.State -eq "Enabled" }
            $FeatureNames = $Features | ForEach-Object { $_.FeatureName }
        
            $Choices = Read-Choice "Select features." $FeatureNames $Features -Multiple -S $Selected
            Write-Spin "Updating features." {
                foreach ($Feature in $using:Features) {
                    if ($Feature.State -eq "Disabled" -and $using:Choices -contains $Feature) {
                        Enable-WindowsOptionalFeature -Path $using:ImageEdit -FeatureName $Feature.FeatureName -All
                    }
                    elseif ($Feature.Stae -eq "Enabled" -and $using:Choices -notcontains $Feature) {
                        Disable-WindowsOptionalFeature -Path $using:ImageEdit -FeatureName $Feature.FeatureName -All
                    }
                }
            } | Out-Null
        }
        "Save & Exit" {
            Write-Spin "Saving changes to $(Format-Highlight "windows image")." {
                Dismount-WindowsImage -Path $using:ImageEdit -Save
            } | Out-Null
            if (-Not (Test-Path $env:WINDOZE_OSCDIMG)) {
                Write-Fail "Couldn't find Oscdimg tool."
                $Method = Read-Choice "Select where to get the Oscdimg tool from." "Local path", "Winget"
                switch ($Method) {
                    "Local path" {
                        $env:WINDOZE_OSCDIMG = Read-Input "Enter the folder containing the Oscdimg tools."
                    }
                    "Winget" {
                        Write-Spin "Installing the $(Format-Highlight "Windows ADK")." {
                            winget.exe install Microsoft.WindowsADK
                        } | Out-Null
                    }
                }
            }
            $SavePath = Read-Input "Enter the path to save the altered disc image at." 
            $OscdimgPath = (Join-Path $env:WINDOZE_OSCDIMG "oscdimg.exe" | Resolve-Path)[0]
            $EtfsbootPath = Join-Path $SourceEdit "boot" "etfsboot.com"
            $EfisysPath = Join-Path $SourceEdit "efi" "microsoft" "boot" "efisys.bin"
            Write-Spin "Saving changes to disc image at $(Format-Highlight $SavePath)." {
                & $using:OscdimgPath -m -o -u2 -udfver102 `
                    -bootdata:2`#p0, e, b$using:EtfsbootPath`#pEF, e, b$using:EfisysPath `
                    $using:SourceEdit $using:SavePath
            } | Out-Null
            Write-Spin "Deleting disc image directory." {
                Remove-Item -Recurse -Force $using:SourceEdit
            } | Out-Null
            exit 0
        }
        "Discard & Exit" {
            Write-Spin "Discarding changes to windows image." {
                Dismount-WindowsImage -Path $using:ImageEdit -Discard
            } | Out-Null
            Write-Spin "Discarding changes to disc image." {
                Remove-Item -Recurse -Force $using:SourceEdit
            } | Out-Null
            exit 0 
        }
        "Exit" { exit 0 }
    }
}