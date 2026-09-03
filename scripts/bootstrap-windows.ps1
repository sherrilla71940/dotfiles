# Run once on a new Windows machine, by hand. Deliberately NOT a chezmoi script: anything
# under home/.chezmoiscripts/ runs on every `chezmoi apply`, which meant a routine apply
# could install software unexpectedly.
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# Wiring the clone up runs before the package-manager gate below. Neither step needs winget,
# and both are the ones that fail silently when skipped.

# Chezmoi reads its source from ~/.local/share/chezmoi, and this repository is developed at
# ~/dotfiles instead (ADR-0006), so the default path is satisfied with a directory junction --
# which, unlike a symlink, needs no elevated privilege. That junction is not part of the source
# state, so `chezmoi apply` neither creates nor repairs it, and a machine missing it silently
# uses whatever the directory happens to contain. An existing entry is never replaced.
#
# Compare the reparse target, not Resolve-Path: that normalises a path but does not follow a
# junction, so it returns the link itself and a correctly linked machine would be reported as
# holding an unrelated directory.
$sourceDir = Join-Path $HOME ".local\share\chezmoi"
$existing = Get-Item -LiteralPath $sourceDir -Force -ErrorAction SilentlyContinue
if ($existing) {
    $linkTarget = $existing.Target | Select-Object -First 1
    $resolved = if ($linkTarget) { [IO.Path]::GetFullPath($linkTarget) } else { $existing.FullName }
    if ($resolved -ieq $repo) {
        Write-Host "chezmoi source directory already points at $repo"
    } elseif ($linkTarget -and -not (Test-Path -LiteralPath $resolved)) {
        Write-Warning "chezmoi source directory is a broken link to $resolved. Remove $sourceDir, then rerun."
    } else {
        Write-Warning "chezmoi source directory exists and is not this repository: $sourceDir -> $resolved. Move it aside and rerun, or set sourceDir yourself. Leaving it untouched."
    }
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourceDir) | Out-Null
    New-Item -ItemType Junction -Path $sourceDir -Target $repo | Out-Null
    Write-Host "linked $sourceDir -> $repo"
}

# The pre-commit hook lives in the repository rather than .git/hooks, so it does nothing until
# core.hooksPath is set. Left unset, every validation check is silently absent on a new clone.
# A failing native command does not stop the script even under ErrorActionPreference Stop, so
# report the failure instead of printing success over it.
git -C $repo config core.hooksPath scripts/git-hooks
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not set core.hooksPath, so the validation hook will not run. Is $repo a Git checkout?"
} else {
    Write-Host "repository validation enabled (core.hooksPath)"
}


if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required. Install 'App Installer' from the Microsoft Store, then rerun."
}

$packageId = "jqlang.jq"
# The documented setup installs Git and chezmoi before cloning. This post-clone helper adds
# jq for the Claude MCP installer and verifies whether the VS Code CLI is already available.
$installed = winget list --id $packageId --exact 2>$null | Select-String -SimpleMatch $packageId
if (-not $installed) {
    winget install --id $packageId --exact --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
} else {
    Write-Host "$packageId already installed"
}

# This script installs the typescript-lsp plugin below, and the plugin does not install its
# language server. Without the binary every session reports a
# plugin load error. Both packages are needed: the server shells out to tsserver, which
# ships with typescript.
if (-not (Get-Command typescript-language-server -ErrorAction SilentlyContinue)) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g typescript-language-server typescript
    } else {
        Write-Warning "npm is not on PATH, so typescript-language-server was skipped. Install Node, then run 'npm install -g typescript-language-server typescript'."
    }
}

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Warning "VS Code CLI is not on PATH. Install VS Code, then enable its 'code' command."
} else {
    # The manifest stays out of routine apply because installing this many extensions is slow
    # and is not something a configuration change should trigger. This script runs once, by
    # hand, which is where it belongs.
    $manifest = Join-Path $repo "scripts\vscode-extensions.txt"
    if (Test-Path $manifest) {
        Write-Host "installing VS Code extensions from the manifest..."
        $failed = @()
        Get-Content $manifest | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith("#") } |
            ForEach-Object {
                # Windows PowerShell 5.1 promotes native stderr to an error record before
                # redirection. VS Code can emit a deprecation warning while still succeeding,
                # so let the native exit code decide whether this installation failed.
                $savedErrorActionPreference = $ErrorActionPreference
                try {
                    $ErrorActionPreference = "Continue"
                    code --install-extension $_ --force 2>$null | Out-Null
                    $extensionInstallExitCode = $LASTEXITCODE
                } finally {
                    $ErrorActionPreference = $savedErrorActionPreference
                }
                if ($extensionInstallExitCode -ne 0) { $failed += $_ }
            }
        if ($failed.Count -gt 0) {
            Write-Warning "$($failed.Count) VS Code extensions failed: $($failed -join ', '). Rerun the manifest command from docs/setup.md."
        }
    }
}

