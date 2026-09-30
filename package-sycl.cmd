@echo off
setlocal

echo ======================================================================
echo  Lc0-SYCL: Standalone Release Build ^& Packaging Script
echo ======================================================================

rem --- 1. Detect / Initialize Visual Studio build tools ---
where /q cl
if errorlevel 1 (
  if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do (
      if exist "%%i\VC\Auxiliary\Build\vcvarsall.bat" (
        echo [VS] Initializing Visual Studio tools from: %%i
        call "%%i\VC\Auxiliary\Build\vcvarsall.bat" amd64
      )
    )
  )
)

rem --- 2. Detect / Initialize Intel oneAPI environment ---
where /q icx
if errorlevel 1 (
  if exist "C:\Program Files (x86)\Intel\oneAPI\setvars.bat" (
    echo [oneAPI] Initializing Intel oneAPI environment...
    call "C:\Program Files (x86)\Intel\oneAPI\setvars.bat"
  ) else if exist "C:\Program Files\Intel\oneAPI\setvars.bat" (
    echo [oneAPI] Initializing Intel oneAPI environment...
    call "C:\Program Files\Intel\oneAPI\setvars.bat"
  )
)

rem --- 3. Ensure 7-Zip is in PATH ---
where /q 7z
if errorlevel 1 if exist "%ProgramFiles%\7-Zip" set "PATH=%ProgramFiles%\7-Zip;%PATH%"
where /q 7z
if errorlevel 1 if exist "%ProgramFiles(x86)%\7-Zip" set "PATH=%ProgramFiles(x86)%\7-Zip;%PATH%"
where /q 7z
if errorlevel 1 (
  echo [ERROR] 7-Zip [7z.exe] not found. Please install 7-Zip or add it to PATH.
  pause
  exit /b 1
)

rem --- 4. Resolve Version & Variables ---
set "VERSION="
for /f "tokens=*" %%v in ('git describe --tags --always 2^>nul') do set "VERSION=%%v"
if not defined VERSION set "VERSION=v0.33.0-sycl"
set "NAME=gpu-intel-sycl"
set "APPVEYOR_REPO_TAG_NAME=%VERSION%"
set "APPVEYOR_BUILD_FOLDER=%CD%"
set "CUDA=false"
set "CUDNN=false"
set "OPENCL=false"
set "DX=false"
set "ONNX=false"
if not defined NET set "NET=791556"

rem --- 5. Resolve MKL Paths ---
if defined MKLROOT if not defined MKL_PATH set "MKL_PATH=%MKLROOT%"
if not defined MKL_PATH if exist "C:\Program Files (x86)\Intel\oneAPI\mkl\latest" set "MKL_PATH=C:\Program Files (x86)\Intel\oneAPI\mkl\latest"
if not defined MKL_PATH if exist "C:\Program Files\Intel\oneAPI\mkl\latest" set "MKL_PATH=C:\Program Files\Intel\oneAPI\mkl\latest"
if "%MKL_PATH:~-1%"=="\" set "MKL_PATH=%MKL_PATH:~0,-1%"
if exist "%MKL_PATH%\lib\intel64" (set "MKL_LIB_PATH=%MKL_PATH%\lib\intel64") else (set "MKL_LIB_PATH=%MKL_PATH%\lib")

echo [Target] Version: %VERSION% (%NAME%)
echo [MKL]    Path:    %MKL_PATH%

echo.
echo ======================================================================
echo  Step 1/3: Configuring Meson (Portable Release Configuration)
echo ======================================================================
set CC=cl
set CXX=icx
meson setup build --wipe --buildtype release -Dgtest=false -Dnative_arch=false -Dsycl=l0 -Ddnnl=false -Df16c=false -Dmkl_include="%MKL_PATH%\include" -Dmkl_libdirs="%MKL_LIB_PATH%" -Ddefault_library=static -Db_vscrt=md
if errorlevel 1 (
  echo [ERROR] Meson configuration failed!
  pause
  exit /b 1
)

echo.
echo ======================================================================
echo  Step 2/3: Compiling Lc0 via scripts\appveyor_win_build.cmd (Ninja)
echo ======================================================================
call scripts\appveyor_win_build.cmd
if errorlevel 1 (
  echo [ERROR] Compilation failed!
  pause
  exit /b 1
)

echo.
echo ======================================================================
echo  Step 3/3: Packaging Standalone Release via scripts\appveyor_win_package.cmd
echo ======================================================================
set "OUT_ZIP=lc0-%VERSION%-windows-%NAME%.zip"
if exist "%OUT_ZIP%" del "%OUT_ZIP%"
call scripts\appveyor_win_package.cmd

echo.
echo ======================================================================
echo  Package Verification: %OUT_ZIP%
echo ======================================================================
if exist "%OUT_ZIP%" (
  7z l "%OUT_ZIP%"
  echo.
  echo [SUCCESS] Release package created: %OUT_ZIP%
) else (
  echo [ERROR] Failed to create %OUT_ZIP%!
)

pause
