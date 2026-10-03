# Farmora: Game Design Document (GDD)

> **Status:** Approved design, MVP v1.0. Implementation NOT started.
> **Companion docs:** `docs/DESIGN.md` (visual system), `docs/UI_SPEC.md` (screens and components).
> **Conventions used in this file**
> - Numbers marked *(placeholder)* are balance data. They must live in one data file and be tunable without code changes.
> - `OPEN` marks a rule the approved design did not define. A recommended default is given so work is not blocked, but the owner must confirm it.
> - `Implementation clarification` marks a rule derived directly from approved rules, written out so it is unambiguous.
> - Anything not in the MVP is labelled **Future / Not MVP** and must not be built.

---

## 1. Game vision

Farmora is a cozy, relaxing portrait-mode farming game for Android and iOS. The player buys animals, feeds them, collects what they make, sells it, and spends the coins on more animals and bigger buildings.

**Promise.** Every tap gives a small, visible reward. A new player can buy a chicken, feed it, collect the egg and sell it in under two minutes, with one obvious thing to tap at each step. Negative states are gentle: a hungry animal asks for food, and nothing ever dies, expires or punishes.

**Audience (working assumptions, to validate in playtests; no research data was supplied).**
- Casual short-session player: two to five minutes at a time, one thumb, little reading.
- Cozy-game collector: plays to see cute animals and watch the farm grow.
- Younger and family players: reads little, taps a lot; needs forgiving errors and no pressure.

**Game feel the player should describe.** "My farm is alive." "My animals are cute." "I made progress." "I want to check again later." "I want to unlock more."

**Avoid.** Countdown pressure, aggressive notifications, stacked popups, clutter, confusing menus, dark patterns.

**Information priority on screen.** 1 Coins, 2 animal and product actions, 3 the farm itself, 4 main navigation, 5 everything secondary. A sixth thing goes behind a tap.

**Hard constraints.**
- Portrait only, reference 390 x 844 dp.
- Local only: no backend, accounts, analytics or network calls in the MVP.
- Engine-agnostic design (Unity, Godot or Flutter + Flame are all acceptable).

---

## 2. Core gameplay loop

```
Buy animal -> Feed -> Animal produces -> Product ready -> Collect -> Sell -> Earn coins
     ^                                                                        |
     +------------------ Buy more animals / Upgrade buildings <---------------+
```

| Step | Player action | System response |
|---|---|---|
| Buy | Market > Animals > Buy, confirm | Coins spent, animal placed in its building, starts hungry |
| Feed | Tap Feed, or tap the wheat bubble | 1 feed spent, hunger +50% |
| Produce | Wait (online or offline) | Production progress advances while hunger > 0 |
| Ready | See product bubble | Bubble bobs above the animal |
| Collect | Tap bubble, or Collect, or Collect-all | Product moves to the Bag |
| Sell | Market > Sell, or Bag > Sell / Sell all | Product removed, coins added |
| Expand | Buy another animal or upgrade a building | More capacity, faster production |

**Target first session.** Launch to first sale in under 2 minutes. The tutorial uses the real screens and a boosted first egg (see Section 8).

**Loop rules.**
- The loop always closes on itself: coins buy animals and upgrades; those raise output; output creates coins.
- There is no fail state, no death, no spoilage and no penalty for being away.

---

## 3. MVP scope

**In the MVP**

| Area | Included |
|---|---|
| Animals | Chicken, Cow, Pig |
| Products | Egg, Milk, Pork |
| Resources | Coins, Feed (XP and level exist as progression values) |
| Buildings | Farm (the world itself), Chicken Coop, Cow Barn, Pig Pen, Feed Storage, Market. Levels 1 to 3 |
| Interactions | View farm, tap animal, feed, view status, collect, bag, sell, buy animal, upgrade building, save and load, offline rewards, short tutorial |
| Screens | 14 (see `docs/UI_SPEC.md`) |
| Settings | Sound, music, vibration, gentle reminders (default off), language, Save now |

**Explicitly not in the MVP** (design leaves visual room only; see Section 10)
- Breeding, genetics, rarity, collection, quests, events.
- Premium currency (the color and icon are defined but never shown to players).
- Accounts, server, social, live-ops, analytics.
- Any form of animal harm, sickness or death.

**Pork rule.** Pork is only a product bubble and sell item. No harm is ever depicted.

---

## 4. Animals

All animals share one behavior model; they differ by product, price, unlock level, housing and cycle time.

| | Chicken | Pig | Cow |
|---|---|---|---|
| Product | Egg | Pork | Milk |
| Price *(placeholder)* | 100 coins | 600 coins | 1,500 coins |
| Unlocks at level *(placeholder)* | 1 | 3 | 5 |
| Housed in | Chicken Coop | Pig Pen | Cow Barn |
| Production cycle when fed *(placeholder)* | 3 min | 10 min | 6 min |
| Sprite size / tap zone (dp) | 64 / 64 x 64 | 96 / 80 x 72 | 128 / 96 x 80 |
| Walk speed (dp/s) | 40 | 36 | 20 |

