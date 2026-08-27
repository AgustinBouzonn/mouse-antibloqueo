# AntiBloqueo

Evita que Windows te bloquee la sesión o apague la pantalla por inactividad.
Vive en la bandeja del sistema, se prende y apaga con un atajo de teclado, y
**cuando lo activás dibuja un infinito con el mouse** (o un corazón, o lo que
elijas). Después el cursor vuelve exacto a donde estaba.

Sin instalación, sin dependencias, sin permisos de administrador. Es un solo
script de PowerShell.

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

---

## Instalación

1. Descargá o cloná el repo donde quieras (por ejemplo `Documentos\Scripts\`):

   ```
   git clone https://github.com/AgustinBouzonn/mouse-antibloqueo.git
   ```

2. Doble clic en **`Iniciar.vbs`**.

Listo. Aparece un puntito gris en la bandeja del sistema (al lado del reloj).

> **¿Por qué `Iniciar.vbs` y no el `.ps1` directo?** Porque el `.vbs` lanza
> PowerShell sin ventana de consola. Si abrís el `.ps1` a mano te queda una
> ventana negra dando vueltas.

### Que arranque solo con Windows (opcional)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Instalar-Inicio.ps1
```

Eso crea dos accesos directos:

- Uno en la carpeta **Inicio**, así arranca solo cada vez que iniciás sesión.
- Uno en el **Escritorio**, con tecla rápida `Ctrl+Alt+M` para relanzarlo si lo cerraste.

Para deshacerlo: el mismo comando con `-Quitar`.

---

## Uso

| Acción | Cómo |
|---|---|
| **Activar / pausar** | `Ctrl` + `Alt` + `J` |
| Activar / pausar (sin teclado) | Doble clic en el ícono de la bandeja |
| Ver el estado | Ícono **verde** = activo, **gris** = pausado |
| Salir | Botón derecho en el ícono → *Salir* |

Arranca **pausado**. Cuando lo activás:

1. Dibuja la figura con el mouse (~1 segundo) y el cursor vuelve a su lugar.
2. A partir de ahí, cada 30 segundos mueve el mouse 1 píxel a la derecha y 1 a
   la izquierda. No te molesta ni aunque estés escribiendo o arrastrando algo.
3. Además le pide a Windows que no apague la pantalla ni suspenda el equipo.

---

## Figuras

Se eligen con el parámetro `-Figura`:

| Valor | Qué dibuja |
|---|---|
| `infinito` | Lemniscata, un ∞ acostado — **por defecto** |
| `circulo` | Un círculo |
| `corazon` | Un corazón |
| `espiral` | Una flor de 3 pétalos que se abre y se cierra |
| `random` | Elige una al azar cada vez que lo activás |
| `ninguna` | Sin animación, solo el movimiento discreto |

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\AntiBloqueo.ps1 -Figura random -Tamano 90
```

---

## Parámetros

| Parámetro | Default | Qué hace |
|---|---|---|
| `-Intervalo` | `30` | Segundos entre movimientos de mantenimiento (mínimo 5) |
| `-Pixeles` | `1` | Cuánto se mueve el mouse en cada movimiento discreto |
| `-Figura` | `infinito` | Qué dibuja al activarse (ver tabla de arriba) |
| `-Tamano` | `60` | Radio de la figura, en píxeles |
| `-Duracion` | `900` | Cuánto tarda en dibujarla, en milisegundos |
| `-FiguraCadaTick` | *(off)* | Dibuja la figura completa en **cada** movimiento, no solo al activar |
| `-IniciarActivo` | *(off)* | Arranca ya activo en vez de pausado |

Ejemplo — corazón grande, cada 60 segundos, arrancando activo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\AntiBloqueo.ps1 `
    -Figura corazon -Tamano 100 -Intervalo 60 -IniciarActivo
```

Si querés dejar tu configuración fija, editá los valores del bloque `param()`
arriba de `AntiBloqueo.ps1` y listo.

### Cambiar el atajo

En `AntiBloqueo.ps1`, cerca del final:

```powershell
$MOD_ALT = 0x0001; $MOD_CONTROL = 0x0002; $VK_J = 0x4A
```

`0x4A` es la tecla `J`. Cambiala por el
[virtual-key code](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)
que quieras (`0x4D` = M, `0x50` = P, etc.). Los modificadores son
`MOD_ALT` `0x0001`, `MOD_CONTROL` `0x0002`, `MOD_SHIFT` `0x0004`, `MOD_WIN` `0x0008`.

---

## Cómo funciona

Windows decide que estás inactivo con `GetLastInputInfo`, que se resetea con
**input real** del sistema. Por eso el script usa `mouse_event` con movimiento
relativo y **no** `SetCursorPos`: mover el cursor por software no cuenta como
actividad y no evita el bloqueo. Este es el error clásico de la mayoría de los
"mouse jigglers" caseros.

Dos detalles que importan:

- **El trazo relee la posición real del cursor en cada paso.** Si la aceleración
  del puntero está activada ("Mejorar la precisión del puntero"), los deltas que
  pedís no son los que Windows aplica. Releyendo la posición en cada paso no se
  acumula deriva y la curva sale limpia.
- **El movimiento de mantenimiento va antes de reposicionar el cursor.** Si fuera
  al revés, esa misma aceleración deja el cursor 1 píxel corrido cada vez.

Además llama a `SetThreadExecutionState` con `ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED`,
que es la forma soportada de pedirle a Windows que no apague la pantalla ni
suspenda — lo mismo que hace un reproductor de video.

La animación espera por `Stopwatch` y no por `Thread.Sleep`, porque en Windows
la resolución del scheduler es de ~15 ms: una animación pensada para 900 ms
terminaba tardando 1500 ms.

### Estructura

| Archivo | Qué es |
|---|---|
| `AntiBloqueo.ps1` | La aplicación: ícono de bandeja, hotkey global, timer y figuras |
| `Iniciar.vbs` | Lanza el `.ps1` sin ventana de consola |
| `Instalar-Inicio.ps1` | Crea/quita los accesos directos de Inicio y Escritorio |

---

## Requisitos

- Windows 10 u 11
- PowerShell 5.1 (el que ya viene con Windows) o superior
- **No** requiere permisos de administrador

---

## Problemas conocidos

**No pasa nada al apretar `Ctrl+Alt+J`.**
Puede que otra aplicación ya tenga tomado ese atajo. Al arrancar, el script
muestra un globo de aviso si no pudo registrarlo. Usá el menú del ícono, o
cambiá la tecla como se explica arriba.

**"No se puede cargar el archivo... la ejecución de scripts está deshabilitada".**
Estás corriendo el `.ps1` directo con una política restrictiva. Usá `Iniciar.vbs`,
que ya pasa `-ExecutionPolicy Bypass`.

**El ícono queda en la bandeja después de cerrarlo.**
Pasa si el proceso se mató a la fuerza en vez de usar *Salir*. Pasale el mouse
por encima y desaparece.

**No evita el bloqueo.**
Si el bloqueo viene de una política de dominio más agresiva que el timer de
inactividad estándar, o de un agente de seguridad corporativo, esto no lo
esquiva. Fijate cuál es tu límite real con:

```powershell
powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE
```

---

## Antes de usarlo en una máquina del trabajo

Esto evita de hecho el bloqueo por inactividad, que en muchos lados es una
política de seguridad. Si la PC es corporativa, chequealo con IT antes de
dejarlo corriendo todo el día. Y no lo dejes activo si te vas del escritorio:
el bloqueo automático existe por algo.

---

## Licencia

MIT — ver [LICENSE](LICENSE).
