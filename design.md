# Wallforge — UI/UX and Visual Design System

## 1. Design Philosophy

Wallforge is a premium digital strategy board game.

The design must communicate:

- Strategy.
- Competition.
- Clarity.
- Depth.
- Modernity.
- Controlled 3D rendering.

The board is the hero.

The interface should support the board rather than compete with it.

---

# 2. Critical Board Direction

The Wallforge board is:

- Front-facing.
- Dark.
- Grid-based.
- Rounded rectangular/square.
- Slightly dimensional.
- Visually similar to a digital strategy arena.

It is NOT:

- Isometric.
- A heavily tilted tabletop.
- A chessboard.
- A physical board photographed from above.

The desired visual effect is:

> **2D strategic composition rendered with subtle 3D depth.**

---

# 3. Visual Layers

```text
Background
   ↓
Board outer frame
   ↓
Board surface
   ↓
Grid
   ↓
Goal area
   ↓
Walls
   ↓
Pawns
   ↓
Interaction highlights
   ↓
UI overlays
```

---

# 4. Color System

## Background

Use very dark navy/charcoal colors.

Purpose:

- Focus attention on the board.
- Provide contrast against colored players.

## Board

Use dark blue/navy surfaces.

The board should not be pure black.

## Grid

Use subtle blue-gray lines.

Grid contrast should be low enough to avoid visual noise.

## Blue player

Use a vivid electric blue.

Use the same color family for:

- Pawn.
- Walls.
- Active indicators.
- Selection state.

## Red player

Use a vivid red/coral-red.

Use the same color family for:

- Pawn.
- Walls.
- Active indicators.
- Selection state.

## Goal

Use green.

The goal should be visually distinct from both players.

## Status

Do not use color alone for:

- Errors.
- Player identity.
- Active turn.
- Victory.

Add text/icons/shape changes.

---

# 5. 3D Visual Treatment

3D is achieved through rendering rather than camera perspective.

### Pawns

Use:

- Rounded geometry/shape.
- Gradient.
- Highlight.
- Contact shadow.
- Subtle glow.

### Walls

Use:

- Beveled rectangular geometry.
- Small depth.
- Shadow.
- Player-colored glow.
- Highlight.

### Board

Use:

- Slight border depth.
- Inner gradient.
- Soft shadow.
- Subtle surface variation.

Avoid excessive bloom.

---

# 6. Board Grid

Initial visual target:

9×9 movement cells.

The grid must:

- Align perfectly.
- Maintain equal cell dimensions.
- Scale responsively.
- Remain sharp on high-density displays.

Never calculate gameplay positions using screen pixels.

---

# 7. Goal Area

Goal area:

- Thin.
- Green.
- Subtle glow.
- Clearly aligned with goal edge.

Use animation only when appropriate:

- Goal proximity.
- Victory.

Do not constantly animate the goal.

---

# 8. Player Pawn

### Shape

Circular/rounded 3D piece.

### Blue

Blue body + subtle highlight + blue glow.

### Red

Red body + subtle highlight + red glow.

### States

Normal:

- Standard shadow.

Active:

- Slight glow/pulse.

Selected:

- Stronger ring/highlight.

Moving:

- Smooth translation.

Landing:

- Small bounce.

Goal:

- Celebration animation.

---

# 9. Walls

Walls are long rectangular barriers.

### Horizontal

Aligned with horizontal board boundaries.

### Vertical

Aligned with vertical board boundaries.

### Normal

Solid player color.

### Ghost

Semi-transparent.

### Valid

Player-colored glow.

### Invalid

Warning treatment and lower opacity.

### Placement

Small scale/opacity animation into final position.

---

# 10. Movement Feedback

When movement mode is active:

- Highlight legal destinations.
- Use subtle pulses.
- Show selection state.
- Keep blocked locations visually quiet.

Do not highlight every board cell unnecessarily.

---

# 11. Wall Placement Feedback

When wall mode is active:

- Show valid wall anchors.
- Display ghost wall.
- Snap to logical wall slots.
- Show orientation clearly.
- Allow cancellation.
- Require confirmation if the setting is enabled.

---

# 12. Typography

Typography should be:

- Modern.
- Highly readable.
- Slightly condensed for game labels where appropriate.
- Clear at small sizes.

Hierarchy:

### Display

Game logo/title.

### Heading

Screen title.

### Body

Descriptions.

### Label

Player, walls, turn, status.

### Numeric

Timer and statistics.

Avoid excessive font families.

Use one primary family and optionally one display family if the visual system benefits from it.

---

# 13. Spacing

Use a consistent spacing scale.

Suggested conceptual scale:

```text
4
8
12
16
24
32
48
64
```

Do not create arbitrary spacing values throughout the application.

---

# 14. Buttons

Primary buttons:

- Strong contrast.
- Rounded.
- Clear label.
- Player accent when context-specific.

Secondary buttons:

- Darker/transparent.
- Border.
- Lower visual weight.

Destructive buttons:

- Reserved for actions such as leaving a match.

Avoid giant buttons that consume gameplay space.

---

# 15. Cards

Use cards for:

- Game modes.
- Profile statistics.
- Online rooms.
- Settings groups.

Cards should have:

- Dark surface.
- Subtle border.
- Small radius.
- Controlled shadow.