**Per-animal state** (matches the save format in Section 9)

| Field | Range | Meaning |
|---|---|---|
| `hunger` | 0 to 100 | Fullness. 100 = fully fed, 0 = starving. (Approved naming: the "Hunger" bar shows fed level.) |
| `happiness` | 0 to 100 | Mood. Low shows a grey cloud and slower idle. Raised by feeding and collecting. |
| `health` | 0 to 100 | Stays at 100 in the MVP. Display only; the sick state is **Future / Not MVP**. |
| `progress` | 0.0 to 1.0 | Production progress toward the next product. 1.0 = product ready. |
| `name` | text | Given at purchase (examples in the design: Mimi, Pip). Renaming is by tapping the name on Animal Details. |

**Feeding rules**
- One tap on Feed = one meal = **1 feed** spent, **hunger +50%** (clamped at 100).
- Feed again is allowed with a **300 ms debounce** so a double tap cannot double-spend.
- Tapping the wheat bubble over a hungry animal feeds it directly with the same rules.
- Hunger decreases about **1% per minute** *(placeholder)*.
- Implementation clarification: an animal produces **only while hunger > 0**. One full bar (100) therefore lasts about 100 minutes; one meal (+50) lasts about 50 minutes of production time.

**Status language** (one bubble above the head plus one face change; bubbles appear only when the player can act)

| State | Face | Bubble | Trigger |
|---|---|---|---|
| Normal | Happy | None | Fed, nothing ready |
| Hungry | Half-closed eyes | Wheat bubble | Hunger is low (see OPEN below) |
| Product ready | Happy | Product bubble, bobs 4 dp on a 1.6 s loop, faint glow | `progress` = 1.0 |
| Low happiness | Slanted brow, small grey cloud, slower idle | Cloud | Happiness low; fixed by feeding or collecting |
| Sick | Pale tint, sleepy eyes, dashed heart bubble | Heart | **Future / Not MVP** |

> **OPEN (not in approved design): thresholds.** The design fixes the status bar turning amber under **30%**. It does not state the exact hunger value that shows the wheat bubble, nor the happiness value that shows the cloud. Recommended default: wheat bubble when `hunger < 30`, cloud when `happiness < 30`, matching the amber threshold. Confirm before building.

> **OPEN (not in approved design): what happens to `progress` when a product is ready but not collected.** Recommended default: production pauses at 1.0 (one stored product per animal) until collected. This keeps the tutorial, Collect-all and the offline reward easy to reason about. Confirm before building.

> **OPEN (not in approved design): happiness rules.** The design says happiness is raised by feeding and collecting and drops when neglected, but gives no numbers. Define gain and decay values in the balance file.

> **OPEN (not in approved design): animal names.** Examples exist (Mimi, Pip) but there is no naming list or rename-length limit. Recommended: a short default-name pool per species and a 12-character rename limit.

---

## 5. Products

| Product | Made by | Sell value *(placeholder)* | Resource color | Icon |
|---|---|---|---|---|
| Egg | Chicken | 5 coins | #FFF3D6 (outline #E9C98B) | Plain oval, narrow end up |
| Milk | Cow | 12 coins | #E6F3FF (outline #7DB8EA) | Glass bottle with fill line |
| Pork | Pig | 30 coins | #F4909A (edge #E06C7A) | Ham with bone dot, no gore |

**Rules**
- Collected products go to the **Bag** (`bag.egg`, `bag.milk`, `bag.pork`).
- Sell value is per item, **before** the Market bonus (Section 7).
- **Collect-all** gathers every ready product with a 60 ms stagger between items.
- Products are never lost, expire, or spoil.
- A product tile at zero quantity stays visible at 60% opacity with its action disabled, so the layout never jumps.

---

## 6. Buildings

Six buildings. **Farm** is the world itself (the scrollable scene) and has no building art or upgrade. The other five have three levels.

| Building | Houses / does | Capacity or effect by level (L1 / L2 / L3) | Upgrade cost to L2 / L3 *(placeholder)* |
|---|---|---|---|
| Chicken Coop | Chickens | 4 / 8 / 12 animals | 500 / 1,500 |
| Cow Barn | Cows | 2 / 4 / 6 animals | 1,200 / 3,500 |
| Pig Pen | Pigs | 3 / 6 / 9 animals | 800 / 2,400 |
| Feed Storage | Stores feed | 100 / 250 / 500 feed | 300 / 900 |
| Market | Sells products, sells feed and animals | Sell bonus +0% / +5% / +10% | 400 / 1,200 |

