<#
.SYNOPSIS
    Windoze image creator.
.DESCRIPTION
    Glamorous shell scripts to create your very own Windows image.
.PARAMETER Source
    Path of the image that should be altered.
    If not specified, will be prompted later.
.EXAMPLE
    ./windoze.ps1 -S ./my/image.iso
#>
Param(
    [Parameter(Position = 0)]
    [Alias("S")]
    [string]
    $Source
)

$env:WINDOZE_HIGHLIGHT ??= 12
$env:WINDOZE_CONFIRM ??= 10
$env:WINDOZE_REJECT ??= 9

<#
.DESCRIPTION
    Formats a list of arguments into an ANSI code.
.PARAMETER Arguments
    The list of arguments to format.
.PARAMETER Command
    The command to use.
    Defaults to Select Graphic Rendition.
#>
function Ansi(
    [Parameter(ValueFromPipeline, Position = 0)]
    [ushort[]]
    $Arguments,
    [Alias("C")]
    [char]
    $Command = "m"
) {
    return $Arguments.Length ? "$([char]27)[$($Arguments -join ";")$Command" : ""
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
function Color(
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
    return $Arguments.Length ? "$(Ansi $Arguments)$Text$(Ansi 0)" : "$Text"
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
function Spin(
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

    [console]::CursorVisible = $false
    while ($Job.State -eq "Running") {
        $Frame = ($Frame + 1) % $Frames.Length
        Write-Host -NoNewline "`r$(Status $Text $Frames[$Frame] -C $Color)"
        Start-Sleep 0.04
    }
    Write-Host "`r$(Confirm $Text)"
    [console]::CursorVisible = $true
    
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
function Status(
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Text,
    [Parameter(Mandatory, Position = 1)]
    [Alias("S")]
    [string]
    $Status,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_HIGHLIGHT
) {
    return "$(Color $Status -F $Color) $Text"
}

<#
.DESCRIPTION
    Highlight a text.
.PARAMETER Text
    The text to highlight.
    Defaults to $env:WINDOZE_HIGHLIGHT.
#>
function Highlight([Parameter(Mandatory, Position = 0, ValueFromPipeline)][string]$Text) {
    return Color $Text -F $env:WINDOZE_HIGHLIGHT
}

<#
.DESCRIPTION
    Format a confirmation.
.PARAMETER Text
    The confirmation text.
.PARAMETER Color
    The color to use for the confirmation icon.
    Defaults to $env:WINDOZE_CONFIRM.
#>
function Confirm(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]
    $Text,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_CONFIRM
) {
    return Status $Text "✔" -C $Color
}

<#
.DESCRIPTION
    Format a rejection.
.PARAMETER Text
    The rejection text.
.PARAMETER Color
    The color to use for the rejection icon.
    Defaults to $env:WINDOZE_REJECT.
#>
function Reject(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]
    $Text,
    [Alias("C")]
    [ushort]
    $Color = $env:WINDOZE_REJECT
) {
    return Status $Text "✘" -C $Color
}

# Print welcome screen.
Write-Output "`nWelcome to $(Highlight "Windoze") image creator!`n"
Spin "Processing..." { Start-Sleep 3 }
Confirm "Done"
Reject "Error"