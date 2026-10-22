# JeczzMod: extensiones de Follow Movement para PNGTube Remix

*Unofficial mod for [PNGTube Remix](https://github.com/MudkipWorld/PNGTuber-Remix) 1.4.5 (Windows) that extends the Follow Movement section: per-axis mouse and stick options, and a secondary input source (e.g. mouse + controller at the same time). Documentation is in Spanish.*

> **Mod no oficial.** No está afiliado ni respaldado por MudkipWorld ni por el proyecto PNGTube Remix. Úsalo bajo tu propia responsabilidad y respalda tus modelos antes de instalarlo.

## Qué agrega

En **Follow Movement** (Position, Rotation y Scale):

- **Opciones por eje** en los selectores *Follow Option*: `Mouse X`, `Mouse Y`, `Controller (Left) X/Y` y `Controller (Right) X/Y`. Solo ese eje mueve, gira o escala el sprite.
- **Sticks separados de los botones**: en la app original, la cruceta cuenta como el stick izquierdo y A/B/X/Y como el derecho. Con el mod, los sticks responden solo al stick, y `D-pad` y `Face buttons (A/B/X/Y)` pasan a ser fuentes propias.
- **Fuente secundaria** (`+ Secondary`) bajo cada selector, para combinar dos entradas. El selector **Combine** elige cómo se combinan:
  - **Last active** (por defecto): manda la última entrada que usaste; la otra se ignora hasta que la uses.
  - **Sum**: los efectos se suman, sin salir del rango mín/máx.
  - **Secondary priority**: la secundaria manda mientras la usas y al soltarla vuelve a la principal.
- **Correcciones** de la 1.4.5:
  - En Position, el stick y el teclado llegan al límite configurado de cada lado. La app original solo llegaba a la mitad con rangos asimétricos.
  - Con "Follow mouse velocity", Mouse X/Y funcionan también en Rotation y Scale.

Los detalles para usuarios están en [`mod/LEEME.txt`](mod/LEEME.txt), que también se incluye en cada paquete.

## Instalación

1. Descarga el `.zip` de la última versión en *Releases*.
2. Sigue `LEEME.txt`: copias `override.cfg` y la carpeta `mods` junto a `PNGTube Remix.exe`. Para quitarlo, usa `Desinstalar JeczzMod.bat`.

**Compatibilidad**
- Solo **PNGTube Remix 1.4.5**. Con otra versión de la app, el mod se desactiva solo y la app funciona normal.
- Los modelos guardados con opciones del mod se abren en la app sin el mod, pero esas opciones se ignoran.

## Cómo funciona

El mod no modifica ningún archivo de la app. Godot lee el `override.cfg` que está junto al ejecutable, y ese archivo registra `mods/jeczz_mod_loader.gd` como autoload. El cargador:

1. Comprueba la versión de la app.
2. Cuando aparece un nodo de seguimiento (`FollowPosition`/`Rotation`/`Scale`), le cambia el script por una subclase del mod (`mods/follow_ext/*_ext.gd`), conservando sus valores. Las escenas de la app ya están en caché cuando el mod arranca, así que reemplazar los scripts por ruta no sirve.
3. Añade las opciones nuevas al final de los selectores (la app guarda el índice, así que los modelos existentes no cambian) y crea las filas `+ Secondary` y `Combine`.

Los ajustes nuevos se guardan en el modelo, por estado, como claves `jz_follow_*` de `sprite_data`.

## Desarrollo

### Carpetas esperadas

```
<carpeta común>/
├─ PNGTubeRemix Windows/        instalación de uso diario
├─ PNGTubeRemix Windows MODS/   copia de pruebas de la instalación
│   ├─ TestModels/<modelo>_test.pngRemix
│   └─ mods/SANDBOX             (lo crea deploy_to_test.sh)
└─ PNGTubeRemix ModDev/         este repositorio
```

### Preparar el entorno

1. **Copia de pruebas:** copia la carpeta de la app completa como `PNGTubeRemix Windows MODS`. Pon una copia de tu modelo en `TestModels/<nombre>_test.pngRemix`.
   - Con el archivo `mods/SANDBOX` (lo crea el script de despliegue), el mod redirige la carga automática a esa copia. Es necesario porque la app guarda encima del modelo al cerrar si está activado *save on exit*.
2. **Código original de la 1.4.5** como referencia (no se versiona):
   - Descarga [GDRE Tools v2.7.4](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4) en `tools/gdre-2.7.4/`.
   - Ejecuta:
     ```
     tools/gdre-2.7.4/gdre_tools.exe --headless --recover="<copia MODS>/PNGTube Remix.pck" --output="recovered_1.4.5"
     ```
   - Los scripts del mod extienden y copian partes de `Scripts/Objects/ObjectComponents/follow_*.gd` de esa versión.

### Flujo de trabajo

| Paso | Comando |
|---|---|
| Desplegar en la copia de pruebas | `sh deploy_to_test.sh` (desde Bash) |
| Desplegar con autoprueba | `sh deploy_to_test.sh --selftest` y después `./run_selftest.ps1 [-WatchFile <modelo real>]` en PowerShell |
| Empaquetar | subir `MOD_VERSION` en `mod/mods/jeczz_mod_loader.gd` y ejecutar `sh build_package.sh` → `dist/JeczzMod-FollowMovement-<versión>.zip` |

- **La autoprueba** (`mod/tests/axis_selftest.gd`):
  - simula los sticks con `Input.action_press` y compara los resultados con el cálculo esperado; no mueve el cursor;
  - **cambia los ajustes de un sprite**, así que nunca la dejes activa para probar a mano.
- **Diagnóstico** (`mod/tests/follow_diag.gd`): es de solo lectura. Escribe la configuración y el uso real del stick en `mods/_tests/diag.log`.
- **Inspector de modelos** (`mod/tests/model_inspect.gd`): lee un `.pngRemix` como datos, sin cargarlo en la app, y escribe en `mods/_tests/inspect.log` el árbol de sprites con su Follow Movement y sus físicas.
  - Se registra como autoload extra en la copia de pruebas.
  - Se ejecuta con `"PNGTube Remix.console.exe" -- --jz-inspect=<ruta del modelo>`.
- **Comparador de modelos** (`mod/tests/model_diff.gd`): lee dos `.pngRemix` como datos y escribe en `mods/_tests/diff.log` cada valor distinto, emparejando los sprites por id.
  - Se ejecuta con `-- --jz-diff-a=<modelo> --jz-diff-b=<modelo>`.
  - Sirve para comprobar que una copia de prueba solo difiere en lo esperado antes de copiarla sobre el modelo real.
- **Prueba de físicas con stick** (`mod/tests/stick_physics_trial.gd`): solo para la copia de pruebas con `SANDBOX`. Añade "+ Secondary: Controller (Left) X" a la raíz y a la cabeza, simula el stick, registra el estiramiento y el balanceo de los sprites indicados y guarda el modelo de prueba.
  - Se ejecuta con `-- --jz-root=<sprite> --jz-head=<sprite> --jz-watch=<sprite>,<sprite>`.

## Versiones

| Versión | Cambios |
|---|---|
| 1.0.0 | Mouse X / Mouse Y |
| 1.1.0 | Fuente secundaria y Combine (Last active, Sum, Secondary priority); alcance completo del stick y Position Snap en Position |
| 1.2.0 | Ejes individuales de los sticks |
| 1.3.0 | Sticks separados de la cruceta y de A/B/X/Y; fuentes nuevas `D-pad` y `Face buttons` |
| 1.3.1 | Last active / Secondary priority: al cambiar de fuente, el sprite ya no da un tirón hacia el centro |

## Licencia

- **Código propio:** publicado con los mismos términos que PNGTube Remix (ver [`LICENSE`](LICENSE)). Uso no comercial libre; el uso comercial requiere permiso.
- **Fragmentos de la app:** algunos archivos contienen fragmentos de PNGTube Remix © MudkipWorld, bajo su licencia (ver [`NOTICE`](NOTICE)).
