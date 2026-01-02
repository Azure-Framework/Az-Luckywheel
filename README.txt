# Az-Slots – Diamond Casino Style Slot Machines (FiveM)

Lightweight, lore-friendly slot machines for the Diamond Casino.  
Auto-detects casino slot props, spins real reel models, evaluates wins server-side, and shows a custom **Diamond Casino–style win/loss/jackpot notification UI**.

---

## Features

- Auto-detects Diamond Casino slot machines  
  - Finds world objects using the models listed in `config.lua`.

- Immersive interaction
  - `E` near a machine to sit.
  - `SPACE` to spin.
  - `BACKSPACE` to stand up.

- Real reel props
  - Spawns the correct reel prop per machine (e.g. `vw_prop_casino_slot_02a_reels`).
  - Spins each reel individually; if reels are missing, the machine simply won’t spin that session.

- Server-side win logic
  - Three random stops (0–`Config.ReelStops - 1`) rolled on the server.
  - Evaluates:
    - Any 2-of-a-kind = small win (configurable).
    - Any 3-of-a-kind = bigger win (configurable).
    - Cherries have boosted payouts.
    - Dedicated jackpot symbol with large 3-of-a-kind payout.
    - Diamond symbols act as **overlay multipliers**.
    - Multiple wins stack (e.g. cherries + diamonds).
  - Results are sent back to the client for animation only; players cannot fake outcomes.

- Az-Framework economy
  - Uses `Az-Framework`’s `addMoney` / `deductMoney` exports.
  - No items, no inventory; purely balance-based.

- Diamond Casino notification UI
  - Custom HTML/CSS/JS NUI in `html/index.html`.
  - Notifications appear **middle-left** of the screen.
  - They slide in from the left, sit for a few seconds, then slide out to the left.
  - Distinct visual variants for:
    - Normal win
    - Loss
    - Jackpot
  - Shows: bet amount, payout, total multiplier, and a text breakdown of how you won.

- Payout after notification
  - Server **does not add money** immediately.
  - It waits for the client to finish reels + show the NUI notification, then pays winnings.
  - This keeps sounds, animation, UI, and balance change nicely in sync.

- `/slotsrules` command
  - `/slotsrules` prints a readable explanation of rules and multipliers into chat.

---

## Requirements

- A FiveM server.
- Diamond Casino interior loaded (default GTA interior or a map that keeps the casino).
- `Az-Framework` resource running (or you can adapt the economy integration).

---

## Installation

1. Drop the resource

   - Place the folder into your resources directory as:

     - `resources/[casino]/az_slots`  
       (or any category you like; folder itself must be `az_slots`)

2. Ensure it in `server.cfg`

   - Add:

     - `ensure az_slots`

3. Make sure the casino exists

   - If you run maps or IPL managers that disable interiors, confirm the Diamond Casino is active.
   - Any world object whose model hash is listed in `Config.MachineModels` becomes a playable machine.

4. Check Az-Framework

   - Ensure `Az-Framework` is running before `az_slots`.
   - This script calls:
     - `exports['Az-Framework']:deductMoney(src, amount)`
     - `exports['Az-Framework']:addMoney(src, amount)`

---

## Usage / Controls

- Walk near a Diamond Casino slot machine model defined in `Config.MachineModels`.
- When the help text appears above the minimap:
  - Press `E` → sit down.
- While seated:
  - Press `SPACE` → spin the reels.
  - Press `BACKSPACE` → stand up and leave.
- In chat:
  - `/slotsrules` → prints the rules and multipliers.

---

## Economy Integration (Az-Framework)

The server handles money **only** via Az-Framework exports:

- `takeBet(src, amount)` calls `fw:deductMoney(src, amount)`.
- `payWinnings(src, amount)` calls `fw:addMoney(src, amount)`.

If you want to adapt to another framework:

1. Open `server.lua`.
2. Replace `fw:deductMoney(src, amount)` with your equivalent, e.g.:
   - QBCore: `Player.Functions.RemoveMoney('cash', amount)`
   - ESX: `xPlayer.removeMoney(amount)`
3. Replace `fw:addMoney(src, amount)` similarly with your own add-money calls.
4. Keep the function signatures the same so the rest of the logic does not need to change.

> Note: There is **no items/chips system** in this script. Bets and payouts are pure money.

---

