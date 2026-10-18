@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-libchewing.ps1
if errorlevel 1 exit /b %errorlevel%

cmake . -Bbuild -G "Visual Studio 17 2022" -A Win32 -DCMAKE_POLICY_VERSION_MINIMUM=3.5
if errorlevel 1 exit /b %errorlevel%
cmake --build build --config Release
if errorlevel 1 exit /b %errorlevel%

cmake . -Bbuild64 -G "Visual Studio 17 2022" -A x64 -DCMAKE_POLICY_VERSION_MINIMUM=3.5
if errorlevel 1 exit /b %errorlevel%
cmake --build build64 --config Release --target PIMETextService
if errorlevel 1 exit /b %errorlevel%

cmake . -Bbuild_arm64 -G "Visual Studio 17 2022" -A ARM64 -DCMAKE_POLICY_VERSION_MINIMUM=3.5
if errorlevel 1 exit /b %errorlevel%
cmake --build build_arm64 --config Release --target PIMETextService
if errorlevel 1 exit /b %errorlevel%

echo "Start building McBopomofo"
cd McBopomofoWeb
cmd /C npm install
if errorlevel 1 exit /b %errorlevel%
cmd /C npm run build:pime
if errorlevel 1 exit /b %errorlevel%
cd ..

echo "Copy McBopomofo to node\input_methods\McBopomofo"
cmd /C rd /s /q node\input_methods\McBopomofo
cmd /C mkdir node\input_methods\McBopomofo
cmd /C xcopy /s /q /y /f McBopomofoWeb\output\pime node\input_methods\McBopomofo\.
if errorlevel 1 exit /b %errorlevel%
cmd /C del /q node\input_methods\McBopomofo\server.js node\input_methods\McBopomofo\webpack_check.js node\input_methods\McBopomofo\run_*.bat node\input_methods\McBopomofo\README.md node\input_methods\McBopomofo\*.txt

echo "Start building McFoximWeb"
cd McFoximWeb
cmd /C npm install
if errorlevel 1 exit /b %errorlevel%
cmd /C npm run build:pime
if errorlevel 1 exit /b %errorlevel%
cd ..

echo "Copy McFoximWeb to node\input_methods\McFoxim"
cmd /C rd /s /q node\input_methods\McFoxim
cmd /C mkdir node\input_methods\McFoxim
cmd /C xcopy /s /q /y /f McFoximWeb\output\pime node\input_methods\McFoxim\.
if errorlevel 1 exit /b %errorlevel%
cmd /C del /q node\input_methods\McFoxim\server.js node\input_methods\McFoxim\webpack_check.js node\input_methods\McFoxim\run_*.bat node\input_methods\McFoxim\README.md node\input_methods\McFoxim\*.txt

echo "Start building McTabimWeb"
cd McTabimWeb
cmd /C npm install
if errorlevel 1 exit /b %errorlevel%
cmd /C npm run build:pime
if errorlevel 1 exit /b %errorlevel%
cd ..

echo "Copy McTabimWeb to node\input_methods\McTabim"
cmd /C rd /s /q node\input_methods\McTabim
cmd /C mkdir node\input_methods\McTabim
cmd /C xcopy /s /q /y /f McTabimWeb\output\pime node\input_methods\McTabim\.
if errorlevel 1 exit /b %errorlevel%
cmd /C del /q node\input_methods\McTabim\server.js node\input_methods\McTabim\webpack_check.js node\input_methods\McTabim\run_*.bat node\input_methods\McTabim\README.md node\input_methods\McTabim\*.txt

echo "Start building emojime"
cd node\input_methods\emojime
cmd /C npm install
if errorlevel 1 exit /b %errorlevel%
cmd /C npm run build
if errorlevel 1 exit /b %errorlevel%
cd ..\..\..
