# Timezone Switcher

> **A fast, single-file WPF utility for Windows designed for remote workers, traders, and international teams who need to switch between US market timezones instantly.**

---

## 🌟 Features

* **Instant System-Level Switching:** Switches system timezones seamlessly via background `tzutil.exe` execution.
* **Auto-Revert Protection:** Automatically reverts your system back to its original native timezone upon closing the application.
* **Live Time Converter:** Interactive hour/minute and AM/PM converter to test schedules across multiple timezones simultaneously.
* **Dynamic Animations:** Features responsive UI animations including ambient mesh glow and interconnected particle networks depending on the active theme.
* **Customizable Themes & Transparency:**
* **Themes:** Dark (default with fast ambient mesh), Light, Cyberpunk (particle network), Nord, and Classic Win95.
* **Window Opacity:** Smooth sliding scale control (defaults to **80%**).


* **Always-on-Top Toggle:** Pin the app to stay above active work windows for quick reference during trading sessions or calls.
* **Single-File Executable:** Self-contained build with zero external framework dependencies required at runtime.

---

## 🚀 Quick Start (Automated PowerShell Build)

You can build the entire project into a single executable with one command using the included script.

### Prerequisites

* **Windows 10 / 11 (x64)**
* **[.NET 10.0 SDK](https://dotnet.microsoft.com/download)** installed and added to `PATH`.

### Build Steps

1. Clone this repository:
```powershell
git clone https://github.com/your-username/TimezoneSwitcher.git
cd TimezoneSwitcher

```


2. Run the automated PowerShell build script:
```powershell
.\Build-TimezoneSwitcher.ps1

```


3. Locate your compiled single-file binary at:
```text
.\TimezoneSwitcher\bin\Release\net10.0-windows\win-x64\publish\TimezoneSwitcher.exe

```



---

## 🛠 Project Structure

```text
TimezoneSwitcher/
├── Build-TimezoneSwitcher.ps1   # PowerShell automated build & setup script
├── app.ico                      # Embedded application icon
├── app.manifest                 # Per-monitor DPI awareness manifest
├── App.xaml / App.xaml.cs       # Application setup, themes, and global logging
├── MainWindow.xaml (.cs)        # Main dashboard, quick switch list & time converter
├── SettingsWindow.xaml (.cs)    # Settings UI (themes, opacity slider, fonts)
└── TimezoneSwitcher.csproj     # .NET 10 project file

```

---

## 🎨 Available Themes

| Theme | Visual Style |
| --- | --- |
| **Dark** | Modern dark glass with fast-breathing radial mesh animation |
| **Light** | Clean, minimal bright interface with soft background glow |
| **Cyberpunk** | High-contrast neon purple and cyan with dynamic particle networking |
| **Nord** | Arctic-inspired cool slate color palette with particle connections |
| **Win95** | Retro Windows 95 teal and gray classic interface |

---

## 📝 Logging & Debugging

When enabled in **Settings > Display Options**, runtime logs and system timezone changes are written to:

```text
./log/app.log

```

---

## 📄 License

This project is licensed under the **MIT License**. Feel free to modify, distribute, and adapt for personal or commercial use.
