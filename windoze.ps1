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
    The text to display while executing the job.
.PARAMETER Script
    The script to execute.
.PARAMETER Color
    The highlight color of the spinner
#>
function Spin([String]$Text, [scriptblock]$Script, [int]$Color) {
    $Frames = "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"
    $Frame = 0
    $Job = Start-Job -ScriptBlock $Script

    [console]::CursorVisible = $false
    while ($Job.State -eq "Running") {
        $Frame = ($Frame + 1) % $Frames.Length
        Write-Host -NoNewline "`r$(Status $Text (Color $Frames[$Frame] $Color))"
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
#>
function Status([string]$Text, [string]$Status) {
    return "$Status $Text"
}


# Print welcome screen.
Write-Output "`nWelcome to $(Color 'Windoze' $COLOR) image creator!`n"

Spin "hi" { Start-Sleep 1 } $COLOR
