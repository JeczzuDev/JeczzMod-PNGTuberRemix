# Runs the MODS test install (deployed with deploy_to_test.sh --selftest) until the
# self-test prints DONE, closes it, and prints the mod/test lines and engine errors.
# With -WatchFile (e.g. your real .pngRemix model), also reports whether that
# file changed during the run.
param([int]$TimeoutSec = 60, [string]$WatchFile = "")
$M = Join-Path $PSScriptRoot "..\PNGTubeRemix Windows MODS" | Resolve-Path
if ($WatchFile) { $before = (Get-Item $WatchFile).LastWriteTime }
$log = "$env:TEMP\jeczz_selftest.log"; $err = "$env:TEMP\jeczz_selftest.err"
Start-Process -FilePath "$M\PNGTube Remix.console.exe" -WorkingDirectory $M -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Minimized | Out-Null
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline -and -not (Select-String -Path $log -Pattern 'JeczzTest\] DONE' -Quiet)) { Start-Sleep -Milliseconds 500 }
Get-Process | Where-Object { $_.Path -like "$M\*" } | Stop-Process -Force
if ($WatchFile) { "watched file untouched: " + ((Get-Item $WatchFile).LastWriteTime -eq $before) }
Get-Content $log, $err | Where-Object { $_ -match 'Jeczz|SCRIPT ERROR|^ERROR|Parse Error|^\s+at: ' }
