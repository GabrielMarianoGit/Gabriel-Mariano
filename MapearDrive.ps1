# Nome da tarefa
$TaskName = "MapearDriveL"

# Caminho de rede a mapear
$NetworkPath = "\\libra.stn.intra\Corporativo\Grupos"

# Script que será executado no logon (PowerShell)
$ScriptContent = @"
# Remove o drive L: caso já exista
try {
    if (Get-PSDrive -Name L -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name L -Force -ErrorAction SilentlyContinue
    }
} catch {}

# Cria o drive L:
New-PSDrive -Name L -PSProvider FileSystem -Root "$NetworkPath" -Persist -Scope Global
"@

# Caminhos dos arquivos
$ScriptsFolder = "C:\Scripts"
$ScriptPath    = Join-Path $ScriptsFolder "MapearDriveL.ps1"
$VbsPath       = Join-Path $ScriptsFolder "RunHidden.vbs"

# Garante que a pasta exista
New-Item -ItemType Directory -Path $ScriptsFolder -Force | Out-Null

# Escreve o script .ps1
Set-Content -Path $ScriptPath -Value $ScriptContent -Force -Encoding UTF8

# Cria o VBS que executa o PowerShell oculto (WindowStyle 0, sem aguardar)
$VbsContent = @"
Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$ScriptPath""", 0, False
"@

# VBS deve ser ASCII/ANSI para evitar caracteres estranhos
Set-Content -Path $VbsPath -Value $VbsContent -Force -Encoding ASCII

# Ação da tarefa: executa o VBS (que chama o PS de forma oculta)
$Action   = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$VbsPath`""

# Trigger: rodar em todo logon de usuário
$Trigger  = New-ScheduledTaskTrigger -AtLogOn

# Principal: usar o SID do grupo Builtin\Users (independente do idioma do SO)
$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited

# Configurações da tarefa
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8

# Se já existir, remove e recria para evitar conflito de propriedades
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Registra a tarefa
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings