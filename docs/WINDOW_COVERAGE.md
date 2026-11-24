# Window skin coverage

Version 0.2 adds window interiors to the existing shell skins. It preserves native and selected-addon layouts, functional controls, content and secure behavior. The selected interaction state is near-black fill with a small blue bottom marker, using the agreed design tokens.

- [Native interiors](native-interiors.md): Character panes/stats, talents/spellbook, NPC/quest/mail/profession content, social/system controls, native selection and load-on-demand rows.
- [Selected-addon interiors](addon-interiors.md): all 19 Baganator public skin-region types, Talents Forever panes/controls, MRT tools and popups, Auctionator panes, Gargul registry-created windows.
- [Catalog scope](window-catalog-scope.md): all 172 source records mapped to native hosts or explicit boundaries.
- [Implementation and validation](COVERAGE.md): applied code paths and remaining native checks.

The shared service changes fonts/shadows, known decorative backgrounds, control surfaces and selection markers. It preserves native text metrics, click areas, keyboard focus, scroll ranges, content textures and semantic colors. Unknown textures are not discarded as decoration. New surfaces are excluded from automatic layout calculations. Multiple presentation owners share a restoration record so disabling one adapter does not undo another active adapter.

Skinner remains a supported foundation with the reviewed beta12.70938.1 profile. vasagoio also runs its own scoped interior adapters without Skinner. Content-free Skinner `.sf` and `.sb` decorations can be replaced by rounded surfaces only when their parent/child contract matches the reviewed source. Native segmented button chrome is also recognized; coin icons and other content textures are retained.

The native catalog contains 132 interior candidates across 115 primary hosts. Registration does not prove every host exists on the current character/client. Dedicated unit/action/HUD records use their existing owners. Eight frontend records, two media/world-capture overlays and the embedded support browser are outside this window-control adapter.

The build has not been opened in WoW. Pixel rendering, every owner state, locale/scale behavior and combat/taint remain user-run verification. No complete runtime coverage claim is made from source inspection alone.
