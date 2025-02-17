@echo off
setlocal enabledelayedexpansion

:: =======================================================
:: CONFIGURATION & INITIALIZATION
:: =======================================================
set "LOGFILE=users_with_groups.log"
set "KEYCLOAK_BIN=C:\product\inst\keycloak\keycloak-20.0.5\bin\kcadm.bat"
set "JQ_EXE=C:\Users\user\Desktop\jq.exe"
set "SERVER_URL=http://localhost:8080/auth"
:: Realm for authentication (e.g., master)
set "AUTH_REALM=master"
:: Target realm to query for users – ensure this realm exists!
set "TARGET_REALM=singleRealm"
set "ADMIN_USER=admin"
set "ADMIN_PASS=admin"
set /a pageSize=100

echo [START] User export process at %DATE% %TIME% > %LOGFILE%

:: =======================================================
:: AUTHENTICATION (Refresh session)
:: =======================================================
echo [%TIME%] Authenticating with Keycloak CLI... >> %LOGFILE%
call "%KEYCLOAK_BIN%" config credentials --server %SERVER_URL% --realm %AUTH_REALM% --user %ADMIN_USER% --password %ADMIN_PASS% >> %LOGFILE% 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Authentication failed. Exiting... >> %LOGFILE%
    exit /b 1
)
echo [%TIME%] Successfully authenticated. >> %LOGFILE%

:: =======================================================
:: GET USER COUNT
:: =======================================================
echo [%TIME%] Fetching user count from realm "%TARGET_REALM%"... >> %LOGFILE%
call "%KEYCLOAK_BIN%" get users/count --server %SERVER_URL% --realm %AUTH_REALM% -r %TARGET_REALM% --format json > user_count.json 2>> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Failed to fetch user count. Exiting... >> %LOGFILE%
    exit /b 1
)
:: The count endpoint returns a JSON number (e.g., 2000). Read it into a variable.
set /p userCount=<user_count.json
echo [%TIME%] User count: %userCount% >> %LOGFILE%

:: Calculate total pages (rounding up)
set /a pages=(%userCount% + %pageSize% - 1) / %pageSize%
echo [%TIME%] Total pages to fetch: %pages% >> %LOGFILE%

:: =======================================================
:: PAGINATION: FETCH ALL USERS IN BATCHES
:: =======================================================
echo [%TIME%] Starting pagination to fetch all users from realm "%TARGET_REALM%"... >> %LOGFILE%
set /a page=0

:pagination_loop
if %page% GEQ %pages% goto :pagination_done

    :: Re-authenticate before each paginated call
    echo [%TIME%] Re-authenticating before fetching page %page%... >> %LOGFILE%
    call "%KEYCLOAK_BIN%" config credentials --server %SERVER_URL% --realm %AUTH_REALM% --user %ADMIN_USER% --password %ADMIN_PASS% >> %LOGFILE% 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [%TIME%] [ERROR] Re-authentication failed. Exiting... >> %LOGFILE%
        exit /b 1
    )
    
    set /a offset=%page% * %pageSize%
    echo [%TIME%] Fetching users with offset %offset% (page %page%)... >> %LOGFILE%
    call "%KEYCLOAK_BIN%" get users --server %SERVER_URL% --realm %AUTH_REALM% -r %TARGET_REALM% --format json -o %offset% -l %pageSize% > page_%page%.json 2>> %LOGFILE%
    if %ERRORLEVEL% NEQ 0 (
        echo [%TIME%] [ERROR] Failed to fetch users at offset %offset%. Exiting... >> %LOGFILE%
        exit /b 1
    )
    
    :: Check if current page file is essentially empty (just [] or very small)
    for %%F in (page_%page%.json) do (
        if %%~zF LEQ 2 (
            echo [%TIME%] No more users returned at offset %offset%. Ending pagination. >> %LOGFILE%
            goto :pagination_done
        )
    )
    
    set /a page+=1
    goto :pagination_loop

:pagination_done
echo [%TIME%] Pagination complete. Total pages fetched: %page% >> %LOGFILE%

