# Bridger: Western (BW) — Game Architecture & Client Control Specification
> **Audience**: AI Coding Assistants & Script Developers  
> **Target Environment**: Roblox (Luau Client / Executor Context)  
> **Game Title**: *Bridger: Western* (abbreviated *BW*)  
> **Scope**: Pure game-native structures, remotes, input handling, and entity lifecycles. Zero custom/third-party script features included.

---

## 1. Top-Level Game Architecture & Framework

*Bridger: Western* is structured around a centralized framework located in `ReplicatedStorage`:
```
ReplicatedStorage/
├── WesternFramework/
│   └── Shared/
│       └── Remotes/
│           └── SpawnPlayerEvent (RemoteEvent)
└── Modules/
    ├── CoreModules/
    │   └── InputHandlerClient (ModuleScript)
    ├── CoreGunClientModule (ModuleScript)
    └── HorseController (ModuleScript)
```

### Auto-Spawn Remote
When a player is on the main menu, the client spawns into the game via:
```lua
local RS = game:GetService("ReplicatedStorage")
local wf = RS:FindFirstChild("WesternFramework")
local remotes = wf and wf:FindFirstChild("Shared") and wf.Shared:FindFirstChild("Remotes")
local spawnEv = remotes and remotes:FindFirstChild("SpawnPlayerEvent")

if spawnEv then
    spawnEv:FireServer()
end
```
Alternatively, the client menu button is at:
`Players.LocalPlayer.PlayerGui.MainMenu.ButtonContainer.PlayButton` (activatable via its `MouseButton1Click` connections).

---

## 2. Input Handler Client (`InputHandlerClient`)

All official gameplay actions in Bridger: Western are managed by `ReplicatedStorage.Modules.CoreModules.InputHandlerClient`.

### Module Access
```lua
local RS = game:GetService("ReplicatedStorage")
local InputHandler = require(RS.Modules.CoreModules.InputHandlerClient)
```

### Virtual Input API
The module provides a method `FireVirtualInput(alias: string, state: boolean)`:
```lua
-- Press an input:
InputHandler:FireVirtualInput(alias, true)

-- Release an input:
InputHandler:FireVirtualInput(alias, false)
```

### Known Input Aliases
| Alias | Associated Key / Action | Description |
| :--- | :--- | :--- |
| `"PrimaryInput"` | Left Mouse Button | Fire weapon / Cast fishing rod / Strike bite / Reel |
| `"SecondaryInput"` | Right Mouse Button | Aim down sights (ADS) |
| `"ActionInput2"` | `E` key (Windows VK `0x45`) | Interact, mount/dismount, reload, cock firearm |
| `"HorseCallInput"` | `H` key | Whistle for / summon horse |
| `"JumpInput"` | `Space` key | Humanoid jump / horse hurdle |

### Fallback Input (Engine Level)
For direct engine inputs, use `VirtualInputManager`:
```lua
local VIM = game:GetService("VirtualInputManager")

-- Send Key:
VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
task.wait(0.05)
VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)

-- Send Mouse Click:
VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
task.wait(0.05)
VIM:SendMouseButtonEvent(ml.X, ml.Y, 0, false, game, 0)
```

---

## 3. Weapon System (`CoreGunClientModule`)

Bridger: Western utilizes a hybrid hitscan/projectile ballistic engine.

### Weapon Tools & Hierarchy
All firearms are Roblox `Tool` instances located in `LocalPlayer.Backpack` or inside `LocalPlayer.Character` when equipped.

```
Tool (e.g. "Martini Henry", "Colt", "Repeater")
├── ServerConfig (ModuleScript)  <-- Vital: contains weapon attributes
├── AmmoInClip (IntValue / ValueBase)
└── Handle (BasePart)
```

#### Weapon Visual Models
When a firearm is equipped, the game renders a cosmetic model in the character:
`Character:FindFirstChild("Visual_" .. weaponName)` or `Character:FindFirstChildWhichIsA("Model")`.
- **Muzzle / Barrel Position**: Inside this visual model, look for:
  `vis:FindFirstChild("Barrel", true)`
  - If it is an `Attachment`: use `Barrel.WorldPosition`
  - If it is a `BasePart`: use `Barrel.Position`

