param(
    [ValidateSet('Configure','Check','Start','Verify','Stop','ResetData','CleanOld','InitGit')]
    [string]$Action = 'Check',
    [string]$OldProject = '',
    [switch]$DeleteData
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $root
if (!(Test-Path -LiteralPath (Join-Path $root 'build.gradle'))) { throw 'Wrong project folder' }

function Run-Docker {
    & docker @args
    if ($LASTEXITCODE -ne 0) { throw "Docker failed (exit $LASTEXITCODE). Read the error above." }
}
function Run-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Git failed (exit $LASTEXITCODE)." }
}
function Read-Settings {
    $settings = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $root 'student.env'))) {
        if ($line -match '^([A-Z_]+)="([^"\r\n]*)"$') { $settings[$Matches[1]] = $Matches[2] }
    }
    foreach ($key in @('STUDENT_NAME','STUDENT_ID','STUDENT_CLASS','STUDENT_EMAIL','GITHUB_USERNAME','EXAM_CODE','APP_PORT','COMPOSE_PROJECT_NAME','MYSQL_DATABASE','MYSQL_USER','MYSQL_PASSWORD','MYSQL_ROOT_PASSWORD')) {
        if (!$settings[$key]) { throw "Missing $key in student.env. Use Configure." }
    }
    if ($settings.COMPOSE_PROJECT_NAME -notmatch '^[a-z0-9][a-z0-9-]*-de001$') { throw 'Invalid COMPOSE_PROJECT_NAME' }
    $port = 0
    if (![int]::TryParse($settings.APP_PORT, [ref]$port) -or $port -lt 8080 -or $port -gt 65535) { throw 'APP_PORT must be 8080..65535' }
    if ($settings.EXAM_CODE -ne '001' -or $settings.MYSQL_DATABASE -ne 'ptit_lab_db') { throw 'Do not change exam code or database name' }
    return $settings
}
function Check-Environment {
    foreach ($key in @('COMPOSE_PROJECT_NAME','COMPOSE_FILE','APP_PORT','APP_IMAGE','APP_TAG','APP_VERSION','MYSQL_DATABASE','MYSQL_USER','MYSQL_PASSWORD','MYSQL_ROOT_PASSWORD','STUDENT_NAME','STUDENT_ID','STUDENT_CLASS','EXAM_CODE')) {
        if ([Environment]::GetEnvironmentVariable($key,'Process')) {
            throw "Terminal has an override: $key. Remove-Item Env:$key then retry."
        }
    }
    Run-Docker info --format '{{.ServerVersion}}'
    Run-Docker compose --env-file student.env config --quiet
}
function Verify-App {
    param($settings)
    $base = 'http://127.0.0.1:' + $settings.APP_PORT
    $labs = Invoke-RestMethod "$base/api/labs" -TimeoutSec 20
    if (@($labs).Count -ne 8) { throw "Expected 8 labs; got $(@($labs).Count)" }
    foreach ($lab in $labs) {
        if (!$lab.id -or !$lab.labName -or !$lab.building -or !$lab.capacity -or !$lab.equipment -or !$lab.status) { throw 'Invalid lab data' }
    }
    $info = Invoke-RestMethod "$base/api/info" -TimeoutSec 20
    if ($info.studentId -cne $settings.STUDENT_ID -or $info.studentName -cne $settings.STUDENT_NAME) { throw 'Student info mismatch' }
    $page = Invoke-WebRequest "$base/student.html" -UseBasicParsing -TimeoutSec 20
    if ($page.StatusCode -ne 200) { throw 'Student page failed' }
    Run-Docker compose --env-file student.env exec -T nginx nginx -t
    $uid = & docker compose --env-file student.env exec -T app id -u
    if ($LASTEXITCODE -ne 0 -or [int]$uid -eq 0) { throw 'App must run as non-root' }
    $mysqlId = & docker compose --env-file student.env ps -q mysql
    if ($LASTEXITCODE -ne 0 -or !$mysqlId) { throw 'MySQL not running' }
    $bindings = & docker inspect $mysqlId --format '{{json .HostConfig.PortBindings}}'
    if ($LASTEXITCODE -ne 0 -or $bindings -notin @('{}','null')) { throw 'MySQL must not publish host ports' }
    Run-Docker compose --env-file student.env ps
    $info | ConvertTo-Json
    Write-Host "PASS: 8 labs, student info, page, Nginx, non-root, private MySQL. Open $base" -ForegroundColor Green
}

