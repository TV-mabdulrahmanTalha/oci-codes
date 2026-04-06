@echo off
setlocal enabledelayedexpansion

:: --- Configuration ---
set "NSG_ID=ocid1.networksecuritygroup.oc1.me-jeddah-1.aaaaaaaaxwirgwfqmyudce47wlnxup4qbgeks4a2ovfjyowyrqzus6rfik5a"
set "RULE_DESC=Talha TV"
set "PORT=22"
set "PROFILE=DEFAULT"
set "REGION=me-jeddah-1"

:: 1. Fetch current Public IPv4 (Forcing -4 flag)
for /f "delims=" %%a in ('curl -s -4 https://ifconfig.me') do set "MY_IP=%%a"
set "CIDR_IP=%MY_IP%/32"
echo Detected IPv4: %MY_IP%

:: 2. Find the Security Rule ID based on the Description
echo Searching for rule: "%RULE_DESC%" in NSG...
for /f "tokens=*" %%i in ('oci network nsg rules list --nsg-id %NSG_ID% --profile %PROFILE% --region %REGION% --query "data[?description=='%RULE_DESC%'].id | [0]" --raw-output') do set "RULE_ID=%%i"

:: 3. Handle Rule Logic
if "%RULE_ID%"=="null" set "RULE_ID="

if "%RULE_ID%"=="" (
    echo [!] Rule "%RULE_DESC%" not found. Adding new rule...
    echo [{"description":"%RULE_DESC%","direction":"INGRESS","protocol":"6","source":"%CIDR_IP%","source-type":"CIDR_BLOCK","tcp-options":{"destination-port-range":{"max":%PORT%,"min":%PORT%}}}] > nsg_rule.json
    
    oci network nsg rules add --nsg-id %NSG_ID% --profile %PROFILE% --region %REGION% --security-rules file://nsg_rule.json
) else (
    echo [+] Found Rule ID: %RULE_ID%
    echo Updating IP to %CIDR_IP%, preserving description and port %PORT%...
    :: Re-including description and tcp-options prevents OCI from resetting them to null/all
    echo [{"id":"%RULE_ID%","source":"%CIDR_IP%","direction":"INGRESS","protocol":"6","description":"%RULE_DESC%","tcp-options":{"destination-port-range":{"max":%PORT%,"min":%PORT%}}}] > nsg_rule.json
    
    oci network nsg rules update --nsg-id %NSG_ID% --profile %PROFILE% --region %REGION% --security-rules file://nsg_rule.json
)

:: Clean up temp file
if exist nsg_rule.json del nsg_rule.json

if %ERRORLEVEL% EQU 0 (
    echo Success! NSG updated. IP: %MY_IP%, Port: %PORT%, Desc: %RULE_DESC%
    echo %MY_IP%| clip
) else (
    echo.
    echo [ERROR] The update failed.
)

pause