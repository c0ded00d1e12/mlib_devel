@echo off
::##################################################################################
::                                                                                 #
:: DO NOT PUT LOCAL CONFIGURATION INFORMATION IN THIS FILE!                        #
::                                                                                 #
::##################################################################################
::                                                                                 #
:: This "startsg.bat" script is used to start the CASPER XSG/FPGA toolflow.        #
::                                                                                 #
:: Put local definitions in "startsg_win.local.bat" in the same directory as this  #
:: file. At a minimum, the "startsg_win.local.bat" file should define MATLAB_PATH  #
:: and XILINX_PATH environment variables that point to the base directory          #
:: of the respective installation directories.  You should define the              #
:: PLATFORM variable (probably as lin64) in that file as well. You should          #
:: define the JASPER_BACKEND variable (probably as vivado) in that file as         #
:: well.                                                                           #
::                                                                                 #
::                                                                                 # 
:: See the `startsg.local.example` file for an example.                            #
::                                                                                 #
::##################################################################################

setlocal ENABLEDELAYEDEXPANSION & :: if you don't do this then in a for loop the variable will only update once

:: Find canonical ("real") directory of this script
SET "SCRIPT_DIR=%~dp0"
SET "SCRIPT_BASE=%~n0" & :: no file extension

:: If local defs file passed on command line, use it
if not "%~1"=="" (
	SET LOCALDEFS="%~1"
) else if exist ".\%SCRIPT_BASE%.local.bat" ( REM Look for local defs in current directory
	SET "LOCALDEFS=.\%SCRIPT_BASE%.local.bat"
) else if exist "%SCRIPT_DIR%%SCRIPT_BASE%.local.bat" ( REM Look in the directory where this script is stored
	SET "LOCALDEFS=%SCRIPT_DIR%%SCRIPT_BASE%.local.bat"
)

:: Error if we didn't find anything
if not "%LOCALDEFS%"=="" if exist "%LOCALDEFS%" (
	echo Found environment variables
) else if not "%~1"=="" (
	echo ERROR: Local environment file "%LOCALDEFS%" not found.
	exit /b 1
) else (
	echo WARNING: Local environment file not found.
)

call "%LOCALDEFS%"
:: Verify that environment paths are reasonable
:: MATLAB path
if "%MATLAB_PATH%"=="" (
	echo ERROR: MATLAB_PATH is not defined.
	exit /b 1       
) else if not exist "%MATLAB_PATH%" (
	echo ERROR: MATLAB_PATH "%MATLAB_PATH%" does not exist
	exit /b 1
)

:: Composer path
if "%COMPOSER_PATH%"=="" (
	echo ERROR: COMPOSER_PATH is not defined.
	exit /b 1       
) else if not exist "%COMPOSER_PATH%" (
	echo ERROR: COMPOSER_PATH "%COMPOSER_PATH%" does not exist
	exit /b 1
)

:: Xilinx path
if "%XILINX_PATH%"=="" (
	echo ERROR: XILINX_PATH is not defined.
	exit /b 1       
) else if not exist "%XILINX_PATH%" (
	echo ERROR: XILINX_PATH "%XILINX_PATH%" does not exist
	exit /b 1
)

:: Platform
if "%PLATFORM%"=="" (
	echo WARNING: PLATFORM is not defined, assuming "win64"
	SET "PLATFORM=win64"
)

:: Jasper backend
if "%JASPER_BACKEND%"=="" (
	echo WARNING: JASPER_BACKEND is not defined, assuming "vitis"
)
:: vitis location
if "VITIS_PATH"=="" if "%JASPER_BACKEND%"=="vitis" (
	echo ERROR: VITIS_PATH is not defined
	exit /b 1
)

:: If not yet defined, set MLIB_DEVEL_PATH based on canonicalized directory of
:: this script.  This is probably what you want, so just don't define it :: elsewhere.
if "%MLIB_DEVEL_PATH%"=="" (
	SET "MLIB_DEVEL_PATH=%SCRIPT_DIR%"
)

:: Check that casper_library exists and is writable
if not exist "%MLIB_DEVEL_PATH%casper_library" (
	echo ERROR: %MLIB_DEVEL_PATH%\casper_library not found
	exit /b 1
)

SET current_user=%USERDOMAIN%\%USERNAME%
icacls .\casper_library | findstr /i %current_user% | findstr ([FM]) >nul
if %errorlevel%==0 (
	echo %current_user% has modify or full privileges.
) else (
	echo "ERROR: %current_user% does not have modify/full privileges"
	exit /b 1
)

