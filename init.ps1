# Кладем в .ps1 и запускаем. Самодокументация в Write-Host и комментах

function New-Shortcut {                                                                               # Функция создания ярлыка с автоматическим подбором иконки из списка возможных путей
    param(
        [Parameter(Mandatory=$true)] [string]  $ShortcutPath,                                         # Полный путь к .lnk файлу
                                     [string]  $TargetPath        = "explorer.exe",
                                     [string]  $Arguments         = "",
                                     [string[]]$PossibleIconPaths = $null,                            # Массив путей к файлам с иконками (индекс 0)
                                     [string]  $Description       = ""
    )
    $wshShell            = New-Object -ComObject WScript.Shell
    $shortcut            = $wshShell.CreateShortcut($ShortcutPath.Trim())                             # Добавлен .Trim() для очистки пути от случайных пробелов
    $shortcut.TargetPath = $TargetPath
    if ($Arguments)   { $shortcut.Arguments   = $Arguments }
    if ($Description) { $shortcut.Description = $Description }
    if ($PossibleIconPaths) {                                                                         # Поиск иконки, если передан массив путей
        $iconPath = $null
        foreach ($path in $PossibleIconPaths) {
            if (Test-Path $path) {
                $iconPath = $path
                break
            }
        }
        if ($iconPath) {
            $shortcut.IconLocation = "$iconPath,0"
            Write-Host "   Использую иконку из: $iconPath"                                            -ForegroundColor Gray
        } else {
            Write-Host "   Файл с иконкой не найден, будет использована стандартная иконка Windows"   -ForegroundColor Yellow
        }
    }
    $shortcut.Save()
}


Write-Host "Установка фона рабочего стола..."                                                         -ForegroundColor Cyan
$firstImage = Get-ChildItem -File | Where { $_.Extension -match "jpg|jpeg|png" } | Select -First 1    # Поиск первого изображения в текущей папке
$imagePath  = $firstImage.FullName                                                                    # Получаем полный путь к файлу
$win32Code  = @'
public class W {
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern int SystemParametersInfo( // Определение метода Win32 API
        int    uiAction,                           // Действие (например, 20 для обоев)
        int    uiParam,                            // Дополнительный параметр
        string pvParam,                            // Значение (путь к файлу)
        int    fWinIni                             // Флаги обновления системы
    );
}
'@
if (-not ([System.Management.Automation.PSTypeName]'W').Type) { 
    Add-Type $win32Code                                                                               # Регистрируем метод C# в сессии PS1
}
try {
    [W]::SystemParametersInfo(20, 0, $imagePath, 3)                                                   # Обновляем фон рабочего стола
} catch {
    Write-Host "Ошибка при установке фона рабочего стола: $($_.Exception.Message)"                    -ForegroundColor Red
}

Write-Host "Установка фона экрана блокировки..."                                                      -ForegroundColor Cyan
try {
    $fileStream = [Windows.Storage.StorageFile]::GetFileFromPathAsync($imagePath).
												 GetAwaiter().
												 GetResult()
    [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($fileStream).
	                                         GetAwaiter().
											 GetResult()
} catch {
    Write-Host "Ошибка при установке фона экрана блокировки: $($_.Exception.Message)"                 -ForegroundColor Red
}

Write-Host "Включение тёмной темы и перезапуск проводника..."                                         -ForegroundColor Cyan
try {
    $themeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty $themeKey AppsUseLightTheme    0                                                 # Тёмная тема приложений
    Set-ItemProperty $themeKey SystemUsesLightTheme 0                                                 # Тёмная тема системы                                                                               
    Stop-Process -Name explorer -Force                                                                # Перезапускаем проводник, чтобы тема применилась сразу
} catch {
    Write-Host "Ошибка при включении тёмной темы: $($_.Exception.Message)"                            -ForegroundColor Red
}

Write-Host "Создание ярлыка на сетевые подключения..."                                                -ForegroundColor Cyan
try {
    $s_path = Join-Path $PWD.Path "Сетевые подключения.lnk"                                           # Используем текущую директорию
    $net = @{
        ShortcutPath      = $s_path
        TargetPath        = "explorer.exe"
        Arguments         = "shell:::{7007ACC7-3202-11D1-AAD2-00805FC1270E}"
        PossibleIconPaths = @("$env:SystemRoot\System32\netshell.dll")
    }
    New-Shortcut @net
    Write-Host "   Ярлык создан: $s_path"                                                             -ForegroundColor Green
} catch {
    Write-Host "   Ошибка при создании ярлыка: $($_.Exception.Message)"                               -ForegroundColor Red
}

Write-Host "Создание ярлыка на Безопасность Windows..."                                               -ForegroundColor Cyan
try {
    $s_path = Join-Path $PWD.Path "Безопасность Windows.lnk"                                          # Используем текущую директорию
    $sec = @{
        ShortcutPath      = $s_path
        TargetPath        = "explorer.exe"
        Arguments         = "windowsdefender:"
        PossibleIconPaths = @(
                                "${env:ProgramFiles}\Windows Security\SecurityHealthSystray.exe",
                                "${env:SystemRoot}\System32\SecurityHealthSystray.exe",
                                "${env:ProgramFiles}\Windows Defender\EppManifest.dll",
                                "${env:ProgramFiles}\Windows Defender\MSASCuiL.exe"
                            )
    }
    New-Shortcut @sec
    Write-Host "   Ярлык создан: $s_path"                                                             -ForegroundColor Green
} catch {
    Write-Host "   Ошибка при создании ярлыка: $($_.Exception.Message)"                               -ForegroundColor Red
}

Write-Host "Включение классического контекстного меню..."                                             -ForegroundColor Cyan
try {
    $clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" # Путь в реестре для отключения нового контекстного меню Windows 11
    
    if (-not (Test-Path $clsidPath)) {                                                                # Создаём ключ, если его нет
        New-Item -Path $clsidPath -Force | Out-Null
    }
    
    Set-ItemProperty -Path $clsidPath -Name "(Default)" -Value "" -Force                              # Устанавливаем пустое значение по умолчанию (это активирует классическое меню)
    
    Stop-Process -Name explorer -Force                                                                # Перезапускаем проводник, чтобы изменения применились сразу
    Write-Host "   Классическое контекстное меню включено (проводник перезапущен)"                    -ForegroundColor Green
} catch {
    Write-Host "   Ошибка при включении классического контекстного меню: $($_.Exception.Message)"     -ForegroundColor Red
}

Write-Host "Отключение встроенного скриншотера Windows 11..."                                         -ForegroundColor Cyan
try {
    $printScreenOff = @{                            
        Path  = "HKCU:\Control Panel\Keyboard"      
        Name  = "PrintScreenKeyForSnippingEnabled"  
        Value = 0                                   
        Force = $true                               
    }
    Set-ItemProperty @printScreenOff
    Write-Host "   Готово. Теперь клавиша PrintScreen не вызывает 'Ножницы'."                         -ForegroundColor Green
} catch {
    Write-Host "   Ошибка: $($_.Exception.Message)"                                                   -ForegroundColor Red
}

Write-Host "Открываю текущую папку..."                                                                -ForegroundColor Cyan
Start-Process explorer
Invoke-Item $PWD.Path
Write-Host "Скрипт завершён."                                                                         -ForegroundColor Green

pause
