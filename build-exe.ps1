Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

$modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\ps2exe\1.0.17\ps2exe.psd1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    $module = Get-Module -ListAvailable -Name ps2exe | Select-Object -First 1
    if ($module) {
        Import-Module $module.Path -Force
    } else {
        Write-Error "ps2exe module not found. Install it with: Install-Module ps2exe -Scope CurrentUser"
        exit 1
    }
}

Invoke-ps2exe -inputFile 'sans.ps1' -outputFile 'sans.exe'