:: =======================================================
:: AGGREGATE PAGES INTO A SINGLE JSON FILE
:: =======================================================
echo [%TIME%] Aggregating paginated user files into all_users_full.json... >> %LOGFILE%
"%JQ_EXE%" -s "add" page_*.json > all_users_full.json 2>> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Failed to aggregate user pages. Exiting... >> %LOGFILE%
    exit /b 1
)
echo [%TIME%] Aggregation complete. >> %LOGFILE%

:: Optionally, remove individual page files
del page_*.json

:: =======================================================
:: EXTRACT USER IDS USING JQ FROM AGGREGATED FILE
:: =======================================================
echo [%TIME%] Extracting user IDs using jq from all_users_full.json... >> %LOGFILE%
"%JQ_EXE%" -r ".[].id" all_users_full.json > user_ids.json 2>> %LOGFILE%
echo [%TIME%] Finished extracting user IDs. >> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] jq failed to extract user IDs. Exiting... >> %LOGFILE%
    exit /b 1
)
if not exist user_ids.json (
    echo [%TIME%] [ERROR] user_ids.json was not created. Exiting... >> %LOGFILE%
    exit /b 1
)
echo [%TIME%] Extracted user IDs: >> %LOGFILE%
type user_ids.json >> %LOGFILE%
echo ------------------------------------ >> %LOGFILE%

:: =======================================================
:: PROCESS EACH USER (CALL SUBROUTINE)
:: =======================================================
echo [%TIME%] Processing each user... >> %LOGFILE%
echo [ > users_with_groups.json
set "firstEntry=true"

for /f "usebackq delims=" %%i in ("user_ids.json") do (
    call :process_user "%%i"
)

:: =======================================================
:: FINALIZE OUTPUT
:: =======================================================
echo ] >> users_with_groups.json

echo [%TIME%] [END] Export completed successfully at %DATE% %TIME% >> %LOGFILE%
echo Export completed successfully!
endlocal
exit /b 0

:process_user
REM -- Subroutine to process a single user; user ID is passed as an argument.
set "user_id=%~1"
echo [%TIME%] Processing user ID: !user_id! >> %LOGFILE%

:: Fetch user details
echo [%TIME%] Fetching details for user !user_id!... >> %LOGFILE%
call "%KEYCLOAK_BIN%" get users/!user_id! --server %SERVER_URL% --realm %AUTH_REALM% -r %TARGET_REALM% --format json > user.json 2>> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] Failed to fetch details for user !user_id!. Skipping... >> %LOGFILE%
    goto :eof
)
echo [%TIME%] User details for !user_id!: >> %LOGFILE%
type user.json >> %LOGFILE%
echo ------------------------------------ >> %LOGFILE%

:: Fetch user groups
echo [%TIME%] Fetching groups for user !user_id!... >> %LOGFILE%
call "%KEYCLOAK_BIN%" get users/!user_id!/groups --server %SERVER_URL% --realm %AUTH_REALM% -r %TARGET_REALM% --format json > groups.json 2>> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [WARNING] Failed to fetch groups for user !user_id!. Using empty groups array. >> %LOGFILE%
    echo [] > groups.json
)
echo [%TIME%] Groups for !user_id!: >> %LOGFILE%
type groups.json >> %LOGFILE%
echo ------------------------------------ >> %LOGFILE%

:: Merge user details and groups using jq
"%JQ_EXE%" --slurpfile groups groups.json ". + {groups: $groups}" user.json > user_with_groups_tmp.json 2>> %LOGFILE%
if %ERRORLEVEL% NEQ 0 (
    echo [%TIME%] [ERROR] jq failed to merge data for user !user_id!. Skipping... >> %LOGFILE%
    goto :eof
)

:: Append merged JSON to final output
if "!firstEntry!"=="true" (
    type user_with_groups_tmp.json >> users_with_groups.json
    set "firstEntry=false"
) else (
    echo , >> users_with_groups.json
    type user_with_groups_tmp.json >> users_with_groups.json
)
echo [%TIME%] Successfully processed user !user_id!. >> %LOGFILE%
echo ------------------------------------ >> %LOGFILE%
goto :eof
 
