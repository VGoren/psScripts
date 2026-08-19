# Кладем в .ps1 и запускаем. Самодокументация в Write-Host и комментах

# Самовозвышение (запрос прав администратора)
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoExit -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Exit
}

function Install-AppFromUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]  [string]  $Url,
        [Parameter(Mandatory = $true)]  [string]  $CheckPath,
        [Parameter(Mandatory = $true)]  [string]  $DownloadDir,
        [Parameter(Mandatory = $false)] [string[]]$InstallArguments = @("/Install", "/NoRestart"),
        [Parameter(Mandatory = $false)] [bool]    $IsPortable       = $false
    )

    if (-not (Test-Path -Path $DownloadDir -PathType Container)) {
        Write-Host "ОШИБКА: Директория '$DownloadDir' не существует!"                                                                    -ForegroundColor Red
        throw "Укажите существующий путь в параметре -DownloadDir."
    }

    $FileName   = Split-Path ($Url.Split('?')[0]) -Leaf                                                                                  # Пытаемся определить имя файла из URL или через HEAD-запрос
    $fileSizeMB = "???"
    try {
        $headers  = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
        $finalUrl = $headers.BaseResponse.ResponseUri.AbsoluteUri                                                                        # Если ссылка - редирект, берем имя из финального URL
        $FileName = Split-Path ($finalUrl.Split('?')[0]) -Leaf
        if ($headers.Headers.'Content-Length') {
            $fileSizeMB = [Math]::Round($headers.Headers.'Content-Length' / 1MB, 2)
        }
    } catch { }
    
    if ($FileName -notmatch "\.") { $FileName = "setup_$(Get-Random).exe" }                                                              # Если имя не определилось (короткое или без расширения), ставим временное

    if (Test-Path $CheckPath) {                                                                                                          # Проверка, установлено ли уже приложение
        Write-Host "$FileName уже установлено"                                                                                           -ForegroundColor DarkGray
        return
    }

    $localPath = Join-Path $DownloadDir $FileName                                                                                        # Логика пути: если портативка, качаем сразу в место назначения
    if ($IsPortable) {
        $localPath = $CheckPath
        $destDir   = Split-Path $localPath
        if (-not (Test-Path $destDir)) {
            New-Item $destDir -Type Directory -Force | Out-Null
        }
    }

    Write-Host "Подготовка:     $FileName"                                                                                               -ForegroundColor Cyan
    Write-Host "Локальный путь: $localPath"                                                                                              -ForegroundColor Gray
    Write-Host "URL:            $Url"                                                                                                    -ForegroundColor Gray

    Write-Host "Скачивание $FileName..."                                                                                                 -ForegroundColor Cyan
    try {
        Start-BitsTransfer -Source $Url -Destination $localPath -DisplayName "Загрузка $FileName ($fileSizeMB MB)" -ErrorAction Stop
    } catch {
        Write-Host "Ошибка при скачивании: $_"                                                                                           -ForegroundColor Red
        return
    }

    if ($IsPortable) {                                                                                                                   # Если портативка - на этом всё, уходим
        Write-Host "$FileName сохранено."                                                                                                -ForegroundColor Green; 
        return 
    }

    Write-Host "Установка $FileName... (ждите)"                                                                                          -ForegroundColor Yellow
    try {
        $process = Start-Process -FilePath $localPath -ArgumentList $InstallArguments -Wait -PassThru
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Host "$FileName успешно установлено."                                                                                  -ForegroundColor Green
            if ($process.ExitCode -eq 3010) { Write-Host "Перезагрузите систему!"                                                        -ForegroundColor Yellow }
        } else {
            Write-Host "Ошибка установки. Код выхода: $($process.ExitCode)"                                                              -ForegroundColor Red
        }
    } catch {
        Write-Host "Критическая ошибка: $_"                                                                                              -ForegroundColor Red
    }

    # Удаление временного файла
    if (Test-Path $localPath) {
        Remove-Item $localPath -Force
        Write-Host "Временный файл удален."                                                                                              -ForegroundColor Gray
    }
}

