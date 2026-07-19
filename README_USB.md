# USB Portability & Desktop Launcher Guide

This guide explains how to build the Windows executable of the application, load it onto your USB drive, and configure the Desktop shortcut launcher.

---

## Step 1: Compile the Windows App

On a Windows PC with the Flutter SDK installed, navigate to this project folder and run:
```bash
flutter build windows
```
This compiles the Flutter project into a native Windows application. The build files will be located in:
`build\windows\x64\runner\Release\`

---

## Step 2: Transfer Files to your USB Drive

1. Plug in your USB drive.
2. In the root of your USB drive, create a folder named exactly `tally_ledger_desktop`.
3. Copy all files and folders inside the `build\windows\x64\runner\Release\` folder and paste them directly into the `tally_ledger_desktop` folder on your USB drive.
4. Move `setup_usb.bat` from this codebase into the **root** of the USB drive (outside the `tally_ledger_desktop` folder).

Your USB directory structure should look like this:
```text
USB Drive/
├── setup_usb.bat
└── tally_ledger_desktop/
    ├── tally_ledger_desktop.exe
    ├── flutter_windows.dll
    ├── data/
    └── (other compiled files and subfolders...)
```

---

## Step 3: Run the Setup on a PC

1. Connect the USB drive to any Windows PC.
2. Open the USB drive folder and double-click `setup_usb.bat`.
3. This creates a shortcut named **"Tally Ledger"** on the PC's desktop.

---

## Step 4: Run the Application

- Double-click the **Tally Ledger** icon on the desktop.
- The launcher script automatically loops through all drive letters (D to Z) to find the USB drive, starts the local SQLite database file on the USB, and launches the app.
- **Portability**: All transaction data, SQLite databases, and reports are saved and read directly from the `tally_ledger_desktop` folder on the USB drive. Removing the USB ensures no financial data remains on the host computer.