switch ($Action) {
    'Configure' {
        Write-Host 'Enter YOUR exam details. Database passwords are generated once; repeat practice keeps them.'
        $data = [ordered]@{}
        foreach ($key in @('STUDENT_NAME','STUDENT_ID','STUDENT_CLASS','STUDENT_EMAIL','GITHUB_USERNAME','APP_PORT','COMPOSE_PROJECT_NAME')) {
            $value = (Read-Host $key).Trim()
            if (!$value -or $value -match '["\x27$`\\\r\n]') { throw "Invalid value for $key. Avoid quotes, dollar, backtick and backslash." }
            $data[$key] = $value
        }
        if ($data.GITHUB_USERNAME -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$') { throw 'Invalid GitHub username' }
        if ($data.COMPOSE_PROJECT_NAME -notmatch '^[a-z0-9][a-z0-9-]*-de001$') { throw 'Example: phamngoclinh-de001' }
        $port = 0
        if (![int]::TryParse($data.APP_PORT,[ref]$port) -or $port -lt 8080 -or $port -gt 65535) { throw 'Invalid APP_PORT' }
        $data.EXAM_CODE = '001'
        $data.MYSQL_DATABASE = 'ptit_lab_db'
        $data.MYSQL_USER = 'app_user'
        $data.MYSQL_PASSWORD = 'App' + [guid]::NewGuid().ToString('N')
        $data.MYSQL_ROOT_PASSWORD = 'Root' + [guid]::NewGuid().ToString('N')
        New-Item -ItemType Directory -Force .practice | Out-Null
        Copy-Item -LiteralPath student.env -Destination ('.practice/student-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.env')
        $lines = foreach ($entry in $data.GetEnumerator()) { '{0}="{1}"' -f $entry.Key,$entry.Value }
        [IO.File]::WriteAllText((Join-Path $root 'student.env'), ($lines -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))
        Write-Host 'Saved UTF-8/LF student.env. If a database already exists, ResetData before Start.' -ForegroundColor Green
    }
    'InitGit' {
        if (!(Test-Path -LiteralPath (Join-Path $root '.git'))) { Run-Git init -b main . }
        $gitRoot = & git rev-parse --show-toplevel
        if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($gitRoot) -ne $root) { throw 'Git root differs from project root; stop here' }
        Run-Git config --local core.autocrlf input
        Run-Git status --short
        Write-Host "Git root OK: $root"
    }
    'CleanOld' {
        if ($OldProject -notmatch '^[a-z0-9][a-z0-9-]*-de001$') { throw 'Provide an exact exam project name with -OldProject' }
        $ids = @(& docker ps -aq --filter "label=com.docker.compose.project=$OldProject")
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Docker' }
        foreach ($id in $ids) {
            if (!$id) { continue }
            $detail = (& docker inspect $id | ConvertFrom-Json)[0]
            if ($LASTEXITCODE -ne 0) { throw 'Inspect failed' }
            $source = $detail.Config.Labels.'com.docker.compose.project.working_dir'
            if (!$source -or [IO.Path]::GetFullPath($source) -ne $root) { throw "Project $OldProject belongs to another folder: $source" }
        }
        $composeArgs = @('compose','--env-file','student.env','-p',$OldProject,'down','--remove-orphans')
        if ($DeleteData) { $composeArgs += '--volumes' }
        Run-Docker @composeArgs
        Write-Host 'Old exam containers removed. Database removed only if -DeleteData was supplied.'
    }
    default {
        $settings = Read-Settings
        Check-Environment
        switch ($Action) {
            'Check' { Write-Host "Config OK: $($settings.COMPOSE_PROJECT_NAME), port $($settings.APP_PORT)" }
            'Start' {
                Run-Docker compose --env-file student.env up -d --build --wait --wait-timeout 300
                Run-Docker compose --env-file student.env restart nginx
                Run-Docker compose --env-file student.env up -d --no-build --wait --wait-timeout 300
                Verify-App $settings
            }
            'Verify' { Verify-App $settings }
            'Stop' { Run-Docker compose --env-file student.env down --remove-orphans }
            'ResetData' {
                if (!$DeleteData) { throw 'Reset deletes the practice database. Add -DeleteData to request this explicitly.' }
                Run-Docker compose --env-file student.env down --volumes --remove-orphans
                Write-Host 'Practice database removed. Run Start to re-create 8 labs and current passwords.'
            }
        }
    }
}
