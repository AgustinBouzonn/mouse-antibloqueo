<#
    Instalar-Inicio.ps1
    -----------------------------------------------------------------
    Crea dos accesos directos:

      1) En la carpeta Inicio de Windows -> AntiBloqueo arranca solo
         cada vez que inicias sesion (queda pausado, gris, hasta que
         apretes Ctrl+Alt+J).

      2) En el Escritorio, con tecla rapida Ctrl+Alt+M -> por si lo
         cerraste y lo queres volver a levantar.

    Para deshacer:  .\Instalar-Inicio.ps1 -Quitar
#>

param([switch]$Quitar)

$ErrorActionPreference = 'Stop'

$carpeta   = Split-Path -Parent $MyInvocation.MyCommand.Path
$vbs       = Join-Path $carpeta 'Iniciar.vbs'
$inicio    = [Environment]::GetFolderPath('Startup')
$escritorio= [Environment]::GetFolderPath('Desktop')
$lnkInicio = Join-Path $inicio     'AntiBloqueo.lnk'
$lnkDesk   = Join-Path $escritorio 'AntiBloqueo.lnk'

if ($Quitar) {
    foreach ($l in @($lnkInicio, $lnkDesk)) {
        if (Test-Path $l) { Remove-Item $l -Force; Write-Host "Borrado: $l" }
    }
    Write-Host 'Listo. AntiBloqueo ya no arranca solo.'
    return
}

if (-not (Test-Path $vbs)) { throw "No encuentro $vbs" }

$ws = New-Object -ComObject WScript.Shell

$a = $ws.CreateShortcut($lnkInicio)
$a.TargetPath       = 'wscript.exe'
$a.Arguments        = '"{0}"' -f $vbs
$a.WorkingDirectory = $carpeta
$a.IconLocation     = "$env:SystemRoot\System32\imageres.dll,109"
$a.Description      = 'AntiBloqueo - evita que la PC se bloquee (Ctrl+Alt+J)'
$a.Save()
Write-Host "Creado: $lnkInicio"

$b = $ws.CreateShortcut($lnkDesk)
$b.TargetPath       = 'wscript.exe'
$b.Arguments        = '"{0}"' -f $vbs
$b.WorkingDirectory = $carpeta
$b.IconLocation     = "$env:SystemRoot\System32\imageres.dll,109"
$b.Description      = 'AntiBloqueo - evita que la PC se bloquee (Ctrl+Alt+J)'
$b.HotKey           = 'CTRL+ALT+M'
$b.Save()
Write-Host "Creado: $lnkDesk  (tecla rapida Ctrl+Alt+M para lanzarlo)"

Write-Host ''
Write-Host 'Listo. Atajos:'
Write-Host '  Ctrl+Alt+M  ->  lanzar AntiBloqueo (si no esta corriendo)'
Write-Host '  Ctrl+Alt+J  ->  activar / pausar'
