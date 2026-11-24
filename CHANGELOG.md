# Changelog

## 0.2.0-alpha.9 — 2026-11-25

- Open one window with `/vasagoio`: Setup first, plus Details, Report, Performance and Tools. Keep Apply preset and Reload UI on Setup; make Reload available outside combat throughout the window.
- Add a selectable Copy report with exact compatibility reasons, addon versions and structured checks. Press Cmd+C or Ctrl+C; no automatic clipboard claim or private profile/chat contents.
- Show Ready to apply separately from Applied. Identify blocked presets and preserve actionable Bartender explanations.
- Accept only tiny native square-button rounding differences (0.001 UI unit); guard backpack getters and report invalid measurements without guessing dimensions or bypassing required setup checks.
- Review FUF 0.81.1, Forever Trinket Menu 1.8.20, Auctionator 353 and Talents Forever 0.38.33.20261124, retaining earlier supported versions. Verify all 730 proposed FUF settings against its installed registries at three supported scales.
- Add guarded aura-test and styling controls, with an explicit two-step snapshot restore in Tools. Closing or leaving Tools cancels confirmation. No automatic reload or new polling.

This keeps design revision 11 and preset marker 4. An already applied, matching alpha.8 preset does not need another application. A blocked alpha.8 preset still needs Apply and Reload after checks pass. The original Bartender failure's exact runtime cause remains unconfirmed; copy the new report if it persists. Native visuals, combat, clipboard interaction and alpha acceptance require user testing.

## 0.2.0-alpha.8 — 2026-11-25

- Apply Vasagoio Specs revision 11: Large 304×72, Medium 224×56, Small 176×40, shared 16px resource bars and 72px clearance above the nearest action row. Player XP fits inside the 72px frame.
- Center the 842px action and utility group. Align two 42px equipped trinkets and the single bag button with the three main rows; retain native actions, flyouts and queue behavior.
- Correct Threat Plates scale, exact HP and name text, threat colors, cast/status anchors and permitted aura markers. Keep explicit role choices and report conflicting custom rules.
- Correct the 216×186 map artwork with its 32px bottom label, and the 248×186 total Details bounds. Keep native Prat message frames while styling their chrome.
- Add player combat and party/raid aggro edges, 16px PvP badges and own hunter-pet happiness name colors. Hide the duplicate Blizzard player castbar through FUF.
- Normalize layered backdrops, add static material, strengthen empty action/bag placeholders, and set near-unit auras to 28px. Native scene blur and automatic long/short aura routing remain outside this implementation.
- Advance setup verification: reapply the preset and reload. Offline regressions cover profile changes, restricted values, failed writes and cleanup; native FPS, combat, map pins and visual parity require user testing.

## 0.2.0-alpha.7

- Added faint, borderless empty placeholders to the four main Bartender action bars and supported empty Baganator slots. Existing action assignments, bag organization, item indicators and bindings remain owned by their addons.
- Added an XP-only strip beneath player power without changing the 320×64 frame or its 64px portrait: health42 + gap2 + power14 + gap2 + XP4. Original 46/2/16 rows return at maximum level or when XP is unavailable; target geometry remains unchanged.
- Disabled Bartender's old StatusTrackingBar through reviewed setup so its long strip no longer crosses the action grid. Setup snapshots preserve restoration.
- Added `/vasagoio auratest show`, `hide` and `reset` as an optional native buff/debuff comparison. It is closed by default and needs no separate addon. It does not replace existing aura displays or add controls to the two-action setup screen.
- Documented unresolved aura experiment limits: 40 candidates per native view, gaps in Long, exactly-60-second classification, permanent effects after pool reuse and native combat acceptance. The test is not production duration sorting.

Update from alpha.6 with WoW closed, keeping SavedVariables. Replace only vasagoio, Apply preset and Reload UI. Open the optional aura test manually afterward and hide it when finished. The requested RestedXP redesign and native quest-tracker replacement are still pending; this release does not claim those changes or an accepted fallback.

## 0.2.0-alpha.6

- Fixed Prat setup resolving the short module name `Font` instead of its actual `Prat_Font` SavedVariables namespace. The adapter verifies the active runtime profile and saved namespace refer to the same data before proposing changes.
- Added safe missing-module lookup and an actionable message when Prat's Font module is disabled. Profile changes or disabling Font after review reject Apply without writes.
- Added source-reviewed FUF 0.81.0 unit-frame and aura support, retaining 0.79.1. The new wrapping option keeps the agreed party column, and new raid resource-color fields use the shared palette.
- Advanced preset compatibility to include these functional changes; previous snapshots show Ready until setup is explicitly applied and reloaded.
- Added a regression suite exercising Prat review, application and restoration through the actual profile engine, plus updated FUF unit/aura and status fixtures.

Replace only the vasagoio folder with WoW closed, keeping SavedVariables. Run `/vasagoio setup`, Apply preset, then Reload UI. Earlier performance fixes remain included; native FPS/visual acceptance is still pending.

## 0.2.0-alpha.5