#### `ServerConfig` Properties
Requiring `ServerConfig` returns a Luau dictionary containing exact weapon physics:
```lua
local cfg = require(tool.ServerConfig)

cfg.FireRate          -- Rate of fire in seconds between shots
cfg.Range             -- Maximum bullet distance (e.g. 215 studs, or 5000 for snipers)
cfg.FireType          -- "Projectile" or "Raycast" / hitscan
cfg.ProjectileSpeed   -- Muzzle velocity (e.g. 1150 studs/second)
cfg.ProjectileGravity -- Bullet drop multiplier (e.g. 0.08)
```

### Gun Client Networking & Firing Hook
The gun client is driven by `ReplicatedStorage.Modules.CoreGunClientModule`.

#### Extracting the Network Table
In `CoreGunClientModule.Equip`, an internal upvalue holds the table responsible for dispatching shots to the server:
```lua
local gunMod = require(RS.Modules.CoreGunClientModule)
local equipFn = gunMod.Equip

-- Inspect upvalues of Equip:
local uvs = debug.getupvalues(equipFn)
for _, uv in pairs(uvs) do
    if typeof(uv) == "table" and typeof(rawget(uv, "FireServer")) == "function" then
        -- This table wraps the server remote!
        local networkTable = uv
        local oldFire = uv.FireServer
        
        -- Signature of FireServer:
        -- networkTable:FireServer(action, targetWorldPos, isAiming, ...)
        -- action: "Fire"
        -- targetWorldPos: Vector3
        -- isAiming: boolean
    end
end
```

### Character Combat Attributes
Characters expose state attributes readable via `Character:GetAttribute(...)`:
| Attribute | Type | Description |
| :--- | :--- | :--- |
| `IsReloading` | `boolean` | True when the player is playing a reload animation |
| `IsKnockedDown` | `boolean` | True when player is downed / incapacitated |
| `IsRagdolled` | `boolean` | True when player is in a ragdoll physics state |

---

## 4. Horse System (`HorseController`)

Horses are autonomous entity models replicated in `workspace.Entities`.

### Identifying Your Horse
Iterate `workspace.Entities` to identify the local player's horse:
```lua
local function getMyHorse()
    local entities = workspace:FindFirstChild("Entities")
    if not entities then return nil end
    local LP = game:GetService("Players").LocalPlayer

    for _, e in ipairs(entities:GetChildren()) do
        -- Check Owner ObjectValue:
        local o = e:FindFirstChild("Owner")
        if o and (o.Value == LP or o.Value == LP.Name or tostring(o.Value) == tostring(LP.UserId)) then
            return e
        end
        -- Check Owner Attributes:
        local attr = e:GetAttribute("Owner") or e:GetAttribute("OwnerUserId") or e:GetAttribute("OwnerName")
        if attr and (attr == LP.Name or attr == LP.UserId or tostring(attr) == tostring(LP.UserId)) then
            return e
        end
    end
    return nil
end
```

### Horse Root & Anatomy
- **Root Part**: `horse:FindFirstChild("HumanoidRootPart")`
- **Mount Prompt**: A `ProximityPrompt` child inside the horse model.

### Checking Riding State
The game sets several state flags when a player is mounted:
1. `Humanoid.SeatPart ~= nil` (the saddle seat).
2. Character Attributes:
   - `Character:GetAttribute("IsRiding") == true`
   - `Character:GetAttribute("Mounted") == true`
   - `Character:GetAttribute("Horse") ~= nil`
3. Horse Attributes:
   - `horse:GetAttribute("Rider") == LP.Name`
   - `horse:GetAttribute("RiderUserId") == LP.UserId`
4. Physical Welds:
   - A `SeatWeld` inside `Humanoid.SeatPart`, or `Weld` / `Motor6D` instances connecting Character limbs to the horse.

### Mounting & Dismounting Controls
- **To Mount**: Approach within 6 studs and fire the `ProximityPrompt` on the horse.
- **To Dismount**:
  1. Fire `InputHandler:FireVirtualInput("ActionInput2", true)` and `false` (Primary Interact).
  2. Send key `E` (VK `0x45`) and `Space` (VK `0x20`).
  3. Set `Humanoid.Sit = false` and `Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)`.
  4. Break `SeatWeld` inside `Humanoid.SeatPart` if stubborn.

### Summoning / Toggling Horse
The horse whistle remote is located in `ReplicatedStorage.Modules.HorseController.Init`:
```lua
local hc = require(game:GetService("ReplicatedStorage").Modules.HorseController)
local uvs = debug.getupvalues(hc.Init)
for _, uv in pairs(uvs) do
    if typeof(uv) == "table" and typeof(rawget(uv, "FireServer")) == "function" then
        -- Calling FireServer() here toggles / calls the horse to player location
        uv:FireServer()
        break
    end
end
```

