# Design System Specification

## 1. Overview & Creative North Star
The core objective of this design system is to translate the high-energy, precision-oriented world of competitive dance into a digital workspace that feels authoritative yet fluid. We are moving away from the "standard administrative dashboard" and toward an **Editorial Kinetic** aesthetic.

**Creative North Star: "The Fluid Official"**
This system balances the rigid requirements of data entry and scoring with the expressive movement of dance. We achieve this through:
*   **Intentional Asymmetry:** Breaking the expected 12-column grid with staggered card placements and varying container widths to create visual rhythm.
*   **Tonal Depth:** Utilizing a sophisticated violet-based palette to create a layered environment that feels "deep" rather than "flat."
*   **The "Air" Principle:** Generous use of negative space (white space) ensures that in high-pressure judging environments, the interface remains calm and legible.

---

## 2. Color Palette
Our color strategy relies on the interplay of violet hues to guide the eye without the need for structural clutter.

### Color Tokens
*   **Background:** `#f7f5ff`
*   **Primary:** `#702ae1` (Container: `#b28cff`, Dim: `#6411d5`)
*   **Secondary:** `#6c43b6` (Container: `#ddc8ff`, Dim: `#6035a9`)
*   **Tertiary:** `#664d9f` (Container: `#bda2fb`, Dim: `#594092`)
*   **Surface:** `#f7f5ff` (Dim: `#d4d3e4`, Bright: `#f7f5ff`)
*   **Surface Container Themes:** 
    * Lowest: `#ffffff`
    * Low: `#f1effc`
    * Default: `#e8e7f5`
    * High: `#e2e1f0`
    * Highest: `#dcdbeb`
*   **Text & Accents:**
    * On Surface: `#2d2e37`
    * On Surface Variant: `#5b5b64`
    * Outline: `#767680`
    * Error: `#b41340`

### Surface Philosophy
#### The "No-Line" Rule
**Strict Mandate:** Designers are prohibited from using 1px solid borders to section off the UI. Separation must be achieved through:
1.  **Background Shifts:** Placing a `surface-container-lowest` card on a `surface-container-low` background.
2.  **Tonal Transitions:** Using the `surface` and `surface-dim` tokens to distinguish between global navigation and primary content areas.

#### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers. 
*   **Base:** `surface` (#f7f5ff) serves as the canvas.
*   **Sections:** Use `surface-container-low` (#f1effc) for large content areas.
*   **Interactive Cards:** Use `surface-container-lowest` (#ffffff) to make active data points "pop" forward toward the user.

#### The "Glass & Gradient" Rule
To add professional "soul," use subtle gradients. 
*   **CTAs:** A linear gradient from `primary` (#702ae1) to `primary_container` (#b28cff) should be applied to high-priority buttons to give them a dimensional, premium feel.
*   **Floating Elements:** For active timers or live status indicators, apply `backdrop-blur: 12px` and 80% opacity to `surface_container_highest` to create a "frosted glass" effect that keeps the judge's focus on the live metrics.

---

## 3. Typography
The typography system uses a dual-font approach to balance personality with extreme legibility.

### Font Families
*   **Headline Font:** `PLUS_JAKARTA_SANS`
*   **Body & Label Font:** `INTER`

### Application Rules
*   **Display & Headlines (Plus Jakarta Sans):** Chosen for its modern, slightly geometric curves that echo the fluidity of movement. Use `display-lg` for scoring totals and `headline-md` for heat titles.
*   **Body & Labels (Inter):** A workhorse typeface designed for readability on mobile and tablet screens. It provides a grounded, professional contrast to the more expressive headlines.
*   **Hierarchy Note:** High-contrast color usage (using `on_surface` for headers and `on_surface_variant` for metadata) is essential to guide the judge's eye through a dense scoring sheet.

---

## 4. Elevation & Depth
In this design system, "Elevation" is a psychological cue, not just a CSS property.

*   **Tonal Layering:** Avoid shadows for static elements. Instead, use the `surface-container` tiers to create a soft, natural lift. A `surface-container-lowest` card sitting on a `surface-container-low` background provides enough contrast to imply depth without adding visual noise.
*   **Ambient Shadows:** For floating elements (e.g., modals, active judge timers), use extra-diffused shadows.
    *   *Spec:* `0px 20px 40px rgba(45, 46, 55, 0.06)`. The shadow color is a tinted version of `on_surface` to mimic natural light.
*   **The Ghost Border Fallback:** If accessibility requirements demand a border (e.g., in high-glare outdoor competition settings), use `outline_variant` at 15% opacity. Never use 100% opaque borders.

---

## 5. Components

### Buttons & Touch Targets
*   **Primary:** Rounded `xl` (3rem) or `lg` (2rem). Must have a minimum height of 56px to accommodate rapid touch input. 
*   **States:** Hover states should shift toward `primary_dim`. Pressed states should utilize a subtle scale-down effect (0.98x) to provide tactile feedback.

### Scoring Cards
*   **Visual Style:** Forbid divider lines. Use `surface-container-low` as the base and `surface-container-lowest` for the individual contestant rows.
*   **Spacing:** Use 16px (1rem) internal padding minimum. The roundedness should be set to `md` (1.5rem) to maintain the "soft" brand personality.

### Status Chips
*   **Action Chips:** Use `secondary_container` with `on_secondary_container` text.
*   **Live Indicators:** Utilize the `error` token (#b41340) for "Live" or "Urgent" states, but always pair it with a 10% opacity background of the same color to soften the impact while maintaining high contrast.

### Input Fields
*   **Design:** Large, rounded fields using `surface_container_highest` for the background. Labels should use `label-md` in `on_surface_variant` positioned strictly above the field to maximize vertical scanning speed.

---

## 6. Do's and Don'ts

### Do
*   **DO** use the `9999px` (full) roundedness for small indicators like "Live" badges or "Heat Number" bubbles to create a distinct visual language from the `lg` cards.
*   **DO** leave at least 24px of breathing room between major content containers.
*   **DO** use `plusJakartaSans` for any numerical data (scores, times) to ensure the numbers feel bespoke and elegant.

### Don't
*   **DON'T** use pure black (#000000) for text. Always use `on_surface` (#2d2e37) to maintain a premium, editorial feel.
*   **DON'T** use 1px dividers to separate list items; use a 8px or 12px gap with a background color shift instead.
*   **DON'T** use sharp corners. Every interactive element must have at least an `sm` (0.5rem) radius to stay consistent with the "Fluid" creative star.
