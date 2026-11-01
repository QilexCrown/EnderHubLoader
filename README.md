# Ender Hub Loader

Public loader for Ender Hub.

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/QilexCrown/EnderHubLoader/main/loader.luau"))()
```

The loader resolves the language bundles and the theme pack, then hands the
compiled runtime to `src/Main.luau`. Every module is fetched from this repository
and cached for the session, so a re-execute does not re-download the hub.

## Layout

| Path | What it is |
| --- | --- |
| `loader.luau` | entry point, resolves remote modules |
| `src/Main.luau` | hub runtime, licence gate, tab registry |
| `src/tabs/*.luau` | one module per sidebar tab |
| `languages/*.luau` | locale bundles, 10 languages (en, he, es, pt, fr, de, tr, id, ru, ar) |
| `themes/Themes.luau` | WindUI theme pack |
| `debug/run-hub.luau` | developer runner with a full traceback |

## Licence

Ender Hub is licensed software. Access requires a key bound to the executor's
hardware id; the key tab inside the hub handles redemption and the plan display.
