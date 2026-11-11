# Web app & dashboard rules

## Visual direction: light theme, premium, calm
- **Light theme only for v1.** Use a near-white canvas (warm or neutral off-white, not pure #fff everywhere), white elevated surfaces, and hairline borders. Shadows are soft and layered, never heavy. Dark mode is out of scope until an ADR adds it.
- **One confident accent colour** for primary actions and progress; everything else stays neutral. Semantic colours for job states (queued, running, rendering, done, failed) must stay distinguishable for colour-blind users, so always pair colour with an icon or label.
- **Typography carries the design.** Use one high-quality sans with tabular numerals for metrics, costs and timers. Keep the type scale tight and use generous whitespace.
- **Data-dense but airy:**
  - job tables use shadcn/Radix patterns, sticky headers and inline status chips
  - progress shows clips k/n plus the stage timeline
  - the cost panel shows the *Estimated (live)* and *Reconciled (billing, delayed)* figures side by side
- **Motion is purposeful and quiet:**
  - 150–250 ms ease-out on state changes
  - spring physics only for drag and sheet interactions
  - respect `prefers-reduced-motion`
  - no decorative scroll animation inside the dashboard
- **Tokens first.** Colours, radii, spacing, shadows and motion durations are CSS variables or Tailwind theme tokens. Never use one-off hex values in components.

## Skill workflow (use in this order)
1. `/impeccable`: shape and art-direct the screen, then **critique and audit** it before calling it done.
2. `/ui-styling` (shadcn/ui + Tailwind) and `/ui-ux-pro-max`: palette, font pairing, components, chart types.
3. `/emil-design-eng`: the polish pass covering spacing, states, focus rings, empty and loading and error states, and micro-details.
4. `/apple-design` and `/animate`: motion (springs, sheets, micro-interactions). Use `/gsap-react`, `/gsap-core`, `/gsap-timeline` and `/gsap-performance` only for complex timelines.
5. `/design-taste-frontend`: only for marketing or landing pages, not the dashboard.

## Definition of done for any screen
- Screenshot it at 1440 px and 390 px using agent-browser or Playwright, then run the `/impeccable` audit and fix its findings.
- Lighthouse accessibility ≥ 95 (chrome-devtools-mcp). Full keyboard navigation and visible focus.
- Every state is designed: empty, loading (skeletons), error, and long-running (GPU minutes).