**Production speed bonus** *(placeholder)*: animals housed in a Coop, Barn or Pen produce at **100% / 125% / 150%** of base speed at L1 / L2 / L3 (design shorthand: +25% and +50%).

**Rules**
- A building at capacity blocks buying another animal for it. The Buy dialog is replaced by "The coop is full" with an **Upgrade** button.
- Feed beyond **Feed Storage capacity** cannot be held.
- Max level (L3): the Upgrade button is hidden and the screen shows "Fully upgraded".
- Upgrade requires coins only. No other requirement.
- Upgrade animation: 1.2 s total, building art swaps at 400 ms, never blocks input.
- The building tag on the farm reads like "Coop Lv 1 - 2/4". The tag turns amber when full. An upgrade arrow badge bobs above the roof **only when the player can afford** the next level.

> **OPEN (not in approved design): starting state of buildings.** The design shows buildings at Level 1 and the save format lists every building. Recommended default: all five buildings exist at Level 1 from the first launch (they are scenery plus capacity), with no building purchase step. Confirm before building.

> **OPEN (not in approved design): Feed Storage cap behavior.** The design shows storage as `x/cap` and a pack as 10 feed. It does not say what happens when the player buys a pack that would exceed the cap. Recommended default: the Buy button is disabled with the reason "Storage is full", and a pack that would partially overflow is refused (not partially applied). Confirm before building.

---

## 7. Economy

**Currencies and resources**

| Resource | Source | Sink |
|---|---|---|
| Coins | Selling products | Buying animals, feed, upgrades |
| Feed | Buying packs at the Market | Feeding animals (1 per meal) |
| Premium (gem) | Not in MVP | Not in MVP. Color and icon defined only, never shown |

**Starting values** *(placeholder)*: **150 coins, 5 feed, level 1.** This buys one chicken (100) and leaves 50 coins and 5 feed.

**Prices** *(placeholder)*

| Item | Price |
|---|---|
| Chicken | 100 |
| Pig | 600 (unlocks at level 3) |
| Cow | 1,500 (unlocks at level 5) |
| Feed pack | 10 feed for 25 coins. Bought instantly, no confirm dialog |
| Upgrades | See Section 6 |

**Sell values** *(placeholder)*: Egg 5, Milk 12, Pork 30. The Market building bonus is **+5% at L2 and +10% at L3**, applied to the total at sale time.

**Economy rules**
- Selling is per product (Market > Sell, or a Bag tile) or **Sell all** (Bag).
- All purchases lock their buttons for a **300 ms commit** so a double tap cannot double-spend.
- Animal purchases always show a confirm dialog. Upgrades always show a confirm dialog. Feed packs do not.
- Insufficient coins: the Buy button stays visible but disabled, the price turns Error red, and a note says exactly how many coins are missing. A "Sell products" action is offered.
- Insufficient feed: Feed is disabled with "No feed left" and a "Buy feed" link to Market > Feed.
- Numbers display with thousands separators and are not abbreviated below 10,000.
- No negative balances, no debt, no timers that pressure spending.

> **OPEN (not in approved design): rounding of the Market bonus.** Recommended default: round the total (not each item) to the nearest whole coin, half up.

> **OPEN (not in approved design): refund or sell-back of animals.** Not specified. Recommended: no selling of animals in the MVP.

**Balance data file.** All values above marked *(placeholder)* must be stored in one data file. A reference shape (the `balance` block of `tokens.json`) was delivered separately and is not part of `docs/`.

---

## 8. Progression

**Player level and XP** exist in the MVP (HUD level badge, `wallet.xp`, `wallet.level`) and gate animals:

| Level | Unlock |
|---|---|
| 1 | Chicken |
| 3 | Pig |
| 5 | Cow |

Locked animals appear dimmed in the Market with "Unlocks at level N" and a disabled Buy button.

**Level-up presentation.** A ring burst from the level badge, badge scale 1.0 to 1.3 to 1.0, and a toast such as "Level 4! Pig unlocked" (illustrative copy). It never pauses play and a celebration never exceeds 800 ms.

> **OPEN (not in approved design): XP rules.** The design defines the XP bar, the level badge and the unlock levels, but **not** how XP is earned or how much XP each level needs. Recommended default for a first pass: XP comes from collecting products and from purchases, with a rising threshold per level. Define sources and thresholds in the balance file before building progression.

**Beyond XP, progression is felt through:** more animals, bigger buildings (L1 to L3), faster production (+25% / +50%), and a higher Market bonus.

**Tutorial** (6 steps, uses the real screens; skippable at any time)

