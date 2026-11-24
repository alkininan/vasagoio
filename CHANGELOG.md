# Changelog

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
