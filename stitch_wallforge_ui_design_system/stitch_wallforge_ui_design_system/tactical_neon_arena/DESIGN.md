---
name: Tactical Neon Arena
colors:
  surface: '#0e131e'
  surface-dim: '#0e131e'
  surface-bright: '#343946'
  surface-container-lowest: '#090e19'
  surface-container-low: '#171b27'
  surface-container: '#1b1f2b'
  surface-container-high: '#252a36'
  surface-container-highest: '#303541'
  on-surface: '#dee2f2'
  on-surface-variant: '#bac9cc'
  inverse-surface: '#dee2f2'
  inverse-on-surface: '#2b303c'
  outline: '#849396'
  outline-variant: '#3b494c'
  surface-tint: '#00daf3'
  primary: '#c3f5ff'
  on-primary: '#00363d'
  primary-container: '#00e5ff'
  on-primary-container: '#00626e'
  inverse-primary: '#006875'
  secondary: '#ffb2b9'
  on-secondary: '#67001f'
  secondary-container: '#b0003a'
  on-secondary-container: '#ffbcc2'
  tertiary: '#a8ffd2'
  on-tertiary: '#003824'
  tertiary-container: '#5be9ad'
  on-tertiary-container: '#006645'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#9cf0ff'
  primary-fixed-dim: '#00daf3'
  on-primary-fixed: '#001f24'
  on-primary-fixed-variant: '#004f58'
  secondary-fixed: '#ffdadc'
  secondary-fixed-dim: '#ffb2b9'
  on-secondary-fixed: '#400010'
  on-secondary-fixed-variant: '#91002f'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#0e131e'
  on-background: '#dee2f2'
  surface-variant: '#303541'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: 0.08em
  display-md:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '800'
    lineHeight: 40px
    letterSpacing: 0.04em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: 0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: 0em
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0em
  body-base:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.06em
  numeric-stat:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 24px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '800'
    lineHeight: 36px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  margin-desktop: 2rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system expresses a high-stakes, competitive, digital-first strategy board environment. Rejecting both vintage skeuomorphic wooden tropes and exaggerated casual cartoon styles, it channels an authoritative esports ethos: analytical precision, atmospheric depth, and tactile digital materialism. 

The aesthetic is constructed on a front-facing 2.5D visual plane. The central board is treated as a high-precision digital arena encased within an infinite obsidian void. Player tokens evoke machined acrylic and polished anodized components, complete with localized specular highlights and perimeter luminescence. Wall barriers snap into physical-feeling subterranean slot grooves. 

The emotional response sought is calculating, tense, and focused. The UI balances technical rigor with luminous energy, ensuring split-second cognitive parsing under ticking turn timers.

## Colors

The palette is engineered exclusively for a deep, dark-mode canvas where high-luminance tactical accents pop with uncompromising contrast.

- **Primary (`#00E5FF`)**: Represents Player 1. High-frequency electric cyan used for legal movement rings, active turn breathing highlights, and P1 placed/ghost wall barricades.
- **Secondary (`#FF4B6E`)**: Represents Player 2. Intense radiant crimson used for opponent alerts, P2 tactical walls, aggressive territory cutoffs, and warning boundaries.
- **Tertiary (`#10B981`)**: The objective anchor. Luminous emerald green used exclusively for baseline goal zones, victory states, and successful placement confirmations.
- **Neutral Foundation (`#0B101B`)**: An obsidian navy tone functioning as the peripheral void. Supported by `#0F172A` (elevated background), `#141B2E` (dock surfaces), `#1E293B` (HUD cards), and `#17233F` (tactical board surface).
- **Text & Borders**: High-clarity pure cool white (`#F8FAFC`) for top-level stats and titles; muted slate (`#94A3B8`) for telemetry, timers, and rules; and hairline structure borders (`#334155`).

## Typography

Typography prioritizes computational precision, athletic discipline, and split-second mobile legibility. Inter is implemented across all roles, relying on weight variation, uppercase tracking, and tabular alignment to delineate metadata from core commands.

Display and label elements leverage expanded tracking (`+0.04em` to `+0.08em`) to mirror digital telemetry readouts, creating structured headings and distinct state tags. Numerical metrics—such as wall inventories (`08 / 10`) and turn clocks—must always render using tabular figures to eliminate layout shift during real-time countdowns. Color is never the sole carrier of meaning; tactical labels (`PLAYER 1`, `GOAL`) accompany chromatic indicators.

## Layout & Spacing

The layout is strictly anchored around a mathematically centered, non-negotiable 1:1 aspect-ratio board arena. All peripheral UI adapts dynamically around this focal point.

