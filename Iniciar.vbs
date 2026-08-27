' Iniciar.vbs - lanza AntiBloqueo.ps1 sin ventana de consola.
' Doble clic aca (o desde el acceso directo) y queda el icono en la bandeja.

Option Explicit

Dim fso, shell, carpeta, ps1, cmd

Set fso   = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

carpeta = fso.GetParentFolderName(WScript.ScriptFullName)
ps1     = carpeta & "\AntiBloqueo.ps1"

If Not fso.FileExists(ps1) Then
    MsgBox "No encuentro AntiBloqueo.ps1 en:" & vbCrLf & carpeta, vbCritical, "AntiBloqueo"
    WScript.Quit 1
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"

' 0 = ventana oculta, False = no esperar
shell.Run cmd, 0, False
