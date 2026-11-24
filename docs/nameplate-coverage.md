# Nameplate implementation coverage

This is a derived implementation and test record for `modules/Nameplates.lua`, not a second design specification. The accepted design remains in the project’s master **Vasagoio Specs DOCX, revision 12**. Source review covers **Threat Plates 13.3.9**. No game launch, combat test or visual acceptance is implied by the offline checks.

## Implemented paths

| Area | Implementation and boundary |
| --- | --- |
| Profile setup | Read-only preparation creates a separate themed profile on Apply. Previous profiles and unrelated settings remain present. Shared dual-spec assignments follow the copied profile; independent assignments stay unchanged. Apply/restore requires reload. |
| Geometry | Profile fields normalize health to 224×24, cast to 224×16 with 8px clearance, and auras to 28px. Category scales and inherited target/non-target size/fade adjustments are normalized. Dimensions use the shared reference-canvas conversion. Additional aura rows and enabled cast-target text can extend the baseline envelope. |
| Text and track | Names occupy the left 120px lane inside health; exact current HP occupies the right 80px lane. Names use Friz 16, HP 14, fixed ivory HP, palette class colors for ordinary player identities and ivory for NPCs. Restricted class tokens pass directly to the native class-color renderer. The outer track is opaque neutral black with radius 10; health/cast fills remain square. Explicit Vasagoio Flat shared media uses native WHITE8X8, avoiding a missing-Flat fallback to glossy Blizzard bars. |
| Threat and casts | Threat Plates supplies native role and threat state. LOW/HIGH use opposing blue/red tank versus DPS colors; MEDIUM is amber. Explicit existing automatic-role preference is preserved, with automatic detection supplied only when unset. The native non-interruptible shield, cast name/time and meaningful target/raid markers remain available. Target selection uses the owner's squarethin 1px blue outline at .85 opacity. Level moves left (32px lane, 2px from the outline); rare/elite icons move right (16px, 2px gap). The native reaction fallback uses the design palette instead of stock bright-red idle NPC bars. |
| Aura presentation | Owner filters, durations, counts and cooldown calculations remain native. Profile typography supplies bottom-inside duration and top-attached count. Out of combat, scoped decoration reuses an existing native border region for semantic bottom markers. Native pool reuse changes the marker with its group. The owner’s existing SquareMask is preserved: this adapter does not implement an exact 10px aura-icon radius or create additional restricted regions. No aura payload is read or reconstructed. |
| Conflicts and cleanup | Required profile differences and enabled custom color/scale/alpha overrides report Pending. Native cosmetic refusals also report Pending. Disable or a changed owner profile releases added tracks and restores captured native background/name colors and aura-marker geometry/art, including texture slice margins. Combat cleanup waits until combat ends. Failed marker restoration is retained for retry and requests reload. Full hook/mask removal requires reload. |

Custom nameplate rules and gameplay filters are preserved; their presence is not a guarantee of visual conformity. Newly allocated or restricted combat aura buttons can retain the owner’s appearance until an unrestricted refresh. The update path uses nameplate/aura events and an out-of-combat refresh, with no new polling ticker or `OnUpdate` loop. Aura events coalesce per unit and touch aura presentation only; they do not repeat plate font/surface styling.

## Offline evidence

Run from the repository root:

```sh
lua tests/nameplates_spec.lua
lua tests/unit_adapters_spec.lua
```

The owner-shaped fixtures check profile isolation/replacement, exact-HP options, role preference preservation, scale normalization, interruptibility cues, text/color sinks, custom-rule reporting, native aura pool reuse, restoration, restricted/refused access and disabled hooks. Bounding checks keep crowd-control icons beyond the native right-hand rare/elite lane. These tests do not emulate the client’s secure renderer or establish rendered pixels/FPS.

Source review includes Threat Plates `Database.lua`, `Nameplate.lua`, `Modules/Scaling.lua`, `Modules/Color.lua`, `Modules/Threat.lua`, `Elements/Healthbar.lua`, `Elements/StatusText.lua`, `Elements/Castbar.lua`, `Styles/basicThemes.lua` and `Widgets/AurasWidgetMidnight.lua`. Upstream implementation/media is not bundled.

## Manual acceptance checks

1. Apply the preset and reload. Check ordinary and elite NPCs, players and pets at the actual resolution/UI scale. Targeting and mouseover must not unexpectedly resize or fade them.
2. Check a long player/NPC name and a large current-HP amount. Names stay inside their lane; HP stays ivory and unabridged. Verify text over dark, bright and low-health scenes.
3. Exercise native tank and DPS/healer roles against hostile NPCs: secure tank/no-aggro DPS blue, transitional threat amber, opposite state red. Friendly/player/no-threat cases must retain the owner’s appropriate behavior.
4. Compare interruptible and non-interruptible casts. Verify the shield, cast name, time and retained target/raid markers remain legible without decorative outlines.
5. Check ordinary buffs, harmful effects, dispellable effects and owner-priority groups. Verify 28px icons, duration/count placement, marker spacing, wrapping and a pooled icon changing groups.
6. Repeat aura/nameplate creation in combat and after combat ends, including restricted PvP units. Record native refusals or missing cosmetics; do not treat an offline pass as permission to bypass client restrictions.
7. Change a custom plate rule and a required profile dimension: setup/status must report the mismatch. Disable/reload and profile restoration must recover the owner appearance without losing gameplay settings.
8. Compare FPS in the same scene with vasagoio on/off while leaving other addons unchanged. Include idle, dense plates and frequent aura changes; record Lua or blocked-action errors.
