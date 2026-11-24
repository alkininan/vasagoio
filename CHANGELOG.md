# Changelog

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
