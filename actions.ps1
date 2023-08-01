function Start-Features (
    [Parameter(Mandatory, Position = 0)]
    [string]$ImageEdit
) {
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

function Start-Save (
    [Parameter(Mandatory, Position = 0)]
    [string]$ImageEdit,
    [Parameter(Position = 1)]
    [string]$OscdimgPath
) {
    Write-Spin "Saving changes to $(Format-Highlight "Windows image")." {
        Dismount-WindowsImage -Path $using:ImageEdit -Save
    } | Out-Null
    
    while (-Not (Test-Path $OscdimgPath -PathType Container)) {
        Write-Fail "Couldn't find Oscdimg tool."
        $OscdimgPath = Get-Oscdimg
    }
    $OscdimgPath = (Resolve-Path $OscdimgPath)[0]

    $SavePath = Read-Input "Enter the path to save the altered disc image at."
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

function Get-Oscdimg {
    $Method = Read-Choice "Select where to get the Oscdimg tool from." "Local path", "Winget"
    switch ($Method) {
        "Local path" {
            return (Read-Input "Enter the folder containing the Oscdimg tools.") -replace '^"|"$'
        }
        "Winget" {
            Write-Spin "Installing the $(Format-Highlight "Windows ADK")." {
                winget.exe install Microsoft.WindowsADK
            } | Out-Null
            return Join-Path ${env:Programfiles(x86)} "Windows Kits/*/Assessment and Deployment Kit/Deployment Tools/*/Oscdimg/oscdimg.exe"
        }
    }
}

function Start-Discard (
    [Parameter(Mandatory, Position = 0)]
    [string]$ImageEdit
) {
    Write-Spin "Discarding changes to windows image." {
        Dismount-WindowsImage -Path $using:ImageEdit -Discard
    } | Out-Null
    Write-Spin "Discarding changes to disc image." {
        Remove-Item -Recurse -Force $using:SourceEdit
    } | Out-Null
    exit 0 
}