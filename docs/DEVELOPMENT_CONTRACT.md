# vasagoio implementation contract

Original addon; no vendor code/assets copied. Public repository contains only this directory. Do not include private project evidence, WTF, account names, chat/inventory/raid data or downloaded fonts.

Every Lua file receives `local addonName, V = ...`. Core defines these APIs before module files load:

- `V:RegisterModule(id, spec)`: spec contains label, description, defaultEnabled, Apply(self), optional Disable(self). `self` is the spec and `V` is captured from the namespace. Apply must be repeat-safe and out of combat. Return `true, detail` for applied; `false, reason` for unavailable/unsupported. Core stores status and catches errors.
- `V:On(event, fn)`: callback receives event and event arguments. Multiple listeners supported. `V:Refresh(reason)` schedules module applications out of combat.
- `V:Report(id, state, detail)`: record concise status; states applied, pending, unsupported, disabled, error. Do not log personal data.
- `V:Print(text)`: user-facing chat message.
- `V:SafeNumber(value)`: returns an ordinary number only if not a secret value; never compare/stringify restricted values first.
- `V:IsSecret(value)`: wraps the client's available secret-value predicate conservatively.
- `V:Pixel(n)`: convert reference design pixels to UIParent logical units using uniform 2560x1440 fit and configured layout scale. Never call SetScale on UIParent.
- `V:Font(role)`: returns path, size in logical units, flags. Roles name, amount, compact, heading, chat, hotkey, count, countdown, compactCountdown, aura. Native fonts only; no redistributed font binaries. Exact Arial Narrow Bold is unresolved unless client/owner exposes a genuine face; do not simulate bold with OUTLINE.
- `V:StyleText(fontString, role, color)`: apply font, color and soft shadow without boxes/outlines.
- `V:Surface(frame, alpha, radius)`: original decorative background only, round corners where supported, no bounds changes to existing native controls. Implemented by root. Return a surface record/frame; repeated calls update.
- `V:HideArtwork(texture)`: root-managed reversible cosmetic hide, without removing gameplay content.
- `V:Remember(obj, getter, setter)`: optional root utility; avoid relying on it until available. Prefer explicit restoration for changed geometry/profile state.
- `V:RegisterProfileAdapter(id, spec)`: label, addon folder, optional module ID, Prepare(self) returns plan {changes={{table=target,path={"SavedVariableGlobal","nestedTable"},key=key,value=value,label=label},...}, detail=string} or nil,reason; optional AfterApply(self). The path resolves the table; key is separate. Setup validates all plans first, snapshots before writing, applies only on explicit user action out of combat. Disabled modules are excluded. Profiles are not silently reset on login. No vendor-private functions without documented/public contract; native SavedVariables schema changes may be targeted only after exact schema checks.

Runtime state: `V.db` is the addon-owned SavedVariables after ADDON_LOADED. `V.db.enabled`, `.modules[id]`, `.overrides`, `.schemaVersion`, `.presetRevision`, `.profileBackups`. First login defaults cosmetic modules on; profile writes require explicit `/vasagoio setup` review/apply. Addon can be unchecked in WoW's AddOns screen. `/vasagoio off` records disabled and requires reload to fully restore hooks/art; profile rollback is separate.

Root owns Core.lua, Tokens.lua, core/*, TOC, README, source manifest, release workflow and package script. Agents own assigned modules and module tests only. Coordinate API changes with root. All functions must guard absent owners and load-on-demand windows, avoid changing protected frames in combat, preserve original native screen structures and selected addon features. Do not launch WoW/CurseForge or write live addon files.

Accepted design: L320x64 health46/resource16; M224x48 health34/resource12; S192x32 health22/resource8; XS128x32 health28/resource4. Portrait=height and2px picture/bar gaps except XS. Names16, compact amounts/percent14. Native Friz default, native Arial Narrow regular chat16, actual Bold roles only when genuine face available. Main42/pet32 icons, gaps8, pet row10left aligned, main16x3, mainwidth792, petwidth392. Player(884,1098),target(1356,1098),pet(672,1114),ToT(1696,1114),84nearest-rowgap on2560x1440. Chat480,map216,meter248,gap16,height186 atbottom8. Radius10outer,0interior, neutralblack#0B0B0B, surfacealpha unit.56/chat.40/window.84. Raid2columns, group gaps12x16, cells6verticalgap. Group titlesoff. Party224x48,pet192x32beside12gap,row12gap. No native window re-layout.

Semantic colors danger signal#E4A0A8/fill#8B4E57/range#AB2D3C30%; information#A8D7EB/fill#486C89; attention#E7CC82/fill#866242. Buff36priority28, bottom signal3high/gap2/insets6, aura wrapgap16. Cooldown full-button radial wipe, remainingblack.8/elapsed.12, centered18main16compact; hotkeyhiddenactive, counttop-right(-8,+6)active/restoredbottomright2ready. No boxes. Nameplates192x24cast16gap8, exact currentHP, valid hostileNPC role/threat states0/3calm/dangerinvertTankvsDPS,1/2warning. Native restricted values are passed through supported owner widgets; never infer hidden values.

All agreed details must be present in code/config/coverage manifest with honest implementation status. Do not mark an unsupported effect implemented merely because a token exists. Browser blur cannot be claimed as native Frosted blur. All native behavior untested until user-run validation.
