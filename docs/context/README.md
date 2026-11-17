# Context maps

Maps of the workspace for anyone, person or agent, picking up work in it cold. Each one was written by reading the
code and cites `path:line`. Line numbers drift as code moves, so grep the symbol when one is off; numbers marked `~`
were approximate from the start. Each map lives in the repo it describes, so it's committed and pushed with that repo.

Start with `workspace.md`, then the map for the area you're touching.

| Map | Covers |
| --- | --- |
| [workspace.md](workspace.md) | The workspace: repos, build and how the engine is referenced, CI, pull/push order, tasks.hor, code and commit style |
| [horizon/docs/context/engine-core.md](../../horizon/docs/context/engine-core.md) | Engine core: GameEngine, Scene/Entity/Component, the three threads, lifecycle, platform seam, content, input, audio, physics |
| [horizon/docs/context/engine-rendering.md](../../horizon/docs/context/engine-rendering.md) | Vulkan backend, Renderer2D, frame flow, Slang shaders and the packed shader pack for mobile |
| [horizon/docs/context/ui-framework.md](../../horizon/docs/context/ui-framework.md) | Horizon.UI: the compositor, layout, HIDL layouts, skins, input and focus, controls, the text editor |
| [horizon/docs/context/engine-platforms-tooling-tests.md](../../horizon/docs/context/engine-platforms-tooling-tests.md) | Desktop, Android and iOS heads, Horizon.Terminal, Horizon.Tooling (LSP/DAP), Horizon.Testing, Horizon.Tests, AutoVoxel, engine CI |
| [horizon/Horizon.HIDL/docs/context.md](../../horizon/Horizon.HIDL/docs/context.md) | HIDL: the language, its pipeline and runtime, and its use in `.hor` / `.jab` / `.hex-workspace` files |
| [hex/docs/context/core-and-mcp.md](../../hex/docs/context/core-and-mcp.md) | Hex architecture, Hex.Core subsystems, the MCP server and its tools, the harness index, agents and extensions |
| [hex/docs/context/dawn-app.md](../../hex/docs/context/dawn-app.md) | Hex.Dawn, the editor app: DawnScene, commands and menus, languages, debugging, git, agent UI, threading |
| [hex/docs/context/testing-and-shipping.md](../../hex/docs/context/testing-and-shipping.md) | Hex unit tests, in-app self-tests, Dusk, Android, installer, versioning and releases |
| [Fighter2D/docs/context/game.md](../../Fighter2D/docs/context/game.md) | Fighter2D: startup, the fight simulation, netcode, `.hor` data for fighters, moves and arenas, tests, Android |

## Things worth knowing before anything else

- Each folder is its own repo, all on `development`. Pull everything before working and push in order after
  (`pull-all` / `push-all`). Push all refuses commits that credit an AI.
- Hex and the game build against the engine source next to them, not a package. A broken engine breaks both.
- HIDL is everywhere: tasks, settings, extensions, UI layouts, and game data are all `.hor` files.
- The engine has three threads (platform, render, simulation) and sleeps when idle in application mode. Work done
  off the UI thread has to `Wake()` it.
- Shaders compile at run time on desktop but come from a prebuilt pack on Android and iOS, so a shader missing from
  the pack works on the desktop and fails on a phone.
- Hex self-tests need a window and Vulkan, CI never runs them, and they're run from `hex/Hex/bin`.
