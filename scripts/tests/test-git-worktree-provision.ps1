# Run the managed worktree helper against disposable repositories containing non-secret
# fixtures. This script requires Windows PowerShell and Git for Windows.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$toolPath = (Resolve-Path (Join-Path $repositoryRoot "home\dot_local\share\git-worktree-provision.ps1")).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd("\", "/")
$testRoot = Join-Path $temporaryParent ("git-worktree-provision-tests-" + [guid]::NewGuid().ToString("N"))
$passed = 0
$failed = 0

function Write-FixtureFile {
    param([string] $Path, [AllowEmptyString()][string] $Content)

    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Invoke-TestProcess {
    param(
        [string] $WorkingDirectory,
        [string] $FilePath,
        [string[]] $Arguments
    )

    Push-Location $WorkingDirectory
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = ($output -join "`n")
        }
    } finally {
        $ErrorActionPreference = $previousErrorAction
        Pop-Location
    }
}

function Invoke-FixtureGit {
    param(
        [string] $WorkingDirectory,
        [string[]] $Arguments,
        [switch] $AllowFailure
    )

    $result = Invoke-TestProcess $WorkingDirectory (Get-Command git.exe).Source $Arguments
    if (-not $AllowFailure -and $result.ExitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($result.Output)"
    }
    return $result
}

