# Optional native aura test

This experiment is included inside vasagoio. **No separate addon is needed.** The test is closed by default, does not replace the working aura display, and is not the finished player-aura layout. Native rendering and combat behavior have not been established by offline tests.

If the earlier standalone `VasagoioAuraProbe` addon is installed, disable it and reload before opening this integrated test. The integrated version blocks opening while the standalone probe is loaded to avoid duplicate test panels and aura processing.

## Open and close

1. Update vasagoio with WoW closed, keeping SavedVariables, then enter the game and reload yourself.
2. Out of combat, open `/vasagoio` → Tools → Aura test → Show.
3. Compare the three columns during normal play, first outside combat and then in combat when naturally available.
4. Select Tools → Aura test → Hide when finished. This closes the panel and stops its native aura processing.

The test can run without reapplying the preset. Setup retains Apply preset and Reload UI; the optional experiment lives in Tools. It does not replace the normal HUD.

The upper row shows player buffs and the lower row shows player debuffs. Each has three native-rendered views:

| View | Purpose |
| --- | --- |
| All | Reference view, limited to 40 matching candidates |
| Short | Native maximum full-duration filter of 60 seconds |
| Long/permanent | Experimental inverse clipping intended to retain full durations over 60 seconds and permanent effects |

Classification concerns an effect's **full duration**, not its remaining timer. The ordinary native timer on an icon still shows remaining time. Existing aura displays remain available for comparison.

## What to compare

These are expected results **if the experiment works**, not verified behavior:

| Situation | Expected views |
| --- | --- |
| Full duration below 60 seconds | All and Short; hidden in Long |
| Full duration exactly 60 seconds | All and Short; hidden in Long |
| Full duration over 60 seconds | All and Long; absent in Short |
| A long effect falls below 60 seconds remaining | Stays in Long; does not move to Short |
| Permanent effect | All and Long; absent in Short |
| New short/long effects received during combat | Same classification without errors |
| A timed short effect expires and its button is reused for a permanent effect | Permanent remains visible in Long |
| A timed effect replaces a permanent effect, then changes back | Correct visibility throughout; no stale clipping |

Check both buffs and debuffs, including a new long debuff received during ordinary combat when available. Untested cases remain unverified. Record missing effects, short effects visible in Long, Lua errors and any performance change. A useful comparison screenshot includes all three columns.

`/vasagoio auratest reset` repositions and refreshes the existing containers out of combat. It retains their button pools, so it is useful for reuse checks and **is not a fresh-pool test**. `/reload`, followed by another manual `show`, creates a fresh test pool. Disabling vasagoio closes the test.

## Limits

- Each view is capped at 40 candidates. More than 40 matching effects are outside the test. Six containers can render up to 240 icons; hide the test when finished.
- Long uses the reference view's native slot layout. Hidden short effects can leave gaps. This does not demonstrate compact packing or production sorting.
- Permanent-effect behavior after native button reuse is unresolved. Alpha.10 explicitly configures empty zero-duration and expired text through the public binding template. Native code still disables zero-duration binding; whether it clears a recycled glyph requires testing.
- Exactly 60 seconds is an explicit boundary test. The formatter's inclusive breakpoint uses the next binary64 value above 60 (`60 + 2^-47`); whether the client preserves that precision is unverified.
- Spell-specific exceptions, including the agreed Battle Shout exception, are not part of this generic duration experiment.
- Hidden icons remain in native slots. The test does not establish click, cancellation or tooltip behavior for a finished aura display.
- Source and offline checks do not establish protected-frame acceptance, rendering correctness or performance in combat. The test does not complete production aura work or establish an accepted fallback.

The test adds no aura polling, aura-data reads or native-child hooks. Its experimental transparent `TotalDuration` text binding moves a fixed clipping rectangle; Lua does not read the bound text, duration, icon identity or resulting geometry. It does not collect or upload aura data, and its open state is not saved across reloads.

## Source basis

- [Native full-duration maximum and permanent exclusion](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua#L106-L111).
- [Native duration-binding registration](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua#L178-L212) and [zero-duration binding disable](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua#L607-L612).
- [Numeric formatter threshold semantics](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericRuleFormatterSharedDocumentation.lua#L19-L29).

These are Blizzard source/API files hosted by a source mirror; availability in source is not a native acceptance result.
