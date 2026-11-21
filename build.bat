@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title VM VIRTUAL - build do QEMU-wasm
echo ==================================================
echo   Compilar QEMU-wasm (Emscripten) via WSL
echo ==================================================
where wsl >nul 2>&1
if errorlevel 1 goto nowsl
wsl -l -q <nul >nul 2>&1
if errorlevel 1 goto nodistro
echo.
echo O configure do QEMU precisa de shell Linux, entao a compilacao roda no WSL.
echo O em++ tambem tem de ser o do Linux (WSL). O emsdk do Windows nao serve.
echo.
set "EMPP="
set /p "EMPP=Caminho do em++ no WSL (ex.: /home/voce/emsdk/upstream/emscripten/em++), Enter = instalar emsdk 4.0.10: "
if "%EMPP:~1,1%"==":" (
  echo.
  echo [AVISO] Isso e um caminho do Windows. O emsdk do Windows NAO funciona dentro do WSL.
  echo         Vou instalar um emsdk Linux 4.0.10 em ~/emsdk no WSL.
  set "EMPP="
)
set "SRC="
set /p "SRC=Pasta do codigo-fonte (Windows ou WSL), Enter = clonar ktock/qemu-wasm em ~/qemu-wasm-src: "
set "OUT=%~dp0dist"
set /p "OUT=Pasta de saida [%~dp0dist]: "
set "SDL=n"
set /p "SDL=Tentar SDL2 para tela (experimental)? s/n [n]: "
set "ARCH=wasm32"
set /p "ARCH=Arquitetura wasm32 ou wasm64 [wasm32]: "
set "MAXMEM=4GB"
set /p "MAXMEM=Memoria maxima da aba [4GB]: "
set "JOBS=%NUMBER_OF_PROCESSORS%"
set /p "JOBS=Threads de compilacao [%NUMBER_OF_PROCESSORS%]: "
set "EMPP=%EMPP:"=%"
set "SRC=%SRC:"=%"
set "OUT=%OUT:"=%"
set "SRC=%SRC:\=/%"
set "OUT=%OUT:\=/%"
echo.
echo Iniciando no WSL...
wsl --cd "%~dp0." bash ./build.sh "%EMPP%" "%SRC%" "%OUT%" "%SDL%" "%ARCH%" "%MAXMEM%" "%JOBS%"
if errorlevel 1 goto fail
echo.
echo Concluido. Resultado em: %~dp0web\images
pause
exit /b 0
:nodistro
echo.
echo [ERRO] O WSL nao esta pronto (sem distribuicao Linux instalada ou WSL quebrado).
echo   1. Abra o PowerShell como Administrador e rode:  wsl --install -d Ubuntu --web-download
echo   2. Reinicie o PC e abra o "Ubuntu" no menu Iniciar para criar usuario/senha.
echo   3. Rode este build.bat de novo.
echo   Se der "Falha catastrofica": ative a virtualizacao (VT-x/SVM) na BIOS, rode Windows Update,
echo   execute  wsl --update --web-download  e reinicie. Sem WSL, use a compilacao na nuvem
echo   (GitHub Actions): veja LEIA-ME-NUVEM.txt
pause
exit /b 1
:nowsl
echo [ERRO] WSL nao encontrado. Instale com: wsl --install
pause
exit /b 1
:fail
echo.
echo [ERRO] A compilacao falhou. Leia as mensagens acima.
pause
exit /b 1
