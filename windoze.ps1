function Install-Dependencies {
    # install scripts if needed
    Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression # install the scoop package manager
    scoop install charm-gum # install the gum shell script tool
}

function Welcome {
    # welcome screen
    gum style --border normal --margin "1" --padding "1 2" --border-foreground $COLOR `
        "Welcome to $(gum style --foreground $COLOR 'Windoze')!"
}

$COLOR = 4

if (-Not (Get-Command "gum" -errorAction SilentlyContinue)) {
    Install-Dependencies
}
Welcome
