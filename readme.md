# Az-LuckyWheel – Diamond Casino Lucky Wheel (FiveM)

Lore-friendly **Diamond Casino Lucky Wheel** for your FiveM server.  
Spawns the wheel & podium car, adds a chip **cashier NPC**, handles all prize logic server-side, and uses a **Diamond Casino–style notification UI** for spins and chip cash-outs.

---

## Features

- **Diamond Casino Lucky Wheel**
  - Spawns the wheel prop at `Config.WheelCoords`.
  - Smooth client-side spin animation to the **exact prize index** chosen by the server.
  - Uses Rockstar’s Diamond Casino wheel animations for the player.

- **Podium / jackpot vehicle**
  - Displays an invincible vehicle on the podium at `Config.ShowCarPlatform`.
  - Jackpot prize (`type = "vehicle"`) can use:
    - A fixed model from `Config.Prizes`, **or**
    - The **current podium model** if `vehicle = nil`.
  - Prize vehicle spawns for the winner at `Config.PrizeVehicleSpawn`.

- **Chips & cashier NPC**
  - Wheel can award **chips** instead of pure cash.
  - Chips are stored in **resource KVP**, keyed by the player’s license.
  - A dedicated **cashier NPC** at `Config.ChipNPC.coords`:
    - Walk up and press **E** → cash out all chips.
    - Converts chips → cash using `Config.ChipCashRate`.
    - NPC plays a short “cheer” reaction before returning to idle.

- **Server-side prize logic**
  - Server chooses a **weighted prize index** from `Config.Prizes`.
  - Prizes support:
    - `money` – direct Az-Framework cash.
    - `chips` – add to KVP chip balance.
    - `vehicle` – jackpot car.
    - `item` – hook into your inventory for tokens/loot.
  - Only the index + label go to the client for animation; outcome can’t be faked.

- **Spin cooldown & cost**
  - `Config.SpinCooldown` (seconds) between spins per player.
  - `Config.SpinCost` per spin (0 = free wheel).

- **Az-Framework economy**
  - Uses `Az-Framework`’s `addMoney` / `deductMoney` exports.
  - All cash changes (spin cost, cash prizes, chip redemption) flow through Az-Framework.

- **Diamond Casino notification UI**
  - Custom HTML/CSS/JS NUI in `html/index.html`.
  - Notifications appear **middle-left** of the screen, sliding in from the left and back out.
  - Variants for:
    - Normal win (cash / chips / item).
    - Loss / denied (cooldown, no funds).
    - Jackpot (vehicle).
    - Chip cash-out.
  - Shows: prize label and **balance change**.
  - Special handling for Lucky Wheel so you **don’t** see “you won $0 on a $0 spin”.

---

## Requirements

- A FiveM server.
- Diamond Casino interior loaded (default GTA interior or a map that keeps the casino).
- `Az-Framework` running (or adapt the money functions).

---

## Installation

1. **Drop the resource**
   Place in your resources directory, for example:
   `resources/[casino]/az_luckywheel`

2. **Ensure it in `server.cfg`**
   ensure Az-Framework  
   ensure az_luckywheel

3. **Configure positions (config.lua)**
   - `Config.WheelCoords` – wheel object position.  
   - `Config.WheelHeading` – wheel heading.  
   - `Config.PlayerStandPos` / `Config.PlayerStandHeading` – where the player stands during the spin animation.  
   - `Config.ShowCarPlatform` – podium display position for the showcase vehicle.  
   - `Config.PrizeVehicleSpawn` – where the winner’s vehicle actually spawns.  
   - `Config.ChipNPC` – chip cashier NPC model + coords.

4. **Check Az-Framework**
   Ensure `Az-Framework` is started **before** `az_luckywheel` and exposes:
   - `exports['Az-Framework']:addMoney(src, amount)`  
   - `exports['Az-Framework']:deductMoney(src, amount)`

---

## Usage / Controls

### Lucky Wheel
- Walk near the wheel at `Config.WheelCoords`.
- When the on-screen help text appears:
  - Press **E** → request a spin.

The script:
1. Sends `az_luckywheel:requestSpin` to the server.  
2. Server validates cooldown / cost and chooses a prize index.  
3. Client plays animation, spins the wheel prop, and plays sound.  
4. After spin, client notifies the server to confirm the prize.  
5. Server applies the reward and pushes a Diamond-style toast.

### Cashier NPC (chip cash-out)
- Walk to the cashier NPC at `Config.ChipNPC.coords`.  
- When the 3D text appears, press **E** → cash out all chips.

