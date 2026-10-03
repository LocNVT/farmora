# Farmora: UI Specification

> **Status:** Approved design, MVP v1.0. Implementation NOT started.
> **Companion docs:** `docs/GDD.md` (rules and numbers), `docs/DESIGN.md` (colors, type, spacing, motion tokens).
> **Conventions:** dp for sizes, sp for text. All colors, fonts and spacing come from `docs/DESIGN.md` tokens. Reference frame **390 x 844 dp**, portrait only. Copy in quotes is the approved text. `OPEN` marks something the approved design did not define; a recommended default is given.
> **Required states** for every interactive component: default, pressed, disabled, selected, loading, error, where applicable.

---

## 1. Screen inventory

14 screens plus shared overlays.

| # | Screen | Type | Entry | Exit |
|---|---|---|---|---|
| 1 | Splash | Full screen | Cold launch | Main Menu (first launch) or Farm (auto-continue) |
| 2 | Main Menu | Root | After Splash | Farm, Settings |
| 3 | Farm | Root, tab "Farm" | Play, Continue, tab, closing any overlay | Other tabs, Animal Interaction, Building Details, Settings |
| 4 | Animal Interaction | Bottom sheet over Farm | Tap animal or bubble; row action in Animals list | Close, swipe down, tap farm outside, tap another animal, Info |
| 5 | Market | Tab root | Market tab, Buy-feed shortcuts, empty-state buttons, Market building | Other tabs, Buy Animal dialog |
| 6 | Inventory (Bag) | Tab root | Bag tab | Other tabs, Market |
| 7 | Animal Details | Pushed screen on Animals stack | Info in sheet; row in Animals list | Back |
| 8 | Building Details | Pushed full screen from Farm | Tap building or its upgrade badge; Upgrade buttons in "full" messages | Back, Upgrade dialog |
| 9 | Upgrade Dialog | Modal | Upgrade on Building Details | Upgrade (animation then Farm), Cancel |
| 10 | Buy Animal Dialog | Modal over Market | Buy on an animal row | Buy (animation then Farm), Cancel |
| 11 | Offline Reward | Blocking modal | Launch or resume after more than 5 min with production | Collect, then Farm |
| 12 | Settings | Pushed over any screen | HUD gear; Main Menu Settings | Back |
| 13 | Tutorial | Overlay on real screens | First Play | After step 6, or Skip |
| 14 | Animals (tab) | Tab root | Animals tab | Animal Details, farm view, other tabs |

Shared pieces: **HUD** (top), **Bottom nav**, **Farm world** (scene), **Toast**, **Tooltip**, **Banner**.

---

## 2. Navigation

**Structure**

```
Splash -> Main Menu -> Farm  (tab root)
                         |-- Tab: Farm      (Farm world + HUD)
                         |-- Tab: Animals   -> Animal Details (push)
                         |-- Tab: Market    -> Buy Animal dialog (modal)
                         |-- Tab: Bag       -> Market (Buy more)
Farm -> Animal Interaction (sheet) -> Animal Details (Info)
Farm -> Building Details (push) -> Upgrade dialog (modal)
HUD gear / Main Menu -> Settings (push)
Launch/resume -> Offline Reward (blocking modal, before any other prompt)
```

**Bottom nav tabs (4):** Farm, Animals, Market, Bag. Settings stays in the HUD gear.

**Back behavior (Android back and iOS swipe/back button)**

| Context | Result |
|---|---|
| Splash while loading | Ignored |
| Main Menu | Exits the app |
| Farm, no overlay | Toast "Press back again to exit" |
| Farm, any overlay open | Closes the top overlay (overlays are a stack) |
| Animals, Market, Bag tab root | Returns to the Farm tab |
| Pushed screen (Animal Details, Building Details, Settings) | Pops one level |
| Offline Reward | Behaves like Collect (rewards never lost) |
| Tutorial | Ignored except on the final card |
| Dialogs | Closes the dialog (Cancel). Not dismissible by scrim: Offline Reward and the tutorial |

**Transitions:** pushed screens slide in from the right in 240 ms; sheets slide up 240 ms (close 180 ms); modals scale 0.92 to 1 with fade in 240 ms; Splash exit is a 240 ms cross-fade.

**Tab rules.** Selected tab uses a Leaf-tint pill with Leaf-dark label. A badge (18 dp Barn circle) on Bag counts newly collected products. Tabs are disabled (45% opacity) only while the tutorial locks a tab.

**Reserved (Future / Not MVP).** A hidden fifth "More" tab slot (78 dp).

---

## 3. Main Farm screen

**Purpose.** Home. See the farm alive and act on animals, buildings and ready products.

**Layout (390 x 844 reference, top to bottom)**

