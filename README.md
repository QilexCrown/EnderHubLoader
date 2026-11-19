# Ender Hub Loader

## 2.8.3 — Native glass controls

Main remains design-only and uses shared glass action/segment controls within native VStack/HStack cards. Info Rejoin and Server Hop use the same controls. The collapsed sidebar uses finite fade/slide/hover/selection motion, handles sparse tab indices and includes the existing visual tab as an eye icon. Visuals controls are unchanged.

The Main consent card is removed; functional withdrawal is in Settings. Startup consent and data-collection guards remain active until the owner implements a replacement. Glass is a native UI material approximation, not scene refraction. No feature logic, new collection or private-chat access was added.

## 2.8.2 — Main design only

The Main feature implementation has been removed at the project owner's request. Main now contains only layout, native controls, placeholders and inspector segment navigation. FPS, object inspection/highlighting, profile lookup, clipboard, audio, chat subscriptions and name masking are not connected. All feature switches default off. UI handles are available as `HX.MainUI`; see `docs/MAIN-UI.md` in the readable source checkout. Existing consent and withdrawal safeguards remain operational. Other tabs and the accepted sidebar rail are unchanged.

## 2.8.1 — Main layout

Main uses full-width FPS controls with separate, mutually exclusive limit and unlimited switches. Inspectors use the World-style Block/Boombox segmented card. Block details include username, display name, observed server status and adjacent copy actions. Boombox includes audio-ID copy and local Play/Pause/Stop preview. Only the Main introduction section has a description. Existing consent and local-only public chat remain in place.

## 2.8.0 — Main and startup consent

Main now contains FPS controls (unlimited by default when supported), block and boombox inspector cards with copy actions and outlines, a local public-chat view, and reversible local name masking.

Startup requires explicit consent before IP/device/profile collection or API requests. Decline or dismiss stops startup. Approval is per execution; saved settings and environment flags cannot approve it. Main includes Withdraw consent & close. The standalone API has a visible Stop Collection button. Withdrawal stops future collection; it does not delete records already sent.

Chat forwarding is removed from both API implementations. The chat view only displays delivered RBXGeneral messages locally. Local name masking does not change IP or HWID. No fake anti-grabber, IP/HWID spoofing or covert whisper controls are included.

Collection destinations: https://ehubdiscordbot.onrender.com and fallback https://ehub-bot.onrender.com; HTTPS IP lookup via https://api.ipify.org. A configured API override is displayed in the consent prompt instead. The prompt lists profile, hardware/device identifier, IP, license key, server, executor/platform and session/performance fields.

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

The contract pins the loader checksum and reference runtime commit so future
updates can verify they follow an intentional release change.

Krypt remains private. Its implementation, credentials, and readable Ender Hub
source are not included in this distribution. Repository visibility is unchanged.

## Licence

Ender Hub is licensed software. Access requires a key bound to the executor's
hardware id; the key tab handles redemption and plan display.

## 2.7.4 — Info styling

The welcome card, credits and right-side feedback shortcut now follow the native
WindUI element surfaces, theme colors, typography and rounded corners. Statistics
use a compact icon-and-text row. The updated hub runtime and Info template were
processed with the private Krypt checkout; the private implementation is not
included here. The embedded library is the tested WindUI fork build.
