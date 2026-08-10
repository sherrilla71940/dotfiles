---
name: browser-collab-testing
description: 'Rapid collaborative browser testing protocol where agent and user share interaction duties. Use when Chrome DevTools MCP cannot automate certain interactions (canvas clicks, map overlays, drag gestures, WebGL elements), when many sequential user actions are needed, when user offers to help click or interact, or when running E2E flows that mix automatable and non-automatable steps. Triggers: "help me test", "I can click for you", "test together", "collaborative testing", "speed up testing", "let me do it".'
---

# Browser Collaborative Testing Protocol

A workflow for fast human-agent collaborative browser testing. The agent handles setup, scripting, and verification. The user handles interactions that MCP tools cannot automate. The goal is **speed** — minimize round-trips, batch instructions, verify in bulk.

## When to Use

- Chrome DevTools MCP `click(uid)` cannot reach the target (canvas, WebGL, SVG hit regions, map overlays)
- A test flow requires **3+ sequential user interactions** — batching saves significant time
- User explicitly offers to help with physical interactions
- Complex gesture-based interactions (drag-and-drop on canvas, multi-touch, hover-then-click sequences)

## When NOT to Use

- All elements are in the DOM and clickable via MCP `click(uid)` or `evaluate_script`
- Single one-off click — just ask inline, no protocol needed

## The Speed Protocol

### Principle: Agent Does Max, User Does Min

Before involving the user, the agent MUST exhaust all automatable options:

| Action | Agent handles | User handles |
|---|---|---|
| Button/link/checkbox clicks | `evaluate_script` or MCP `click(uid)` | Never |
| Text input | MCP `fill(uid)` or `evaluate_script` | Never |
| Zoom, scroll, pan | `evaluate_script` (e.g. `map.setZoom()`) | Never |
| Page state queries | `evaluate_script` returning JSON | Never |
| Canvas element clicks | Cannot automate | Yes |
| Map polyline/overlay clicks | Cannot automate reliably | Yes |
| Drag on canvas/WebGL | Cannot automate | Yes |
| Complex hover-click sequences | Unreliable | Yes |

### Phase 1: Agent Sets Up

Prepare ALL preconditions in a single `evaluate_script` call before involving the user:

```javascript
// GOOD: One call sets up everything
() => {
  window.gMap.setZoom(19);
  window.gMap.setCenter({ lat: 25.016, lng: 121.299 });
  document.getElementById('btn_insert_mode').click();
  return { ready: true, hint: document.getElementById('hint')?.textContent };
}
```

### Phase 2: Agent Briefs User

Take a screenshot, then give **precise, batched instructions**:

**Good (batched, specific):**
> Please do these 3 actions:
> 1. Click the blue line between the nodes labeled "N07-1" and "N08-1"
> 2. Click the new node that appears on that line
> 3. Click the "→ 分支出" button at the bottom
>
> Tell me when done.

**Bad (vague, one-at-a-time):**
> Click a polyline on the map.
> *(waits for response)*
> Now click the node.
> *(waits for response)*
> Now click the button.

### Phase 3: User Acts

User performs all requested actions and responds with "done", "clicked", or describes what happened.

### Phase 4: Agent Verifies (Bulk)

Check ALL expected outcomes in one `evaluate_script`:

```javascript
// GOOD: Verify everything at once
() => {
  const labels = document.querySelectorAll('.infoBox');
  const newNodes = Array.from(labels).filter(d => d.textContent?.includes('NEW'));
  const saveBtn = document.getElementById('btn_save');
  const hintBar = document.getElementById('hint');
  return {
    newNodeCount: newNodes.length,
    newNodeLabels: newNodes.map(n => n.textContent?.trim()),
    isDirty: saveBtn?.offsetParent !== null,
    currentMode: hintBar?.textContent?.trim(),
    totalLabels: labels.length
  };
}
```

Then take a screenshot for visual confirmation.

## Efficiency Rules

1. **Never ask the user for something the agent can do** — buttons, checkboxes, zoom, typing, state queries
2. **Batch user instructions** — 3-5 actions per round-trip, not one at a time
3. **Always screenshot before asking** — user needs to see what they're clicking
4. **Always verify after user acts** — don't assume the click landed
5. **One `evaluate_script` per verification** — return a JSON object with all checks
6. **Describe targets by visible label, not by coordinates** — "the line between N07-1 and N08-1" not "click at pixel 429, 522"
7. **State the expected result** — "a new node should appear on the line" so the user can also confirm visually

## Examples of Non-Automatable Elements

| Technology | What MCP Can't Click | Why |
|---|---|---|
| Google Maps Polylines | Canvas-rendered lines | No DOM target, Google Maps internal hit-testing |
| Google Maps custom overlays | Some OverlayView subclasses | May render on canvas layer |
| Chart.js / ECharts | Bar segments, pie slices, data points | Canvas rendering |
| D3.js (canvas mode) | Shapes rendered via `<canvas>` | No DOM elements |
| Fabric.js / Konva.js | Objects on canvas | Internal hit-test, not DOM |
| WebGL / Three.js | 3D objects | GPU-rendered, raycasting needed |
| HTML5 Canvas games | Sprites, UI elements | No DOM |
| Drag-and-drop on canvas | Drag gestures | Requires coordinated mouse events |
| MapLibre / Leaflet | Vector tile features | Internal event system |

## Troubleshooting

| Problem | Solution |
|---|---|
| User click didn't register | Ask user to click more precisely on the element; zoom in first via `evaluate_script` |
| Wrong element clicked | Take screenshot, annotate with a description of exact target, retry |
| State didn't change after click | Check via `evaluate_script` whether the app's mode/state is correct; the click may have landed on the wrong layer |
| Too many round-trips | Batch more actions per turn; group related steps together |
| User unsure what to click | Zoom in closer, center the target element, take screenshot, describe with landmarks ("the orange circle just below the '竣工' label") |