| Step | Title | Player does |
|---|---|---|
| 1 | Welcome to Farmora | Reads the welcome |
| 2 | Buy your first chicken | Market > Animals > Buy |
| 3 | Feed your chicken | Tap Feed |
| 4 | Collect the egg | Tap the egg bubble or Collect |
| 5 | Sell the egg | Market > Sell |
| 6 | Grow your farm | Final card |

- **Tutorial boost:** the first egg is ready after **20 seconds** so the first sale fits inside two minutes.
- Skipping grants the same 150 starting coins.
- If the player deviates (for example buys a different animal), the tutorial adapts or ends quietly. It never blocks the game.
- `tutorialStep` is saved so the tutorial resumes at the right step.

---

## 9. Offline progression

**Rules**
1. On launch or resume, compute `elapsed = min(now - lastSeen, 8 hours)`.
2. If the clock went backwards (`now < lastSeen`), `elapsed = 0`.
3. Simulate production for each animal over `elapsed`, using the same rules as online play: an animal produces only while `hunger > 0`, and hunger keeps falling about 1% per minute while away.
4. If **more than 5 minutes** passed **and** something was produced, show the **Offline Reward** modal. Otherwise skip the modal and load the farm.
5. The modal is blocking and shows once per return, before any other prompt. It cannot be dismissed except by **Collect**. Android back behaves like Collect, so rewards are never lost.
6. Collect moves the products to the Bag. No coins are credited automatically; the player sells as usual.
7. If saving the rewards fails, hold them and show the modal again on the next launch.
8. Update `lastSeen` (UTC) on every save, on backgrounding, and on Save now.

**Cap note** shown in the modal: "up to 8 hours".

**Implementation clarification: no free production.** Animals that were hungry (0) when the player left produce nothing for the time they were empty. Offline play is never better than staying online and feeding.

> **OPEN (not in approved design): coins in the offline reward.** The design's reward modal lists "eggs, milk, coins" rows, while the Flows board says "Coins arrive with the animal products". The Economy section above sells products only at the Market. Recommended default: the "coins" row shows the **sell value of the products collected** as information and does not credit coins until the player sells. Confirm before building.

**Save data** (local JSON, one file; atomic write)

```
save {
  version, lastSeen (UTC), tutorialStep,
  wallet    { coins, feed, xp, level },
  bag       { egg, milk, pork },
  buildings [ { id, level } ],
  animals   [ { id, species, name, buildingId, hunger, happiness, health, progress } ],
  settings  { sound, music, vibration, reminders }
}
```

- Write to a temp file, then rename, so a crash cannot corrupt the save.
- Save **2 s after any change**, when the app goes to the background, and on **Settings > Save now**.
- Keep one previous backup.
- Include `version` from day one and migrate older files forward. Preserve unknown fields (future traits, rarity).
- A damaged save offers "Start new farm" behind a confirm dialog and keeps the old file as a backup.
- Save failure: a non-blocking banner, auto-retry at 5 s, 15 s, 60 s, and play continues.

**Reminders.** The Settings toggle "gentle reminders" exists and defaults to **off**. No reminder content or schedule is defined in the approved design.

---

## 10. Future features

> Everything in this section is **Future / Not MVP**. None of it may be built or shown in MVP UI. The approved design only reserves room for it, and the rule is: a future feature may **add** a slot, chip, ring or tab, but may never move an MVP button.

| Feature | Reserved room in the MVP layout |
|---|---|
| Breeding | A 56 dp row below the Feed/Collect buttons on Animal Details; a "Breed" ghost button appears only when two eligible animals share a building. Result is an egg or baby with a hatch animation no longer than 1.2 s |
| Genetics and traits | A reserved 160 dp block under the Production card on Animal Details (hidden in MVP). Traits are tags, stats use the existing status bars, appearance uses color dots. No new component types |
| Rare animals and rarity | 3 dp rarity ring around portraits and a badge on animal cards. Proposed colors: Common #7A6A52, Uncommon #26803A, Rare #8A5A00, Legendary #8A63D9 |
| Collection | A Collection grid under a hidden fifth "More" nav slot (78 dp). Undiscovered animals shown as dim silhouettes. An Animals-list chip lane that scrolls horizontally |
| Variants | A color-dot variant picker row between description and price in the Buy dialog |
| Quests | A 36 dp chip lane below the HUD on the Farm screen; a right-edge rail above Collect-all can take one floating action |
| Events | A fourth Market segment ("Special") by switching to a scrollable tab row; one event offer card above the products list; rewards through the existing Offline Reward modal. Guidance uses the info-blue tooltip, completion uses the toast. No new modal types |
| Sickness and low health | The status language reserves a pale tint, sleepy eyes and dashed heart bubble |
| Premium currency | Gem color #24B8C9 and icon defined, hidden |

**Data model readiness.** The save format already carries `version`, `buildingId`, and per-animal `health`, and the loader preserves unknown fields, so future fields do not require a migration rewrite.