$apps =                                                                                                                                  # Список приложений для установки, доступных в WinGet
@(
    "Google.Chrome.EXE"

    # IDE
    "Microsoft.VisualStudio.2022.Community"   # IDE
    "Google.AndroidStudio"                    # IDE
    "JetBrains.IntelliJIDEA.Community"        # IDE
    "Microsoft.VisualStudioCode"              # IDE

    # AI
    "Ollama.Ollama"                           # AI Local
    "Anysphere.Cursor"                        # IDE AI
    "Google.Antigravity"                      # IDE AI
    "Google.AntigravityIDE"                   # IDE AI

    # SQL
    "WiseCoders.DbSchema"                     # SQL аналитика
    "Microsoft.SQLServer.2019.Express"        # SQL Server 15
    "PostgreSQL.PostgreSQL"                   # PostgreSQL
    "PostgreSQL.pgAdmin"                      # SQL IDE
    "DBeaver.DBeaver.Community"               # SQL IDE Универсальный

    # Компараторы
    "ScooterSoftware.BeyondCompare.5"         # Компаратор (мощный, но на пробном периоде)

    # Системы контроля версий
    "Git.Git"                                 #
    "GitExtensionsTeam.GitExtensions"         #
    "TortoiseSVN.TortoiseSVN"                 #

    # На всякий случай
    "Docker.DockerDesktop"                    # Контейнеризация
    "OpenJS.NodeJS"                           #
    "Python.Launcher"                         #
    "LocalSend.LocalSend"                     # Легкая передача в локалке
    "MoonlightGameStreamingProject.Moonlight" # RDP с графикой
    "Oracle.VirtualBox"                       # Работа с VM

    # Communication
    "Discord.Discord"                         # Мессенджер
    "Rakuten.Viber"                           # Мессенджер

    # Системные
    "Notepad++.Notepad++"                     # Текстовый редактор
    "Google.GoogleDrive"                      # Облачное хранилище
    "FxSound.FxSound"                         # Усилитель звука
    "VideoLAN.VLC"                            # Плеер
    "RARLab.WinRAR"                           # Архиватор
    "7zip.7zip"                               # Архиватор
    "dotPDN.PaintDotNet"                      # Paint.NET
    "Eassos.DiskGenius"                       # Работа с дисками/разделами
    "Ghisler.TotalCommander"                  # Проводник
    "xanderfrangos.twinkletray"               # Диммер для мониторов
    "Skillbrains.Lightshot"                   # Скриншотер
    "SoftwareOK.DesktopOK"                    # Организация рабочего стола (просто запоминает расположение ярлыков для каждого разрешения)
    #"iTop.iTopEasyDesktop"                    # Организация рабочего стола (группировка иконок) как https://github.com/PinchToDebug/DeskFrame только лучше

    # VPN
    "Proton.ProtonVPN"                        # VPN
    "Windscribe.Windscribe"                   # VPN
)

Write-Host "Анализ системы..."                                                                                                           -ForegroundColor Cyan
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$installed = winget list --accept-source-agreements | Out-String
$lines     = $installed -split "`r?`n"
$exclude   = "MSIX|Microsoft\.|SDK|Runtime|Framework|Redist|VCLibs|Extension|Driver|Update"
Write-Host "Установлено вне списка `$apps (синхронизируй если нужно):"                                                                   -ForegroundColor Red
for ($i = 3; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i].Trim() -split "\s{2,}"
    if ($parts.Count -ge 2) {
        $name, $id = $parts[0].Trim(), $parts[1].Trim()
        if ($apps -notcontains $id -and $id -notmatch $exclude -and $id -ne "ID") {
            # Если ID похож на пакетный менеджер (есть точка и нет ARP/GUID) - Желтый, иначе Красный
            $isPkg = ($id -match "\." -and $id -notmatch "^ARP" -and $id -notmatch "\{[0-9A-Fa-f-]{36}\}")
            $color = if ($isPkg) { "Yellow" } else { "DarkRed" }
            Write-Host "  - $name [$id]"                                                                                                 -ForegroundColor $color
        }
    }
}
Write-Host "--------------------------------------------------"                                                                          -ForegroundColor Gray
Read-Host "Нажми Enter, чтобы начать установку/обновление..."

