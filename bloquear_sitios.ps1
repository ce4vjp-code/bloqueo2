<#
.SYNOPSIS
  Bloquea sitios para adultos y de apuestas en línea en Windows.

.DESCRIPTION
  Capa 1: agrega una lista de dominios al archivo hosts (porno + apuestas).
  Capa 2: configura DNS familiar de Cloudflare (1.1.1.3 / 1.0.0.3), que filtra malware y contenido adulto.
  Capa 3: desactiva DNS-sobre-HTTPS en Chrome y Edge para que no se salten el bloqueo.

.USO (PowerShell como Administrador)
  .\bloquear_sitios.ps1            -> instala el bloqueo
  .\bloquear_sitios.ps1 -Quitar    -> revierte todo
#>

param([switch]$Quitar)

# ---------- Verificar administrador ----------
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host "Ejecuta este script como Administrador." -ForegroundColor Red
    exit 1
}

$hostsPath   = "$env:SystemRoot\System32\drivers\etc\hosts"
$marcaInicio = "# >>> BLOQUEO-SITIOS INICIO >>>"
$marcaFin    = "# <<< BLOQUEO-SITIOS FIN <<<"
$listaUrl    = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-porn/hosts"

# Dominios extra que quieras bloquear a mano (apuestas populares en Chile/LatAm, etc.)
$extra = @(
    "bet365.com","www.bet365.com","betano.com","www.betano.com","1xbet.com","www.1xbet.com",
    "betway.com","www.betway.com","codere.com","www.codere.com","caliente.mx","www.caliente.mx",
    "stake.com","www.stake.com","pokerstars.com","www.pokerstars.com","betsson.com","www.betsson.com",
    "bwin.com","www.bwin.com","888casino.com","www.888casino.com","williamhill.com","www.williamhill.com"
)

# Detectar adaptadores de red activos
function Get-Adaptadores { Get-NetAdapter | Where-Object { $_.Status -eq "Up" } }

# Quitar el bloque anterior del archivo hosts (si existe)
function Limpiar-Hosts {
    $lineas = Get-Content $hostsPath
    $salida = New-Object System.Collections.Generic.List[string]
    $dentro = $false
    foreach ($l in $lineas) {
        if ($l -eq $marcaInicio) { $dentro = $true; continue }
        if ($l -eq $marcaFin)    { $dentro = $false; continue }
        if (-not $dentro) { $salida.Add($l) }
    }
    Set-Content -Path $hostsPath -Value $salida -Encoding ASCII
}

# Políticas de Chrome/Edge para desactivar DNS seguro (DoH)
$politicas = @(
    "HKLM:\SOFTWARE\Policies\Google\Chrome",
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
)

# ---------- MODO QUITAR ----------
if ($Quitar) {
    Write-Host "Revirtiendo bloqueo..." -ForegroundColor Yellow
    Limpiar-Hosts
    foreach ($a in Get-Adaptadores) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses }
    foreach ($p in $politicas) {
        if (Test-Path $p) { Remove-ItemProperty -Path $p -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue }
    }
    ipconfig /flushdns | Out-Null
    Write-Host "Listo. Bloqueo eliminado." -ForegroundColor Green
    exit 0
}

# ---------- MODO INSTALAR ----------
Write-Host "Instalando bloqueo..." -ForegroundColor Cyan

# 1) Respaldo del archivo hosts
$respaldo = "$hostsPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $hostsPath $respaldo
Write-Host "Respaldo creado: $respaldo"

# 2) Descargar lista y armar bloque
$dominios = New-Object System.Collections.Generic.HashSet[string]
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $contenido = (Invoke-WebRequest -Uri $listaUrl -UseBasicParsing -TimeoutSec 60).Content -split "`n"
    foreach ($l in $contenido) {
        if ($l -match '^\s*0\.0\.0\.0\s+(\S+)') {
            $d = $Matches[1]
            if ($d -ne "0.0.0.0" -and $d -notmatch '^(localhost|local|broadcasthost)') { [void]$dominios.Add($d) }
        }
    }
    Write-Host "Dominios descargados: $($dominios.Count)"
} catch {
    Write-Host "No se pudo descargar la lista; se usará solo la lista manual." -ForegroundColor Yellow
}
foreach ($e in $extra) { [void]$dominios.Add($e) }

Limpiar-Hosts
$bloque = New-Object System.Collections.Generic.List[string]
$bloque.Add($marcaInicio)
foreach ($d in $dominios) { $bloque.Add("0.0.0.0 $d") }
$bloque.Add($marcaFin)
Add-Content -Path $hostsPath -Value $bloque -Encoding ASCII

# 3) DNS familiar de Cloudflare (bloquea malware + adultos)
foreach ($a in Get-Adaptadores) {
    Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ("1.1.1.3","1.0.0.3")
    Write-Host "DNS configurado en: $($a.Name)"
}

# 4) Desactivar DNS-sobre-HTTPS en Chrome y Edge
foreach ($p in $politicas) {
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "DnsOverHttpsMode" -Value "off" -Type String
}

ipconfig /flushdns | Out-Null
Write-Host "`nListo. Reinicia el navegador para que tome los cambios." -ForegroundColor Green
Write-Host "Para revertir: .\bloquear_sitios.ps1 -Quitar"