function New-FixtureRepository {
    param([string] $Name)

    $path = Join-Path $testRoot $Name
    [IO.Directory]::CreateDirectory($path) | Out-Null
    Invoke-FixtureGit $path @("init", "--quiet", "--initial-branch=main") | Out-Null
    Invoke-FixtureGit $path @("config", "user.name", "Worktree Fixture") | Out-Null
    Invoke-FixtureGit $path @("config", "user.email", "fixture@example.invalid") | Out-Null

    $toolForShell = $toolPath.Replace("\", "/")
    $addAlias = "!powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$toolForShell`" add"
    $copyAlias = "!powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$toolForShell`" copy"
    Invoke-FixtureGit $path @("config", "alias.wt-add", $addAlias) | Out-Null
    Invoke-FixtureGit $path @("config", "alias.wt-copy", $copyAlias) | Out-Null

    Write-FixtureFile (Join-Path $path "README.md") "fixture`n"
    Invoke-FixtureGit $path @("add", "README.md") | Out-Null
    Invoke-FixtureGit $path @("commit", "--quiet", "-m", "fixture") | Out-Null
    return $path
}

function Add-Manifest {
    param(
        [string] $Repository,
        [string] $IgnoreContent,
        [string] $ManifestContent
    )

    Write-FixtureFile (Join-Path $Repository ".gitignore") $IgnoreContent
    Write-FixtureFile (Join-Path $Repository ".worktreeinclude") $ManifestContent
    Invoke-FixtureGit $Repository @("add", ".gitignore", ".worktreeinclude") | Out-Null
    Invoke-FixtureGit $Repository @("commit", "--quiet", "-m", "add worktree manifest") | Out-Null
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-OutputContains {
    param($Result, [string] $Expected, [string] $Message)
    if (-not $Result.Output.Contains($Expected)) {
        throw "$Message Output:`n$($Result.Output)"
    }
}

function Invoke-Case {
    param([string] $Name, [scriptblock] $Test)

    if ($env:WORKTREE_PROVISION_TEST_FILTER -and
        $Name -notlike "*$($env:WORKTREE_PROVISION_TEST_FILTER)*") {
        return
    }

    try {
        & $Test
        $script:passed++
        Write-Host "PASS $Name"
    } catch {
        $script:failed++
        Write-Host "FAIL $Name"
        Write-Host "  $($_.Exception.Message)"
    }
}

[IO.Directory]::CreateDirectory($testRoot) | Out-Null
try {
    Invoke-Case "create without manifest" {
        $repo = New-FixtureRepository "no-manifest"
        $target = Join-Path $testRoot "no-manifest-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Creation without a manifest should succeed."
        Assert-OutputContains $result "[skipped] .worktreeinclude" "The missing manifest should be reported."
        Assert-True (Test-Path -LiteralPath (Join-Path $target ".git")) "The worktree was not created."
    }

    Invoke-Case "copy matching ignored file" {
        $repo = New-FixtureRepository "matching"
        Add-Manifest $repo ".env.local`n" ".env.local`n"
        Write-FixtureFile (Join-Path $repo ".env.local") "fixture-value`n"
        $target = Join-Path $testRoot "matching-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Provisioning should succeed."
        Assert-Equal "fixture-value`n" ([IO.File]::ReadAllText((Join-Path $target ".env.local"))) "The ignored file was not copied exactly."
    }

    Invoke-Case "do not copy matched unignored file" {
        $repo = New-FixtureRepository "unignored"
        Add-Manifest $repo "*.ignored`n" "local.txt`n"
        Write-FixtureFile (Join-Path $repo "local.txt") "not ignored`n"
        $target = Join-Path $testRoot "unignored-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "An ineligible source file should not fail creation. Output: $($result.Output)"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $target "local.txt"))) "An unignored file was copied."
        Assert-OutputContains $result "[missing] local.txt" "The ineligible manifest entry should be reported."
    }

    Invoke-Case "do not copy ignored file outside manifest" {
        $repo = New-FixtureRepository "outside-manifest"
        Add-Manifest $repo "*.local`n" "approved.local`n"
        Write-FixtureFile (Join-Path $repo "approved.local") "approved`n"
        Write-FixtureFile (Join-Path $repo "other.local") "not approved`n"
        $target = Join-Path $testRoot "outside-manifest-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Provisioning should succeed."
        Assert-True (Test-Path -LiteralPath (Join-Path $target "approved.local")) "The approved file is missing."
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $target "other.local"))) "An unapproved ignored file was copied."
    }

    Invoke-Case "copy nested directory pattern" {
        $repo = New-FixtureRepository "nested"
        Add-Manifest $repo "config/`n" "config/`n"
        Write-FixtureFile (Join-Path $repo "config\one\two.local") "nested`n"
        $target = Join-Path $testRoot "nested-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Nested provisioning should succeed."
        Assert-True (Test-Path -LiteralPath (Join-Path $target "config\one\two.local")) "The nested file is missing."
    }

    Invoke-Case "copy paths containing spaces and Unicode" {
        $repo = New-FixtureRepository "unicode"
        Add-Manifest $repo "config space/`n" "config space/`n"
        $relative = "config space\測試.local"
        Write-FixtureFile (Join-Path $repo $relative) "unicode`n"
        $target = Join-Path $testRoot "target space 測試"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Unicode provisioning should succeed."
        Assert-True (Test-Path -LiteralPath (Join-Path $target $relative)) "The Unicode fixture is missing."
    }

    Invoke-Case "report missing source pattern" {
        $repo = New-FixtureRepository "missing"
        Add-Manifest $repo "*.env`n" "missing.env`n"
        $target = Join-Path $testRoot "missing-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "A missing optional file should not fail creation."
        Assert-OutputContains $result "[missing] missing.env" "The missing source pattern was not reported."
    }

    Invoke-Case "preserve existing target file" {
        $repo = New-FixtureRepository "conflict"
        Add-Manifest $repo ".env`n" ".env`n"
        Invoke-FixtureGit $repo @("checkout", "--quiet", "-b", "target-with-file") | Out-Null
        Write-FixtureFile (Join-Path $repo ".env") "tracked-target`n"
        Invoke-FixtureGit $repo @("add", "--force", ".env") | Out-Null
        Invoke-FixtureGit $repo @("commit", "--quiet", "-m", "track target file") | Out-Null
        Invoke-FixtureGit $repo @("checkout", "--quiet", "main") | Out-Null
        Write-FixtureFile (Join-Path $repo ".env") "ignored-source`n"
        $target = Join-Path $testRoot "conflict-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", $target, "target-with-file") -AllowFailure
        Assert-Equal 0 $result.ExitCode "A target conflict should be skipped without failing."
        Assert-OutputContains $result "[conflict] .env" "The conflict was not reported."
        $targetContent = [IO.File]::ReadAllText((Join-Path $target ".env")).Trim()
        Assert-Equal "tracked-target" $targetContent "The target file was overwritten."
    }

    Invoke-Case "preserve native Git failure" {
        $repo = New-FixtureRepository "git-failure"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach") -AllowFailure
        Assert-True ($result.ExitCode -ne 0) "Invalid native Git arguments should fail."
        Assert-True (-not $result.Output.Contains("[copied]")) "Copying ran after Git failed."
    }

    Invoke-Case "leave worktree after provisioning rejection" {
        $repo = New-FixtureRepository "copy-failure"
        Add-Manifest $repo ".project-continuity/`n" ".project-continuity/`n"
        Write-FixtureFile (Join-Path $repo ".project-continuity\state.md") "fixture state`n"
        $target = Join-Path $testRoot "copy-failure-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 2 $result.ExitCode "A blocked source should fail provisioning."
        Assert-OutputContains $result "[rejected] .project-continuity/state.md" "The blocked file was not reported."
        Assert-True (Test-Path -LiteralPath (Join-Path $target ".git")) "The created worktree was deleted after provisioning failed."
    }

    Invoke-Case "reject traversal pattern" {
        $repo = New-FixtureRepository "traversal"
        Add-Manifest $repo "*.env`n" "../outside.env`n"
        $target = Join-Path $testRoot "traversal-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 2 $result.ExitCode "A traversal manifest should fail provisioning."
        Assert-OutputContains $result "parent-directory traversal" "The traversal reason was not reported."
    }

    Invoke-Case "reject source reparse point" {
        $repo = New-FixtureRepository "source-reparse"
        Add-Manifest $repo "linked`n" "linked`n"
        $external = Join-Path $testRoot "source-reparse-external"
        [IO.Directory]::CreateDirectory($external) | Out-Null
        Write-FixtureFile (Join-Path $external "local.env") "outside`n"
        New-Item -ItemType Junction -Path (Join-Path $repo "linked") -Target $external | Out-Null
        $target = Join-Path $testRoot "source-reparse-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 2 $result.ExitCode "A source reparse point should fail provisioning."
        Assert-OutputContains $result "source path traverses" "The source reparse point was not reported."
    }

    Invoke-Case "repair raw worktree from discovered primary" {
        $repo = New-FixtureRepository "repair-primary"
        Add-Manifest $repo ".env.local`n" ".env.local`n"
        Write-FixtureFile (Join-Path $repo ".env.local") "repair`n"
        $target = Join-Path $testRoot "repair-primary-target"
        Invoke-FixtureGit $repo @("worktree", "add", "--quiet", "--detach", $target, "HEAD") | Out-Null
        $result = Invoke-FixtureGit $target @("wt-copy") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Automatic repair should succeed. Output: $($result.Output)"
        Assert-OutputContains $result "Source worktree:" "The selected source was not reported."
        Assert-True (Test-Path -LiteralPath (Join-Path $target ".env.local")) "Repair did not copy the file."
    }

    Invoke-Case "repair raw worktree from explicit source" {
        $repo = New-FixtureRepository "repair-explicit"
        Add-Manifest $repo ".env.test`n" ".env.test`n"
        Write-FixtureFile (Join-Path $repo ".env.test") "explicit`n"
        $target = Join-Path $testRoot "repair-explicit-target"
        Invoke-FixtureGit $repo @("worktree", "add", "--quiet", "--detach", $target, "HEAD") | Out-Null
        $result = Invoke-FixtureGit $target @("wt-copy", "--source", $repo) -AllowFailure
        Assert-Equal 0 $result.ExitCode "Explicit repair should succeed. Output: $($result.Output)"
        Assert-True (Test-Path -LiteralPath (Join-Path $target ".env.test")) "Explicit repair did not copy the file."
    }

    Invoke-Case "forward branch and start-point arguments" {
        $repo = New-FixtureRepository "branch-forwarding"
        Invoke-FixtureGit $repo @("checkout", "--quiet", "-b", "develop") | Out-Null
        Write-FixtureFile (Join-Path $repo "develop.txt") "develop`n"
        Invoke-FixtureGit $repo @("add", "develop.txt") | Out-Null
        Invoke-FixtureGit $repo @("commit", "--quiet", "-m", "develop marker") | Out-Null
        Invoke-FixtureGit $repo @("checkout", "--quiet", "main") | Out-Null
        $target = Join-Path $testRoot "branch-forwarding-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--", "-b", "feat/from-develop", $target, "develop") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Native branch arguments should succeed."
        Assert-OutputContains $result "Handoff reminder: continuity and uncommitted changes stay in this worktree." "The handoff reminder was not printed."
        Assert-OutputContains $result "Open this exact path in Claude Code, Codex, or Copilot:" "The exact-path instruction was not printed."
        Assert-OutputContains $result "Then say: Continue from project continuity." "The continuation prompt was not printed."
        Assert-OutputContains $result "Use a separate worktree for another unfinished task." "The task-isolation reminder was not printed."
        $branch = Invoke-FixtureGit $target @("branch", "--show-current")
        Assert-Equal "feat/from-develop" $branch.Output.Trim() "The target branch is wrong."
        Assert-True (Test-Path -LiteralPath (Join-Path $target "develop.txt")) "The worktree did not start from develop."
    }

    Invoke-Case "open completed worktree in VS Code" {
        $repo = New-FixtureRepository "open-code"
        $shimDirectory = Join-Path $testRoot "code-shim"
        [IO.Directory]::CreateDirectory($shimDirectory) | Out-Null
        $logPath = Join-Path $testRoot "code-invocation.txt"
        $codeShim = '@echo off' + "`r`n" +
            '> "%WORKTREE_PROVISION_TEST_CODE_LOG%" echo %*' + "`r`n" +
            'exit /b 0' + "`r`n"
        Write-FixtureFile (Join-Path $shimDirectory "code.cmd") $codeShim
        $target = Join-Path $testRoot "open-code-target"
        $previousPath = $env:PATH
        $previousLog = $env:WORKTREE_PROVISION_TEST_CODE_LOG
        try {
            $env:PATH = "$shimDirectory;$previousPath"
            $env:WORKTREE_PROVISION_TEST_CODE_LOG = $logPath
            $result = Invoke-FixtureGit $repo @("wt-add", "--open-code", "--", "--detach", $target, "HEAD") -AllowFailure
        } finally {
            $env:PATH = $previousPath
            $env:WORKTREE_PROVISION_TEST_CODE_LOG = $previousLog
        }
        Assert-Equal 0 $result.ExitCode "Opening VS Code should succeed through the shim. Output: $($result.Output)"
        Assert-True (Test-Path -LiteralPath $logPath) "The VS Code shim was not invoked."
        Assert-True ([IO.File]::ReadAllText($logPath).Contains("--new-window")) "The VS Code invocation omitted --new-window."
    }

    Invoke-Case "dry run creates nothing" {
        $repo = New-FixtureRepository "dry-run"
        Add-Manifest $repo ".env.local`n" ".env.local`n"
        Write-FixtureFile (Join-Path $repo ".env.local") "dry`n"
        $target = Join-Path $testRoot "dry-run-target"
        $result = Invoke-FixtureGit $repo @("wt-add", "--dry-run", "--", "--detach", $target, "HEAD") -AllowFailure
        Assert-Equal 0 $result.ExitCode "Dry run should succeed."
        Assert-OutputContains $result "[eligible] .env.local" "Dry run did not report the eligible file."
        Assert-True (-not (Test-Path -LiteralPath $target)) "Dry run created a worktree."
    }
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $safePrefix = $temporaryParent + [IO.Path]::DirectorySeparatorChar + "git-worktree-provision-tests-"
    if ($resolvedTestRoot.StartsWith($safePrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Host "Worktree tool tests: passed=$passed failed=$failed"
if ($failed -gt 0) { exit 1 }