:: Check for a custom python environment to load
if not "%CASPER_PYTHON_VENV_ON_START%"=="" if exist "%CASPER_PYTHON_VENV_ON_START%" (
	"%CASPER_PYTHON_VENV_ON_START%Scripts\activate"
) else if not "%CASPER_PYTHON_VENV_ON_START%"=="" (
	echo ERROR: Python venv not found at "%CASPER_PYTHON_VENV_ON_START%"
	exit /b 1
)

:: If user has defined HDL_DSP_DEVEL_PATH, include relevant libraries
if not "%HDL_DSP_DEVEL_PATH"=="" (
	if exist "%HDL_DSP_DEVEL_PATH%" (
    		echo Using DSP HDL libraries from "%HDL_DSP_DEVEL_PATH%"
		REM More stuff
		if exist "%HDL_DSP_DEVEL_PATH%wrappers\simulink\" (
			pushd "%HDL_DSP_DEVEL_PATH%"
			SET "HDL_SL_DEVEL_PATH=%CD%\wrappers\simulink"
			echo Found DSP Simulink bindings at "%DSP_HDL_SL_PATH%"
		else
			echo Error finding DSP HDL simulink libraries at "%HDL_DSP_DEVEL_PATH%/wrappers/simulink"
			echo Continuing without DSP HDL libraries
			SET DSP_HDL_SL_PATH=""
		    fi
		) else (
			echo ERROR: "%HDL_DSP_DEVEL_PATH%" does not exist
			exit /b 1
		)
	)
)


:: Show environment essentials (echo paths etc)
for /f %%i in ('where python') DO (
	SET this_python=%%i
	goto :done
)
:done

echo Using MATLAB_PATH="%MATLAB_PATH%"
echo Using XILINX_PATH="%XILINX_PATH%"
echo Using COMPOSER_PATH="%COMPOSER_PATH%"
echo Using VITIS_PATH="%VITIS_PATH%"
echo Using PLATFORM="%PLATFORM%"
echo Using MLIB_DEVEL_PATH="%MLIB_DEVEL_PATH%"
echo Using JASPER_BACKEND="%JASPER_BACKEND%"
echo Using XML2VHDL_PATH="%XML2VHDL_PATH%"
echo Using LD_PRELOAD="%LD_PRELOAD%"
echo Using DSP_HDL_DEVEL_PATH="%HDL_DSP_DEVEL_PATH%"
echo Using python: "%this_python%'


:: Finish environment setup
SET SYSGEN_SCRIPT=%MLIB_DEVEL_PATH%\startsg
SET XPS_BASE_PATH=%MLIB_DEVEL_PATH%\xps_base
SET MATLAB=%MATLAB_PATH%
SET CASPER_BASE_PATH=%MLIB_DEVEL_PATH%
SET HDL_ROOT=%CASPER_BASE_PATH%\jasper_library\hdl_sources

if exist "%COMPOSER_PATH%settings64.bat" ( REM file exists
	if not exist "%COMPOSER_PATH%settings64.bat\" ( REM not a directory
		call "%COMPOSER_PATH%settings64.bat"
	) else (
		echo ERROR: Xilinx settings script "%COMPOSER_PATH%settings64.bat" not found
		exit \b 1
	)
)

call set result=%PATH:%MATLAB_PATH%bin=%
if "%result%"=="%PATH%" (
	SET "PATH=%MATLAB_PATH%bin;%PATH%"
)

REM icacls can be used if further permissions are necessary
REM # Set umask to allow group writes
REM umask 002

set "MYVIVADO="

echo %CMDCMDLINE% | findstr /i "call" >nul
if %errorlevel% neq 0 (
	SET CASPER_STARTUP_DIR=%cd%

	echo Changing to directory: "%MLIB_DEVEL_PATH%"
	REM Change into the MLIB_DEVEL_PATH directory
	REM (so MATLAB will find our startup.m file).
	cd "%MLIB_DEVEL_PATH%"

  	REM Start sysgen in OPENGL graphics mode to prevent java errors
  	echo Starting model_composer
  	REM "${COMPOSER_PATH}/bin/model_composer" 
  	model_composer.bat -matlab "%MATLAB_PATH%" -hls "%VITIS_PATH%" -vivado "%XILINX_PATH%"
)
