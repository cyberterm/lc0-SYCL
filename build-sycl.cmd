@echo off
setlocal

rem --- Auto-initialize Visual Studio build tools if cl is not in PATH ---
where /q cl
if errorlevel 1 (
  if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do (
      if exist "%%i\VC\Auxiliary\Build\vcvarsall.bat" (
        echo Initializing Visual Studio build tools from: %%i
        call "%%i\VC\Auxiliary\Build\vcvarsall.bat" amd64
      )
    )
  )
)

rem --- Auto-initialize Intel oneAPI environment if icx is not in PATH ---
where /q icx
if errorlevel 1 (
  if exist "C:\Program Files (x86)\Intel\oneAPI\setvars.bat" (
    echo Initializing Intel oneAPI environment...
    call "C:\Program Files (x86)\Intel\oneAPI\setvars.bat"
  ) else if exist "C:\Program Files\Intel\oneAPI\setvars.bat" (
    echo Initializing Intel oneAPI environment...
    call "C:\Program Files\Intel\oneAPI\setvars.bat"
  )
)

rem 1. Set the following for the options you want to build.
rem SYCL can be off, l0, amd or nvidia.
set SYCL=l0
set CUDNN=true
set CUDA=true
set DX12=false
set OPENCL=false
set MKL=false
set DNNL=false
set OPENBLAS=false
set EIGEN=false
set TEST=false

rem 2. Edit the paths for the build dependencies (or use oneAPI defaults if installed).
set CUDA_PATH=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.0
set CUDNN_PATH=%CUDA_PATH%
set OPENBLAS_PATH=C:\OpenBLAS
if defined MKLROOT if not defined MKL_PATH set "MKL_PATH=%MKLROOT%"
if not defined MKL_PATH set "MKL_PATH=C:\Program Files (x86)\Intel\oneAPI\mkl\latest"
if defined DNNLROOT if not defined DNNL_PATH set "DNNL_PATH=%DNNLROOT%"
if not defined DNNL_PATH set "DNNL_PATH=C:\Program Files (x86)\Intel\oneAPI\dnnl\latest"
set OPENCL_LIB_PATH=%CUDA_PATH%\lib\x64
set OPENCL_INCLUDE_PATH=%CUDA_PATH%\include

rem 3. In most cases you won't need to change anything further down.
echo Deleting build directory:
if exist build rd /s /q build

rem Strip trailing backslash from paths if present
if "%MKL_PATH:~-1%"=="\" set "MKL_PATH=%MKL_PATH:~0,-1%"
if "%DNNL_PATH:~-1%"=="\" set "DNNL_PATH=%DNNL_PATH:~0,-1%"

rem Support both legacy 'intel64' subfolder and modern flattened 'lib' folder
if exist "%MKL_PATH%\lib\intel64" (
  set "MKL_LIB_PATH=%MKL_PATH%\lib\intel64"
) else (
  set "MKL_LIB_PATH=%MKL_PATH%\lib"
)

rem Support both legacy 'cpu_iomp' subfolder and modern flattened structure
if exist "%DNNL_PATH%\cpu_iomp" (
  set "DNNL_PATH=%DNNL_PATH%\cpu_iomp"
) else if not exist "%DNNL_PATH%\include" (
  if exist "%DNNL_PATH%\..\include" set "DNNL_PATH=%DNNL_PATH%\.."
)

rem Use cl for C files to get a resource compiler as needed for zlib.
set CC=cl
set CXX=icx

set BLAS=true
if %MKL%==false if %DNNL%==false if %OPENBLAS%==false if %EIGEN%==false set BLAS=false

if "%CUDA_PATH%"=="%CUDNN_PATH%" (
  set CUDNN_LIB_PATH=%CUDNN_PATH%\lib\x64
  set CUDNN_INCLUDE_PATH=%CUDNN_PATH%\include
) else (
  set CUDNN_LIB_PATH=%CUDA_PATH%\lib\x64,%CUDNN_PATH%\lib\x64
  set CUDNN_INCLUDE_PATH=%CUDA_PATH%\include,%CUDNN_PATH%\include
)

if %CUDNN%==true set PATH=%CUDA_PATH%\bin;%PATH%

meson setup build --buildtype release -Ddx=%DX12% -Dcudnn=%CUDNN% -Dplain_cuda=%CUDA% ^
-Dopencl=%OPENCL% -Dblas=%BLAS% -Dmkl=%MKL% -Dopenblas=%OPENBLAS% -Ddnnl=%DNNL% -Dgtest=%TEST% ^
-Dcudnn_include="%CUDNN_INCLUDE_PATH%" -Dcudnn_libdirs="%CUDNN_LIB_PATH%" ^
-Dmkl_include="%MKL_PATH%\include" -Dmkl_libdirs="%MKL_LIB_PATH%" -Ddnnl_dir="%DNNL_PATH%" ^
-Dopencl_libdirs="%OPENCL_LIB_PATH%" -Dopencl_include="%OPENCL_INCLUDE_PATH%" ^
-Dopenblas_include="%OPENBLAS_PATH%\include" -Dopenblas_libdirs="%OPENBLAS_PATH%\lib" ^
-Ddefault_library=static -Dsycl=%SYCL% -Db_vscrt=md

if errorlevel 1 exit /b

pause

cd build

ninja
