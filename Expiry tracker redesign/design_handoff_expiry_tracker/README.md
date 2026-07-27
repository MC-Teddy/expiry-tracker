# Handoff: Expiry Tracker Redesign

## Overview
A visual redesign of the Expiry Tracker mobile app (a food-expiry/inventory tracker with barcode scanning and OCR date-reading). Four key screens were redesigned: Overview/Home dashboard, All Items list, Barcode/Expiry Scan, and Item Detail.

## About the Design Files
The file `Expiry Tracker Redesign.dc.html` is a **design reference built in HTML** — an interactive-looking prototype showing intended look, layout and states, not production code to copy directly. The task is to **recreate this design in your codebase's existing environment** (React Native, SwiftUI, Kotlin/Compose, Flutter, etc. — whatever the app already uses), following its established component and state patterns. If no mobile framework is established yet, pick the most appropriate one for an expiry-tracking PWA/native app and implement there.

## Fidelity
**High-fidelity.** Colors, typography, spacing and component states shown are final — recreate pixel-close using your platform's native equivalents (the HTML uses flat divs/SVG icons standing in for what should be native components/icons in your stack).

## Design System
Built on "Modernist": a flat, architectural system — Archivo typeface, a single red accent (#ec3013), zero corner radius everywhere, strong 2px dividers instead of cards/shadows for separation, flush-left labels (including inside buttons). Tokens are in `modernist-styles.css` (CSS custom properties); full rationale in `modernist-design-system-readme.md`. The redesign uses a **dark variant** of the same system for the app UI itself (light theme is used only for this handoff's own presentation chrome — ignore it):

- Dark background: `#201e1d` (page), `#302d2c` (raised surface/thumbnails)
- Text: `#f8f4f4` (primary), same at 45–60% opacity for secondary/meta
- Dividers: `rgba(245,242,240,0.14)` at 1px between rows, 2px between major sections
- Accent (unchanged from light theme): `#ec3013` — used for primary buttons, active nav icon, active tab
- Status/urgency uses accent-ramp steps only (mono-accent scheme, no separate red/yellow/green):
  - Expired: `#ff563c` text on `rgba(236,48,19,0.16)` background
  - Expiring soon: `#ff9783` text on `rgba(255,151,131,0.14)` background
  - Good/neutral: plain text at ~55% opacity, no tint
- Font: Archivo (weight 800 for headings/labels/buttons, 400/600 for body)
- Radius: 0px everywhere, no exceptions
- Icons: Lucide-style line icons, 2px stroke, currentColor

## Platforms
Two variants were designed on the same system: a **mobile app** (4 phone screens) and a **desktop app** (sidebar + wide layout, 4 screens). Desktop reuses all mobile styling/tokens but adds a persistent left sidebar nav, elevated (shadowed) stat cards instead of flat dividers, a data table for All Items, a two-column Item Detail layout, and a scan flow shown as a modal dialog over the app (webcam-based instead of a full-screen camera).

## Status color coding
Stat cards and per-item urgency tags use real traffic-light colors (not the design system's mono accent) so they read at a glance:
- **Expired** — `#ff5b4a` text/icon on `rgba(255,59,48,0.18)` background, plus a small solid dot
- **Expiring soon** — `#f2b73c` text/icon on `rgba(242,183,60,0.18)` background, plus a small solid dot
- **Good / plenty of time** — `#3fb972` text
- Category tags (e.g. "Meat") stay neutral (`rgba(245,242,240,0.12)` bg / `rgba(245,242,240,0.8)` text) so they're never confused with urgency
- "View all" links and active sidebar/tab state still use the system's accent red (`#ec3013`) — that's brand/navigation, not a status signal

## Screens

### 1. Overview / Home
- Status bar + header row: package-icon wordmark left, bell + sun/moon (theme) icons right
- 3-column stat strip (divided by 1px verticals, 2px top/bottom): Expired / Expiring Soon / Good, each an icon + big number + small caps label
- Two flush-left action buttons side by side: "Scan" (solid accent fill) and "Add item" (outlined)
- "Needs attention" section: kicker label + count, "View all" link (accent-400), list of item rows — 38px square thumbnail, name + category, right-aligned urgency tag
- Bottom tab bar: Home (active/accent) · Scan · Add · All · Settings, icon + 9px label each

### 2. All Items
- Header: "All Items" title + count subtitle
- Search field (icon + placeholder) + a square icon button (export/download)
- 3-way sort segmented control: Soonest (active/accent fill) · Name · Recently Added
- Row list: 40px thumbnail, name + category, right-aligned status tag (same urgency tag styling as Overview) or plain day count when not urgent
- Bottom tab bar, "All" active

### 3. Scan (Barcode / Expiry OCR)
- Full-bleed grayscale camera viewfinder background
- Top bar: close (X) icon left, "Scan Barcode" label pill center
- Center viewfinder frame with 4 corner brackets (white, accent-colored border)
- Instruction text below frame: "Aim at the expiry date label"
- OCR-read result pill: calendar icon + "BEST BY 07 / 29 / 26"
- Bottom-center capture button: white ring + solid accent core

### 4. Item Detail
- Full-width photo (260px) with back-chevron and edit icons overlaid top corners
- Title row: item name + urgency tag (e.g. "Expired 1d")
- "Added [date]" meta line
- Divided detail rows (icon + label left, value right): Expiry date, Category (as a tag), Barcode
- Bottom action row: "Edit item" (solid accent, flush-left label + icon) and a square outlined destructive icon button (delete, accent-red border/icon)

### Desktop equivalents (same 4 screens, wider canvas)
- **Dashboard**: left sidebar (logo, Overview/All Items/Scan/Settings nav, account footer) + header (title, search, "Add item" button) + 3 elevated stat cards + "Needs attention" list
- **All Items**: sidebar + header (title/count, sort segmented control, Excel export) + a full data table (photo, name, category, expiry date, status column)
- **Item Detail**: sidebar + two-column layout — photo/actions column on the left, name/tags/detail rows on the right
- **Scan**: sidebar + dimmed background page with a centered modal dialog — webcam viewfinder on the left, detected expiry date + barcode readouts on the right, Cancel/Save actions

## Interactions & Behavior (implied, not yet wired)
- Bottom tab bar navigates between Home / Scan / Add / All / Settings
- Sort segmented control on All Items re-orders the list (Soonest First / Name / Recently Added)
- Tapping a list row anywhere (Home's "Needs attention", All Items) opens Item Detail
- Scan screen: capture button triggers OCR read of the expiry date; a confirmation/edit form follows (not included in this handoff — extend the Item Detail / Add Item pattern)
- Theme toggle (sun/moon icon) switches light/dark — this handoff only designed the dark state
- Urgency tag colors and thresholds should stay data-driven (expired vs. "expiring soon" vs. "good") rather than hardcoded per item

## Design Tokens
| Token | Value |
|---|---|
| Background (dark) | `#201e1d` |
| Surface (dark) | `#302d2c` |
| Text primary | `#f8f4f4` |
| Divider | `rgba(245,242,240,0.14)` |
| Accent | `#ec3013` |
| Accent (expired text) | `#ff563c` |
| Accent (expiring-soon text) | `#ff9783` |
| Expired tag bg | `rgba(236,48,19,0.16)` |
| Expiring-soon tag bg | `rgba(255,151,131,0.14)` |
| Font — heading/label | Archivo, weight 800 |
| Font — body | Archivo, weight 400/600 |
| Corner radius | 0px (all elements) |
| Row divider weight | 1px (rows), 2px (sections) |

Full light-theme token set (for any light-mode screens you build later) is in `modernist-styles.css`.

## Assets
- All photos are placeholders (`<image-slot>` drop targets in the HTML) — replace with real product/package photography. Per the design system, all photography should render in **grayscale** (pure black and white, no color tint).
- Icons are inline SVG line icons in a Lucide-compatible style — swap for your platform's Lucide icon set (or equivalent) at matching stroke widths.

## Files
- `Expiry Tracker Redesign.dc.html` — the full design reference (open in a browser). Note: this is a Design Component file (custom `<x-dc>`/templating format from the design tool) — read it as an HTML/CSS reference, not as importable code.
- `modernist-styles.css` — the design system's token sheet (colors, type, spacing, radius, shadows as CSS variables) and base component classes.
- `modernist-design-system-readme.md` — full design system guidance and rationale.
