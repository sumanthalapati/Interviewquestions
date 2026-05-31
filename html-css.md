# 🎨 HTML5, CSS3 & SASS Interview Questions — Complete Guide

> 100 questions across 10 sections covering HTML5 semantics, CSS fundamentals, Flexbox, Grid, responsive design, CSS variables, SCSS, animations, architecture, and Bootstrap 5.

---

## Table of Contents

1. [HTML5 Semantics & Accessibility](#section-1--html5-semantics--accessibility)
2. [CSS Box Model & Fundamentals](#section-2--css-box-model--fundamentals)
3. [Flexbox](#section-3--flexbox)
4. [CSS Grid](#section-4--css-grid)
5. [Responsive Design & Media Queries](#section-5--responsive-design--media-queries)
6. [CSS Variables & Theming](#section-6--css-variables--theming)
7. [SASS/SCSS](#section-7--sassscss)
8. [Animations & Transitions](#section-8--animations--transitions)
9. [CSS Architecture & BEM](#section-9--css-architecture--bem)
10. [Bootstrap 5](#section-10--bootstrap-5)

---

---

# ⚖️ HTML & CSS Comparisons — Side-by-Side Differences

---

## HTML-C1 — `<div>` vs Semantic Elements

| | `<div>` / `<span>` | Semantic (`<article>`, `<nav>`, etc.) |
|-|------------------|--------------------------------------|
| Meaning to browser | None (generic) | Describes purpose |
| SEO | ❌ No benefit | ✅ Search engines understand structure |
| Accessibility | ❌ No ARIA role | ✅ Screen readers announce purpose |
| Styling | Same | Same |
| Use for | Layout containers with no semantic meaning | Content sections with clear purpose |

```html
<!-- ❌ div soup — no meaning -->
<div class="header"><div class="nav">...</div></div>
<div class="main"><div class="post">...</div></div>

<!-- ✅ Semantic HTML -->
<header><nav aria-label="Main">...</nav></header>
<main><article>...</article></main>
<footer>...</footer>
```

---

## HTML-C2 — `id` vs `class` vs `data-*` attribute

| | `id` | `class` | `data-*` |
|-|------|---------|---------|
| Uniqueness | Must be unique per page | Reusable on many elements | Custom key-value data |
| CSS selector | `#id` | `.class` | `[data-x]` |
| JS access | `getElementById` | `getElementsByClassName` | `dataset.x` |
| Specificity | Highest (100) | Medium (10) | Low (0 attribute) |
| Use for | Anchors, JS hooks, single unique element | Styling groups of elements | Embed data in HTML for JS |

```html
<button id="submit-btn" class="btn btn-primary" data-order-id="123" data-action="confirm">
  Confirm
</button>

<script>
  const btn = document.getElementById('submit-btn');
  const orderId = btn.dataset.orderId; // "123"
</script>
```

---

## HTML-C3 — `<script>` placement: `defer` vs `async` vs body-end

| | Inline (head, no attr) | `async` | `defer` | Body end |
|-|----------------------|---------|---------|---------|
| Blocks HTML parse | ✅ Yes | Partially | ❌ No | ❌ No |
| Execute order | Immediately | When downloaded (random) | DOM-ready, in order | In order |
| Use for | ❌ Avoid | Analytics, independent scripts | App JS (order matters) | Legacy fallback |

```html
<!-- ❌ Blocks parsing -->
<head><script src="app.js"></script></head>

<!-- ✅ defer — download in parallel, execute after DOM ready, in order -->
<head><script src="app.js" defer></script></head>

<!-- async — download in parallel, execute ASAP (no order guarantee) -->
<head><script src="analytics.js" async></script></head>
```

---

## CSS-C1 — `display: flex` vs `display: grid`

| | Flexbox | Grid |
|-|---------|------|
| Dimensions | 1D (row OR column) | 2D (rows AND columns simultaneously) |
| Content-driven | ✅ Items define size | ❌ Layout-driven (you define tracks) |
| Alignment | Main axis + cross axis | Row axis + column axis |
| Use for | Navigation bar, card row, button groups | Page layout, dashboard, complex alignment |

```css
/* Flexbox — horizontal nav */
nav { display: flex; gap: 16px; align-items: center; justify-content: space-between; }

/* Grid — two-column page layout */
.layout {
  display: grid;
  grid-template-columns: 260px 1fr;  /* sidebar + main */
  grid-template-rows: 60px 1fr 40px; /* header + content + footer */
  min-height: 100vh;
}
.sidebar { grid-row: 2; }
.main    { grid-row: 2; }
```

---

## CSS-C2 — `position: relative` vs `absolute` vs `fixed` vs `sticky`

| | `static` | `relative` | `absolute` | `fixed` | `sticky` |
|-|----------|-----------|-----------|---------|---------|
| Flow | Normal | Normal (offset from self) | Removed from flow | Removed from flow | Normal then fixed |
| Positioned relative to | N/A | Self | Nearest positioned ancestor | Viewport | Scroll container |
| Use for | Default | Offset / parent for absolute children | Tooltips, dropdowns, badges | Sticky headers, cookie banners | Table headers, TOC |

```css
.parent { position: relative; }         /* makes parent the anchor */
.badge  { position: absolute; top: 0; right: 0; } /* positions within .parent */

.navbar { position: sticky; top: 0; z-index: 100; } /* sticks at top when scrolling */
```

---

## CSS-C3 — `em` vs `rem` vs `px` vs `%` vs `vw/vh`

| | `px` | `em` | `rem` | `%` | `vw`/`vh` |
|-|------|------|-------|-----|----------|
| Absolute | ✅ | ❌ | ❌ | ❌ | ❌ |
| Relative to | — | Parent font-size | Root `<html>` font-size | Parent dimension | Viewport |
| Scales with user preference | ❌ | ✅ | ✅ | Depends | ❌ |
| Use for | Borders, shadows | Component-relative spacing | Typography, global spacing | Fluid widths | Full-screen sections |

```css
:root { font-size: 16px; }       /* 1rem = 16px globally */

h1 { font-size: 2rem; }         /* 32px — scales if user changes browser font */
p  { font-size: 1rem; }         /* 16px */
.card { padding: 1.5rem; }      /* relative to root — consistent */

.container { width: 90%; max-width: 1200px; } /* fluid */
.hero { height: 100vh; }        /* full viewport height */
```

---

## CSS-C4 — CSS Specificity: Which Rule Wins?

```
Specificity scoring:
  Inline style          → 1,0,0,0 (1000)
  ID selector (#id)     → 0,1,0,0 (100)
  Class / attr / pseudo → 0,0,1,0 (10)
  Element / pseudo-elem → 0,0,0,1 (1)
  !important            → Overrides everything (avoid)

Examples:
  p                        → 0,0,0,1 (1)
  .card p                  → 0,0,1,1 (11)
  #main .card p            → 0,1,1,1 (111)
  style="color: red"       → 1,0,0,0 (1000)
  p { color: blue !important } → beats everything except inline !important
```

```css
/* ❌ !important arms race — hard to maintain */
.button { color: red !important; }
.nav .button { color: blue !important; } /* now need !important everywhere */

/* ✅ Use specificity intentionally — BEM keeps it flat */
.button { color: red; }
.button--primary { color: blue; } /* same specificity, last rule wins */
```

---

## CSS-C5 — `margin` vs `padding` vs `border` (Box Model)

| | `padding` | `border` | `margin` |
|-|----------|---------|---------|
| Background colour fills | ✅ Yes | N/A | ❌ No (always transparent) |
| Clickable area | ✅ | ✅ | ❌ |
| Collapse with adjacent | ❌ | ❌ | ✅ Vertical margins collapse |
| Use for | Inner spacing | Visual boundary | Outer spacing between elements |

```css
/* box-sizing: border-box — width includes padding + border */
* { box-sizing: border-box; } /* ✅ makes layout predictable */

.card {
  width: 300px;      /* total width = 300px including padding + border */
  padding: 16px;     /* inner space — background-coloured */
  border: 1px solid; /* visual boundary */
  margin: 8px;       /* outer space — transparent */
}
```