| Layer | Spec |
|---|---|
| Top safe area | 24 to 59 dp |
| HUD | 72 dp, below the inset, 14 dp top padding |
| Farm world | Full-bleed scene behind everything |
| Building tags | 24 dp pills under each building |
| Bubbles | Hunger and product bubbles above animals (36 dp visual, 48 dp target) |
| Collect-all | 60 dp, bottom-right, 16 dp above the nav |
| Bottom nav | 72 dp + inset (106 dp on the reference) |
| Chip lane | 36 dp under the HUD, empty in MVP (**Future / Not MVP**) |

**Elements and sizes**
- HUD: see Section 17.
- Animals: chicken 64 dp (tap zone 64 x 64), pig 96 dp (80 x 72), cow 128 dp (96 x 80).
- Buildings: tap target at least 72 x 72 dp (the whole art).
- Building tag format: "Coop Lv 1 - 2/4". Full = amber text on Ink. 70% opacity while panning.
- Upgrade badge: 24 dp Leaf arrow above the roof, bobbing, shown **only when affordable**.

**Interactions**

| Gesture | Result |
|---|---|
| Tap animal | Selects (ring), pans camera 280 ms so the animal sits above the sheet, opens Animal Interaction |
| Tap bubble | Does the one obvious action: collect a ready product, or feed a hungry animal |
| Tap building | Opens Building Details |
| Long press (400 ms) animal | Tooltip with name and status; does not open the sheet |
| Drag (starts after 8 dp) | Pans with 400 ms inertia, rubber-band at the map edge. A drag that starts on an animal still pans |
| Pinch | Zoom 0.8x to 1.4x. Double tap on empty ground resets to 1.0x. Zoom not saved |
| Collect-all | Gathers every ready product with a 60 ms stagger |
| Tap feed "+" in HUD | Opens Market, Feed segment |
| Tap gear | Opens Settings |

Movement under 8 dp counts as a tap. Overlapping tap zones choose the nearest centre. Bubbles sit above animals so they win overlaps.

**States**
- **Empty (no animals):** a hint bubble over the coop reads "Buy your first chicken" and the Market tab pulses once.
- **Error:** save-failure banner under the HUD; missing art falls back to a rounded placeholder block.
- **Ambient:** clouds drift 8 dp/s, animals wander, grass tufts sway; never more than two ambient movements at once; paused while a sheet or modal covers most of the screen.

---

## 4. Animal interaction UI

**Purpose.** Check one animal and act (feed, collect, info) without leaving the farm.

**Container: floating bottom sheet**

| Property | Spec |
|---|---|
| Height | 272 dp (one fixed peek height, no expanded state in MVP) |
| Side margin | 8 dp; bottom margin 8 dp above the nav |
| Radius | 28 dp (top corners) |
| Padding | 8 dp top, 16 dp sides, 16 dp bottom |
| Fill / shadow | Panel #FFFBEF, modal shadow |
| Grabber | 36 x 5 dp inside a 48 dp touch zone |
| World above | Stays interactive |

**Content (top to bottom)**
1. Header row: portrait 56 dp; name (Fredoka 600 22); species and level caption; **Info** and **Close** icon buttons (48 dp).
2. Three status columns: Health, Hunger, Mood (see "Status bar" in Section 17).
3. Production bar (progress bar, 10 dp).
4. Action row: **Feed** (primary) and **Collect** (secondary), 52 dp tall, equal width.

**Rules**
- The useful button is the raised one; the other is disabled **with a reason**.
- Feed disabled, no feed: tooltip "No feed left" plus a "Buy feed" link to Market > Feed.
- Collect disabled, nothing ready: button shows "Not ready yet".
- Tapping another animal updates the sheet in place.
- Dismiss: Close, swipe down, tap the farm outside the panel, or system back. Swipe dismisses when released past 40% of the height or faster than 600 dp/s.

**Animation.** Slides up 240 ms ease-out; camera pans 280 ms; selection ring pulses; close 180 ms.

---

## 5. Animal detail UI

**Purpose.** Full view of one animal: status, production and name.

**Layout (scrollable column)**

| Block | Spec |
|---|---|
| Header | Scenic header 300 dp tall, animal 180 dp, idle animation; Back button top-left |
| Identity | Name in Title (Fredoka 600 28/32); tap the name to rename; species, level and building as caption |
| Status card | White card, radius 20, padding 16: three status bars (Health, Hunger, Happiness), animate to value in 300 ms |
| Production card | Product icon, progress bar, "ready" state |
| Actions | **Feed** and **Collect** row, 52 dp, same rules as the sheet |
| Reserved row | 56 dp below the actions for **Breed** (**Future / Not MVP**, hidden) |
| Reserved block | 160 dp for traits (**Future / Not MVP**, hidden) |

**Navigation.** Pushed onto the Animals tab stack (slides in 240 ms from the right). Back pops to wherever the player came from.

**States.** No empty state. Errors are the same as the sheet (no feed, not ready).

