@echo off
echo --- DIAGNOSTICO FLUTTER --- > debug_env.log
echo Data/Hora: %DATE% %TIME% >> debug_env.log

echo. >> debug_env.log
echo --- PATH --- >> debug_env.log
echo %PATH% >> debug_env.log

echo. >> debug_env.log
echo --- WHERE FLUTTER --- >> debug_env.log
where flutter >> debug_env.log 2>&1

echo. >> debug_env.log
echo --- BUSCA NO DISCO C (DIRETO) --- >> debug_env.log
if exist C:\flutter\bin\flutter.bat (echo Localizado em C:\flutter\bin >> debug_env.log) else (echo Nao encontrado em C:\flutter\bin >> debug_env.log)

echo. >> debug_env.log
echo --- BUSCA NO DISCO D (DIRETO) --- >> debug_env.log
if exist D:\flutter\bin\flutter.bat (echo Localizado em D:\flutter\bin >> debug_env.log) else (echo Nao encontrado em D:\flutter\bin >> debug_env.log)

echo. >> debug_env.log
echo --- USUARIO ATUAL --- >> debug_env.log
whoami >> debug_env.log

echo --- FIM --- >> debug_env.log