# Claude Code plugins are installed software, not configuration, so they belong here rather
# than in the chezmoi-managed settings: pinning enabledPlugins would mean a plugin disabled
# locally came back on the next apply. The official marketplace is normally registered on the
# first interactive launch, so add it explicitly to make this script safe to run before that.
if (Get-Command claude -ErrorAction SilentlyContinue) {
    claude plugin marketplace add anthropics/claude-plugins-official 2>$null | Out-Null
    foreach ($plugin in @("figma", "typescript-lsp", "playwright")) {
        claude plugin install "$plugin@claude-plugins-official" --scope user 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not install $plugin. Add it from /plugin once Claude Code is running."
        }
    }

    # ~/.claude.json also holds application-owned state, so the installer adds only missing
    # server names and leaves any existing one exactly as it is.
    $mcpInstaller = Join-Path $repo "scripts\install-claude-mcp.ps1"
    if (Test-Path $mcpInstaller) {
        powershell -NoProfile -ExecutionPolicy Bypass -File $mcpInstaller
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The Claude MCP installer failed. Run scripts\install-claude-mcp.ps1 by hand."
        }
    }
} else {
    Write-Warning "claude is not on PATH, so plugins were skipped. Install Claude Code, then rerun this script."
}

# Codex Memories is off upstream and is toggled by Codex's own command, which writes into
# ~/.codex/config.toml. That file carries the create_ prefix so chezmoi never overwrites the
# trust and runtime state Codex keeps there, which also means a source edit would not reach a
# machine that already has the file. Enabling it here is the same trade as the plugins above:
# set once on a new machine, and a later 'codex features disable memories' stays disabled.
if (Get-Command codex -ErrorAction SilentlyContinue) {
    codex features enable memories 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not enable Codex memories. Run 'codex features enable memories' by hand."
    }
} else {
    Write-Warning "codex is not on PATH, so Codex memories was skipped. Install Codex CLI, then rerun this script."
}

# Windows attributes every toast to an Application User Model ID (AUMID). Given none, it
# invents a per-process identity whose display name is empty, so a Claude Code notification
# arrives anonymous. ~/.local/share/show-agent-notification.ps1 asks for the AUMID below and
# falls back to the built-in Windows PowerShell identity until this registration exists.
$claudeCodeAumid = "Anthropic.ClaudeCode"
$claudeCodeDisplayName = "Claude Code"

