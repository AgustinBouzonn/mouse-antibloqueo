<#
    AntiBloqueo.ps1
    -----------------------------------------------------------------
    Evita que Windows se bloquee / apague la pantalla por inactividad.

    - Vive en la bandeja del sistema (al lado del reloj).
    - Atajo global  Ctrl + Alt + J  -> activa / pausa.
    - Al ACTIVARLO dibuja una figura con el mouse (por defecto un
      infinito) y despues el cursor vuelve exacto a donde estaba.
    - Mientras esta activo mueve el mouse 1 px cada N segundos y le
      pide a Windows que no apague la pantalla ni suspenda el equipo.

    Uso:
        powershell -NoProfile -ExecutionPolicy Bypass -File AntiBloqueo.ps1
        ... -Figura corazon -Tamano 90
        ... -Intervalo 60 -IniciarActivo
        ... -FiguraCadaTick        (dibuja la figura en cada movimiento)
#>

param(
    [int]    $Intervalo = 30,   # segundos entre movimientos
    [int]    $Pixeles   = 1,    # jiggle discreto: cuanto se mueve (va y vuelve)

    [ValidateSet('infinito','circulo','corazon','espiral','random','ninguna')]
    [string] $Figura    = 'infinito',
    [int]    $Tamano    = 60,   # radio de la figura en pixeles
    [int]    $Duracion  = 900,  # cuanto tarda en dibujarla, en milisegundos

    [switch] $FiguraCadaTick,   # dibujar la figura tambien en cada tick
    [switch] $IniciarActivo     # arrancar ya activo en vez de pausado
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- instancia unica
$creado = $false
$mutex  = New-Object System.Threading.Mutex($true, 'Local\AntiBloqueo', [ref]$creado)
if (-not $creado) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        'AntiBloqueo ya esta corriendo. Fijate el icono en la bandeja del sistema.',
        'AntiBloqueo', 'OK', 'Information') | Out-Null
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- ventana oculta + WinAPI
$codigo = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[StructLayout(LayoutKind.Sequential)]
public struct PT { public int X; public int Y; }