## Game Logic / Payouts

### Reel Stops

- Each spin rolls three integers (stops) on the server:
  - `0` through `Config.ReelStops - 1` (default 16).
- These indices are used both:
  - For evaluating the result (which symbol).
  - For picking the physical reel slice to show.

### Diamonds Overlay

- Configured in `config.lua`:

  - `Config.DiamondSymbols` → the stop indices considered “diamond” symbols (e.g. `{ 4, 11 }`).
  - `Config.DiamondReward`:
    - `[1] = multiplier for having 1 diamond somewhere`
    - `[2] = multiplier for 2 diamonds`
    - `[3] = multiplier for 3 diamonds`

- These multipliers are **added** on top of any other wins.

  Example:  
  - 3 cherries → x8.0  
  - 1 diamond → +x1.0  
  - Total multiplier = x9.0, so payout = `bet * 9.0`.

### 2-of-a-kind & 3-of-a-kind

- `Config.TwoOfKindDefault` – base multiplier for any 2-of-a-kind (non-diamond).
- `Config.ThreeOfKindDefault` – base multiplier for any 3-of-a-kind (non-diamond).
- Overrides:

  - `Config.TwoOfKind[index]` – special 2-of-a-kind multiplier for that symbol.
  - `Config.ThreeOfKind[index]` – special 3-of-a-kind multiplier for that symbol.

- Cherries are configured to pay extra:
  - 2 cherries → slightly higher than default.
  - 3 cherries → acts as a mini-jackpot (large multiplier).
- Jackpot symbol has the largest 3-of-a-kind multiplier.

### Evaluation Summary (server.lua)

1. Count how many times each index appears in the 3 stops.
2. Count diamonds and add the diamond overlay multiplier if present.
3. For each non-diamond symbol:
   - If it appears 3 times, add either `Config.ThreeOfKind[index]` or default.
   - If it appears 2 times, add either `Config.TwoOfKind[index]` or default.
4. Sum all multipliers into `totalMult`.
5. If `totalMult <= 0`, payout = 0.
6. Otherwise, `payout = floor(bet * totalMult)`.
7. Payout is **only paid after the client finishes animating and showing the NUI notification**.

The server passes back:

- `reels` (the 3 stops),
- `bet`,
- `payout`,
- `multiplier`,
- `details` (e.g. `"Three Cherries (x8.0)"`, `"Diamonds x2 (x3.5)"`).

The client uses these for UI only.

---

## Diamond Casino Notification UI

### Location & Animation

- Located in `html/index.html`.
- The root notification stack is positioned:

  - Middle-left area of the screen.
  - Using `position: fixed` and percentages.

- Each notification:
  - Slides in from the left toward the center.
  - Sits for several seconds (`LIFETIME` constant in JS).
  - Slides back out to the left before being removed.

### Behavior

- The client receives the spin result from the server.
- Once reel spin animations finish, the client builds a data payload:

  - `type` – `"win"`, `"loss"`, or `"jackpot"`.
  - `amount` – payout (0 for loss).
  - `bet` – current bet.
  - `multiplier` – total multiplier from the spin.
  - `details` – list of human-readable win components.

- The client calls:

  - `SendNUIMessage({ action = "slots_notify", ... })`

- The NUI JS listens for `message` events and, when `action === "slots_notify"`, creates a toast card using the configured styling.

- Win tiers:
  - `type = "loss"` if payout <= 0.
  - `type = "jackpot"` if multiplier >= some high threshold (e.g. 25x).
  - Otherwise `type = "win"`.

### Visual Customization

In `html/index.html`:

- The main classes to tweak:

  - `.slots-root` – position, stacking behavior.
  - `.slot-toast` – glass card, border, background gradients, blur, radius.
  - `.slot-toast--win`, `.slot-toast--loss`, `.slot-toast--jackpot` – per-state colors and glow.
  - `.slot-icon` – icon circle (★ / ✖ / ♦).
  - `.slot-title`, `.slot-pill`, `.slot-mainline`, `.slot-details`, `.slot-amount` – typography.

- Animation keyframes:

  - `@keyframes slot-enter` – slide-in from the left.
  - `@keyframes slot-exit` – slide-out to the left.

To tweak timings:

- Adjust `LIFETIME` (ms) in the script section to make notifications stay longer/shorter.
- Adjust animation durations in `slot-enter` / `slot-exit` keyframes and the CSS `animation` values.

