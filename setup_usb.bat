@echo off
:: Setup script for creating a dynamic Windows Desktop Shortcut for the USB app
set "ShortcutName=Tally Ledger.lnk"
set "DesktopPath=%USERPROFILE%\Desktop"
set "VBSFile=%temp%\CreateShortcut.vbs"

echo Set oWS = CreateObject("WScript.Shell") > "%VBSFile%"
echo sLinkFile = "%DesktopPath%\%ShortcutName%" >> "%VBSFile%"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%VBSFile%"
echo oLink.TargetPath = "cmd.exe" >> "%VBSFile%"
echo oLink.Arguments = "/c ""for %%i in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do if exist %%i:\tally_ledger_desktop\tally_ledger_desktop.exe (start """" /d %%i:\tally_ledger_desktop %%i:\tally_ledger_desktop\tally_ledger_desktop.exe & exit)""" >> "%VBSFile%"
echo oLink.Description = "Launch Tally Ledger from USB" >> "%VBSFile%"
echo oLink.IconLocation = "shell32.dll, 43" >> "%VBSFile%"
echo oLink.Save >> "%VBSFile%"

cscript //nologo "%VBSFile%"
del "%VBSFile%"

echo ========================================================
echo Shortcut "Tally Ledger" has been created on your Desktop!
echo.
echo Whenever your USB is plugged in, you can double-click this
echo icon to run the app directly from your USB drive.
echo ========================================================
pause
