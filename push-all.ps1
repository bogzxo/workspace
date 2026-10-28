<#
Pushes the workspace in the order things depend on each other, so nothing on GitHub ever needs a commit that isn't
there yet.

  1. HIDL (horizon/Horizon.HIDL), the language the engine is built on
  2. The engine (horizon), with its HIDL submodule moved on to what was just pushed when that moved
  3. Hex and Fighter2D, which build against the engine on GitHub as it is, so they go after it
  4. The workspace itself

Every repo is fetched first. One that GitHub has commits for that aren't here stops the lot, pull-all.ps1 first, and
so does a commit that credits Claude or an AI, before anything is pushed. Uncommitted work is left where it is and
said, it's yours to commit. Only HIDL's move in the engine is committed here.

  .\push-all.ps1            does it
  .\push-all.ps1 -DryRun    says what it would do and changes nothing
#>
param(
    [switch]$DryRun
)

# Git writes its progress to stderr, which Windows PowerShell takes for an error under Stop. Every call's exit code
# is checked by hand instead
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

# The repos that are pushed, in order. Hex, the game and the workspace are left out on a machine that hasn't got them
$hidl = Join-Path (Join-Path $root 'horizon') 'Horizon.HIDL'
$engine = Join-Path $root 'horizon'
$after = @(
    (Join-Path $root 'hex'),
    (Join-Path $root 'Fighter2D'),
    $root
) | Where-Object { Test-Path (Join-Path $_ '.git') }

# What gives a commit away as Claude's, which never goes to GitHub
$credit = 'co-authored-by:\s*claude|generated with \[?claude|noreply@anthropic\.com'

# Named so it can't be taken for git itself, PowerShell doesn't mind the case of a name and a function called Git
# called itself forever
function Invoke-Git {
    param([string]$Dir)
    $output = & git -C $Dir @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git -C $Dir $($args -join ' ') failed`n$($output -join "`n")" }
    return $output
}

function Say([string]$Text, [string]$Colour = 'Gray') { Write-Host $Text -ForegroundColor $Colour }

function Name([string]$Dir) {
    $name = $Dir.Substring($root.Length).TrimStart('\', '/')
    if ($name) { return $name } else { return 'the workspace' }
}

# The commits a repo has that its upstream hasn't, oldest first
function Unpushed([string]$Dir) {
    $ahead = & git -C $Dir rev-list --reverse '@{u}..HEAD' 2>$null
    if ($LASTEXITCODE -ne 0) { throw "$(Name $Dir) has no upstream branch to push to, check it out on a branch first" }
    return @($ahead | Where-Object { $_ })
}

# The commits its upstream has that a repo hasn't
function Missing([string]$Dir) {
    return @(& git -C $Dir rev-list 'HEAD..@{u}' 2>$null | Where-Object { $_ })
}

function Push([string]$Dir) {
    $ahead = Unpushed $Dir
    if ($ahead.Count -eq 0) { Say "  $(Name $Dir) is on GitHub already"; return }

    $branch = (Invoke-Git $Dir rev-parse --abbrev-ref HEAD) | Select-Object -First 1
    if ($DryRun) { Say "  would push $($ahead.Count) commit(s) of $(Name $Dir) to origin/$branch" 'Yellow'; return }

    Invoke-Git $Dir push origin $branch | Out-Null
    Say "  pushed $($ahead.Count) commit(s) of $(Name $Dir) to origin/$branch" 'Green'
}

# Whether a commit is on GitHub, which is what a submodule may point at
function On-GitHub([string]$Dir, [string]$Commit) {
    $branches = & git -C $Dir branch -r --contains $Commit 2>$null
    return [bool]($branches | Where-Object { $_ -match 'origin/' })
}

try {
    if ($DryRun) { Say "Dry run, nothing is changed`n" 'Cyan' }

    # Everybody fetched, nobody behind GitHub, and nothing that credits Claude goes anywhere
    Say 'Checking the repos' 'Cyan'
    $all = @($hidl, $engine) + @($after)
    foreach ($dir in $all) {
        if (-not (Test-Path (Join-Path $dir '.git'))) { throw "$(Name $dir) isn't a git checkout, setup.ps1 clones it" }
        Invoke-Git $dir fetch -q origin | Out-Null

        foreach ($commit in (Unpushed $dir)) {
            $text = (Invoke-Git $dir log -1 --format='%an %ae%n%B' $commit) -join "`n"
            if ($text -match $credit) {
                throw "$(Name $dir) $($commit.Substring(0, 7)) credits Claude or an AI, take that out of it (git commit --amend, or a rebase) and run this again"
            }
        }

        $behind = Missing $dir
        if ($behind.Count -gt 0) { throw "GitHub has $($behind.Count) commit(s) of $(Name $dir) that aren't here, run pull-all.ps1 first" }

        $dirty = @(& git -C $dir status --porcelain --ignore-submodules=all | Where-Object { $_ })
        if ($dirty.Count -gt 0) { Say "  $(Name $dir) has $($dirty.Count) uncommitted change(s), they stay here" 'DarkYellow' }
    }

    # HIDL, then the engine pointing at it
    Say "`nHIDL" 'Cyan'
    Push $hidl
    $hidlAt = (Invoke-Git $hidl rev-parse HEAD) | Select-Object -First 1

    Say "`nThe engine" 'Cyan'
    $pinned = (Invoke-Git $engine rev-parse 'HEAD:Horizon.HIDL') | Select-Object -First 1
    if ($pinned -eq $hidlAt) {
        Say "  the engine has HIDL at $($hidlAt.Substring(0, 7)) already"
    }
    elseif ($DryRun) {
        Say "  would move the engine's HIDL from $($pinned.Substring(0, 7)) to $($hidlAt.Substring(0, 7)) and commit it" 'Yellow'
    }
    else {
        if (-not (On-GitHub $hidl $hidlAt)) { throw "HIDL $($hidlAt.Substring(0, 7)) isn't on GitHub, the engine can't point at it" }
        $hidlSubject = (Invoke-Git $hidl log -1 --format=%s $hidlAt) | Select-Object -First 1
        Invoke-Git $engine add '--' Horizon.HIDL | Out-Null
        Invoke-Git $engine commit -q -m "HIDL at $hidlSubject" '--' Horizon.HIDL | Out-Null
        Say "  moved the engine's HIDL to $($hidlAt.Substring(0, 7)) and committed it" 'Green'
    }
    Push $engine

    # Everything on the engine, now that it's on GitHub as they want it
    foreach ($dir in $after) {
        Say "`n$(Name $dir)" 'Cyan'
        Push $dir
    }

    Say "`nDone, everything is on GitHub in order." 'Green'
}
catch {
    Say "`nStopped. $($_.Exception.Message)" 'Red'
    exit 1
}