Write-Host "Начало установки/обновления приложений через WinGet"                                                                         -ForegroundColor Cyan
foreach ($app in $apps) {
    Write-Host "Обработка: $app..."                                                                                                      -ForegroundColor Yellow
    
    winget install -e --id $app --accept-source-agreements --accept-package-agreements --silent
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Успешно: $app"                                                                                                       -ForegroundColor Green
    } else {
        Write-Host "Результат для $($app) (Код: $LASTEXITCODE)"                                                                          -ForegroundColor Gray
    }
}
Write-Host "Конец установки приложений через WinGet"                                                                                     -ForegroundColor Cyan

$remoteApps =                                                                                                                            # Список приложений для установки, НЕдоступных в WinGet
@(                                                                                                       
    @{Url = "https://go.microsoft.com/fwlink/?linkid=2199013&clcid=0x409"; CheckPath = "C:\Program Files (x86)\Microsoft SQL Server Management Studio 18"; DownloadDir = $PSScriptRoot }                     # 18.12.1 нужна для RedGate
   #@{Url = "https://download.anydesk.com/AnyDesk.exe";                    CheckPath = $PSScriptRoot;                                                      DownloadDir = $PSScriptRoot; IsPortable = $true } # 6.0.5 стабильная без лимитов
)
foreach ($app in $remoteApps)                                                                                                            # Запуск цикла по списку
{ 
    Install-AppFromUrl @app
}

# Пиратство
# RedGate_SQL_ToolBelt_v3.1.0.2733                                                                                                       # без него в SSMS делать нечего
#     0.SSMS 18.12.1 должна быть установлена
#     1.Устанавливаем компоненты SSMS Integration Pack - 
#                                SQLPrompt             - intellisense (SSMS only, в Visual Studio не понадобится)
#                                SQLSearch             - навигация 
#                                SQLDependencyTracker  - аналог WiseCoders.DbSchema, кое-что умеет, но слабая произв-ть. По желанию крч
#     2. Выключаем интернет, 
#                  Windows Defender
#     3. Включаем  SSMS 18.12.1, 
#                  RedGate_SQL_ToolBelt_v3.1.0.2733\Keygens\RedGate Keygens\RePT\MultiKeyGen.exe
#     4. В SSMS        SQLPrompt -> Manage License -> Activate
#     5. В MultiKeyGen Program Selection: Red-Gate SQL Compare
#                      Edition Selection: Professional
#                      Licensing Methods: any
#                      Number of Users  : 1
#                      Generate -> Copy
#     6. В SSMS        вставляем ключ -> Activate -> Activate manually -> копируем HTML слева
#     7. В MultiKeyGen вставляем HTML слева  -> копируем HTML справа
#     8. В SSMS        вставляем HTML справа -> Activate -> Close                 
# 
# Araxis Merge Professional Edition 2025.1 (x64)                                                                                         # лучший компаратор ever
#     Всё просто - подменить ярлык    

