# bloqueo2

Instalacion.


Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -Command "irm https://raw.githubusercontent.com/ce4vjp-code/bloqueo2/refs/heads/main/bloquear_sitios.ps1| iex"'

desbloqueo

Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ce4vjp-code/bloqueo2/refs/heads/main/bloquear_sitios.ps1))) -Quitar"'