> **OPEN (not in approved design): rename rules.** The design says "tap the name to rename" but gives no dialog layout or character limit. Recommended: reuse the Modal component with one text field, a 12-character limit, and Cancel / Save buttons.

---

## 6. Feed flow

**Primary path (2 taps)**
1. Tap an animal. The Animal Interaction sheet opens.
2. Tap **Feed**.

**Shortcut (1 tap).** Tap the wheat bubble above a hungry animal. Same rules.

**Rules**
- One tap = one meal = **1 feed**, hunger **+50%**.
- 300 ms debounce between feeds.
- Feed allowed while hunger is below 100; at full the button is disabled with caption "Full".
- The animation never blocks input; tapping twice fills a very hungry animal.

**Timeline (total about 1 s)**

| Time | Event |
|---|---|
| 0 ms | Button press (sink 3 dp), feed counter decrements |
| 0 to 250 ms | Food arcs into the animal |
| 250 to 700 ms | Animal eats (3 pecks, 3 slow chews, or nose-dive with 4 bites) |
| 700 to 1000 ms | Hunger bar eases up 300 ms; a heart floats 40 dp |

**Sound and haptic.** Crunch and a happy cluck, oink or moo; light haptic.

**Error: out of feed**
- Feed disabled; feed pill in the HUD shakes; Feed button wiggles 2 degrees (200 ms).
- Toast "Out of feed. Buy more at the market." (stays 2.2 s) offers the market.
- A secondary "Buy feed" button opens Market > Feed.

> **OPEN (not in approved design): "Full" caption.** The design disables Feed only for no-feed. Recommended: also disable at hunger 100 with the caption "Full" so a meal is never wasted. Confirm before building.

---

## 7. Production and collection flow

**Production (system)**
- A fed animal advances `progress` toward 1.0 over its cycle time (Egg 3 min, Milk 6, Pork 10 at 100% speed; faster with building level).
- At `progress` = 1.0 the product bubble appears above the animal and bobs 4 dp on a 1.6 s loop with a faint glow. A single soft chime plays when it first appears (not looped).
- The ambient bob stops as soon as the product is collected.

**Collect (player)**

| Method | Result |
|---|---|
| Tap the product bubble | Collects that animal's product |
| **Collect** in the sheet or Animal Details | Same |
| **Collect** in the Animals list row | Same; camera jumps to the animal |
| **Collect-all** (60 dp, bottom-right of Farm) | Gathers every ready product, 60 ms stagger between items |

**Timeline per item:** 120 ms bubble pop, 400 ms product arc to the Bag tab or HUD, 600 ms "+1 Egg" floater rises and fades. Plink sound, light haptic. The Bag tab badge counts newly collected products.

**States.** Nothing ready: Collect shows "Not ready yet" (disabled).

**Offline.** Products produced while away are delivered through the Offline Reward modal (Section 13).

---

## 8. Market

**Purpose.** Turn products into coins and coins into feed and animals. The Market is also the **Shop** (Animals and Feed segments).

**Layout**

| Block | Spec |
|---|---|
| HUD | 72 dp, shared |
| Title | "Market" (Title style) |
| Segmented control | **Sell / Animals / Feed**, 48 dp tall, tap or horizontal swipe (24 dp, mostly horizontal) to switch |
| List | Rows 72 dp with product disc (56 dp), name, quantity, price, 48 dp action; 12 dp gap |
| Bottom | Fade above the nav |

### 8.1 Sell segment
- One row per product (Egg, Milk, Pork) showing quantity and the coins it is worth.
- **Sell** per row (Sun secondary button, 48 dp). A zero-quantity row is dimmed to 60% with the action disabled.
- Sell all lives in the Bag.
- Sell animation: counts tick down in the row, up to 8 coin sprites arc to the HUD coin pill in 400 ms, pill bumps to 108%, coin clinks, light haptic.
- Toast on sale: "Sold 12 eggs  +60 coins".
- Empty (no products): "Nothing to sell yet / Collect eggs, milk or pork from your animals first / Back to farm".

### 8.2 Animals segment (Shop)
- Rows (72 dp) for Chicken, Pig, Cow with portrait, name, price, **Buy** button (48 dp). The one-line description and capacity appear in the Buy dialog.
- Locked animals are dimmed with "Unlocks at level N" and a disabled Buy.
- **Buy always opens the Buy Animal dialog** (Section 12.1).
- Empty farm state also opens here (Open market > Animals segment).

### 8.3 Feed segment (Shop)
- One row: Feed pack "10 feed" with its price (25 coins) and a **Buy** button.
- Feed is bought **instantly**: no confirm dialog, "+10" floater, feed pill ticks up.
- Not enough coins: toast, Buy disabled, price in Error red.

**Errors.** Not enough coins or feed: toast, disabled Buy, price in red. Android back returns to the Farm tab.

---

## 9. Inventory

**Purpose.** See everything owned and sell quickly. Tab label: **Bag**.