Do not make every element a card.

---

# 16. Main Game Layout

## Mobile

```text
Player information
Turn
      ↓
  GAME BOARD
      ↓
Current player information
Action controls
```

The board should occupy the majority of the usable screen.

## Desktop

```text
Player panel |     BOARD     | Opponent panel
             |               |
             |               |
```

The board remains centered.

---

# 17. Home

Home screen should contain:

- Wallforge logo.
- Short tagline.
- Main Play button.
- Mode options.
- Profile/settings access.
- Small board visual.

Tagline:

**Forge your path. Block your rival.**

---

# 18. Game Modes

Three primary modes:

### Local

Two players on one device.

### Vs AI

Single player against AI.

### Online

Remote two-player match.

Each mode needs:

- Icon/visual.
- Title.
- Short description.
- Action.

---

# 19. Online UI

Show:

- Create match.
- Join match.
- Room code.
- Opponent status.
- Connection state.

Connection states:

- Connecting.
- Waiting.
- Connected.
- Reconnecting.
- Disconnected.

---

# 20. AI UI

Difficulty options:

- Easy.
- Medium.
- Hard.
- Expert.

Explain difficulty briefly.

Avoid misleading claims such as "perfect AI".

---

# 21. Result Screen

Winner:

- Victory heading.
- Player piece.
- Statistics.
- Rematch.
- Home.

Loser:

- Match complete.
- Statistics.
- Rematch.
- Home.

Avoid humiliating language.

---

# 22. Tutorial UX

Use the real board.

Teach one concept at a time.

Example sequence:

```text
Goal
 ↓
Move
 ↓
Wall
 ↓
Block
 ↓
Race
```

Allow users to skip and revisit the tutorial.

---

# 23. Settings

Groups:

### Gameplay

- Confirm wall placement.
- Movement assistance.

### Audio

- Music.
- Effects.
- Volume.

### Haptics

- Haptic feedback.

### Accessibility

- Reduced motion.
- Color assistance.
- High contrast.
- UI scale.

### Account

- Account information.
- Sign out.

---

# 24. Animation Principles

Animations should be:

- Smooth.
- Short.
- Purposeful.

They should communicate:

- Cause.
- Result.
- State change.

Avoid animation for decoration alone.

Recommended conceptual timing:

- Micro feedback: 100–180 ms.
- UI transition: 180–300 ms.
- Pawn movement: 250–450 ms.
- Wall placement: 180–300 ms.
- Victory: 500–1000 ms.

Exact timing should be tuned during implementation.

---

# 25. Sound/Haptics

Sound should communicate:

- Move.
- Wall placement.
- Invalid action.
- Turn change.
- Victory.
- Button press.

Haptics should be:

- Subtle.
- Optional.
- Disabled by reduced-motion/accessibility settings where appropriate.

---

# 26. Accessibility

Never communicate important information using color alone.

For example:

Blue player:

```text
BLUE + blue color + player label
```

Red player:

```text
RED + red color + player label
```

Wall placement states should also use:

- Shape.
- Opacity.
- Icons.
- Text where appropriate.

---

# 27. Responsive Design

The game must adapt to:

- Small phones.
- Large phones.
- Tablets.
- Desktop browsers.

Do not simply scale every component proportionally.

The board may change relative size while information panels change layout.

---

# 28. Input

### Touch

- Tap cell.
- Tap wall slot.
- Drag where useful.
- Pinch/zoom only if later justified.

### Mouse

- Hover highlights.
- Click movement.
- Click wall placement.
- Optional drag preview.

### Keyboard

Web accessibility shortcuts can be introduced later.

Do not make keyboard input required for core gameplay.

---

# 29. UI States

Every interactive component should consider:

- Default.
- Hover.
- Pressed.
- Selected.
- Disabled.
- Loading.
- Error.
- Success.

Game-specific:

- Your turn.
- Opponent turn.
- Legal move.
- Illegal move.
- Valid wall.
- Invalid wall.
- Victory.
- Defeat.
- Reconnecting.

---

# 30. Assets

Approved project assets belong under:

```text
assets/
```

Suggested:

```text
assets/
├── images/
├── icons/
├── audio/
└── fonts/
```

Use vector assets where they provide a clear benefit.

Avoid unnecessarily large raster images.

---

# 31. Design Source of Truth

For this project:

1. `game_spec.md` controls game rules, state and coordinates.
2. `DESIGN.md` inside `stitch_wallforge_ui_design_system/` defines visual tokens (colours, typography, radii, spacing, elevation).
3. The five screen PNGs and HTML prototypes inside the Stitch folder define layout measures and layering.
4. `design.md` (this file) provides supplementary visual guidance not covered by Stitch.
5. Flutter implementation defines responsive behaviour.
6. Screenshots and prototypes are references, not executable specifications.

Owner decision: 2026-09-21.

---

# 32. Design Quality Checklist

Before approving a screen:

- Is the board visually dominant where appropriate?
- Is the turn obvious?
- Is the player identity obvious?
- Is the wall count obvious?
- Are legal actions obvious?
- Is the goal obvious?
- Is the design readable on mobile?
- Does it work on web?
- Does it use the Wallforge visual language?
- Does it avoid unnecessary decoration?
- Does it preserve the front-facing board style?