---

## Client Script (client.lua) Overview

The key responsibilities of `client.lua`:

- Maintains the list of discovered machines (by model hash).
- Handles sitting/standing and help prompts.
- Spawns reel props and animates their rotations.
- Plays local audio using the correct audio set per machine.
- Sends spin requests to the server.
- Receives spin results and:
  - Spins reels to their stop positions.
  - Determines win tier (loss / win / jackpot) from `payout` and `multiplier`.
  - Sends NUI notification.
  - Plays win/loss/jackpot sounds.

It also registers:

- `RegisterNetEvent("az_slots:spinResult", ...)` – to handle results.
- `RegisterNetEvent("az_slots:spinDenied", ...)` – for not enough money / bad machine / bad bet.
- `RegisterCommand("slotsrules", ...)` – prints rules in chat.

---

## Server Script (server.lua) Overview

The server:

- Validates that the machine model exists in `Config.MachineModels`.
- Clamps/validates the bet using `Config.MinBet` and `Config.MaxBet`.
- Attempts to deduct the bet via `Az-Framework` (`deductMoney`).
- Rolls random stops within `Config.ReelStops`.
- Evaluates the result using the configurable payout rules.
- Logs the spin result to server console (useful for tuning).
- Sends the result to the client.
- Pays winnings **after** the notification flow (based on the design change) so that the balance update matches the visible notification.

---

## `/slotsrules` Command

The command:

- Reads values from config:

  - `Config.TwoOfKindDefault`
  - `Config.ThreeOfKindDefault`
  - `Config.DiamondReward`

- Prints a concise breakdown to chat:

  - Any 2-of-a-kind → approximate multiplier.
  - Any 3-of-a-kind → larger multiplier.
  - Special notes for cherries, jackpot symbols, and diamonds.
  - Reminder that multiple wins stack.
  - Control hints: `E` sit, `SPACE` spin, `BACKSPACE` stand.

This is purely client-side and always available.

---

## How To Edit / Extend

### Change Bet Sizes

- In `config.lua`:

  - Global min/max:
    - `Config.MinBet`
    - `Config.MaxBet`
  - Per machine:
    - `Config.MachineModels[model].bet`

### Add or Remove Machines

- In `config.lua`, add another entry to `Config.MachineModels` with:

  - `name` – display name.
  - `model` – hash of the world prop.
  - `reelModel` – reel prop model.
  - `bet` – default bet.

- On next script restart, the script will discover any matching objects in the world and make them playable.

### Adjust Payout Balance

- In `config.lua`:

  - `Config.DiamondSymbols` / `Config.DiamondReward` – diamond overlay.
  - `Config.TwoOfKindDefault` / `Config.ThreeOfKindDefault` – baseline multipliers.
  - `Config.TwoOfKind` – per-symbol overrides (2-of-a-kind).
  - `Config.ThreeOfKind` – per-symbol overrides (3-of-a-kind).

Tighten or loosen the math by tweaking these multipliers.

### Customize Notification Look

- Edit `html/index.html`:

  - Position / stacking: `.slots-root`.
  - Card look: `.slot-toast`, `.slot-toast--win`, `.slot-toast--loss`, `.slot-toast--jackpot`.
  - Icons / titles / text in JS section (e.g. change from `The Diamond` to your server name).
  - Lifetime: `LIFETIME` constant (ms) in the script.

Then restart the resource.

---

## Notes / Troubleshooting

- No notifications:
  - Ensure `fxmanifest.lua` includes `ui_page "html/index.html"` and the HTML/CSS/JS files as `files`.
  - Check F8 console for NUI errors.
- Machines not interactable:
  - Confirm the prop hashes actually match `Config.MachineModels`.
  - Use a simple debug script to print entity model hashes in the casino if needed.
- Never winning:
  - Check server console; you should see logged spin results.
  - Adjust multipliers in `config.lua` to be more generous while testing.
- Money not changing:
  - Ensure `Az-Framework` is running and the exports exist.
  - If you swapped to another framework, double-check your replacement functions in `server.lua`.

---

Enjoy your Diamond Casino experience. 🎰  
All logic is Az-Framework focused and framework-agnostic enough that you can swap economy and tweak payouts without touching the core spin system.
