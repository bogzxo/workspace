<#
Brings the whole workspace up to what's on GitHub, and clones whatever isn't here yet. Run it before starting work, the
game and Hex build against the engine next to them and not a pinned commit of it, so the engine wants to be as new as
the game is.

  1. The workspace itself (this folder, bogzxo/workspace)
  2. The engine (horizon), then HIDL inside of it (horizon/Horizon.HIDL), which is a submodule of the engine but is
     kept on its own development here so it's worked on like the rest
  3. Hex (hex), with its extensions submodule put where Hex wants it
  4. The game (Fighter2D)

Everything is on development. Uncommitted work is stashed and put back around the pull. A repo with commits of yours
that GitHub hasn't got while GitHub has new ones too isn't touched, it's said, and git -C <repo> pull --rebase in it
sorts it out.

  .\pull-all.ps1
#>

# Git writes its progress to stderr, which Windows PowerShell takes for an error under Stop. Every call's exit code
# is checked by hand instead
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

$repos = @(
    @{ Dir = 'horizon'; Url = 'https://github.com/bogzxo/horizon' },
    @{ Dir = 'hex'; Url = 'https://github.com/bogzxo/hex' },
    @{ Dir = 'Fighter2D'; Url = 'https://github.com/bogzxo/fighter-2d' }
)
$hidl = Join-Path (Join-Path $root 'horizon') 'Horizon.HIDL'

$problems = New-Object System.Collections.Generic.List[string]

function Say([string]$Text, [string]$Colour = 'Gray') { Write-Host $Text -ForegroundColor $Colour }

function Name([string]$Dir) {
    $name = $Dir.Substring($root.Length).TrimStart('\', '/')
    if ($name) { return $name } else { return 'the workspace' }
}

function Branch([string]$Dir) {
    $branch = & git -C $Dir symbolic-ref --short -q HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($branch | Select-Object -First 1)
}

# A repo on its branch brought up to its upstream, only ever fast forwarded
function Pull([string]$Dir, [string[]]$Extra = @()) {
    $branch = Branch $Dir
    if (-not $branch) {
        $problems.Add("$(Name $Dir) isn't on a branch, check out development in it")
        return $false
    }
    if ($branch -ne 'development') { Say "  $(Name $Dir) is on $branch, not development, pulling that" 'DarkYellow' }

    $output = & git -C $Dir pull -q --ff-only --autostash @Extra 2>&1
    if ($LASTEXITCODE -ne 0) {
        $problems.Add("$(Name $Dir) couldn't be pulled, it has commits of yours GitHub hasn't and GitHub has new ones too. git -C `"$Dir`" pull --rebase sorts it out`n$($output -join "`n")")
        return $false
    }

    Say "  $(Name $Dir) is up to date on $branch" 'Green'
    return $true
}

function Clone([string]$Dir, [string]$Url) {
    Say "  cloning $Url into $(Name $Dir)" 'Cyan'
    $output = & git clone -q -b development $Url $Dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        $problems.Add("$Url couldn't be cloned, you might not have access to it yet`n$($output -join "`n")")
        return $false
    }
    return $true
}

# The submodules a repo keeps checked out where it says, HIDL in the engine and the extensions in Hex
function Submodules([string]$Dir) {
    $output = & git -C $Dir submodule update -q --init --recursive 2>&1
    if ($LASTEXITCODE -ne 0) { $problems.Add("$(Name $Dir)'s submodules couldn't be checked out`n$($output -join "`n")") }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Say "Git isn't installed, get it from https://git-scm.com and run this again" 'Red'
    exit 1
}

if (Test-Path (Join-Path $root '.git')) {
    Say 'The workspace' 'Cyan'
    Pull $root | Out-Null
}

foreach ($repo in $repos) {
    $dir = Join-Path $root $repo.Dir
    Say "`n$($repo.Dir)" 'Cyan'

    if (-not (Test-Path (Join-Path $dir '.git'))) {
        if (-not (Clone $dir $repo.Url)) { continue }
        Submodules $dir
    }
    elseif ($repo.Dir -eq 'horizon') {
        # HIDL is pulled on its own below, the engine's commit of it isn't what's worked on here
        Pull $dir @('--no-recurse-submodules') | Out-Null
        if (-not (Test-Path (Join-Path $hidl '.git'))) { Submodules $dir }
    }
    elseif (Pull $dir) {
        Submodules $dir
    }

    if ($repo.Dir -eq 'horizon' -and (Test-Path (Join-Path $hidl '.git'))) {
        # A fresh checkout of HIDL sits on the engine's commit of it, off any branch, and goes onto development
        if (-not (Branch $hidl)) {
            $dirty = @(& git -C $hidl status --porcelain 2>$null | Where-Object { $_ })
            if ($dirty.Count -eq 0) {
                & git -C $hidl fetch -q origin 2>&1 | Out-Null
                $output = & git -C $hidl checkout -q development 2>&1
                if ($LASTEXITCODE -ne 0) { $problems.Add("$(Name $hidl) couldn't go onto development`n$($output -join "`n")") }
            }
        }
        if (Branch $hidl) { Pull $hidl | Out-Null }
        else { $problems.Add("$(Name $hidl) isn't on a branch and has changes, check out development in it") }
    }
}

if ($problems.Count -gt 0) {
    Say "`nNot all of it came down:" 'Red'
    foreach ($problem in $problems) { Say "  $problem" 'Red' }
    exit 1
}

Say "`nDone, everything is as it is on GitHub." 'Green'
