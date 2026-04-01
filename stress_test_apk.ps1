param (
    [string]$PackageName = "com.antigravity.reabauditiva",
    [int]$DurationSeconds = 300
)

Write-Host "Iniciando Stress Test Clínico - DSP Áudio Engine" -ForegroundColor Cyan
Write-Host "Alvo: $PackageName | Duração: $DurationSeconds segundos" -ForegroundColor Cyan

# 1. Garante que o app está rodando
adb shell am force-stop $PackageName
adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 5

# 2. Descobre o PID Principal do App
$pidStr = adb shell pidof $PackageName
if (-not $pidStr) {
    Write-Host "Erro: App não está rodando." -ForegroundColor Red
    exit
}
Write-Host "PID do App detectado: $pidStr" -ForegroundColor Green

# 3. Descobre o TID (Thread ID) do Oboe/Audio
# O thread do Oboe normalmente tem nome 'OboeAudio' ou 'AAudio'
$audioTid = adb shell "top -H -n 1 -p $pidStr | grep -E 'Oboe|AAudio'" | ForEach-Object { ($_ -split '\s+')[1] }
if (-not $audioTid) {
    Write-Host "Aviso: Thread do Oboe não identificada diretamente. Usando monitoramento global de threads." -ForegroundColor Yellow
} else {
    Write-Host "Thread de Áudio (DSP) isolada no TID: $audioTid" -ForegroundColor Green
}

# 4. Inicia Monitoramento Contínuo (Core Affinity e Temperatura)
$endTime = (Get-Date).AddSeconds($DurationSeconds)

Write-Host "`n[MONITOR DE HARDWARE EM TEMPO REAL]" -ForegroundColor Magenta
Write-Host "TID`tCORE`tFREQ(MHz)`tCPU%`tTEMP(°C)`tSTATUS" -ForegroundColor Gray

while ((Get-Date) -lt $endTime) {
    # Coleta qual core a thread de áudio está rodando (Coluna P = Last Used Processor)
    # top output format: PID TID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ P ARGS
    $topLine = adb shell "top -H -n 1 -p $pidStr -o TID,P,%CPU,CMD | grep -E 'Oboe|AAudio'"
    
    $core = "??"
    $cpuUsage = "??"
    if ($topLine -match '\d+') {
        $parts = $topLine.Trim() -split '\s+'
        $core = $parts[1]
        $cpuUsage = $parts[2]
    }

    # Leitura de Throttling Térmico (Ex: sensor 0 comum para SOC)
    $tempRaw = adb shell "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null"
    $tempC = 0
    if ($tempRaw -match '\d+') {
        $tempC = [math]::Round([int]$tempRaw / 1000, 1) # Miligraus para Graus Celsius
    }

    # Frequência Atual do Core em uso
    $freqRaw = "?"
    if ($core -ne "??") {
        $freqRaw = adb shell "cat /sys/devices/system/cpu/cpu$core/cpufreq/scaling_cur_freq 2>/dev/null"
        if ($freqRaw -match '\d+') {
            $freqRaw = [math]::Round([int]$freqRaw / 1000) # MHz
        }
    }

    # Lógica de Diagnóstico
    $status = "OK/SAFE"
    $color = "Green"
    
    if ($tempC -gt 45) {
        $status = "THERMAL THROTTLING WARNING"
        $color = "Yellow"
    }
    if ($tempC -gt 55) {
        $status = "CRITICAL THROTTLING - DROPS IMMINENT"
        $color = "Red"
    }
    # Assumindo arquitetura big.LITTLE (Cores 0-3 = LITTLE, 4-7 = BIG)
    if ($core -ne "??" -and [int]$core -lt 4) {
        $status += " (LITTLE CORE DETECTED)"
        if ($color -eq "Green") { $color = "Yellow" }
    }

    Write-Host "$audioTid`tCPU$core`t$freqRaw`t`t$cpuUsage%`t${tempC}°C`t$status" -ForegroundColor $color
    
    Start-Sleep -Seconds 2
}

Write-Host "Teste Concluído." -ForegroundColor Cyan