# An AUMID becomes real when a Start Menu shortcut carries it in the shell property store.
# WScript.Shell cannot write that property, so the shortcut is built through the COM
# interfaces that can.
if (-not ("ClaudeCodeBootstrap.ShortcutWriter" -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ClaudeCodeBootstrap
{
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey
    {
        public Guid FormatId;
        public int PropertyId;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PropVariant
    {
        public ushort ValueType;
        public ushort Reserved1;
        public ushort Reserved2;
        public ushort Reserved3;
        public IntPtr Value;
        public IntPtr Padding;
    }

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    public class ShellLink { }

    // Only the setters below are ever called, but every method must be declared so the
    // interface vtable lines up with the real one.
    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
    public interface IShellLinkW
    {
        void GetPath(IntPtr file, int maxLength, IntPtr findData, uint flags);
        void GetIDList(out IntPtr idList);
        void SetIDList(IntPtr idList);
        void GetDescription(IntPtr name, int maxLength);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string name);
        void GetWorkingDirectory(IntPtr directory, int maxLength);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string directory);
        void GetArguments(IntPtr arguments, int maxLength);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string arguments);
        void GetHotkey(out short hotkey);
        void SetHotkey(short hotkey);
        void GetShowCmd(out int showCommand);
        void SetShowCmd(int showCommand);
        void GetIconLocation(IntPtr iconPath, int maxLength, out int iconIndex);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string iconPath, int iconIndex);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string relativePath, uint reserved);
        void Resolve(IntPtr window, uint flags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99")]
    public interface IPropertyStore
    {
        void GetCount(out uint count);
        void GetAt(uint index, out PropertyKey key);
        void GetValue(ref PropertyKey key, out PropVariant value);
        void SetValue(ref PropertyKey key, ref PropVariant value);
        void Commit();
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("0000010b-0000-0000-C000-000000000046")]
    public interface IPersistFile
    {
        void GetClassID(out Guid classId);
        [PreserveSig] int IsDirty();
        void Load([MarshalAs(UnmanagedType.LPWStr)] string fileName, uint mode);
        void Save([MarshalAs(UnmanagedType.LPWStr)] string fileName, [MarshalAs(UnmanagedType.Bool)] bool remember);
        void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string fileName);
        void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string fileName);
    }

    public static class ShortcutWriter
    {
        // PKEY_AppUserModel_ID, the property that binds a shortcut to an AUMID.
        private static readonly Guid AppUserModelIdFormat = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        private const int AppUserModelIdProperty = 5;
        private const ushort VariantTypeWideString = 31;

        public static void Write(string shortcutPath, string targetPath, string arguments,
            string workingDirectory, string description, string appUserModelId, string iconPath)
        {
            object shellLink = new ShellLink();
            try
            {
                IShellLinkW link = (IShellLinkW)shellLink;
                link.SetPath(targetPath);
                link.SetArguments(arguments);
                link.SetWorkingDirectory(workingDirectory);
                link.SetDescription(description);

                // Windows takes the logo on a toast from the shortcut that registers the
                // AUMID. Without one the banner shows a generic placeholder. An empty path
                // leaves the shortcut iconless rather than pointing at something missing.
                if (!string.IsNullOrEmpty(iconPath))
                {
                    link.SetIconLocation(iconPath, 0);
                }

                PropertyKey key = new PropertyKey();
                key.FormatId = AppUserModelIdFormat;
                key.PropertyId = AppUserModelIdProperty;

                PropVariant value = new PropVariant();
                value.ValueType = VariantTypeWideString;
                value.Value = Marshal.StringToCoTaskMemUni(appUserModelId);
                try
                {
                    IPropertyStore store = (IPropertyStore)shellLink;
                    store.SetValue(ref key, ref value);
                    store.Commit();
                }
                finally
                {
                    Marshal.FreeCoTaskMem(value.Value);
                }

                ((IPersistFile)shellLink).Save(shortcutPath, true);
            }
            finally
            {
                Marshal.ReleaseComObject(shellLink);
            }
        }
    }
}
'@
}

# Writing the shortcut every run keeps this idempotent and repairs a stale or deleted one.
# The target is powershell.exe rather than the claude executable because the latter lives
# under a Node version directory that moves on every Node upgrade.
$startMenuPrograms = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
New-Item -ItemType Directory -Force -Path $startMenuPrograms | Out-Null

# Borrow the icon from an installed Claude desktop application rather than committing an
# image to this repository. The path deliberately omits the version directory beside it, so
# an application update does not leave the shortcut pointing at a removed file. Absent that
# installation the shortcut simply has no icon, which is how it behaved before.
$claudeIconPath = Join-Path $env:LOCALAPPDATA "AnthropicClaude\app.ico"
if (-not (Test-Path -LiteralPath $claudeIconPath)) {
    $claudeIconPath = ""
    Write-Host "Claude application icon not found; notifications will use the default icon."
}

