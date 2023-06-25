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

$env:WINDOZE_HIGHLIGHT ??= 12
$env:WINDOZE_SECONDARY ??= 8
$env:WINDOZE_SUCCESS ??= 10
$env:WINDOZE_FAIL ??= 9

<#
.DESCRIPTION
    Formats a list of arguments into an ANSI code.
.PARAMETER Arguments
    The list of arguments to format.
.PARAMETER Command
    The command to use.
    Defaults to Select Graphic Rendition.
#>
function Format-Ansi(
    [Parameter(Mandatory, Position = 0)]
    [char]
    $Command,
    [Parameter(Position = 1)]
    [string[]]
    $Arguments = @()
) {
    return "$([char]27)[$($Arguments -join ";")$Command"
}

<#
.DESCRIPTION
    Apply coloring to text.
.PARAMETER Text
    The text to style.
.PARAMETER Foreground
    The color of the text.
.PARAMETER Background
    The color of the background.
#>
function Format-Color(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]
    $Text,
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("F")]
    [ushort]
    $Foreground,
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias("B")]
    [ushort]
    $Background
) {
    $Arguments = (
        $(if ($Foreground -is [ushort]) { 38, 5, $Foreground } else { @() }) + `
        $(if ($Foreground -is [ushort]) { 38, 5, $Foreground } else { @() })
    )
    return $Arguments.Length ? "$(Format-Ansi "m" $Arguments)$Text$(Format-Ansi "m" 0)" : "$Text"
}


<#
.DESCRIPTION
    Removes the previous lines.
.PARAMETER Amount
    The amount of lines to remove.
    Defaults to 1.
#>
function Remove-Lines(
    [Parameter(Position = 0)]
    $Amount = 1
) {
    Write-Host -NoNewline "$(Format-Ansi "F" $Amount)$(Format-Ansi "J")"
}

<#
.DESCRIPTION
    Play a spinning animation while executing a script.
.PARAMETER Title
    The text to display while executing the job.
.PARAMETER Script
    The script to execute.
.PARAMETER Color
    The highlight color of the spinner.
    Defaults to $env:WINDOZE_HIGHLIGHT.
#>
function Write-Spin(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]
    $Text,
    [Parameter(Mandatory, Position = 1)]
    [Alias("S")]
    [scriptblock]
    $Script,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_HIGHLIGHT
) {
    $Frames = "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"
    $Frame = 0
    $Job = Start-Job -ScriptBlock $Script

    $CursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    while ($Job.State -eq "Running") {
        $Frame = ($Frame + 1) % $Frames.Length
        Write-Status -NoNewLine "$Text`r" $Frames[$Frame] -C $Color
        Start-Sleep 0.04
    }
    if ($Job.Error) { Write-Fail $Text } else { Write-Success $Text }
    [Console]::CursorVisible = $CursorVisible

    $Result = Receive-Job $Job
    Remove-Job -Job $Job
    if ($Job.Error) { throw $Job.Error }

    return $Result
}

<#
.DESCRIPTION
    Format a status.
.PARAMETER Text
    The text of the status.
.PARAMETER Status
    The status to prepend.
.PARAMETER Color
    The color to use for the status.
    Defaults to $env:WINDOZE_HIGHLIGHT.
#>
function Write-Status(
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Text,
    [Parameter(Mandatory, Position = 1)]
    [Alias("S")]
    [string]
    $Status,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_HIGHLIGHT,
    [switch]
    $NoNewLine
) {
    Write-Host "$(Format-Color $Status -F $Color) $Text" -NoNewline:$NoNewLine
}

<#
.DESCRIPTION
    Highlight a text.
.PARAMETER Text
    The text to highlight.
#>
function Format-Highlight([Parameter(Mandatory, Position = 0, ValueFromPipeline)][string]$Text) {
    return Format-Color $Text -F $env:WINDOZE_HIGHLIGHT
}

<#
.DESCRIPTION
    Make a text secondary.
.PARAMETER Text
    The text to make secondary.
#>
function Format-Secondary([Parameter(Mandatory, Position = 0, ValueFromPipeline)][string]$Text) {
    return Format-Color $Text -F $env:WINDOZE_SECONDARY
}

<#
.DESCRIPTION
    Format a success.
.PARAMETER Text
    The success text.
.PARAMETER Color
    The color to use for the success icon.
    Defaults to $env:WINDOZE_SUCCESS.
#>
function Write-Success(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]
    $Text,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_SUCCESS,
    [switch]
    $NoNewLine
) {
    Write-Status $Text "✔" -C $Color -NoNewLine:$NoNewLine
}

<#
.DESCRIPTION
    Format a failure.
.PARAMETER Text
    The failure text.
.PARAMETER Color
    The color to use for the failure icon.
    Defaults to $env:WINDOZE_FAIL.
#>
function Write-Fail(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]
    $Text,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_FAIL,
    [switch]
    $NoNewLine
) {
    Write-Status $Text "✘" -C $Color -NoNewLine:$NoNewLine
}

<#
.DESCRIPTION
    Prompt an input from the console.
.PARAMETER Prompt
    The prompt to display.
.PARAMETER Placeholder
    The placeholder to show in an empty input.
#>
function Read-Input(
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Prompt,
    [Alias("S")]
    [string]
    $Separator = "`n> "
) {
    $Text = "$(Format-Secondary $Prompt)$(Format-Highlight $Separator)"
    Write-Host -NoNewline $Text
    $Inp = Read-Host
    Remove-Lines ("$Text$Inp" -split "\n").Length
    return $Inp
}

<#
.DESCRIPTION
    Prompt a choice from the console.
.PARAMETER Prompt
    The prompt to display.
.PARAMETER Choices
    The choices to give.
.PARAMETER Values
    The values to return for the selected choices.
#>
function Read-Choice(
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Prompt,
    [Parameter(Mandatory, Position = 1)]
    [string[]]
    $Choices,
    [Parameter(Position = 2)]
    [string[]]
    $Values = $Choices
) {
    $Selected = 0
    
    $CursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    do {
        $Text = Format-Secondary $Prompt
        for ($I = 0; $I -lt $Choices.Length; $I++) {
            if ($I -eq $Selected) {
                $Text += Format-Highlight "`n> $($Choices[$I])"
            }
            else {
                $Text += "`n  $($Choices[$I])" 
            }
        }
        Write-Host $Text

        $Key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($Key.VirtualKeyCode) {
            0x26 { $Selected-- }
            0x28 { $Selected++ }
            0x0D { $Choice = $Values[$Selected] }
            0x43 { if ($Key.ControlKeyState) { break } }
        }
        $Selected = ($Selected + $Choices.Length) % $Choices.Length
        Remove-Lines ($Text -split "\n").Length
    } while (-Not $Choice)
    [Console]::CursorVisible = $CursorVisible

    return $Choice
}


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