- **Mobile (< 768px)**: Uses a vertical single-column stack with `1rem` outer margins. The board scales to span available width while maintaining square constraints. The opponent HUD docks to the top edge; the active player HUD, inventory bar, and turn action controls dock to the bottom.
- **Desktop & Tablet (≥ 768px)**: Switches to a balanced 3-column layout with `2rem` screen margins. Player 1's HUD and tactical controls sit in a fixed-width left rail (280px), the 9×9 board occupies the auto-scaling center (capped at 640px), and Player 2/AI metrics inhabit the right rail (280px).
- **Rhythm**: Spacing follows a strict 4px base module (`space-xs` = 4px, `space-sm` = 8px, `space-md` = 12px, `space-lg` = 16px, `space-xl` = 24px). Interactive grid points, wall slots, and control pills require an absolute minimum hit-target clearance of 44×44px.

## Elevation & Depth

Depth is conveyed through a combination of controlled dimensional materials, frosted glass tiers, and localized illumination rather than generic drop shadows.

- **Ground Plane (Level 0)**: Obsidian navy (`#0B101B`). Absorbs ambient view, zero elevation.
- **Board Arena (Level 1)**: Tactical navy (`#17233F`) sitting in an etched recess, surrounded by `#0B101B` 3px perimeter channels. Cells are delineated by `#2C3A5C` recessed hairline grooves.
- **HUD Containers & Cards (Level 2)**: Frosted slate glass (`rgba(30, 41, 59, 0.75)` with `backdrop-filter: blur(12px)`). Encased in a 1px structural outline (`#334155`), with an ambient drop shadow of `0 8px 24px rgba(0, 0, 0, 0.45)` and a hairline 1px inner top highlight (`rgba(255, 255, 255, 0.08)`).
- **Game Pieces & Wall Barriers (Level 3)**: Front-facing 2.5D items. Pawns utilize radial fill gradients (lightened crest to saturated anchor) crowned with a directional top-left specular highlight (`#FFFFFF` at 60% opacity) and a soft contact ground shadow (`rgba(0, 0, 0, 0.6)`). Placed walls exhibit a 1px beveled top-edge catchlight.
- **Active State Highlights (Level 4)**: Realized not through height, but via luminous glow rings (`0 0 12px rgba(0, 229, 255, 0.5)` for P1; `0 0 12px rgba(255, 75, 110, 0.5)` for P2).

## Shapes

The interface balances technical sharpness with smooth ergonomics through a moderate roundedness profile.

- **HUD Cards & Modals**: Use `rounded-lg` (16px) or `rounded-xl` (20px) to establish a modern, contained presentation.
- **Interactive Buttons & Selectors**: Use `rounded-md` (8px to 12px) for structured, confident touch surfaces.
- **Wall Placement Bars**: Beveled with an intentional `4px` corner radius, preventing harsh aliasing on pixel boundaries while preserving their identity as solid physical barriers.
- **Movement Tokens & Turn Indicator Rings**: Perfectly circular (`full` / 9999px) to contrast against the rectilinear grid framework.

## Components

### Buttons
- **Primary Action**: 52px height. Full background fill of Player 1 Cyan (`#00E5FF`) or Player 2 Crimson (`#FF4B6E`). Label rendered in obsidian `#0B101B` with `title-md` bold weight. Hover triggers a subtle scale expansion (1.02) and a 12px peripheral glow.
- **Secondary / Glass Action**: 48px height. Dark slate glass surface (`#1E293B`), 1px outline (`#334155`), label in crisp `#F8FAFC`. On press: 150ms transform scale down to 0.98.
- **Segmented Mode Toggle**: Segmented container with a sliding pill background to alternate between "Move Pawn", "Place Wall (H)", and "Place Wall (V)". Active selection illuminates with the active player's color glow.

### Cards & HUD Containers
- **Turn Indicator Card**: Glassmorphic slate card framing the active player. Emits a continuous, slow breathing border animation (2px spread) in the acting player's accent color.
- **Wall Inventory Display**: Integrated within the player card. Displays remaining walls as a horizontal row of 10 micro luminous vertical notches that extinguish into dark slate (`#334155`) as walls are spent.

### Tactile Board Primitives
- **Grid Tile**: 9×9 dark blue rounded squares (`#17233F`, `r=6px`). Legal destinations generate a concentric, pulsing 2px circular ring in cyan or emerald.
- **Wall Ghost**: Semi-transparent (35% opacity) barrier hovering dynamically under pointer/touch over the slot grooves. Flashes intense translucent crimson (`#EF4444` at 50%) when a placement violates game rules or blocks pathfinding.
- **Goal Zone**: The target row features a directional emerald gradient wash (`#10B981` at 20% opacity) with a luminous 2px base indicator strip.

### Form Inputs & Code Fields
- **Match / Room Input**: 48px height, `#0F172A` background, 1px border (`#334155`), `r=12px`. Typed characters display in white with tabular spacing. Active focus produces a 2px Cyan outline with a 4px soft outer glow.

### Modals & Dialogs
- Centered glass surface (`#0F172A`), `20px` corner radius, enclosed by a `1px` subtle outline (`#334155`). Hero victory/defeat announcements use `display-md` typography with a radial ambient highlight behind the result crest.