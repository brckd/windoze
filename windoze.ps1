<#
.SYNOPSIS
    Windoze image creator.
.DESCRIPTION
    Glamorous shell scripts to create your very own Windows image.
.PARAMETER Source
    Path of the image that should be altered.
    If not specified, will be prompted
#>
param(
    [string]$Source
)

$env:WINDOZE_HIGHLIGHT ??= 12
$env:WINDOZE_CONFIRM ??= 9
$env:WINDOZE_REJECT ??= 10

<#
.DESCRIPTION
    Formats a list of arguments into an ANSI code.
.PARAMETER Arguments
    The list of arguments to format.
.PARAMETER Command
    The command to use.
    Defaults to Select Graphic Rendition.
#>
function Ansi([ushort[]]$Arguments, [char]$Command = "m") {
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
function Color([string]$Text, [ushort]$Foreground, [ushort]$Background) {
    $Args = (
        $(if ($Foreground -is [ushort]) { 38, 5, $Foreground } else { @() }) + `
        $(if ($Foreground -is [ushort]) { 38, 5, $Foreground } else { @() })
    )
    return $Args.Length ? "$(Ansi $Args)$Text$(Ansi 0)" : "$Text"
}

<#
.DESCRIPTION
    Highlight a text.
.PARAMETER Text
    The text to highlight.
#>
function Highlight([string]$Text) {
    return Color $Text $env:WINDOZE_HIGHLIGHT
}

<#
.DESCRIPTION
    Play a spinning animation while executing a script.
.PARAMETER Title
    The text to display while executing the job.
.PARAMETER Script
    The script to execute.
.PARAMETER Color
    The highlight color of the spinner
#>
function Spin([string]$Text, [scriptblock]$Script, [int]$Color = $env:WINDOZE_HIGHLIGHT) {
    $Frames = "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"
    $Frame = 0
    $Job = Start-Job -ScriptBlock $Script

    [console]::CursorVisible = $false
    while ($Job.State -eq "Running") {
        $Frame = ($Frame + 1) % $Frames.Length
        Write-Host -NoNewline "`r$(Status $Text $Frames[$Frame] $Color)"
        Start-Sleep 0.04
    }
    Reset-Line
    [console]::CursorVisible = $true
    
    $Result = Receive-Job $Job
    Remove-Job -Job $Job
    if ($Job.Error) { throw $Job.Error } 
    return $Result
}

<#
.DESCRIPTION
    Reset the current line in the console.
#>
function Reset-Line {
    Write-Host -NoNewline "`r$(" " * $host.UI.RawUI.CursorPosition.X)`r"
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
#>
function Status([string]$Text, [string]$Status, [int]$Color = $env:WINDOZE_HIGHLIGHT) {
    return "$(Color $Status $Color) $Text"
}

function Confirm([string]$Text, [string]$Color = $env:WINDOZE_CONFIRM) {
    return Status $Text "✔" $Color
}

function Reject([string]$Text, [string]$Color = $env:WINDOZE_REJECT) {
    return Status $Text "✘" $Color
}

# Print welcome screen.
Write-Output "`nWelcome to $(Highlight "Windoze") image creator!`n"

Spin "Processing..." { Start-Sleep 3 }
Confirm "Done"
Reject "Error"