---

## 5. Fishing System

Fishing in Bridger: Western utilizes animation states, sound cues, and QTE minigames.

### Fishing Rod Tool & Casting Mechanics
- **Tool Name**: `FishingRod` (in Character or Backpack).
- **Casting the Line**:
  1. Character must NOT be seated/mounted on a horse.
  2. Character and Camera must face the water (detected via `Raycast` where `hit.Material == Enum.Material.Water` or name contains `"water"`).
  3. **Crucial**: Casting is a **charged throw**. Simply tapping `PrimaryInput` for < 0.1s will not launch the line. You must hold `PrimaryInput` (or Left Mouse Button) for `~0.35s` then release.

### Animation IDs (Roblox Asset IDs)
The player's `Humanoid.Animator:GetPlayingAnimationTracks()` emits specific asset IDs:
| Animation Asset ID | State | Description |
| :--- | :--- | :--- |
| `99374973462906` | `SwingRod` | Playing during the physical cast swing |
| `99032819855540` | `RodIdle` | Playing while the line is in the water awaiting a bite |
| `85381268135994` | `ReelLoop` | Playing while line is actively reeling in |
| `98675703339517` | `BringBack` | Played if cast is yanked back early or fails |
| `124675900911926` | `Success` | Played when a fish is caught |

### Verifying Active Cast
When the line is successfully in the water:
1. Animation track `99032819855540` (`RodIdle`) or `99374973462906` (`SwingRod`) is active.
2. The rod tool spawns or enables a `RopeConstraint`, `RodConstraint`, or `Beam`.
3. A `Bobber` part is extended out into the water (> 6 studs from the player).

### Bite Detection
When a fish bites the line, the game produces a spatial audio cue:
- A `Sound` instance named `"FishBite"` or `"BiteCrunch"` plays inside a BasePart within 200 studs in `workspace`.
- Striking immediately upon this sound via `PrimaryInput` hooks the fish.

### Fishing QTE Minigames
When a fish is hooked, the client triggers a QTE interface:
- **GUI Hierarchy**: `Players.LocalPlayer.PlayerGui.MashingSystem`
- **Player Attributes**:
  - `LP:GetAttribute("IsMashing") == true`
  - `LP:GetAttribute("IsShaking") == true`
  - `LP:GetAttribute("IsReacting") == true`
- **Key Prompt**:
  `PlayerGui.MashingSystem.Container.Circle.KeyLabel.Text` contains the key to mash (default is `'G'`, VK `0x47`).

---

## 6. NPC Interaction, Dialogue & Economy

### NPC World Objects
NPCs (e.g. Daniel the Fish Buyer / Bait Merchant, Mud Witch) reside in:
- `workspace.NPC` or `workspace.Entities`
- Contain a `ClickDetector` to trigger interaction:
  ```lua
  fireclickdetector(npc:FindFirstChildOfClass("ClickDetector"))
  ```

### Dialogue GUI Structure
When an NPC is engaged, the game opens `Players.LocalPlayer.PlayerGui.DialogueGui`:
```
PlayerGui/
└── DialogueGui/
    └── MainFrame/
        ├── NPCText (TextLabel)       <-- Current speech text from NPC
        ├── ChoiceList (Frame)        <-- Container of response options
        │   ├── TemplateButton (TextButton, hidden)
        │   └── <OptionButton> (TextButton, visible)
        └── CloseButton / ExitButton
```
- **Selecting Dialogue**: Fire the `MouseButton1Click` connection on the desired `TextButton` inside `ChoiceList`.
- **Closing Dialogue**: Select options containing farewell text (e.g. "Bye", "Thanks", "Later", "Nevermind").

### Currency & Moola
The player's money count is rendered in:
`Players.LocalPlayer.PlayerGui.MoolaCount`
- Value label: `MoolaCount:FindFirstChild("CoinAmount", true)`
- Format: Text string with suffixes (e.g. `"500"`, `"1.2K"`, `"2.5M"`).

---

## 7. Inventory & Stack Data Conventions

Items in `LocalPlayer.Backpack` and `Character` follow these native conventions:
- **Quantity Suffix**: Stackable tools append their quantity in parentheses:
  `"Bait (15)"`, `"AmmoPack (3)"` -> extract with regex pattern `%(%d+%)`.
- **Quantity Attributes**: Tools often contain attributes:
  `tool:GetAttribute("Amount")` or `"Quantity"` / `"Count"`.