**Layout**

| Block | Spec |
|---|---|
| Title | "Bag" with kind count |
| Product tiles | **2 columns**, 12 dp gap; tile padding 14 / 12 / 12; disc 56 dp |
| Feed tile | Feed icon, count, storage "36 / 100" |
| Sell all bar | Sticky, 56 dp, above the nav; shows the total coins |

**Product tile:** disc 56 dp, name Fredoka 600 17, quantity Fredoka 700 22 ("x12"), value caption with coin ("60"), **Sell** button 48 dp at full tile width. Tile width about 150 dp.

**States**
- **Zero quantity:** tile at 60% opacity, Sell disabled, caption "Nothing yet". The tile never disappears.
- **Empty bag:** "Your bag is empty / Feed your animals and collect what they make / Go to farm".
- **Error:** if a sale cannot be saved, toast "Could not sell. Try again" and quantities are restored.

**Actions:** Sell one kind (tile), **Sell all** (bar), **Buy more** feed (opens Market > Feed). Counts tick and coins fly on sale.

---

## 10. Shop

There is **no separate Shop screen** in the approved design. The Shop is the Market tab:

| Shop function | Where |
|---|---|
| Buy animals | Market > Animals segment (Section 8.2) |
| Buy feed | Market > Feed segment (Section 8.3), or the HUD feed "+" |
| Sell products | Market > Sell segment (Section 8.1), or the Bag |

Do not build a separate Shop screen or a gem/premium store (**Future / Not MVP**). The reserved fourth "Special" Market segment is **Future / Not MVP**.

---

## 11. Upgrade UI

Two steps: **Building Details** (decide), then **Upgrade Dialog** (confirm).

### 11.1 Building Details (screen 8)

| Block | Spec |
|---|---|
| Header | Scenic header 380 dp: current art and next-level art side by side with an arrow between them; Back button |
| Level pills | "Lv 1" to "Lv 2" |
| Comparison card | Capacity row (for example "4 to 8") and speed row (for example "100% to 125%"). Market shows sell bonus; Feed Storage shows storage |
| Capacity pips | 8 dp pips: Leaf = housed, Line = free |
| Cost row | Coin icon + cost |
| Action | **Upgrade to Level N** (primary, 52 dp) |

- **Max level:** header shows a "Max level" badge, comparison reads "Fully upgraded", Upgrade button hidden.
- **Not enough coins:** cost in Error red, Upgrade disabled, "Need N more coins" beside it.
- **Animation:** the arrow slides in; numbers tick up from old to new in 300 ms.
- **Navigation:** pushed full screen from Farm. Back pops.

### 11.2 Upgrade Dialog (screen 9)
Same anatomy as the Buy Animal dialog.

| Element | Spec |
|---|---|
| Modal | Width 326 dp (screen minus 64, max 340), radius 28, padding 24, gap 14 |
| Art | Building art 96 dp |
| Title | "Upgrade coop?" (Fredoka 600 26/30) |
| Before / after strip | "Lv 1 to Lv 2" and "4 to 8" |
| Cost | Coin icon + price, Fredoka 700 |
| Buttons | **Cancel** (ghost) and **Upgrade** (primary), width ratio **1 : 1.2** |

- If coins fall below the cost while open, Upgrade becomes disabled with caption "Need N more coins".
- **On confirm:** buttons lock 300 ms; cost flies out of the HUD; building squashes and sparkles 600 ms; art swaps at 400 ms of 1.2 s; capacity tag ticks up; toast "Coop upgraded". Returns to Farm; the player can tap away at any time.
- Dismiss: Cancel, scrim tap, system back.

### 11.3 Upgrade shortcuts
"Building is full" messages (Buy dialog, empty states) include an **Upgrade** button that opens Building Details for that building.

---

## 12. Dialogs

**Common modal spec**

| Property | Spec |
|---|---|
| Width | Screen width minus 64 dp, max 340 dp |
| Radius / padding / gap | 28 / 24 / 14 dp |
| Fill / shadow | Panel #FFFBEF, modal shadow, over 45% brown scrim |
| Enter | Scale 0.92 to 1 + fade, 240 ms |
| Buttons | Ghost left, primary right, ratio 1 : 1.2, 52 dp tall |
| Dismiss | Tap scrim, Cancel, or system back. Never trap the player (exceptions: Offline Reward and the tutorial) |
| Focus | Focus trapped inside while open |
| Double-tap guard | Purchase buttons lock 300 ms on confirm |

### 12.1 Buy Animal dialog (screen 10)

| Element | Spec |
|---|---|
| Portrait | 96 dp |
| Title | "Buy a chicken?" (Fredoka 600 26/30) |
| Description | One line ("Lays eggs when it is fed.") |
| Chips | "Makes Egg", "Coop 2/4 to 3/4" |
| Price | Coin icon + price, Fredoka 700 30 |
| Buttons | Cancel / Buy |

