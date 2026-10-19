<div align="center">

# 🖱️ AntiBloqueo

**Evitá que Windows bloquee la sesión o apague la pantalla por inactividad.**

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square&logo=windows&logoColor=white)](#requisitos)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)](AntiBloqueo.ps1)
[![Sin dependencias](https://img.shields.io/badge/dependencias-ninguna-success?style=flat-square)](#requisitos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

</div>

AntiBloqueo vive en la bandeja del sistema y se activa o pausa con un atajo de teclado. Al activarlo **dibuja una figura con el mouse**, un infinito por defecto, y el cursor vuelve exacto a donde estaba.

Es un solo script de PowerShell: sin instalación, sin dependencias y sin permisos de administrador.

```
    oo  o                                    o  o
 o        o                                o       o
o              o                        o              o
o                     o           o                        o
                         oo
o                       o          o                       o
   o               o                      o               o
      o o o  o                                  o  o o o
```

## Características

- ⌨️ **Atajo global** `Ctrl` + `Alt` + `J` para activar y pausar.
- 🟢 **Ícono de bandeja** que muestra el estado: verde activo, gris pausado.
- ∞ **Seis modos de figura**, configurables por parámetro.
- 🪶 **Movimiento imperceptible** de 1 píxel que no interfiere con lo que estés haciendo.
- 💡 **Pantalla siempre encendida** mediante la API soportada de Windows.
- 🔒 **Instancia única**: si ya está corriendo, un segundo arranque solo te avisa.

## Inicio rápido

1. Cloná o descargá el repo en una carpeta fija, por ejemplo `Documentos\Scripts\`:

   ```
   git clone https://github.com/AgustinBouzonn/mouse-antibloqueo.git
   ```

2. Hacé doble clic en **`Iniciar.vbs`**.

Aparece un punto gris en la bandeja del sistema, al lado del reloj.

> **¿Por qué `Iniciar.vbs` y no el `.ps1` directo?** El `.vbs` lanza PowerShell sin ventana de consola. Si abrís el `.ps1` a mano, queda una ventana negra abierta mientras corre.

### Arranque automático con Windows (opcional)

Desde la carpeta del repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Instalar-Inicio.ps1
```

El script crea dos accesos directos:

- **Carpeta Inicio:** AntiBloqueo arranca solo, pausado, cada vez que iniciás sesión.
- **Escritorio:** con la tecla rápida `Ctrl` + `Alt` + `M`, para relanzarlo si lo cerraste.

Los accesos directos apuntan a la carpeta donde está el repo. Si la movés, volvé a correr el script. Para deshacerlo, usá el mismo comando con `-Quitar`.

## Uso

| Acción | Cómo |
|---|---|
| **Activar / pausar** | `Ctrl` + `Alt` + `J` |
| Activar / pausar sin teclado | Doble clic en el ícono, o botón derecho → *Activar / Pausar* |
| Ver el estado | Ícono **verde** = activo, **gris** = pausado |
| Salir | Botón derecho en el ícono → *Salir* |

Arranca **pausado**. Cuando lo activás:

1. Dibuja la figura con el mouse en menos de un segundo y el cursor vuelve a su lugar.
2. Cada 30 segundos, o el intervalo que configures, mueve el mouse 1 píxel a la derecha y 1 a la izquierda. No molesta aunque estés escribiendo o arrastrando algo.
3. Le pide a Windows que no apague la pantalla ni suspenda el equipo.

## Figuras

Se eligen con el parámetro `-Figura`:

| Valor | Qué dibuja |
|---|---|
| `infinito` | Lemniscata de Gerono, un ∞ acostado. **Por defecto** |
| `circulo` | Un círculo |
| `corazon` | Un corazón |
| `espiral` | Una flor de 3 pétalos que se abre y se cierra |
| `random` | Una al azar cada vez que lo activás |
| `ninguna` | Sin animación, solo el movimiento discreto |

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\AntiBloqueo.ps1 -Figura random -Tamano 90
```

## Parámetros

| Parámetro | Default | Qué hace |
|---|---|---|
| `-Intervalo` | `30` | Segundos entre movimientos de mantenimiento. Mínimo 5 |
| `-Pixeles` | `1` | Cuánto se mueve el mouse en cada movimiento discreto |
| `-Figura` | `infinito` | Qué dibuja al activarse. Ver [Figuras](#figuras) |
| `-Tamano` | `60` | Radio de la figura, en píxeles. Mínimo 10 |
| `-Duracion` | `900` | Cuánto tarda en dibujarla, en milisegundos. Mínimo 100 |
| `-FiguraCadaTick` | *apagado* | Dibuja la figura completa en **cada** movimiento, no solo al activar |
| `-IniciarActivo` | *apagado* | Arranca activo en vez de pausado |

Ejemplo: corazón grande, cada 60 segundos, arrancando activo.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\AntiBloqueo.ps1 `
    -Figura corazon -Tamano 100 -Intervalo 60 -IniciarActivo
```

Para fijar tu configuración, editá los valores por defecto del bloque `param()` al principio de `AntiBloqueo.ps1`.

### Cambiar el atajo

En `AntiBloqueo.ps1`, cerca del final:

```powershell
$MOD_ALT = 0x0001; $MOD_CONTROL = 0x0002; $VK_J = 0x4A
```

`0x4A` es la tecla `J`. Reemplazala por el [virtual-key code](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes) que quieras, por ejemplo `0x4D` para M o `0x50` para P.

| Modificador | Valor |
|---|---|
| `MOD_ALT` | `0x0001` |
| `MOD_CONTROL` | `0x0002` |
| `MOD_SHIFT` | `0x0004` |
| `MOD_WIN` | `0x0008` |

## Cómo funciona

Windows decide que estás inactivo con `GetLastInputInfo`, que solo se resetea con **input real** del sistema. Por eso el script usa `mouse_event` con movimiento relativo y **no** `SetCursorPos`: mover el cursor por software no cuenta como actividad y no evita el bloqueo. Es el error clásico de la mayoría de los "mouse jigglers" caseros.

Tres detalles de implementación:

- **El trazo relee la posición real del cursor en cada paso.** Con la aceleración del puntero activada ("Mejorar la precisión del puntero"), Windows no aplica exactamente los deltas pedidos. Releer la posición evita que se acumule deriva y la curva sale limpia.
- **El movimiento de mantenimiento va antes de reposicionar el cursor.** En el orden inverso, esa misma aceleración deja el cursor corrido un píxel cada vez.
- **La animación espera por `Stopwatch` y no por `Thread.Sleep`.** El scheduler de Windows tiene una resolución de unos 15 ms, y una animación pensada para 900 ms terminaba tardando 1500 ms.

Para la pantalla, llama a `SetThreadExecutionState` con `ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED`. Es la forma soportada de pedirle a Windows que no apague la pantalla ni suspenda, la misma que usa un reproductor de video.

## Estructura del proyecto

| Archivo | Qué es |
|---|---|
| `AntiBloqueo.ps1` | La aplicación: ícono de bandeja, atajo global, timer y figuras |
| `Iniciar.vbs` | Lanza el `.ps1` sin ventana de consola |
| `Instalar-Inicio.ps1` | Crea o quita los accesos directos de Inicio y Escritorio |

## Requisitos

- Windows 10 u 11
- PowerShell 5.1, el que ya viene con Windows, o superior
- **No** requiere permisos de administrador

## Problemas conocidos

**No pasa nada al apretar `Ctrl` + `Alt` + `J`.**
Otra aplicación puede tener tomado ese atajo. Al arrancar, el script muestra un globo de aviso si no pudo registrarlo. Usá el menú del ícono o cambiá la tecla como se explica en [Cambiar el atajo](#cambiar-el-atajo).

**"No se puede cargar el archivo... la ejecución de scripts está deshabilitada".**
Estás corriendo el `.ps1` directo con una política restrictiva. Usá `Iniciar.vbs`, que ya pasa `-ExecutionPolicy Bypass`.

**El ícono queda en la bandeja después de cerrarlo.**
Pasa cuando el proceso se mata a la fuerza en vez de usar *Salir*. Pasá el mouse por encima del ícono y desaparece.

**No evita el bloqueo.**
Si el bloqueo viene de una política de dominio o de un agente de seguridad corporativo, AntiBloqueo no lo esquiva. Para ver tu límite real de inactividad:

```powershell
powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE
```

## Uso responsable

El bloqueo por inactividad suele ser una política de seguridad. Si la PC es corporativa, consultalo con el área de IT antes de usarlo. Pausalo cuando te alejes del escritorio.

## Licencia

Distribuido bajo licencia MIT. Ver [LICENSE](LICENSE).
