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
    [int]$COLOR = 94
)

# highlight the provided text with a ANSI color code
<#
.DESCRIPTION
    Highlight text with a ANSI color code.
.PARAMETER Text
    The text to highlight.
.PARAMETER Color
    The ANSII code to highlight the text with.
#>
function Color([String]$Text, [int]$Color) {
    return "$([char]27)[$($Color)m$Text$([char]27)[0m"
}

<#
.DESCRIPTION
    Play a spinning animation while executing a script.
.PARAMETER Title
    The title to display while executing the job.
.PARAMETER Script
    The script to execute.
.PARAMETER Color
    The highlight color of the spinner
#>
function Spin([String]$Title, [scriptblock]$Script, [int]$Color) {
    $CursorPosition = $host.UI.RawUI.CursorPosition
    $Frames = "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"
    $Job = Start-Job -ScriptBlock $Script

    [console]::CursorVisible = $false

    for ($Frame = 0; $Job.State -ne "Completed"; $Frame++) {
        $Frame %= $Frames.Length
        Write-Host -NoNewline "`r$(Color $Frames[$Frame] $Color) $($Title)"
        Start-Sleep 0.04
    }

    Write-Host -NoNewline "`r"
    $CursorPosition.Y += 1
    [console]::CursorVisible = $true
    
    $Result = Receive-Job $Job
    Remove-Job -Job $Job
    if ($Job.Error) { throw $Job.Error } 

    return $Result
}

# Print welcome screen.
Write-Output "`nWelcome to $(Color $COLOR 'Windoze')!`n"