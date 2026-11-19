# Ender Hub Loader

Krypt-protected release distribution for Ender Hub. This repository is the layout
and runtime reference for `QilexCrown/Ender-Hub-source`, the readable source
counterpart. The source repository follows this release, not the other way around.

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/EnderHubLoader/main/loader.luau"))()
```

The current entry point embeds WindUI and the protected hub runtime. It retains
the existing executor compatibility shim and boot error reporting. The module
paths below remain available for compatibility; listing them does not mean the
current entry point fetches each tab separately at boot.

## Shared layout

| Path | Release artifact |
| --- | --- |
| `loader.luau` | shipped entry point |
| `Main.luau` | compatibility runtime module |
| `EnderApi.luau` | compatibility API module |
| `src/Main.luau` | assembled protected runtime |
| `src/tabs/*.luau` | 12 protected tab modules |
| `languages/*.luau` | locale bundles and index |
| `themes/Themes.luau` | theme pack |
| `debug/run-hub.luau` | protected developer runner |
| `build-layout.json` | shared runtime path and tab-order contract |

Both repositories carry the same layout contract. The readable counterpart has
matching runtime paths and loader-named tab sources. Its build inlines tab bodies
to preserve shared lexical state; the protected release stays executable as
shipped. Layout synchronization does not publish readable source here.

The contract pins the existing loader checksum and reference runtime commit so
future updates can verify they follow an intentional release change. This layout
alignment does not rebuild or alter any shipped Luau in this repository.

Krypt remains private. Its implementation, credentials, and readable Ender Hub
source are not included in this distribution. Repository visibility is unchanged.

## Licence

Ender Hub is licensed software. Access requires a key bound to the executor's
hardware id; the key tab handles redemption and plan display.