Server:
- Reads your chip KVP (`chips:<license>`).  
- Converts chips → cash using `Config.ChipCashRate`.  
- Resets chip balance to 0 and adds cash via Az-Framework.  
- NPC plays cheer animation and UI shows a “cash-out” toast.

---

## Economy Integration (Az-Framework)

All cash changes use Az-Framework:

- Spin cost → `fw:deductMoney(src, Config.SpinCost)`  
- Cash prizes / chip redemption → `fw:addMoney(src, amount)`  
- Chips are stored as KVP integers, not items.

If using another framework, replace those calls with your equivalents.

---

## Config & Prize Logic

### Wheel / Player / NPC Setup
- Wheel: `Config.WheelCoords  = vector3(977.97, 50.3, 73.97)`  
- Player Stand: `Config.PlayerStandPos = vector3(976.974, 50.331, 74.681)`  
- Podium: `Config.ShowCarPlatform = vector4(963.847, 47.632, 75.568, 201.719)`  
- Prize Vehicle Spawn: `Config.PrizeVehicleSpawn = vector4(920.887, 53.165, 80.894, 330.512)`  
- Chip Rate: `Config.ChipCashRate = 1` (1 chip = $1)  
- Cashier NPC: `Config.ChipNPC = { coords = vector4(977.891, 38.230, 74.882, 38.522), pedModel = "s_m_y_casino_01" }`

### Spin cost & cooldown
- `Config.SpinCooldown = 60` (seconds)  
- `Config.SpinCost = 0` (free spin)

### Prize Table
| Index | Label | Type | Value | Weight |
|-------|--------|------|--------|--------|
| 1 | $5,000 Cash | money | 5000 | 40 |
| 2 | Small Chips (1,000) | chips | 1000 | 35 |
| 3 | Medium Chips (5,000) | chips | 5000 | 25 |
| 5 | Bonus Cash ($1,000) | money | 1000 | 30 |
| 6 | $10,000 Cash | money | 10000 | 25 |
| 7 | Vehicle Token (Small) | item | veh_token_s | 8 |
| 9 | Bonus Chips (2,000) | chips | 2000 | 30 |
| 10 | Big Chips (15,000) | chips | 15000 | 10 |
| 11 | $25,000 Cash | money | 25000 | 8 |
| 12 | Bonus Cash ($3,000) | money | 3000 | 30 |
| 14 | Small Cash ($2,500) | money | 2500 | 40 |
| 15 | Medium Chips (8,000) | chips | 8000 | 20 |
| 16 | Bonus Chips (4,000) | chips | 4000 | 30 |
| 18 | JACKPOT VEHICLE | vehicle | nil | 1 |
| 19 | Big Cash ($50,000) | money | 50000 | 4 |
| 20 | Huge Chips (20,000) | chips | 20000 | 30 |

Weights affect rarity. Type “vehicle” will spawn the podium car if no model defined.

---

## Notification UI

- HTML/CSS/JS located in `html/index.html`.  
- Toasts appear middle-left.  
- Uses Diamond slot toast visuals.  
- Wheel results display clean labels like “Lucky Wheel: $10,000 Cash”.  
- Cashier redemption shows “Cashed out 5,000 chips for $5,000”.

---

## Client Script Overview

- Spawns wheel prop, podium car, and NPC.  
- Manages help prompts and input (E to spin, E to cash out).  
- Plays native casino wheel animations + sounds.  
- Sends `requestSpin` and `confirmPrize` events.  
- Handles `spinDenied`, `spinResult`, `npcReact`.  
- Controls NUI notifications.

---

## Server Script Overview

- Validates spin cooldowns and cost.  
- Picks prize index by weighted random.  
- Logs results server-side for tuning.  
- Handles each prize type:
  - money → Az-Framework addMoney
  - chips → KVP increment
  - vehicle → spawn event
  - item → external inventory event
- Redeems chips → cash with rate conversion.  
- Triggers `npcReact` for the cashier ped.

---

## Notes / Troubleshooting

- **Wheel not spinning?**  
  Ensure wheel entity and heading match Diamond Casino interior props.

- **No UI notifications?**  
  Verify NUI files listed in `fxmanifest.lua` and no console errors.

- **No casino interior?**  
  Enable default GTA V IPLs for Diamond Casino.

- **Chips not saving?**  
  Check KVP keys persist with correct license identifier.

- **Podium car missing?**  
  Validate `Config.ShowCarPlatform` coords and ensure model loads properly.

---

Enjoy your Diamond Casino Lucky Wheel experience. 🎡  
Fully integrated with **Az-Framework**, optimized, and fully lore-friendly.