- Replaced the technical setup report and management controls with a compact preset/status screen: Apply preset, Reload UI, component rows and inline results. Problems are shown first.
- Required core HUD readiness is enforced by the profile engine before any writes; optional unavailable components remain visible as Skipped.
- Applied status checks the preset marker, saved values, active owner profile and available runtime status. Old or partial snapshots cannot silently appear fully configured.
- Highlighted Reload UI after success, preserved explicit reload, and disabled both actions in combat. The screen adds no polling loop.
- Kept technical field/status/performance reports and snapshot recovery as separate commands.

The alpha.4 performance and HUD fixes remain included. Updating preserves settings; older unmarked snapshots show Ready until an explicit apply/reload establishes the current preset. Native validation remains pending.

## 0.2.0-alpha.4

The first user-run alpha.3 test showed a large FPS drop and leftover HUD overlap. This candidate removes confirmed redundant styling work and corrects the reviewed layout. Native FPS recovery is pending the user's comparison.

- Scoped action/unit refreshes to their own modules, coalesced bursts and bounded reentrant callbacks while preserving a follow-up for newly created widgets.
- Deferred closed-window traversal, stopped repeated repainting of stationary native windows, deduplicated nested walks and cached unchanged surface/font updates.
- Filtered aura updates by affected units and buttons; unchanged and unrelated aura events no longer repaint all FUF pools.
- Added `/vasagoio perf` for module-application counts and timings; it does not measure total addon CPU or FPS.
- Updated Bartender setup to hide extra normal bars and disable BlizzardArt, BagBar and MicroMenu, preserving slots, binding configuration, paging and special controls.
- Removed inherited idle cast rows and the player's redundant threat row while preserving actual cast feedback.
- Added reviewed RestedXP v4.11.40 guide placement beside native objectives, with synchronized saved/live anchors on apply and restore, plus conflict protection.

Replace the addon folder with WoW closed. Keep SavedVariables, enable vasagoio, run `/vasagoio setup` again and reload to apply the layout corrections. Keep Skinner unchanged for a same-scene FPS comparison. CurseForge publication remains deferred until alpha acceptance.

## 0.2.0-alpha.3

- Added source-reviewed Gargul 8.1.1 compatibility while retaining 8.1.0. Its existing and lazily created windows use the reviewed interior adapter; future unreviewed versions still skip it.
- Selected Details' bundled TinyThreat as the threat meter and removed ThreatClassic2 from the install plan. The selection is now 26 packages, with TinyThreat recorded under Details.
- Documented TinyThreat selection and first-run checks. The existing Details window-1 preset supplies its typography, dimensions and surface; additional windows and TinyThreat's native threat colors remain owner-managed.

This is an offline-validated alpha candidate. Native visuals, combat behavior and alpha acceptance still require user-run checks; CurseForge publication remains pending.

## 0.2.0-alpha.2

Adds reviewed compatibility for Talents Forever Book 0.38.33.20261123 so a fresh installation can use its current release. The earlier 0.38.28.20261116 contract remains supported; unreviewed future releases still retain their owner appearance. New drawer and plan-state handling preserves native layout and meaningful state indicators.

This remains an alpha candidate for user-run installation, visual and combat checks. Offline validation does not mark native acceptance complete, and CurseForge publication remains pending that acceptance.

## 0.2.0-alpha.1

The previous build styled window shells but left their interiors inconsistent. This release extends the shared design into native and selected-addon controls while retaining their original layouts and behavior.

- Added scoped interior primitives for buttons, tabs, inputs, checkboxes, dropdowns, scroll controls, labels and panels. Selected tabs/rows and focused inputs use the accepted near-black fill with a small blue bottom marker; no blue selection fill.
- Added native candidate registry, interior artwork maps, narrative text treatment, dynamic stat rows and native selection bindings. Registered all 132 eligible source-catalog candidates across 115 primary hosts; excluded frontend/browser/HUD/media boundaries explicitly.
- Added all 19 Baganator skin-region types, Talents Forever pane/control styling, MRT tools/popups, Auctionator panes and Gargul 8.1.0 registry-based integration.
- Preserved semantic item/quest/requirement colors, content textures, native metrics, clicks, keyboard focus, scripts and secure attributes. Decorative frames are excluded from native automatic layout.
- Added shared skin ownership, module restoration, source-catalog consistency and regression fixtures for currency icons, font wrappers, selection, lazy controls and combat deferral.

Native visual and combat/taint validation remains pending. No game or updater was launched, and no live addon/WTF files were modified during development.

## 0.1.0-alpha.1

First native implementation of the accepted Bael design under the name **vasagoio**.

- Added reviewed addon-profile setup, persistent snapshots and conflict-aware restoration.
- Added unit/nameplate, action, HUD, native window and selected-addon skin modules.
- Preserved original native window structures and functional addon ownership.
- Added shared geometry, color and typography tokens, original rounded masks, status/disable controls and portable packaging.
- Added offline Lua5.1 fixtures, package checks and CI.

Native visual and combat validation is pending. Several accepted details remain partial or blocked by owner capabilities; see docs/COVERAGE.md. This release is not a complete all-window skin.