public class AntiLockForm : Form
{
    [DllImport("user32.dll")]   private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")]   private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("user32.dll")]   private static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")]   private static extern bool GetCursorPos(out PT p);
    [DllImport("user32.dll")]   private static extern bool SetCursorPos(int x, int y);
    [DllImport("kernel32.dll")] private static extern uint SetThreadExecutionState(uint esFlags);

    private const int  WM_HOTKEY           = 0x0312;
    private const uint MOUSEEVENTF_MOVE    = 0x0001;
    private const uint ES_CONTINUOUS       = 0x80000000;
    private const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    private const uint ES_DISPLAY_REQUIRED = 0x00000002;

    public event EventHandler HotkeyPressed;

    public AntiLockForm()
    {
        this.FormBorderStyle = FormBorderStyle.FixedToolWindow;
        this.ShowInTaskbar   = false;
        this.StartPosition   = FormStartPosition.Manual;
        this.Location        = new System.Drawing.Point(-32000, -32000);
        this.Size            = new System.Drawing.Size(1, 1);
    }

    // la ventana nunca se muestra: solo existe para recibir el mensaje del hotkey
    protected override void SetVisibleCore(bool value) { base.SetVisibleCore(false); }

    public void EnsureHandle() { IntPtr h = this.Handle; }

    public bool RegisterToggleHotkey(int id, uint modifiers, uint key) { return RegisterHotKey(this.Handle, id, modifiers, key); }
    public void UnregisterToggleHotkey(int id)                        { UnregisterHotKey(this.Handle, id); }

    // movimiento relativo real: cuenta como actividad para el timer de inactividad de Windows
    public void Jiggle(int px)
    {
        mouse_event(MOUSEEVENTF_MOVE,  px, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_MOVE, -px, 0, 0, UIntPtr.Zero);
    }

    // -------------------------------------------------- figuras
    // Curvas cerradas parametrizadas en t = [0, 2*PI). Y positivo = hacia abajo
    // (coordenadas de pantalla), por eso el corazon va con el signo invertido.
    private static void ShapePoint(string shape, double t, double size, out double x, out double y)
    {
        switch (shape)
        {
            case "circulo":
                x = size * Math.Sin(t);
                y = -size * Math.Cos(t);
                break;

            case "corazon":
                double s = size / 16.0;
                x =  s * 16 * Math.Pow(Math.Sin(t), 3);
                y = -s * (13 * Math.Cos(t) - 5 * Math.Cos(2 * t) - 2 * Math.Cos(3 * t) - Math.Cos(4 * t));
                break;

            case "espiral":
                double r = size * Math.Sin(t / 2.0);   // abre y cierra
                x = r * Math.Cos(3 * t);
                y = r * Math.Sin(3 * t);
                break;

            default: // "infinito" - lemniscata de Gerono
                x = size * Math.Sin(t);
                y = (size / 2.0) * Math.Sin(2 * t);
                break;
        }
    }

    // Thread.Sleep tiene resolucion de ~15 ms en Windows, asi que para una
    // animacion de 1 segundo hay que esperar por reloj real, no por Sleep.
    private static void WaitUntil(System.Diagnostics.Stopwatch sw, double targetMs)
    {
        while (sw.Elapsed.TotalMilliseconds < targetMs)
        {
            double falta = targetMs - sw.Elapsed.TotalMilliseconds;
            if (falta > 20) System.Threading.Thread.Sleep(1);
            else            System.Threading.Thread.SpinWait(150);
        }
    }

    public void DrawShape(string shape, int size, int steps, int totalMs)
    {
        PT start;
        if (!GetCursorPos(out start)) { Jiggle(1); return; }

        double x0, y0;
        ShapePoint(shape, 0, size, out x0, out y0);   // offset: la figura arranca donde esta el cursor

        System.Drawing.Rectangle vs = SystemInformation.VirtualScreen;
        System.Diagnostics.Stopwatch sw = System.Diagnostics.Stopwatch.StartNew();

        for (int i = 1; i <= steps; i++)
        {
            double t = 2.0 * Math.PI * i / steps;
            double px, py;
            ShapePoint(shape, t, size, out px, out py);

            double tx = start.X + (px - x0);
            double ty = start.Y + (py - y0);

            // no salirse de la pantalla
            if (tx < vs.Left + 1)     tx = vs.Left + 1;
            if (tx > vs.Right - 2)    tx = vs.Right - 2;
            if (ty < vs.Top + 1)      ty = vs.Top + 1;
            if (ty > vs.Bottom - 2)   ty = vs.Bottom - 2;

            // leemos la posicion real en cada paso: asi la aceleracion del
            // puntero no acumula deriva y la figura sale limpia
            PT cur;
            if (!GetCursorPos(out cur)) break;

            int dx = (int)Math.Round(tx - cur.X);
            int dy = (int)Math.Round(ty - cur.Y);
            if (dx != 0 || dy != 0) mouse_event(MOUSEEVENTF_MOVE, dx, dy, 0, UIntPtr.Zero);

            WaitUntil(sw, (double)totalMs * i / steps);
        }

        // el Jiggle va ANTES del reposicionamiento: si fuera despues, la
        // aceleracion del puntero puede dejar el cursor 1 px corrido.
        Jiggle(1);
        SetCursorPos(start.X, start.Y);   // vuelve exacto a donde estaba
    }

    public void KeepAwake(bool on)
    {
        if (on) SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
        else    SetThreadExecutionState(ES_CONTINUOUS);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY && HotkeyPressed != null) HotkeyPressed(this, EventArgs.Empty);
        base.WndProc(ref m);
    }
}
"@

Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition $codigo

# ---------------------------------------------------------------- iconos de bandeja
function New-DotIcon {
    param([System.Drawing.Color]$Color)
    $bmp = New-Object System.Drawing.Bitmap 16, 16
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush $Color
    $pen   = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(160, 255, 255, 255)), 1.5
    $g.FillEllipse($brush, 2, 2, 12, 12)
    $g.DrawEllipse($pen,   2, 2, 12, 12)
    $brush.Dispose(); $pen.Dispose(); $g.Dispose()
    $ico = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
    return $ico
}