- **Quantity ValueBases**: Tools may contain an `IntValue` child named `"Amount"` or `"Quantity"`.

---

## 8. World Spawns & Lootables

### Workspace Organization
| Container | Description |
| :--- | :--- |
| `workspace.Entities` | Players, horses, animals, and moving entities |
| `workspace.NPC` | Dialogue NPCs and vendors |
| `workspace.Chests` | Interactive loot chests (contain `ProximityPrompt`) |
| `workspace.SpawnedHerbs` | Harvestable plants (e.g. `Dogbane Herb`, contain `ProximityPrompt`) |
| `workspace.Effects` | Transient visual particles and temporary parts |
| `workspace.MouseIgnore` | Transparent visual barriers and camera colliders |
| `workspace.ProjectileContainer` | Active in-flight bullets and arrows |

### Saint Corpse Parts
Corpse parts are special event items:
- **Naming**: BasePart names begin with `"Saints"` (e.g. `SaintsHeart`, `SaintsLeftEye`).
- **Interaction**: Contain a `ProximityPrompt` (hold `E` to grab).
- **Attributes**:
  - Part Attribute: `part:GetAttribute("BeingPickedUp")`
  - Character Attribute: `char:GetAttribute("HasCorpsePart")`
- **Global Announcement**: Text banner appears in `PlayerGui` containing `"IT APPEARS ONCE AGAIN"`.

---

## 9. Client Security & Anti-Cheat Environment (Adonis In-Depth)

The client environment incorporates a customized **Adonis AntiCheat** implementation. Handling it incorrectly leads to immediate client termination (`Crash: Anti-Cheat Tamper` or `Kicked: Unexpected Client State`).

### The Raw Adonis Bypass (The Golden Rule)
At the absolute top of any bundled script, the raw base bypass must execute **unmodified, un-pcalled, and without asynchronous wrapping**:

```lua
-- ── ADONIS ANTICHEAT BYPASS (RAW & UN-PCALLED) ─────────────────────────────
do
    local getinfo = getinfo or debug.getinfo
    local DEBUG = false
    local Hooked = {}
    local Detected, Kill

    setthreadidentity(2)

    for i, v in getgc(true) do
        if typeof(v) == "table" then
            local DetectFunc = rawget(v, "Detected")
            local KillFunc = rawget(v, "Kill")

            if typeof(DetectFunc) == "function" and not Detected then
                Detected = DetectFunc
                local Old; Old = hookfunction(Detected, function(Action, Info, NoCrash)
                    if Action ~= "_" then
                        if DEBUG then warn(`Adonis AntiCheat: {Action}`) end
                        return true
                    end
                    return Old(Action, Info, NoCrash)
                end)
                table.insert(Hooked, Detected)
            end

            if typeof(KillFunc) == "function" and not Kill then
                Kill = KillFunc
                local Old; Old = hookfunction(Kill, function(Info)
                    if DEBUG then warn(`Adonis AntiCheat: {Info}`) end
                    return true
                end)
                table.insert(Hooked, Kill)
            end
        end
    end

    hookfunction(getrenv().debug.info, newcclosure(function(...)
        local LevelOrFunc, Info = ...
        if Detected and LevelOrFunc == Detected then return "Disconnected" end
        if Kill and LevelOrFunc == Kill then return "Disconnected" end
        return getinfo(...)
    end))

    setthreadidentity(7)
end
```

### What Gets You Kicked vs. What Doesn't
| Action | Outcome | Rationale / Technical Cause |
| :--- | :--- | :--- |
| **Adding a persistent `task.spawn` loop to re-scan `getgc`** | **INSTANT KICK** | Adonis watches its own GC memory structures. Polling `getgc(true)` repeatedly in background threads trips metatable and memory read heuristics. |
| **Wrapping the bypass in `pcall()`** | **INSTANT KICK** | Adonis has trap metamethods that detect pcall frames around initialization calls. The bypass must run raw. |
| **Running hooks under Identity 7 without switching to 2** | **KICK / SILENT FAIL** | Core Adonis tables reside in lower security levels (`thread identity 2`). `setthreadidentity(2)` is required during `getgc` hook assignment, then switch back to `7`. |
| **Using `VirtualInputManager` to click** | **INTERFACE CORRUPTION** | Sends global hardware clicks, causing unintentional interactions with on-screen HUD elements, blackscreens, and chat toggles. |
| **Using `IH:FireVirtualInput("PrimaryInput", ...)`** | **SAFE & NATIVE** | Fires natively through the game's internal `InputHandler` framework without touching the OS mouse cursor. |
| **Single one-time raw GC hook at script startup** | **SAFE & UNTOUCHED** | Disables `Detected` and `Kill` handlers cleanly before Adonis begins its main verification ticks. |

