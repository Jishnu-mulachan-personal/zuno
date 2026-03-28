# Design System: The Digital Hearth

## 1. Creative North Star

> **"The Digital Hearth"** — A private, glowing sanctuary that blends Swiss typographic precision with the warmth of a terracotta palette.

We reject cold, frantic interfaces. Instead, we create **Editorial Intimacy**: breathing room, tactile depth, and intentional asymmetry. Cards "float" within tonal layers rather than sitting on a rigid grid.

---

## 2. Color Palette

### Core Tokens

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#944931` | Brand CTAs, highlights |
| `primary_container` | `#d67d61` | Gradient end, secondary accents |
| `surface` | `#fcf9f6` | Main viewport background |
| `surface-container-low` | `#f6f3f0` | Section backgrounds |
| `surface-container-lowest` | `#ffffff` | Cards (creates "lift") |
| `on-surface` | `#1c1c1a` | All body text (never pure black) |
| `outline-variant` | `#dac1ba` | Ghost borders (at 15% opacity only) |
| `tertiary` | `#93f2f2` (teal) | Success states, active chips, "moments of delight" |

### Surface Hierarchy (Physical Stack of Paper)
```
[Base]           surface (#fcf9f6)          — main viewport
[Sectioning]     surface-container-low       — background blocks
[Interactive]    surface-container-lowest    — floating cards
```

### The "No-Line" Rule
> **Forbidden:** 1px solid borders for section/container definition.

Use instead:
- **Background shifts** between surface tokens
- **Negative space** (spacing scale 8–12) to create mental boundaries

### The "Glass & Gradient" Rule
- **Glassmorphism:** `surface` at 80% opacity + `20px` backdrop-blur for floating headers/navbars
- **Signature CTA gradient:** `linear-gradient(135deg, #944931, #d67d61)` — the "Soulful Glow"
- **Ghost border fallback:** `outline-variant` at **15% opacity** only

---

## 3. Typography

| Role | Font | Usage |
|---|---|---|
| Display / Headlines | **Noto Serif** | Hero moments, anchoring sections — editorial, book-like |
| Body / Titles / UI | **Plus Jakarta Sans** | Functional clarity, geometric balance |

### Hierarchy Rule
- If headline is `headline-lg`, body text needs **≥ 2.5× the white space** of the line height
- Always maintain stark contrast between headline and body sizes

---

## 4. Elevation & Depth

> **Depth = Tonal Layer, not shadow.**

| Layer | Method |
|---|---|
| Soft card lift | `surface-container-lowest` on `surface-container-low` background |
| Ambient modal shadow | `on-surface` (#1c1c1a) at **4% opacity**, `blur: 40px` |
| Ghost border | `outline-variant` at **15% opacity** |

**Never** use default Material Design shadows — if it looks like a drop shadow, it's too heavy.

---

## 5. Component Specs

### Cards
- `border-radius: 1.5rem` (xl)
- No divider lines inside cards
- List item separation: `spacing.4` + `surface-variant` hover background shift

### Buttons
| Type | Style |
|---|---|
| **Primary** | Gradient `#944931 → #d67d61`, `border-radius: 9999px` (full), `label-md` UPPERCASE |
| **Secondary** | `surface-container-high` bg, `on-surface` text, no border |

### Input Fields
- Background: `surface-container-highest`
- `border-radius: md`
- Label: `label-sm` **above** field — never inside as placeholder

### Chips
- Active state: `tertiary_fixed` (#93f2f2) — "teal spark" against terracotta warmth

### Signature: "The Hearth Glow" Image Mask
- `border-radius: xl`
- Subtle inner shadow — photography feels "set into" the page like a framed photograph

---

## 6. Spacing Reference

| Token | Value | Usage |
|---|---|---|
| `spacing.4` | 16px | Internal list item separation |
| `spacing.8` | 32px | Section breathing room |
| `spacing.12` | 48px | Mental boundary separation |
| `spacing.16` | 64px | Major content block separation |
| `spacing.20` | 80px | Hero section padding |

**Intentional asymmetry:** More padding on left than right in editorial layouts.

---

## 7. Do's and Don'ts

| ✅ Do | ❌ Don't |
|---|---|
| Use `on-surface` (#1c1c1a) for all text | Use pure `#000000` |
| Use `tertiary` teal for delight moments | Use standard Material shadows |
| Use asymmetric margins in editorial layouts | Use hard 1px lines to separate sections |
| Use `spacing.16`/`spacing.20` between major blocks | Use aggressive gamification visuals |
| Apply glassmorphism to floating nav | Use placeholder images |