# Настройки приложений
Write-Host "Добавление компонентов через vs_installer.exe"                                                                               -ForegroundColor Cyan
$vsArgs = @(
    'modify',
    '--installPath', '"C:\Program Files\Microsoft Visual Studio\2022\Professional"',
    '--add',                           'Microsoft.VisualStudio.Workload.NativeDesktop',
    '--add',                           'Microsoft.VisualStudio.Workload.Data',
    '--add',                           'Microsoft.Net.Component.4.8.1.SDK',
    '--add',                           'Microsoft.Net.Component.4.8.1.TargetingPack',
    '--add',                           'Microsoft.Net.Component.4.8.TargetingPack',
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.x86.x64',
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.Spectre',                                        # .x86.x64 по умолчанию
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.ATL',                                            # .x86.x64 по умолчанию
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.ATL.Spectre',                                    # .x86.x64 по умолчанию
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.MFC',                                            # .x86.x64 по умолчанию
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.MFC.Spectre',                                    # .x86.x64 по умолчанию
    '--add',                           'Microsoft.VisualStudio.Component.VC.14.29.16.11.CLI.Support',
    '--addProductLang', 'En-us',
    '--includeRecommended',
    '--passive',
    '--norestart'
)

Start-Process "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" -ArgumentList $vsArgs -Wait

Write-Host "# Установка Araxis Merge в качестве компаратора Git"                                                                         -ForegroundColor Cyan
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser             = New-Object System.Windows.Forms.OpenFileDialog                                                                # Инициализация выбора
$FileBrowser.Filter      = "Araxis Merge (Compare.exe)|Compare.exe|Все файлы (*.*)|*.*"                                                  # Фильтр файлов
$FileBrowser.Title       = "Выберите файл C:\Users\User\AppData\Local\Apps\Araxis\Araxis Merge\Compare.exe"                              # Заголовок окна
$TopWindow               = New-Object System.Windows.Forms.Form                                                                          # Создание формы-владельца
$TopWindow.TopMost       = $true                                                                                                         # Установка формы поверх всех окон
$DialogResult            = $FileBrowser.ShowDialog($TopWindow)                                                                           # Открытие диалога поверх формы
$TopWindow.Dispose()                                                                                                                     # Освобождение ресурсов формы
if ($DialogResult -ne "OK") {
    Write-Host "Отменено"                                                                                                                -ForegroundColor Yellow
    exit
}

if ($FileBrowser.ShowDialog() -eq 'OK') {
    $araxisExe = $FileBrowser.FileName.Replace('\', '/')                                                                                 # Сохраняем выбранный путь
                                                                                                                                                                                                                                                   
    git config --global --remove-section difftool.ax  2>$null                                                                            # Очистка старых конфигов
    git config --global --remove-section mergetool.ax 2>$null                                                                            
    git config --global --remove-section diff         2>$null                                                                            
    git config --global --remove-section merge        2>$null                                                                            
                                                                                                                                         
    git config --global diff.tool  ax                                                                                                    # Назначаем инструменты
    git config --global merge.tool ax                                                                                                    
                                                                                                                                         
    $q = '\"'                                                                                                                            # Экранирование, чтобы внутри .gitconfig путь к EXE-файлу был обернут в кавычки (безопасность)
    $diffCmd  = "$q$araxisExe$q -2 -wait $q`$LOCAL$q $q`$REMOTE$q"                                                                       # Сборка команд
    $mergeCmd = "$q$araxisExe$q -3 -wait -merge $q`$LOCAL$q $q`$BASE$q $q`$REMOTE$q $q`$MERGED$q"                                        
                                                                                                                                         
    git config --global difftool.ax.cmd  $diffCmd                                                                                        # Запись в глобальный конфиг Git
    git config --global mergetool.ax.cmd $mergeCmd                                                                                       
                                                                                                                                         
    git config --global mergetool.prompt           false                                                                                 # Настройки поведения
    git config --global difftool.prompt            false
    git config --global mergetool.keepBackup       false
    git config --global mergetool.ax.trustExitCode true

    write-host "`n[OK] Конфиг очищен от лишних флагов."                                                                                  -ForegroundColor Green
    write-host "Теперь Araxis будет использовать настройки из своего GUI."                                                               -ForegroundColor Yellow
} else {
    Write-Host "Путь не выбран. Настройка Git отменена."                                                                                 -ForegroundColor Red
}

Pause
