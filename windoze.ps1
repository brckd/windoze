<#
.SYNOPSIS
    Windoze image creator.
.DESCRIPTION
    Glamorous shell scripts to create your very own Windows image.
.PARAMETER Source
    Path of the image that should be altered.
    If not specified, will be prompted 
.PARAMETER COLOR
    Highlight color of the output.
    Defaults to Windoze blue.
#>
param(
    [string]$Source,
    [ushort]$COLOR = 12
)

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
function Color([string]$Text, $Foreground = @(), $Background = @()) {
    if ($Foreground.Length) { $Foreground = 38, 5, $Foreground } 
    if ($Background.Length) { $Background = 48, 5, $Background } 
    $Ansi = Ansi ($Foreground + $Background)
    return $Ansi ? "$Ansi$Text$(Ansi 0)" : "$Text"
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
function Spin([string]$Text, [scriptblock]$Script, [int]$Color) {
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
function Status([string]$Text, [string]$Status, [int]$Color = $COLOR) {
    return "$(Color $Status $Color) $Text"
}

function Confirm([string]$Text, [string]$Color = 10) {
    return Status $Text "✔" $COLOR
}

function Reject([string]$Text, [string]$Color = 9) {
    return Status $Text "✘" $COLOR
}

# Print welcome screen.
Write-Output "`nWelcome to $(Color "Windoze" $COLOR) image creator!`n"

Spin "Processing..." { Start-Sleep 3 } $COLOR
Confirm "Done"
Reject "Error"