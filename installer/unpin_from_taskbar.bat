@echo off
set "EXE=%~1"
if "%EXE%"=="" exit /b 1
powershell -NoProfile -Command ^
"try { $s = New-Object -ComObject Shell.Application; $f = $s.Namespace([System.IO.Path]::GetDirectoryName('%EXE%')); $l = $f.ParseName([System.IO.Path]::GetFileName('%EXE%')); if ($l) { $v = $l.Verbs() | Where-Object { $_.Name -like '*unpin from ta*' }; if ($v) { $v.DoIt() } } } catch {}"
