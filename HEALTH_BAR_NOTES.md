# Health Bar UI Upgrade

The player HUD and floating enemy health bars now use a local `HealthBarStyle.gd` helper with the same visual language as the Status Effects component: dark charcoal background, brown framing, gold accent, cream text, rounded geometry, dark outline, and the Fredoka variable font. The font and its SIL Open Font License are included locally; no Status Effects gameplay system or addon dependency has been added.

## Player HUD
- A framed Vitality panel with heart mark, animated numeric health value, and color-coded fill.
- High health uses the Status Effects green, medium health uses gold, and critical health uses the Status Effects red.
- Health fill eases toward the latest value. A pale damage trail holds the lost health briefly and then catches up smoothly.
- Damage produces a brief card punch/flash. Healing gives a warmer, gentler feedback pulse.
- At critical health, the fill pulses until health rises above the critical threshold. At death, the fill becomes muted, the mark changes to an x, and the label displays `DEAD`.
- The HUD intro fades/scales into place.

## Enemy health bars
- Compact floating bars use the same palette, font and rounded framing.
- Bars stay hidden until an enemy is damaged; the first appearance animates in, and additional hits pulse the bar.
- The health value is displayed over the bar. Health changes animate the fill and numeric value; damage trail catches up after a short delay.
- Critical health pulses red. The bar hides when the enemy emits `died`.

## Scope
Only the existing health bar visuals and their local animation/feedback were changed. Player/enemy health ownership, damage resolution, combat, status effects, AI, and other gameplay systems were not changed. Existing `health_changed` and `died` signals remain the integration contract.