$iconOn  = New-DotIcon ([System.Drawing.Color]::FromArgb(46, 204, 113))   # verde
$iconOff = New-DotIcon ([System.Drawing.Color]::FromArgb(130, 130, 130))  # gris

# ---------------------------------------------------------------- objetos principales
$form = New-Object AntiLockForm
$form.EnsureHandle()

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = [Math]::Max(5, $Intervalo) * 1000

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon    = $iconOff
$notify.Text    = 'AntiBloqueo: pausado'
$notify.Visible = $true

$menu     = New-Object System.Windows.Forms.ContextMenuStrip
$miToggle = $menu.Items.Add('Activar / Pausar   (Ctrl+Alt+J)')
$null     = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$miSalir  = $menu.Items.Add('Salir')
$notify.ContextMenuStrip = $menu

$script:activo = $false

# ---------------------------------------------------------------- logica
function Invoke-Figura {
    if ($Figura -eq 'ninguna') { $form.Jiggle($Pixeles); return }

    $f = $Figura
    if ($f -eq 'random') { $f = @('infinito','circulo','corazon','espiral') | Get-Random }

    $pasos = switch ($f) {
        'corazon' { 110 }
        'espiral' { 130 }
        default   {  90 }
    }
    $form.DrawShape($f, [Math]::Max(10, $Tamano), $pasos, [Math]::Max(100, $Duracion))
}

function Set-Estado {
    param([bool]$On)

    $script:activo = $On
    $timer.Enabled = $On
    $form.KeepAwake($On)

    if ($On) {
        $notify.Icon            = $iconOn
        $notify.Text            = 'AntiBloqueo: ACTIVO'
        $notify.BalloonTipIcon  = 'Info'
        $notify.BalloonTipTitle = 'AntiBloqueo activado'
        $notify.BalloonTipText  = "La PC no se va a bloquear. Movimiento cada $Intervalo s."
        $notify.ShowBalloonTip(1500)
        Invoke-Figura                       # el saludo: dibuja la figura
    }
    else {
        $notify.Icon            = $iconOff
        $notify.Text            = 'AntiBloqueo: pausado'
        $notify.BalloonTipIcon  = 'Info'
        $notify.BalloonTipTitle = 'AntiBloqueo pausado'
        $notify.BalloonTipText  = 'Windows vuelve a bloquear normalmente.'
        $notify.ShowBalloonTip(1500)
    }
}

function Invoke-Toggle { Set-Estado (-not $script:activo) }

function Stop-App {
    $timer.Stop()
    $form.KeepAwake($false)
    $form.UnregisterToggleHotkey(1)
    $notify.Visible = $false
    $notify.Dispose()
    $form.Close()
}

$timer.add_Tick({
    if ($FiguraCadaTick) { Invoke-Figura } else { $form.Jiggle($Pixeles) }
    $form.KeepAwake($true)   # se renueva por las dudas
})

$form.add_HotkeyPressed({ Invoke-Toggle })
$miToggle.add_Click({ Invoke-Toggle })
$miSalir.add_Click({ Stop-App })
$notify.add_MouseDoubleClick({ Invoke-Toggle })

# ---------------------------------------------------------------- hotkey global: Ctrl+Alt+J
$MOD_ALT = 0x0001; $MOD_CONTROL = 0x0002; $VK_J = 0x4A
$ok = $form.RegisterToggleHotkey(1, ($MOD_CONTROL -bor $MOD_ALT), $VK_J)
if (-not $ok) {
    $notify.BalloonTipIcon  = 'Warning'
    $notify.BalloonTipTitle = 'AntiBloqueo'
    $notify.BalloonTipText  = 'No se pudo registrar Ctrl+Alt+J (otra app lo usa). Usa el menu del icono.'
    $notify.ShowBalloonTip(4000)
}

if ($IniciarActivo) { Set-Estado $true } else { Set-Estado $false }

# ---------------------------------------------------------------- loop de mensajes
try {
    [System.Windows.Forms.Application]::Run($form)
}
finally {
    $form.KeepAwake($false)
    if ($notify) { $notify.Visible = $false; $notify.Dispose() }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
