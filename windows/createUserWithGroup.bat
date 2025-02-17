@echo off
setlocal enabledelayedexpansion

:: =======================================================
:: CONFIGURATION & INITIALIZATION
:: =======================================================
set "LOGFILE=userscreated.log"
set "KEYCLOAK_BIN=C:\product\inst\keycloak\keycloak-20.0.5\bin\kcadm.bat"
set "JQ_EXE=C:\Users\user\Desktop\jq.exe"
set "SERVER_URL=http://localhost:8080/auth"
set "REALM=master"
set "GROUP_NAME=SuperUsers"
set "ADMIN_USER=admin"
set "ADMIN_PASS=admin"

echo [START] User export process at %DATE% %TIME% > %LOGFILE%

:: =======================================================
:: AUTHENTICATION (REQUIRED TO REFRESH THE SESSION)
:: =======================================================
echo [%TIME%] Authenticating with Keycloak CLI... >> %LOGFILE%
call "%KEYCLOAK_BIN%" config credentials --server %SERVER_URL% --realm %REALM% --user %ADMIN_USER% --password %ADMIN_PASS% >> %LOGFILE% 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Authentication failed. Exiting... >> %LOGFILE%
    exit /b 1
)
echo [%TIME%] Successfully authenticated. >> %LOGFILE%

:: =======================================================
:: FETCH ALL GROUPS
:: =======================================================
echo [%TIME%] Fetching all groups... >> %LOGFILE%
call "%KEYCLOAK_BIN%" get groups --server %SERVER_URL% --realm %REALM% -r singleRealm --format json > all_groups.json 2>> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Failed to fetch groups. Exiting... >> %LOGFILE%
    exit /b 1
)
echo [%TIME%] Finished fetching groups. >> %LOGFILE%

:: =======================================================
:: SELECT GROUP ID FOR %GROUP_NAME%
:: =======================================================
echo [%TIME%] Selecting group "%GROUP_NAME%"... >> %LOGFILE%
for /f "delims=" %%I in ('type all_groups.json ^| %JQ_EXE% -r ".[] | select(.name==\"%GROUP_NAME%\") | .id"') do (
    set "GROUP_ID=%%I"
)
if "%GROUP_ID%"=="" (
    echo [%TIME%] [ERROR] Group "%GROUP_NAME%" not found. Exiting... >> %LOGFILE%
    exit /b 1
)
echo [%TIME%] Selected group "%GROUP_NAME%" with ID: %GROUP_ID% >> %LOGFILE%

:: =======================================================
:: LOOP TO CREATE 120 USERS AND ASSIGN THEM TO THE GROUP
:: =======================================================
for /l %%i in (1,1,120) do (
    :: Format new user name and email (e.g., user001, user002, …)
    if %%i LSS 10 (
        set "NEWUSER=user00%%i"
        set "EMAIL=user00%%i@example.com"
    ) else if %%i LSS 100 (
        set "NEWUSER=user0%%i"
        set "EMAIL=user0%%i@example.com"
    ) else (
        set "NEWUSER=user%%i"
        set "EMAIL=user%%i@example.com"
    )

    echo [%TIME%] Creating user !NEWUSER!... >> %LOGFILE%
    call "%KEYCLOAK_BIN%" create users --server %SERVER_URL% --realm %REALM% -r singleRealm -s username=!NEWUSER! -s email=!EMAIL! -s enabled=true -s "credentials=[{""type"":""password"",""value"":""Password123"",""temporary"":false}]" >> %LOGFILE% 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [%TIME%] [ERROR] Failed to create user !NEWUSER!. Skipping... >> %LOGFILE%
    ) else (
        timeout /t 1 /nobreak >nul
        echo [%TIME%] Retrieving ID for user !NEWUSER!... >> %LOGFILE%
        call "%KEYCLOAK_BIN%" get users --server %SERVER_URL% --realm %REALM% -r singleRealm --format json -q username=!NEWUSER! > user_!NEWUSER!.json 2>> %LOGFILE%
        set "USER_ID="
        for /f "delims=" %%U in ('type user_!NEWUSER!.json ^| %JQ_EXE% -r ".[0].id"') do (
            set "USER_ID=%%U"
        )
        if "!USER_ID!"=="" (
            echo [%TIME%] [ERROR] Could not retrieve ID for user !NEWUSER!. Skipping... >> %LOGFILE%
        ) else (
            echo [%TIME%] User ID for !NEWUSER!: !USER_ID! >> %LOGFILE%
            echo [%TIME%] Adding user !NEWUSER! to group "%GROUP_NAME%"... >> %LOGFILE%
            call "%KEYCLOAK_BIN%" update users/!USER_ID!/groups/%GROUP_ID% --server %SERVER_URL% --realm %REALM% -r singleRealm -f empty.json >> %LOGFILE% 2>&1
            if %ERRORLEVEL% NEQ 0 (
                echo [%TIME%] [ERROR] Failed to add user !NEWUSER! to group "%GROUP_NAME%". >> %LOGFILE%
            ) else (
                echo [%TIME%] User !NEWUSER! successfully added to group "%GROUP_NAME%". >> %LOGFILE%
            )
        )
    )
    echo -------------------------------------------------- >> %LOGFILE%
)

echo [%TIME%] Finished creating users. >> %LOGFILE%
echo [END] User creation process at %DATE% %TIME% >> %LOGFILE%
pause