**Variants**

| Variant | Behavior |
|---|---|
| Insufficient coins | Price in Error red; Barn-tint note "You need N more coins."; **Sell products** button; Buy disabled |
| Building full | Replaced by "The coop is full / Upgrade it to make room for more chickens" with **Upgrade** and "Not now" |
| Locked by level | Buy disabled with "Unlocks at level N" |

**On Buy:** buttons lock 300 ms; animal drops in at the building door (300 ms drop and squash); confetti 600 ms (max 20 pieces); "New chicken!" banner; then a "Meet Pip" card with a **Feed Pip** button; the app switches to the Farm tab with the new animal highlighted and hungry.

### 12.2 Upgrade dialog
See Section 11.2.

### 12.3 Start new farm (damaged save)
Confirm dialog on the Main Menu. Title and copy follow the standard recipe; buttons **Cancel** and **Start new farm**. The old save is kept as a backup.

> **OPEN (not in approved design): exact copy for the damaged-save dialog.** Recommended: title "Start a new farm?", body "Your old farm is kept as a backup.", buttons Cancel / Start new.

### 12.4 Offline Reward
See Section 13.

---

## 13. Offline reward

**Trigger.** On launch or resume, when more than 5 minutes have passed and something was produced. Shown once per return, before any other prompt. If nothing was produced, the modal is skipped.

**Layout**

| Block | Spec |
|---|---|
| Container | Modal over the dimmed farm, standard modal spec |
| Title | "Welcome back!" (Fredoka 700 34) |
| Away line | Away duration (for example "You were away 3 h 20 min") |
| Reward rows | **64 dp** each for eggs, milk, coins; icon disc, label, count |
| Cap note | "up to 8 hours" caption |
| Action | **Collect** (primary, 56 dp), the only way out |

**Behavior**
- Rows count up one after another: 80 ms stagger, 600 ms count; confetti 800 ms.
- **Collect** sends items flying to the Bag and HUD in 400 ms, then shows the Farm.
- Android back behaves like Collect. Not dismissible by scrim.
- If saving the rewards fails, hold them and show the modal again on the next launch.
- Rules for what is produced and the 8 h cap: `docs/GDD.md`, Section 9.

---

## 14. Tutorial

**Purpose.** Teach the loop in under two minutes using the real screens.

**Elements**

| Element | Spec |
|---|---|
| Scrim | Brown, 58%, with a spotlight cut-out (radius = target radius + 4) |
| Ring | Pulsing ring around the target; pings every 1.4 s |
| Tooltip card | Margins 16, radius 24, padding 16 x 18, pointer 20; title Fredoka 600 22/26, body 15/22; progress dots |
| Skip | "Skip tutorial" link, 44 dp tap area |

**Steps**

| # | Title | Spotlight target |
|---|---|---|
| 1 | Welcome to Farmora | Welcome card |
| 2 | Buy your first chicken | Market tab, then Buy |
| 3 | Feed your chicken | Feed button or wheat bubble |
| 4 | Collect the egg | Egg bubble or Collect |
| 5 | Sell the egg | Sell button |
| 6 | Grow your farm | Final card |

**Rules**
- **No Next buttons.** The player does the highlighted action to advance.
- Taps outside the spotlight are blocked. Android back is ignored except on the final card.
- Tabs other than the target are disabled (45% opacity) while a step requires a specific tab.
- Step completion: small chime and a toast.
- **Skip** at any time; skipping grants the same 150 starting coins.
- If the player deviates (for example buys a different animal), the tutorial adapts or ends quietly. It never blocks the game.
- Tutorial boost: the first egg is ready after 20 s.
- `tutorialStep` is saved so the tutorial resumes.

**Animation.** Spotlight tweens between targets 240 ms; ring pings 1.4 s; tooltip rises 200 ms.

---

## 15. Toasts

**Component spec**

| Property | Spec |
|---|---|
| Size | 48 dp tall, padding 0 x 16, radius 24 |
| Position | Screen space, 16 dp above the nav, centered |
| Timing | In 200 ms, stays **2.2 s**, out 160 ms |
| Queue | One at a time; a newer toast replaces the older one |
| Colors | Success: Leaf #26803A with white text. Error / problem: Barn tint #FBE3DC with ink text #7A2A1B and info icon (never red fill). Info: #256FB8 with white text |
| Type | Nunito 700, 14/18 |

**Approved toasts**

| Trigger | Text | Type |
|---|---|---|
| Sell | "Sold 12 eggs  +60 coins" | Success |
| Save ok | "Saved" | Info |
| Upgrade done | "Coop upgraded" | Success |
| Out of feed | "Out of feed. Buy more at the market." (component sample: "Not enough feed. Buy some at the market.") | Error tint |
| Sale not saved | "Could not sell. Try again" | Error tint |
| Back at Farm root | "Press back again to exit" | Info |
| Level up | "Level 4! Pig unlocked" (illustrative) | Success, non-blocking |
| Tutorial step done | Short congratulation | Success |
| Purchase | Banner "New chicken!" (slides down) | Success |