[ClaudeCodeBootstrap.ShortcutWriter]::Write(
    (Join-Path $startMenuPrograms "$claudeCodeDisplayName.lnk"),
    (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"),
    "-NoExit -Command claude",
    $env:USERPROFILE,
    $claudeCodeDisplayName,
    $claudeCodeAumid,
    $claudeIconPath)

# Toast markup can only point at a bitmap, so the largest frame of the icon is written out as
# one. The notification hook uses it when it exists and omits the image when it does not, so a
# machine without a Claude desktop installation simply gets a banner with no logo.
#
# Windows paints the small header icon as a monochrome mask in the system accent colour, which
# no property overrides for an identity registered this way. The logo inside the banner is drawn
# in full colour, which is why the hook places it there rather than relying on the header alone.
if ($claudeIconPath) {
    Add-Type -AssemblyName System.Drawing
    $notificationIconPath = Join-Path $env:USERPROFILE ".claude\claude-notification-icon.png"
    try {
        $icon = $null
        foreach ($size in 256, 128, 64, 48, 32) {
            try {
                $candidate = New-Object System.Drawing.Icon($claudeIconPath, $size, $size)
                if ($candidate.Width -ge $size) { $icon = $candidate; break }
                $candidate.Dispose()
            } catch {}
        }
        if ($null -eq $icon) { $icon = New-Object System.Drawing.Icon($claudeIconPath) }

        $bitmap = $icon.ToBitmap()
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $notificationIconPath) | Out-Null
            $bitmap.Save($notificationIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "Notification logo written from the Claude application icon ($($bitmap.Width)x$($bitmap.Height))."
        } finally {
            $bitmap.Dispose()
            $icon.Dispose()
        }
    } catch {
        Write-Host "Could not write the notification logo: $($_.Exception.Message)"
    }
}

# The name Windows shows on the banner and in Settings > Notifications comes from this key.
# Six auto-generated identities on this machine had an empty one, which is the symptom that
# made Claude Code notifications unattributable.
$identityKey = "HKCU:\SOFTWARE\Classes\AppUserModelId\$claudeCodeAumid"
if (-not (Test-Path -LiteralPath $identityKey)) {
    New-Item -Path $identityKey -Force | Out-Null
}
New-ItemProperty -Path $identityKey -Name "DisplayName" -Value $claudeCodeDisplayName `
    -PropertyType String -Force | Out-Null

# The header icon. Windows draws it as a monochrome mask in the system accent colour rather than
# in the icon's own colours, so it gives the banner Claude's shape but not its palette, which is
# still better than the generic placeholder shown without it.
if ($notificationIconPath -and (Test-Path -LiteralPath $notificationIconPath)) {
    New-ItemProperty -Path $identityKey -Name "IconUri" -Value $notificationIconPath `
        -PropertyType String -Force | Out-Null
}

Write-Host "Claude Code notification identity registered as $claudeCodeAumid"

# Codex raises its own session-end banner through the same script, and an AUMID is what puts a
# sender's name on a toast. Without this the Codex banner would either be attributed to Claude
# Code or fall back to the anonymous Windows PowerShell identity. There is no icon: Codex ships
# no desktop application to borrow one from, and the identity is still worth registering for the
# name alone.
$codexAumid = "OpenAI.Codex"
$codexDisplayName = "Codex"

[ClaudeCodeBootstrap.ShortcutWriter]::Write(
    (Join-Path $startMenuPrograms "$codexDisplayName.lnk"),
    (Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"),
    "-NoExit -Command codex",
    $env:USERPROFILE,
    $codexDisplayName,
    $codexAumid,
    "")

$codexIdentityKey = "HKCU:\SOFTWARE\Classes\AppUserModelId\$codexAumid"
if (-not (Test-Path -LiteralPath $codexIdentityKey)) {
    New-Item -Path $codexIdentityKey -Force | Out-Null
}
New-ItemProperty -Path $codexIdentityKey -Name "DisplayName" -Value $codexDisplayName `
    -PropertyType String -Force | Out-Null

Write-Host "Codex notification identity registered as $codexAumid"

Write-Host 'Optional tools are ready.'
