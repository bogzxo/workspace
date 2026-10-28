# The Horizon workspace

The folder the engine, Hex and Fighter2D are worked on in together. Each is its own repo, cloned next to each other
in here, and `Directory.Build.props` has them all build against the one engine checkout, so a change to the engine is
seen by Hex and the game the moment it's saved. `Horizon.Workspace.sln` opens the lot.

| Folder | Repo | What it is |
| --- | --- | --- |
| `horizon` | [bogzxo/horizon](https://github.com/bogzxo/horizon) | The engine |
| `horizon/Horizon.HIDL` | [bogzxo/hidl](https://github.com/bogzxo/hidl) | HIDL, the language, a submodule of the engine |
| `hex` | [bogzxo/hex](https://github.com/bogzxo/hex) | Hex, the editor |
| `Fighter2D` | [bogzxo/fighter-2d](https://github.com/bogzxo/fighter-2d) | The game |

Everything is on `development`. Nothing pins the engine any more, Hex and the game build against whatever engine is
next to them, here or in CI, so the one rule is to pull everything before working and push everything in order after.

## Getting going

You want [Git](https://git-scm.com), the [.NET 11 SDK](https://dotnet.microsoft.com/download/dotnet/11.0) (a preview
or release candidate is fine), and access to the repos above (fighter-2d is private, ask bogz to add you). On Linux or
macOS you want [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) too.

```
git clone https://github.com/bogzxo/workspace horizon
```

Then run `setup.cmd` in the new `horizon` folder on Windows (double click it), or `pwsh setup.ps1` on Linux and macOS.
It checks for the SDK and clones the engine, HIDL, Hex and the game into place. Open `Horizon.Workspace.sln`, or
`dotnet build Fighter2D` to build the game.

## Every day

- **Before working** `pull-all.cmd` (or `pwsh pull-all.ps1`). Brings every repo up to what's on GitHub, the workspace
  itself too, and clones anything that's new. Uncommitted work is stashed around the pull and put back. If you and
  GitHub both have new commits in a repo it leaves that one alone and says so, `git pull --rebase` in it sorts it.
- **Commit** in each repo as normal, on `development`.
- **After working** `push-all.cmd` (or `pwsh push-all.ps1`, `-DryRun` to see what it'd do). Pushes HIDL, then the
  engine (moving its HIDL submodule on and committing that if HIDL moved), then Hex, the game and the workspace. That
  order means GitHub never has a game commit that needs an engine commit that isn't up yet. It stops before pushing
  anything if GitHub has commits you haven't pulled, so pull first.

In Hex the same three are automations, Pull all, Push all and Push all (dry run), from `tasks.hor`.

## When the game won't build

Nine times out of ten the engine and the game are out of step, someone pushed both and you pulled one. Run
`pull-all` and build again. If the engine on GitHub itself is broken for the game, the fix goes into the engine and
gets pushed, there's no older engine commit the game is held at.
