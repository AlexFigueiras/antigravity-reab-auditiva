:: =====================================================
:: GUIA DE BUNDLES - PROJETO REAB-AUDITIVA
:: =====================================================
:: bundle "Essentials"           -> Base para qualquer tarefa
:: bundle "Agent Architect"     -> Fluxos de voz e IA (Core do App)
:: bundle "Full-Stack Developer" -> Backend, Supabase e Stripe
:: bundle "Web Designer"         -> Interface (UI/UX) e CSS
:: =====================================================

@echo off
setlocal enabledelayedexpansion

:: --- CONFIGURACAO DE CAMINHOS ---
:: Usamos aspas em tudo para evitar que o ponto do .agent quebre o script
set "PROJETO_SKILLS=C:\Users\Alex\antigravity-reab-auditiva\.agent\skills"
set "LIB_OFFICIAL=C:\Users\Alex\biblioteca-skills\skills"
set "LIB_PROPRIA=C:\Users\Alex\biblioteca-skills-proprias"

if "%~1"=="" (
    echo [!] Erro: Informe o bundle. Ex: bundle essentials
    exit /b
)

echo [1/3] LIMPEZA NUCLEAR: Resetando pasta .agent\skills...
:: Removemos a pasta inteira e recriamos para garantir limpeza total
if exist "%PROJETO_SKILLS%" (
    rd /s /q "%PROJETO_SKILLS%"
)
mkdir "%PROJETO_SKILLS%"

echo [2/3] INSTALANDO BUNDLES SELECIONADOS...

:: O loop agora percorre todos os argumentos passados
for %%B in (%*) do (
    set "TARGET=%%~B"
    echo [+] Processando: !TARGET!

    :: IF /I torna a busca insensivel a maiusculas/minusculas
    if /i "!TARGET!"=="Essentials" (
        echo     - Carregando ferramentas base...
        for %%S in (concise-planning lint-and-validate git-pushing kaizen systematic-debugging) do (
            robocopy "%LIB_OFFICIAL%\%%S" "%PROJETO_SKILLS%\%%S" /E /NFL /NDL /NJH /NJS /R:0 /W:0 >nul
        )
    )

    if /i "!TARGET!"=="Agent Architect" (
        echo     - Carregando ferramentas de IA e Agentes...
        for %%S in (agent-evaluation langgraph mcp-builder prompt-engineering ai-agents-architect rag-engineer) do (
            robocopy "%LIB_OFFICIAL%\%%S" "%PROJETO_SKILLS%\%%S" /E /NFL /NDL /NJH /NJS /R:0 /W:0 >nul
        )
    )

    if /i "!TARGET!"=="Full-Stack Developer" (
        echo     - Carregando ferramentas de Backend e APIs...
        for %%S in (senior-fullstack frontend-developer backend-dev-guidelines api-patterns database-design stripe-integration) do (
            robocopy "%LIB_OFFICIAL%\%%S" "%PROJETO_SKILLS%\%%S" /E /NFL /NDL /NJH /NJS /R:0 /W:0 >nul
        )
    )
)

echo [3/3] INJETANDO SKILLS PROPRIETARIAS...
robocopy "%LIB_PROPRIA%\AUDIOLOGIA_CLINICA" "%PROJETO_SKILLS%\AUDIOLOGIA_CLINICA" /E /NFL /NDL /NJH /NJS /R:0 /W:0 >nul
robocopy "%LIB_PROPRIA%\DSP_AUDIO_ENGINE" "%PROJETO_SKILLS%\DSP_AUDIO_ENGINE" /E /NFL /NDL /NJH /NJS /R:0 /W:0 >nul

echo.
echo =====================================================
echo SUCESSO: Ambiente configurado e proprietario protegido.
echo =====================================================