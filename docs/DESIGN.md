# Farmora: Visual Design System

> **Status:** Approved design, MVP v1.0. Implementation NOT started.
> **Companion docs:** `docs/GDD.md` (rules and numbers), `docs/UI_SPEC.md` (screens and components).
> **Source of truth:** the approved design canvas is the reference for look; this file is the reference for values. A machine-readable copy of the tokens (`tokens.json`) was delivered separately and is not part of `docs/`.
> **Conventions:** all sizes are dp (iOS pt) unless marked sp (text). At 390 wide, 1 sp = 1 px. Use tokens, never ad-hoc values. `OPEN` marks something the approved design did not define.

---

## 1. Visual direction

**Name: "Soft Clay Meadow".** Cute, calm, readable at a glance.

| Principle | Rule |
|---|---|
| Shape language | Everything is a rounded blob first: pill buttons, pebble-shaped animals, chunky buildings. Smallest corner radius anywhere is **10 dp**. No sharp triangles except beaks and roofs, which get rounded joins |
| Outlines | Art uses a **3-unit warm-brown outline (#3B2A1A)** on a 100-unit sprite. Never pure black |
| Light | One light from the **top-left**. Soft warm shadows, never grey |
| Color | Warm cream UI floating over a bright meadow. Color carries meaning: **green = go, gold = money, red/pink = health only** |
| Calm | At most **2 ambient animations on screen at once**. Attention indicators appear only for things the player can act on now |
| Depth | Buttons have a 4 dp solid bottom edge ("clay" feel). Cards have a 2 dp edge plus a soft blur |

**Backdrop.** Meadow ground #A9DB8A (shade #8FCB72), sky #CBEBFF, soil #C99A6B. No text sits on the meadow without a panel behind it.

---

## 2. Color palette

### Primary: Leaf

| Token | HEX | Use |
|---|---|---|
| `color.primary` Leaf | **#26803A** | Primary button, brand, success actions |
| `color.primaryPressed` | **#1D6730** | Pressed fill |
| `color.primaryEdge` | **#1B5E2C** | Primary button bottom edge |
| `color.primaryLight` | **#7BD389** | Highlights, progress fill, glow |
| `color.primaryTint` | **#E4F5DA** | Selected card, chips, hint backgrounds |

### Secondary and accent

| Token | HEX | Use |
|---|---|---|
| `color.secondary` Sun | **#FFC53D** | Secondary button, sell and coin actions |
| `color.secondaryEdge` | **#D99A0B** | Sun button bottom edge |
| `color.secondaryText` | **#4A2F12** | Text on Sun |
| Sun pressed | **#F2B52A** | Pressed secondary fill |
| `color.accent` Barn | **#C94A32** | Roofs, badges, "new" tags |
| `color.accentTint` | **#FBE3DC** | Soft error and alert backgrounds (text #7A2A1B, border #E8B3A6) |

### Background, panel, card, text

| Token | HEX | Use |
|---|---|---|
| `color.bg` Cream | **#FFF6DF** | App background behind lists and screens |
| `color.panel` | **#FFFBEF** | Bottom sheets, modals, nav bar, HUD pills |
| `color.card` | **#FFFFFF** | Item cards, animal cards, rows |
| `color.ink` | **#3B2A1A** | Primary text, art outlines |
| `color.inkSoft` | **#6E5A46** | Secondary text, captions (6.4:1 on cream) |
| `color.line` | **#EBDDBB** | Dividers, card edges |
| `color.track` | **#F0E5C8** | Empty bar track |
| Selected-card tint | **#F3FAEC** | Animal row selected fill |
| Pressed neutral | **#F6EED8** | Pressed fill for white and panel surfaces |
| `color.disabledFill` | **#E6DCC3** | Disabled button fill (text #6E5A46) |
| `color.disabledEdge` | **#D3C7A8** | Disabled button bottom edge |
| Toggle off | **#D8CBA8** | Toggle track when off |
| Grabber | **#E3D4AE** | Bottom-sheet grabber |
| `color.scrim` | **rgba(59,42,26,0.45)** | Modal scrim (tutorial scrim is 58%) |

### Semantic

| Token | HEX | Text on it | Use |
|---|---|---|---|
| `color.success` | **#26803A** | White | Purchase done, sold, saved |
| `color.warning` | **#E59A00** | **Ink** | Hungry, low feed, attention |
| `color.error` | **#C63B32** | White | Insufficient-coins price text, save failed |
| `color.info` | **#256FB8** | White | Tooltips, tutorial hints, info icon |

### Resources and status

| Token | HEX | Notes |
|---|---|---|
| `res.coin` | **#FFC53D** | Outline #C98A00. Disc behind the coin glyph |
| `res.feed` | **#E0A84A** | Sack / disc #F3D9A0, outline #C99A3F |
| `res.egg` | **#FFF3D6** | Outline #E9C98B |
| `res.milk` | **#E6F3FF** | Outline #7DB8EA |
| `res.pork` | **#F4909A** | Edge #E06C7A |
| `res.xp` | **#8A63D9** | Tint #EEE7FB. Level badge and XP bar |
| `res.gem` (premium, placeholder) | **#24B8C9** | Disc #BFEFF5. Defined only; hidden in MVP |
| `stat.health` | **#E5584F** | Pair with heart icon |
| `stat.hunger` | **#E2A12B** | Hunger bar (full = fed). Pair with wheat icon |
| `stat.happiness` | **#F27FA5** | Pair with smile icon |
| Badge "ready / info" | bg #E4F5DA, text #1D5A2C | Status badge, "Egg ready" |
| Badge "hungry / upgrade" | bg #FFE9A8, text #6B4400 | Status badge, "Hungry", "Upgrade ready" |

### Rules
- **Contrast:** white text on Leaf, Barn, Error and Info is at least 4.5:1. Ink text is used on Sun, Warning and all resource tints.
- **Never color alone:** every state pairs color with an icon or a word.
- **Never red for hunger** or any animal state in the MVP. Red/pink means health only.

---

## 3. Typography

Two families, both rounded and legible at small mobile sizes. Bundle both fonts (SIL Open Font License).

| Family | Weights | Role |
|---|---|---|
| **Fredoka** | 600, 700 | Display, headings, buttons, **every number** |
| **Nunito** | 600, 700 | Body copy, captions |

| Style | Font | Size / line height (sp) | Use |
|---|---|---|---|
| Display | Fredoka 700 | 36 / 40 | Splash, level-up, welcome-back title only |
| Title | Fredoka 600 | 28 / 32 | Screen, sheet and modal titles |
| Section | Fredoka 600 | 20 / 24 | Group headers, animal names |
| Body | Nunito 600 | 15 / 22 | Descriptions, dialog text (max 2 lines in a dialog) |
| Button | Fredoka 600 | 16 / 20 | All button labels, sentence case, 1 to 2 words |
| Currency / number | Fredoka 600 | 18 / 22 | Coins, counts, prices |
| Caption | Nunito 700 | 12 / 16 | Status labels, hints. **Never below 12 sp** |

**Specific sizes used in the approved screens** (still from the families above)

| Element | Spec |
|---|---|
| Splash wordmark | Fredoka 700, 64 sp |
| Offline "Welcome back!" | Fredoka 700, 34 sp |
| Buy dialog title | Fredoka 600, 26/30 |
| Buy dialog price | Fredoka 700, 30 sp (24 sp in the component sample) |
| Tutorial tooltip title | Fredoka 600, 22/26 |
| Animal name in sheet | Fredoka 600, 22 |
| Animal row name | Fredoka 600, 18/22 |
| Product tile quantity | Fredoka 700, 22 |
| Toast / tooltip text | Nunito 700, 13 to 14 |
| Nav label | Nunito 700, 12/16 |

**Rules**
- Respect OS font scaling up to **130%**. Layouts use **minimum heights**, so rows grow instead of clipping. HUD pills widen. Numbers never wrap.
- Thousands separators on all numbers; no abbreviations under 10,000.
- Copy tone: friendly, no blame. Headline up to 5 words, body up to 10 words, button 1 to 2 words. Never "Error" or "Failed", and no exclamation marks on negative states.

---

## 4. Iconography

**Style**
- 24 x 24 grid, **2.25 stroke**, round caps and joins, 2 dp inner padding.
- Outline only for navigation and actions.
- Resources get a **colored disc** behind the same outline glyph.
- Rounded corners, no sharp terminals. One idea per icon. No text inside icons.
- Ship as **24 x 24 SVG with `stroke="currentColor"`** so one asset serves every state color. Resource discs are separate circles, not baked into the glyph.

**Sizes**

| Context | Size |
|---|---|
| Navigation icon | 28 dp |
| Button icon | 20 dp, 8 dp gap to label |
| Icon button glyph | 24 dp inside a 48 dp circle |
| Resource disc, HUD | 28 to 30 dp disc, 16 to 18 dp glyph |
| Resource disc, cards | 44 dp disc, 26 dp glyph (56 dp disc on product tiles and rows) |
| Status bar icon | 16 to 18 dp |
| Minimum rendered size | 16 dp |

**Colors.** Ink #3B2A1A on light surfaces, white on Leaf or Barn. Selected nav icons switch to a Leaf-tint disc behind the glyph and a Leaf stroke; the shape does not change.

**Icon set (23 approved glyphs)**

| Icon | Description | Used for |
|---|---|---|
| Home | Little house with arched door | Farm tab |
| Animals | Paw print | Animals tab and list |
| Market | Stall with scalloped awning | Market tab |
| Inventory | Satchel with handle | Bag tab |
| Settings | Eight-ray gear | HUD gear |
| Coin | Double ring, always on gold | Currency |
| Feed | Wheat stalk, three leaf pairs | Feed resource, hunger icon |
| Egg | Plain oval, narrow end up | Product |
| Milk | Glass bottle with fill line | Product |
| Pork | Ham with bone dot, no gore | Product |
| Upgrade | Arrow up to a ceiling bar | Upgrade actions and badge |
| Buy | Cart, always paired with a price | Buy actions |
| Sell | Price tag | Sell actions |
| Feed action | Bowl with sprouts | Feed button |
| Collect | Basket with handles | Collect button |
| Close | Rounded cross | Close |
| Back | Chevron left | Back |
| Information | Circle with i | Info, error banners |
| Health | Heart | Health bar |
| Happiness | Smiling face | Happiness bar |
| XP | Star | Level badge |
| Premium (placeholder) | Gem | Hidden in MVP |
| Sound | Speaker with wave | Sound toggle |

Future icons (breeding, collection, quests) follow the same grid and live in the same set. **Future / Not MVP.**

---

## 5. Spacing system

**Scale (dp):** `4, 8, 12, 16, 20, 24, 32, 48`

| Value | Use |
|---|---|
| 4 | Icon-to-label tight |
| 8 | Icon gap, chip padding, minimum gap between touch targets |
| 12 | List item gap |
| 16 | Screen margin, card padding |
| 20 | Button side padding |
| 24 | Section gap, dialog padding |
| 32 | Large gap, empty states |
| 48 | Hero spacing, minimum touch size |

**Corner radius**

| Radius | Use |
|---|---|
| 10 | Chips, tooltips, small tags |
| 14 | Buttons, inputs |
| 20 | Cards, item tiles |
| 28 | Modals, bottom-sheet top corners, nav top corners |
| 999 | Resource pills, progress bars, status badges |

**Elevation**

| Token | Value |
|---|---|
| Button depth | 4 dp solid edge below; pressed = translate 3 dp down, edge 1 dp |
| Card | `0 2 0 #EBDDBB` + `0 6 16 rgba(59,42,26,.08)` |
| HUD pill | `0 2 0 #EBDDBB` + `0 6 14 rgba(59,42,26,.12)` |
| Modal and sheet | `0 12 32 rgba(59,42,26,.28)` over the 45% scrim |
| Toast | `0 8 20 rgba(59,42,26,.22)` |

**Touch targets**

| Control | Minimum |
|---|---|
| Any target | 48 x 48 dp, with 8 dp minimum gap between neighbours |
| Buttons | 52 dp tall (primary), 44 dp in rows with a 48 dp target |
| Nav items | 56 dp tall |
| Animals on the farm | 64 dp tap zone, even when the sprite is smaller |
| Bubbles | 36 dp visual, 48 dp target |
| Buildings | 72 x 72 dp |
| Collect-all | 60 dp |
| Skip tutorial | 44 dp tap area |
| Edge | Keep targets at least 8 dp from the screen edge |

---

## 6. Design principles

1. **One primary action per view.** Leaf (primary) is for the one best next action. Max one primary per view.
2. **Every tap answers.** At least one of press animation, sound, haptic or state change, with a visual response within 100 ms.
3. **Icon first, short words.** One obvious thing to tap at each step. Younger players read little.
4. **Gentle by default.** No countdown pressure, no penalty, no death, no flashing, no stacked popups. Reminders are off by default.
5. **No dead ends.** Every empty or error state follows one recipe: friendly icon or animal, one-line headline, one-line next step, one button that does it. Non-blocking errors use a toast or banner, never a modal.
6. **Disabled always explains.** A disabled button always sits beside its reason (red price, caption or tooltip), never a silent grey.
7. **The farm stays visible.** Sheets float above the nav and the world above stays tappable. Layout never jumps: zero-quantity tiles dim instead of disappearing.
8. **Reach.** Primary actions in the bottom 60% of the screen, one-thumb friendly. No gesture-only actions, no timed taps, no hold-to-play.
9. **Accessible by construction.** State is never color alone, contrast at least 4.5:1, labels on every icon button, the game is playable muted.
10. **Room for growth.** Future features may add a slot, chip, ring or tab. They may never move an MVP button.

---

## 7. Animal visual direction

Three animals, one family. They share the **3-unit warm-brown outline** on a 100-unit sprite, the same **eye size (6 units, highlight 2)**, the same **blush cheek**, and the same **drop shadow** (ellipse #3B2A1A at 13% opacity), so any new animal drops in. Silhouettes differ by height-to-width ratio and head shape so each reads at 40 dp.

| | Chicken | Pig | Cow |
|---|---|---|---|
| Silhouette | Tall egg | Wide bean | Long box with a square head |
| Sprite / tap zone (dp) | 64 / 64 x 64 | 96 / 80 x 72 | 128 / 96 x 80 |
| Body | #FFFBEF | #F9B7C0 | #FFFBEF |
| Accent colors | Comb #E5584F, beak and legs #F2A100, wing #F4E4BD, cheek #FF9F9A | Snout #FF9FB0, ears #F29AA8, legs #F6A5B1, cheek #FF7F95, mud #B07D4F | Patches and ears #8A6A55, muzzle #FFB4A8, horns #F3E3B5, bell #FFC53D |
| Shape | Soft egg on legs; round body 58 x 50 units, no neck, teardrop wing, three-lobe comb, small beak | Round bean, short legs, big flat snout disc, one floppy ear, curly tail | Long rounded box, four stubby legs, soft square head, big muzzle, short round horns |
| Face | Dot eye high and close to the beak; blinks every 4 to 6 s (80 ms close); happy = closed arc | Round eyes slightly raised; oversized snout with two tall nostrils; never shows teeth | Eyes wide-set and half-lidded; slow to blink; two nostril dots; ears low and level |

**Animation and feedback by animal**

| Animal | Idle and wander | Tap | Feed | Collect / ready |
|---|---|---|---|---|
| Chicken | Bob 2 dp over 1.2 s; peck loop every 5 s; wander 40 dp/s with 4-degree waddle; hop 10 dp when happy | Squash to 90% x 110% in 160 ms, "bok" | Three pecks in 450 ms | Wing flap; egg pops up 24 dp into the counter |
| Pig | Snout wiggle every 2 s; trot with 3 dp bounce at 36 dp/s; mud roll in the pen; tail spin when happy | Jump 8 dp, squeal | Nose dive into trough, four quick bites | Ham bubble bobs above |
| Cow | Slow chew loop 1.4 s; tail swish every 3 s; ear flick every 7 s; graze 2 s; walk 20 dp/s | Head tilts 8 degrees, bell jingles, "moo" | Three slow chews, tail wag | Bell glows; milk bottle bubble bobs above |

**Status language** (one bubble above the head plus one face change; never red, never flashing, bubbles only when actionable)

| State | Look |
|---|---|
| Normal | Happy face, no indicator, idle bob and blink |
| Hungry | Half-closed eyes, wheat bubble |
| Product ready | Product bubble bobs 4 dp on a 1.6 s loop with a faint glow ring |
| Low happiness | Small grey cloud, slanted brow, slower idle |
| Sick (**Future / Not MVP**) | Pale tint, sleepy curve eyes, dashed heart bubble |

**Production notes.** Pork is a product bubble only; no harm is ever depicted. Illustration approach: vector art with shared definitions and CSS-style variables so variants can recolor body, wing and comb without new drawings. Future variants (white, brown, golden chicken) only change `--body`, `--wing`, `--comb`.

---

## 8. Building visual direction

Every building is identified by **silhouette and a sign plaque**, never by a text label. Upgrades add things you can see: more width, more detail, more trim. Level 2 and 3 art reuses the Level 1 base so production stays small.

| Building | Shape | Colors | Sign plaque | L2 adds | L3 adds |
|---|---|---|---|---|---|
| Chicken Coop | Small wooden shed, steep roof, arched pop-hole door | Wood #D9A066 (L2-3 lighter #E8B77C), roof #C94A32, door #7A4A22 | Cream plaque with an egg (golden at L3) | Wider body, window with flower box, weather vane | Side nest annex, white roof trim, lantern, picket fence, golden egg plaque |
| Cow Barn | Wide gambrel barn with big X door; the largest building | Body #C94A32, roof #7A4A22, door #FFFBEF, hay window #F3D77A | Cream plaque with a milk bottle on the left wall | Side shed and a fence | Silo, white roof trim, weather vane |
| Pig Pen | Low fenced mud yard with a trough; open and flat so pigs stay visible | Mud #B07D4F, fence #D9A066, trough #9A6A3A, feed #E0B25C | Wooden signpost with a pig-snout plaque | Roofed trough shelter | Bigger yard, flowers along the fence |
| Feed Storage | Tall cylinder with a dome roof; the only tall building | Wheat #F1D9A0, dome #C94A32, sacks #F3D9A0 | Round cream plaque with a wheat stalk | Second sack stack | Twin silos |
| Market | Open stall with a scalloped striped awning | Awning #C94A32 and cream stripes, counter #D9A066, sign gold coin #FFC53D | Cream plaque with a gold coin above the awning | Second awning panel and a crate | Bunting and lantern |

The **Farm** is the world itself (layered scene), not a building. It has no upgrade art.

**On-farm indicators**

| Indicator | Spec |
|---|---|
| Building tag | Pill under the building: name, level, housed / capacity. 24 dp tall, panel fill, Nunito 700 12 sp. Always visible; 70% opacity while panning. Example "Coop Lv 1 - 2/4" |
| Full | Tag text turns Warning amber on Ink |
| Upgrade ready | 24 dp Leaf arrow badge bobbing above the roof, **only when affordable**. Tapping opens Building Details |
| Capacity pips (Building Details) | One 8 dp pip per slot, Leaf filled when housed, Line color when free |
| Feed Storage fill | A fill window on the silo shows storage level; the Feed pill mirrors it |

---

## 9. Animation principles

**Timing tokens**

| Token | Duration | Use |
|---|---|---|
| Instant | 80 ms | Press |
| Quick | 120 ms | Release, pop |
| Standard | 200 to 240 ms | Sheets, modals |
| Emphasis | 300 to 400 ms | Counters, flights |
| Celebration | 600 to 800 ms | Never blocking |

**Easing**

| Name | Curve | Use |
|---|---|---|
| Ease-out | cubic-bezier(0.2, 0.8, 0.2, 1) | Entrances |
| Ease-in-out | cubic-bezier(0.4, 0, 0.2, 1) | Movement |
| Overshoot | cubic-bezier(0.34, 1.56, 0.64, 1) | Rewards |

**Rules**
1. No animation blocks input. Celebrations can be tapped through.
2. Target **60 fps** on a three-year-old mid-range phone. Particle caps are fixed per effect.
3. At most **2 ambient animations** at once; ambient animations pause while a sheet or modal covers most of the screen.
4. Animations exist to explain cause and effect, not to decorate.

**Catalogue**

| Interaction | Timing | What happens |
|---|---|---|
| Button press | Down 80 ms, release 120 ms | Button sinks 3 dp (edge to 1 dp); springs back with 4% overshoot |
| Purchase | 300 ms drop + 600 ms confetti | Animal drops in at the building door, squashes on landing, **max 20** confetti pieces, "New chicken!" banner slides down |
| Selling | 400 ms flight + 400 ms counter roll | **Max 8** coin sprites arc from the row to the coin pill; pill bumps to 108%; count ticks down in the row |
| Feeding | 250 ms toss + 450 ms eat + 300 ms bar fill | Food arcs in, animal eats, hunger bar eases up, a heart floats 40 dp |
| Collecting | 120 ms pop + 400 ms flight + 600 ms floater | Bubble pops, product arcs to the Bag tab or HUD, "+1 Egg" rises and fades |
| Level up | 500 ms burst + 400 ms badge | Ring burst, badge scales 1.0 > 1.3 > 1.0, toast. Does not pause play |
| Building upgrade | 1.2 s, swap at 400 ms | Building squashes, sparkles 600 ms, art swaps at the midpoint, capacity tag ticks up |
| Error | 280 ms | Element shakes 8 dp three times and flashes Error tint 300 ms |
| Not enough coins | 600 ms | Coin pill shakes and turns Error red; the price pulses |
| Not enough feed | 200 ms + 2.2 s toast | Feed pill shakes; Feed button wiggles 2 degrees; toast offers the market |
| Product ready (ambient) | 1.6 s loop | Bubble bobs 4 dp with a faint glow ring; stops when collected |
| Idle farm (ambient) | Loops, 2 at a time max | Animals blink and wander, clouds drift 8 dp/s, grass tufts sway |
| Modal in | 240 ms | Scale 0.92 > 1 plus fade |
| Sheet in / out | 240 ms / 180 ms | Slide up ease-out |
| Toast | in 200 ms, stays 2.2 s, out 160 ms | One at a time |
| Toggle | 160 ms | Thumb slides |
| Numbers (HUD) | 400 ms | Roll up or down; pill bumps 1.08x |

**Reduced motion** (when the OS asks for it): shakes become a static color flash, flights become 150 ms fades, confetti and particles are removed, ambient loops pause, camera pan becomes an instant cut. Feedback still happens, just calmer.

**Accessibility limit:** nothing flashes more than 3 times per second.

---

## 10. Feedback principles

1. **Every tap answers within 100 ms** with at least one of press animation, sound, haptic or state change.
2. **Every sound has a visual twin**, so the game is fully playable muted. Sound, music and vibration are **three separate toggles** in Settings.
3. **Haptics are light and meaningful:** light for collect and buy, success pattern for level-up, short double tick for errors. Haptics and sound are optional.
4. **Rewards are visible:** products fly to the counter that grows, coins fly to the coin pill, numbers roll.
5. **Negative feedback is soft:** a soft "bonk", a shake, a Barn-tint note that says exactly what is missing ("You need 260 more coins."). Never red full-screen, never "Failed".
6. **Currency changes are announced politely** to screen readers ("Coins 1,300").
7. **Confirmation where money is committed:** animals and upgrades confirm in a dialog; feed packs and selling do not.
8. **Purchases lock their buttons for 300 ms** to prevent double-spend.

| Event | Visual | Sound / haptic |
|---|---|---|
| Button press | Sink | Soft tick, no haptic |
| Purchase | Drop, confetti, banner | Pop and chime, medium haptic |
| Sell | Coins fly, count ticks | Coin clinks (up to 3), light haptic per batch |
| Feed | Toss, eat, bar fill, heart | Crunch and animal sound, light haptic |
| Collect | Pop, flight, floater | Plink, light haptic |
| Level up | Burst, badge | Short fanfare (1 s), success haptic |
| Upgrade | Squash, sparkle, swap | Three hammer taps, medium haptic |
| Error | Shake and tint | Soft bonk, double-tick haptic |
| Product ready (first appears) | Bubble | Single soft chime (not looped) |
| Ambience | Idle farm | Quiet ambience, off with Sound |

---

## 11. Mobile portrait layout

**Reference:** **390 x 844 dp**, portrait only, orientation locked.

**Farm screen zones (top to bottom)**

| Zone | Spec |
|---|---|
| Top safe area | 24 to 59 dp (notch, camera hole) |
| HUD | 72 dp tall, starts below the inset; includes 14 dp top padding; pills 44 dp |
| Farm world | Full bleed behind everything |
| Chip lane (reserved) | 36 dp under the HUD, empty in MVP (**Future / Not MVP**) |
| Animal sheet | 272 dp, floats above the nav |
| Collect-all | 60 dp button, bottom-right, 16 dp above the nav |
| Bottom nav | 72 dp plus bottom inset (0 to 34 dp). On the 390 x 844 reference: 106 dp |

**Anchoring.** HUD anchors to the top safe area, nav and sheets to the bottom safe area, Collect-all to the bottom right. Do not use absolute pixel positions for UI; use anchors, margins and flex rows.

**Margins.** Screen margin 16 dp (24 dp on tablet). Card padding 16 dp. List gap 10 to 12 dp. Section gap 24 dp.

**Touch zones**

| Area | Spec |
|---|---|
| HUD | Gear 44 dp visual in a 48 dp target; feed plus 28 dp in a 48 dp target |
| Farm | Animals 64 dp, bubbles 48 dp, buildings 72 dp, Collect-all 60 dp |
| Sheet | Buttons 52 dp, icon buttons 48 dp |

**Overlays**
- Building tags and bubbles are drawn in **world space** (scale with zoom, clamped between 0.9x and 1.2x so they stay legible).
- Toasts and banners are drawn in **screen space**.
- Overlays form a **stack**; Android back pops the top overlay.

**Camera.** One-finger pan with 400 ms inertia, clamped to the map edge with a soft rubber-band. Pinch zoom 0.8x to 1.4x; double tap on empty ground resets to 1.0x. Zoom is not saved between sessions. Every action must work at 1.0x.

---

## 12. Responsive rules

**Reference devices**

| Device | Pixels | Scale | dp size |
|---|---|---|---|
| Small Android | 720 x 1280 | 2.0x | 360 x 640 |
| Common Android | 1080 x 1920 | 3.0x | 360 x 640 |
| Modern Android | 1080 x 2400 | 2.625x | 412 x 915 |
| iPhone SE | 750 x 1334 | 2.0x | 375 x 667 pt |
| iPhone 15 (reference) | 1170 x 2532 | 3.0x | 390 x 844 pt |
| iPhone Pro Max | 1290 x 2796 | 3.0x | 430 x 932 pt |

**Rules**
1. **Portrait only.** Orientation is locked.
2. **World scaling.** The farm world scales to **fit width**. Taller screens (20:9) add ground at the bottom. Shorter screens (16:9) crop sky at the top. **Buildings and animals are never cropped.**
3. **Safe areas.** Top inset 24 to 59 dp; HUD starts below it plus 14 dp. Bottom inset 0 to 34 dp; nav is 72 dp plus the inset. Keep tap targets at least 8 dp from the screen edge.
4. **Tablet.** The game column is **centered at a maximum of 480 dp wide**; the meadow background extends to the edges. Screen margin becomes 24 dp.
5. **Modals.** Width = screen width minus 64 dp, maximum 340 dp.
6. **Text scaling.** Support OS font scaling up to 130% using minimum heights; HUD pills widen; numbers never wrap or abbreviate below 10,000.
7. **Touch minimums hold at every size:** 48 dp targets, 52 dp buttons, 56 dp nav items, 64 dp animals.
8. **Assets.** Anchor-based UI with 9-slice panels; SVG or high-resolution PNG icons at 1x, 2x and 3x.
9. **Fallback.** Missing art falls back to a rounded placeholder block, never a blank screen.

> **OPEN (not in approved design): minimum supported size.** Reference devices go down to 360 x 640 dp. The design does not state a hard minimum. Recommended: treat 360 x 640 dp as the minimum and verify the Animal sheet (272 dp) still leaves the animal visible at that height.