> **OPEN (not in approved design): final wording.** The two out-of-feed texts above differ between boards. Recommended: use "Out of feed. Buy more at the market." everywhere.

**Tooltips**

| Property | Spec |
|---|---|
| Color | Info blue #256FB8, white text |
| Type | Nunito 700, 13/18 |
| Shape | Radius 10, padding 8 x 12, max width 200 dp, 5 dp pointer |
| Timing | Appears 200 ms after a 400 ms long press, hides on release |
| Examples | "Hold an animal to see its status", "No feed left", the reason on a disabled button |

---

## 16. Empty, loading and error states

**Recipe (every state):** friendly icon or animal, one-line headline, one-line next step, one button that does it. No blame, no red screens, no dead ends. Headline up to 5 words, body up to 10 words, button 1 to 2 words. Never "Error" or "Failed", no exclamation mark on negative states. Disabled buttons always sit beside the reason.

| State | Visual | Headline | Body | Button | Next |
|---|---|---|---|---|---|
| Empty bag | Grey disc, bag icon | Your bag is empty | Feed your animals and collect what they make. | Go to farm | Farm tab |
| No animals | Dashed-outline chicken | Your farm is quiet | Buy your first chicken at the market. | Open market | Market > Animals |
| No products | Dashed egg | Nothing to sell yet | Collect eggs, milk or pork from your animals first. | Back to farm | Farm tab |
| Not enough coins | Red-outlined coin pill + Barn-tint note | (note) You need N more coins. | Buy stays visible but disabled, price in red | Sell products | Sell segment |
| Not enough feed | Disabled Feed + info tooltip | (tooltip) Out of feed. Buy more at the market. | Mimi is hungry | Buy feed | Market > Feed |
| Building full | Yellow disc with upgrade icon | The coop is full | Upgrade it to make room for more chickens. | Upgrade coop (+ "Not now") | Building Details |
| Save error | Barn-tint banner with info icon | We could not save just now. We will try again in a moment. | Non-blocking, play continues | Try now | Retry; auto-retry 5 s, 15 s, 60 s |
| Loading | Bobbing chicken, progress bar | Loading your farm | Skeleton rows | none | After 8 s: "Taking longer than usual" + **Try again** (56 dp) |
| Damaged save | Menu state | Save damaged | n/a | Start new farm | Confirm dialog, backup kept |
| Animals list empty | Same as No animals | Your farm is quiet | | Open market | Market |
| Locked animal | Dimmed row | Unlocks at level N | | none (Buy disabled) | n/a |
| Max-level building | Badge | Fully upgraded | | Upgrade hidden | n/a |

**Loading component:** progress bar 10 dp (indeterminate: a 40%-wide highlight sweeps left to right, 1.2 s loop); skeleton rows 44 dp high with a soft horizontal shimmer. Splash bar is 12 dp.

**Banner (save error):** Barn tint #FBE3DC, 2 dp border #E8B3A6, radius 16, padding 12, info icon 24 dp, text Nunito 700 13/18 color #7A2A1B; sits under the HUD; non-blocking.

---

## 17. Component specifications

All sizes in dp, text in sp. Colors and fonts come from `docs/DESIGN.md`. State names are fixed: **default, pressed, disabled, selected, loading, error**.

### 17.1 Primary button

| Property | Spec |
|---|---|
| Height / min width | 52 / 88 |
| Padding / radius | 0 x 20 / 14 |
| Icon / gap | 20 / 8 |
| Label | Fredoka 600 16/20, sentence case |
| Fill / edge | Leaf #26803A / 4 dp solid #1B5E2C |
| Hit area | Full 52 dp height; extended 4 dp each side where neighbours allow |

| State | Look and behavior |
|---|---|
| Default | As above |
| Pressed | Sinks 3 dp (edge to 1 dp), fill #1D6730, 80 ms; release 120 ms with 4% overshoot |
| Disabled | Fill #E6DCC3, text #6E5A46, edge #D3C7A8; reason shown nearby |
| Loading | Spinner (20 dp, 0.8 s) replaces the icon; input locked |
| Selected | Extra 4 dp ring #7BD389 |

Max one primary per view.

### 17.2 Secondary button (Sun)
Same geometry. Fill #FFC53D, text #4A2F12, edge #D99A0B. Pressed #F2B52A, edge 1 dp. Used for **Collect** and **Sell**. Disabled same as primary.

### 17.3 Ghost button
Same geometry. Fill white, text #3B2A1A, 2 dp border #EBDDBB, edge #EBDDBB. Pressed #F6EED8. Used for Cancel and low-priority choices.