---

## 10. Critical Mistakes & Pitfalls to Avoid (Lessons Learned)

These are real mistakes made during development that caused severe regressions, along with the required pattern:

### 1. Workspace Instance Scanning in Tight Loops (`WS:GetChildren()`)
* **The Mistake**: Running `for _, d in ipairs(WS:GetChildren()) do` inside high-frequency polling loops (e.g. 25Hz `task.wait(0.04)` to detect bite sound effects). In The Wild West, `Workspace` has over 20,000 instances; iterating them 25 times per second thrashes the CPU and Lua garbage collector, dropping client FPS from 60 to 5.
* **The Fix**:
  - Scope all sound and part searches strictly to `char:GetDescendants()` (under 50 instances).
  - Target specific containers (`workspace.Entities`, `workspace.NPC`) rather than the root `workspace`.
  - Check named parts directly using `:FindFirstChild("Bobber")` instead of full scans.
  - Keep check intervals $\ge 0.1\text{s}$ (10Hz is more than fast enough for human-timed QTEs and bites).

### 2. Confusing Editor Linter Warnings with Runtime Errors
* **The Mistake**: Opening bundled files in Real and seeing ~1,850 `UnknownGlobal` warnings, assuming the bundle is broken. Real runs the Luau Language Server statically; modular closures referencing environment variables (`LP`, `S`, `UI`, `root`, `FISH`) trigger static linter warnings even though they execute perfectly at runtime.
* **The Fix**:
  - Place `--!nocheck` and `--!nolint` on lines 1–2 of `scripty_bundle.luau` before any non-comment code.
  - Close and reopen the tab in Real so it re-reads the updated file from disk.

### 3. Syntax Error Cascades from Missing Block Terminators (`end`)
* **The Mistake**: Forgetting a single `end` on a `while` loop inside an asynchronous `task.spawn(function() ... end)` closure. Luau matches the next `end)` against the `while` statement, triggering three false error locations:
  1. Line $N$: `Expected identifier when parsing expression, got ')'`
  2. Line $N+4$: `Expected ')' to close '(', got 'local'`
  3. Line $EOF$: `Expected 'end' to close 'function' at line 2296, got <eof>`
* **The Fix**: Triage block nesting directly by line indentation in the source module rather than writing complex external AST scripts.

### 4. Ground Teleportation & Horse Dismounting (`landBeside`)
* **The Mistake**: Teleporting the player while still mounted on a horse, or teleporting directly onto target coordinates without validating dry ground. The player can get stuck in a swim state or embedded inside horse geometry.
* **The Fix**:
  - Call `dismount()` first and wait $0.3\text{s}$ for seat physics to clear.
  - Probe dry ground in 6 cardinal and diagonal offsets using raycasts (`groundY(pos + dir * offset)`).
  - Reset `AssemblyLinearVelocity = Vector3.zero` over 5–10 Heartbeat frames upon landing.

---

## 11. AI Engineering & Contributor Guide

If you are an AI assistant or contributor working on this codebase with zero prior context, follow these strict architectural rules:

### Architecture & Bundling Protocol
1. **Never edit `scripty_bundle.luau` directly**:
   - The repository is modularized into 13 standalone files inside `modules/` and orchestrated by `scripty.luau`.
   - `bundle.py` compiles the modules into `scripty_bundle.luau` and hardlinks it to Real's workspace.
   - Always make edits inside the relevant module in `modules/`, then run `python bundle.py`.
2. **Environment Upvalues & Cross-Module State**:
   - Modules share runtime variables (`LP`, `WS`, `S`, `UI`, `TH`, `FISH`, `COMBAT`, `root`, `hum`, `char`, `logAction`).
   - When a module exports functions, ensure it returns them cleanly in its export table at the bottom of the module file.
3. **Quota Conservation & Execution Hygiene**:
   - Never write auxiliary Python inspection/regex scripts for simple syntax errors or one-line bug fixes.
   - Read compiler diagnostics and line numbers directly, make targeted edits with `replace_file_content`, run `bundle.py`, and test.
   - Respect the machine and project rules in `GEMINI.md` and `.agents/rules/coding_efficiency.md`.