**In-row action buttons:** 44 dp tall (animal rows) or 48 dp tall (product tiles and market rows), padding 0 x 14, same styles.

### 17.4 Icon button

| Property | Spec |
|---|---|
| Size | 48 x 48 circle, glyph 24, min 8 dp gap to neighbours |
| Surface | Panel #FFFBEF or white, 2 dp edge #EBDDBB, soft shadow |
| Pressed | Fill #F6EED8, scale 0.94 |
| Disabled | 45% opacity |
| Selected | Leaf tint #E4F5DA, 2 dp Leaf inset ring, Leaf glyph |
| Requirement | Content description / accessibility label on every icon button |

### 17.5 HUD

| Property | Spec |
|---|---|
| Height / padding | 72 below the safe area; top padding 14, side padding 16, gap 8 |
| Level badge | 44 dp, XP purple #8A63D9, shows "Lv N" |
| Coin pill | 44 dp tall, radius 999, min width 110, disc 30, number Fredoka 600 18/22 |
| Feed pill | Same as coin pill plus "+" (28 dp visual in a 48 dp target); tap opens Market > Feed |
| Gear | 44 dp visual in a 48 dp target |
| Fill / shadow | Panel #FFFBEF, 2 dp edge #EBDDBB plus soft blur |
| Defaults in specs | Coins 1,240, Feed 36, Level 3 (tutorial boards: 150, 5, Lv 1) |

| State | Behavior |
|---|---|
| Value change | Number rolls over 400 ms; pill bumps to 1.08x |
| Error (not enough) | Pill shakes 8 dp x 3 (280 ms); number turns Error red #C63B32 for 600 ms |
| Pressed (feed) | Pill fill #F6EED8, scale 0.96 |
| Accessibility | Currency changes announced politely ("Coins 1,300") |

### 17.6 Bottom navigation

| Property | Spec |
|---|---|
| Height | 72 + bottom inset |
| Items | 4: Farm, Animals, Market, Bag; each 56 tall (about 78 wide), padding 8 |
| Shape / fill | Radius 28 top corners; panel #FFFBEF |
| Icon / label | 28 dp icon; Nunito 700 12/16 |
| Selected | Leaf tint pill (#E4F5DA), label #1D5A2C |
| Default | Label / icon #6E5A46 |
| Pressed | Fill #F6EED8, scale 0.96 |
| Disabled | 45% opacity (tutorial lock only) |
| Badge | 18 dp Barn circle with count |
| Target | Whole 56 dp item |

### 17.7 Animal sheet
See Section 4 (272 dp, margins 8, radius 28, grabber 36 x 5).

### 17.8 Status bar

| Property | Spec |
|---|---|
| Track | 8 dp tall, radius 4, #F0E5C8 |
| Icon / label / value | Icon 16 to 18 dp; label 12 sp; value 13 sp |
| Fills | Health #E5584F (heart), Hunger #E2A12B (wheat), Happiness #F27FA5 (smile) |
| Animation | Animates to value in 300 ms |
| Low (under 30%) | Fill turns Warning amber and the icon pulses once per 2 s. **Never red, never flashing** |

### 17.9 Progress bar

| Property | Spec |
|---|---|
| Size | 10 dp tall, radius 5, full width |
| Colors | Track #F0E5C8, fill #7BD389, ready #26803A |
| States | Default, ready (3 dp soft glow ring), empty (0%), loading (indeterminate sweep, 1.2 s loop) |
| Animation | Width animates 300 ms ease-out |

### 17.10 Animal card (list row)

| Property | Spec |
|---|---|
| Size | Row 80 dp, radius 20, padding 0 x 12, gap 12 |
| Contents | Portrait 52 dp circle (#E4F5DA), name Fredoka 600 18/22, status badge 22 dp, action button 44 dp |
| Surface | White, 2 dp edge #EBDDBB, soft shadow |
| Status badges | "Egg ready" #E4F5DA / #1D5A2C; "Hungry" #FFE9A8 / #6B4400 |
| Selected | 3 dp Leaf inset ring, fill #F3FAEC |
| Action | **Collect** (Sun) when ready; **Feed** (Leaf) when hungry |

### 17.11 Product tile and market row

| Property | Spec |
|---|---|
| Tile | 150 dp wide (2 columns), radius 20, padding 12 to 14, gap 4 |
| Disc | 56 dp |
| Name / quantity | Fredoka 600 17 / Fredoka 700 20 to 22 |
| Value caption | Nunito 700 12 with coin dot |
| Action | 48 dp, full tile width |
| Zero quantity | 60% opacity, caption "Nothing yet", action disabled |
| Market row | 72 dp tall, radius 20, 48 dp action |

### 17.12 Building card

| Property | Spec |
|---|---|
| Size | Row 96 dp, thumbnail 72 dp (radius 16) |
| Contents | Name Fredoka 600 17, "Lv 1 - 3 / 4 animals" caption, "Upgrade ready" badge |

### 17.13 Building tag (world space)
24 dp pill, panel fill, Nunito 700 12. Format "Coop Lv 1 - 2/4". Full: amber text on Ink. 70% opacity while panning. Scales with zoom, clamped 0.9x to 1.2x.

### 17.14 Modal and dialog
See Section 12.

### 17.15 Bottom sheet

| Property | Spec |
|---|---|
| Radius | 28 top corners |
| Grabber | 36 x 5 dp, #E3D4AE |
| Peek | 272 dp above the nav, one fixed height (MVP) |
| Dismiss | Swipe down or Close; world stays tappable |

### 17.16 Toggle

| Property | Spec |
|---|---|
| Size | 56 x 32, thumb 24, inset 4 |
| Colors | On Leaf #26803A; off #D8CBA8; thumb white |
| Target | 56 x 48 |
| Animation | Thumb slides 160 ms |

### 17.17 Segmented control and chips

| Property | Spec |
|---|---|
| Segmented (Market) | 48 dp tall (approved). Switch by tap or horizontal swipe |
| Filter chips (Animals) | Chip radius 10 to 20 per the radius scale; Leaf tint #E4F5DA with #1D5A2C label is the approved "selected" look (same as nav); chips scroll horizontally |

> **OPEN (not in approved design): exact styling of the segmented control and filter chips.** Sizes beyond the 48 dp segmented height are not specified. Recommended: segment and chip selected state = Leaf tint #E4F5DA with #1D5A2C label and a 2 dp Leaf ring; unselected = white with #6E5A46 label; chip height 40 dp.

### 17.18 Toast, tooltip, banner
See Sections 15 and 16.

### 17.19 Tutorial tooltip
See Section 14.

### 17.20 Resource disc

| Context | Spec |
|---|---|
| HUD | 28 to 30 dp disc, 16 to 18 dp glyph |
| Cards | 44 dp disc, 26 dp glyph |
| Product tile | 56 dp disc, 30 dp glyph |
| Colors | See `docs/DESIGN.md` resources table |

---

## 18. Remaining screen specifications

### 18.1 Splash (screen 1)
- Wordmark (Fredoka 700 64 sp), bobbing chicken 140 dp, 12 dp progress bar, version caption, meadow background. Not interactive.
- After 8 s: caption becomes "Taking longer than usual" and a 56 dp **Try again** button appears.
- Animation: logo drops in 300 ms with a small squash; chicken bobs 6 dp on a 1.8 s loop; progress eases; exit is a 240 ms cross-fade.
- Android back ignored while loading.

### 18.2 Main Menu (screen 2)
- Wordmark, chicken, cow and pig on the meadow; **Play** (64 dp primary), **Continue farm** (56 dp ghost), **Settings** and **Sound** buttons (56 dp).
- First launch: Continue hidden; Play starts the tutorial. Afterwards Continue farm is primary.
- Damaged save: Continue shows "Save damaged" and offers "Start new farm" (Section 12.3).
- Animation: animals idle; buttons rise in with a 60 ms stagger, 240 ms each; press sinks 3 dp.
- Root screen: Android back exits the app.

### 18.3 Animals tab (screen 14)
- HUD, title with count, **filter chips** (All, Chickens, Cows, Pigs), animal cards 80 dp.
- Primary action per row: Collect or Feed (44 dp). Action buttons jump the camera to the animal on the farm; tapping the row opens Animal Details.
- **Ready animals float to the top.** Rows reorder with a 200 ms slide when status changes.
- Empty: "Your farm is quiet" with **Open market**.
- Error: toast with the reason (no feed). Back returns to Farm.

### 18.4 Settings (screen 12)
- Back button and Title; a card of four toggles (56 x 32 dp): **sound, music, vibration, gentle reminders** (reminders off by default); a card with **language**, "Game saved" with **Save now**, credits and version.
- Each toggle acts immediately; there is no primary action.
- Save now failure: the row shows "Could not save" in Error tint with **Try again**.
- Pushed over any screen; slides in 240 ms; Back pops.

---

## 19. Accessibility requirements (applies to all screens)

- Contrast at least 4.5:1 (white on Leaf, Barn, Error, Info; ink on Sun, Warning, resource tints).
- State is never color alone: Hungry has a wheat bubble and the word "Hungry"; Ready has a product bubble and the word "ready"; errors carry an info icon.
- Targets at least 48 x 48 dp with 8 dp gaps; no gesture-only actions; no timed taps; no hold-required actions (long press only adds a tooltip).
- Screen readers: every icon button labelled; animals announce "Mimi, chicken, hungry, egg ready"; bubbles focusable and named ("Collect egg from Mimi"); currency changes announced politely.
- Reduced motion and sound/haptic fallbacks: see `docs/DESIGN.md` Sections 9 and 10.
- Nothing flashes more than 3 times per second.
