# Bridger: Western (BW) — Game Architecture & Client Control Specification
> **Audience**: AI Coding Assistants & Script Developers  
> **Target Environment**: Roblox (Luau Client / Executor Context)  
> **Game Title**: *Bridger: Western* (abbreviated *BW*)  
> **Scope**: Pure game-native structures, remotes, input handling, and entity lifecycles. Zero custom/third-party script features included.

---

## 0. Mandatory AI Operating Directives (Enforced on EVERY Message)

> [!IMPORTANT]
> **PERSISTENT SYSTEM INVARIANT — NEVER FORGET OR DRIFT**:
> The AI assistant MUST actively cross-reference and adhere to this specification on **EVERY SINGLE MESSAGE AND RESPONSE**, without exception. Do not follow this document for a few turns and then revert to generic Roblox scripting assumptions. Every script, modification, remote call, input event, and game mechanic interaction MUST strictly comply with this document on every turn.

### Core Pre-Flight Checklist (Run Before Every Generation)
1. **Continuous Spec Verification**: Validate that all game calls match BW-specific architecture (e.g. use `InputHandlerClient`, NEVER `VirtualInputManager`; verify Adonis anti-cheat safety constraints; ensure horse dismount before CFrame movement; avoid `workspace:GetDescendants()`).
2. **Space Optimization (Fewer Lines of Code)**: Maximize line-count economy and minimize token bloat on every script. Write tight, compact, space-optimized Luau. Avoid unnecessary filler lines, excessive blank lines, or redundant multi-line commentary. Combine short guard clauses, use ternary expressions (`cond and a or b`), and keep helper routines concise.
3. **Speed Efficiency & Micro-Performance**: Optimize for peak runtime execution speed on every script. Cache high-frequency globals and engine services into local upvalues (`local task_wait = task.wait`, `local Vec3 = Vector3.new`, etc.), eliminate table/string allocations in hot paths or render loops, and rely on Roblox spatial queries (`workspace:GetPartBoundsInRadius`) rather than hierarchy scans.
4. **Unknown Mechanic Suggestion Rule**: If the user asks for a function or automation for ANY game mechanic not explicitly documented in this spec or whose internal mechanics are unknown, **DO NOT GUESS OR WRITE SPECULATIVE CODE**. You MUST immediately suggest a **safe diagnostic test script** (per Section 12.2) to inspect the live game state, and provide 4 structured clarification options.
5. **Concise Communication & Zero Spec Acknowledgement**: NEVER acknowledge reading, checking, or following this spec (do not say "Understood", "I've reviewed the spec", etc.). If prompted with this file or starting a session, simply ask what the user wants to make. Keep all explanations short, direct, and factual with zero corporate buzzwords.

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

## 9. Client Security & Anti-Cheat Environment

The client environment incorporates **Adonis AntiCheat** alongside game-native server validation. Understanding what trips detections versus what executes safely is essential for maintaining client stability.

### What Gets Kicked (Known Kick Vectors)
1. **Persistent Background GC Scanners**:
   - *Failure Vector*: Spawning persistent loops (e.g. `task.spawn(function() while task.wait(5) do for i, v in getgc(true) do ... end end)`) to repeatedly re-hook Adonis tables.
   - *Why It Kicks*: Adonis deploys honeypot table references and detects abnormal repetitive iteration across garbage-collected closures. Running persistent scanners triggers integrity checks and results in an immediate disconnect/kick.
2. **P-Calling or Wrapping Adonis Bypasses**:
   - *Failure Vector*: Wrapping bypass functions in `pcall` or passing modified function wrappers that tamper with stack traces or environment identity.
   - *Why It Kicks*: Adonis checks the caller identity and closure structure of its internal `Detected` and `Kill` handlers. The bypass must be executed cleanly, once, under thread identity `2` (the game script identity), directly neutralizing `Detected` and `Kill` functions at initialization.
3. **Mounted Character Teleportation Desync**:
   - *Failure Vector*: Setting the player's `HumanoidRootPart.CFrame` across large distances while still seated on or bonded to a horse seat.
   - *Why It Kicks*: The server runs velocity and proximity validation between horse and rider. If the character's position snaps while the horse entity remains behind, the server registers a severe position/state desync, triggering an instant kick.
4. **Invalid Remote Firing Sequences**:
   - *Failure Vector*: Calling gameplay remotes (such as shooting, reloading, or claiming loot) out of order or while in an invalid player state (e.g., attempting to fire during a loading screen or without equipping the corresponding tool).
   - *Why It Kicks*: The server enforces strict state transitions. Remote calls must always replicate the exact lifecycle order expected by the client modules.

### What Is Safe (Undetected Operations)
1. **Clean, One-Time Adonis Table Neutralization**:
   - Executing a clean, single-pass `getgc(true)` scan at script startup with `setthreadidentity(2)`.
   - Locating the internal table containing `Detected` and `Kill` and substituting them with empty/dummy functions.
2. **Game-Native Virtual Input (`InputHandlerClient`)**:
   - Firing inputs via `InputHandler:FireVirtualInput(alias, state)`.
   - Because this goes directly through the game's official input router, all input events pass client-side input validation cleanly without OS-level synthetic event anomalies.
3. **Controlled CFrame Movement with Zeroed Linear Velocity**:
   - Moving the player via short CFrame hops while ensuring `AssemblyLinearVelocity = Vector3.zero` and `AssemblyAngularVelocity = Vector3.zero`.
   - Always dismounting the horse first, waiting for physics to settle (0.2–0.3s), and then repositioning the character.
4. **Native Interaction Events**:
   - Triggering `ProximityPrompt` via `fireproximityprompt(prompt)`.
   - Triggering NPC `ClickDetector` via `fireclickdetector(detector)`.

---

## 10. Performance Pitfalls & Critical Traps to Avoid

Developing automation scripts for large-scale western games requires extreme caution regarding client performance and engine resources.

### 1. The Workspace Traversal Trap (Massive FPS Drops)
* **The Mistake**: Calling `workspace:GetChildren()` or `workspace:GetDescendants()` inside high-frequency polling loops (e.g. checking sounds or entities every 0.04s).
* **Why It Destroys Performance**: The game map contains tens of thousands of instances (foliage, terrain cells, buildings, props, animals). Traversing the full Workspace hierarchy in Lua takes dozens of milliseconds per tick, choking the engine main thread and dropping FPS from 60 to 5.
* **The Correct Pattern**:
  - For player-related objects (equipped tools, animations, fishing rods): Scope checks strictly to `Character:GetDescendants()`, which only contains ~50 instances.
  - For spatial checks: Use Roblox's built-in spatial engine:
    ```lua
    local params = OverlapParams.new()
    params.MaxParts = 25
    local nearbyParts = workspace:GetPartBoundsInRadius(rootPos, radius, params)
    ```
    This executes in C++ in microseconds via spatial partitioning rather than iterating thousands of Lua objects.
  - Avoid string allocations (e.g. `sfx.Name:lower()`) and multi-pattern string regex inside tight loops; check exact names or cache instance references.

### 2. The VirtualInputManager Coordinate Trap
* **The Mistake**: Using `VirtualInputManager` to perform in-game primary actions
* **Why It Fails**: `VirtualInputManager` simulates OS-level hardware at screen pixel coordinates. This method is completely detected NEVER USE IT UNDER ANY CIRCUMSTANCES.
* **The Correct Pattern**: Always use the game's internal `InputHandlerClient:FireVirtualInput("PrimaryInput", true/false)`. It operates independently of screen coordinates and never accidentally clicks on GUI elements.

### 3. Horse Mounting & Ground Raycasting Traps
* **The Mistake**: Assuming a target position's Y coordinate has dry ground, or teleporting directly onto horse coordinates without radial ground alignment.
* **Why It Fails**: Western terrain is highly uneven, with deep riverbeds, steep cliffs, and overhangs. Blind teleportation causes characters to get stuck under the map or drown in water.
* **The Correct Pattern**:
  - Sample 6 radial ground offsets (`(1,0,0)`, `(-1,0,0)`, `(0,0,1)`, `(0,0,-1)`, `(1,0,1)`, `(-1,0,-1)`) using raycasting against terrain.
  - Pick the candidate position that has valid dry ground (`hit.Material ~= Enum.Material.Water`) and sits within reasonable elevation delta (< 12 studs).
  - Offset the character Y coordinate by `+3.5` studs above ground level to prevent feet clipping.

---

## 11. AI Engineering, Code Compactness & High-Performance Optimization

For any AI assistant or developer building scripts and automation for *Bridger: Western*:

### 1. Code Space Optimization & Line Count Economy (Fewer Lines of Code)
Every script, module, or function must be written with strict space optimization and line-count economy:
* **Eliminate Boilerplate & Ceremony**: Avoid verbose, multi-line ceremonial structures, empty vertical padding, and trivial comments that merely repeat what the code does.
* **Compact Guard Clauses**: Use concise early exits on a single line where appropriate:
  ```lua
  if not char or not root then return end
  ```
* **Ternary & Idiomatic Short-Circuits**: Utilize Luau's `cond and a or b` pattern for compact assignments instead of 5-line `if ... else ... end` statements:
  ```lua
  local speed = isMounted and 28 or 16
  ```
* **Condensed Multi-Variable Declarations**: Declare related variables on single lines:
  ```lua
  local LP, RS, Players = game:GetService("Players").LocalPlayer, game:GetService("ReplicatedStorage"), game:GetService("Players")
  local root, hum = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
  ```
* **Reusable Compact Utility Functions**: Consolidate repetitive tasks (e.g., getting horse, finding tools, checking attributes) into tight 2–3 line helper functions rather than repeating multi-line boilerplate across features.

### 2. Runtime Speed & Micro-Performance Efficiency
Bridger: Western operates under heavy client physics and entity loads. Every script must be engineered for maximum execution speed and zero frame hitching:
* **Local Upvalue Caching**: Global and service lookups incur index overhead in Luau. Localize high-frequency library functions and engine constructors at the top of the file:
  ```lua
  local task_wait, task_spawn, task_delay = task.wait, task.spawn, task.delay
  local Vec3, CF = Vector3.new, CFrame.new
  local tbl_find, tbl_insert, tbl_clear = table.find, table.insert, table.clear
  local str_find, str_match = string.find, string.match
  local math_min, math_max, math_floor = math.min, math.max, math.floor
  ```
* **Zero Allocation in Hot Paths**:
  - Never instantiate new tables (`{}`), closures, or strings inside `RenderStepped`, `Heartbeat`, or fast polling loops (< 0.1s).
  - Clear and reuse pre-allocated buffer tables using `table.clear(cachedTable)`.
* **C++ Spatial Partitioning Over Luau Iteration**:
  - Never iterate through children or descendants to detect nearby entities, loot, or parts.
  - Always use Roblox's hardware-accelerated spatial queries:
    ```lua
    local parts = workspace:GetPartBoundsInRadius(rootPos, radius, overlapParams)
    ```
* **Event-Driven Over Busy Polling**:
  - Use `GetAttributeChangedSignal`, `AncestryChanged`, or `ChildAdded` rather than rapid `while task.wait(0.05) do` checks whenever possible.
* **Fast-Path Early Exits**: Place the cheapest, most likely failure checks (e.g. `if not isEnabled then return end`) at the very top of event handlers to avoid computing expensive math or queries when inactive.

### 3. Closure Bundling & Static Linter Directives
* When modular source files are bundled into a single self-contained script using closure encapsulation (`EMBEDDED_MODULES["Name"] = function(...)`), variables shared across modules will be flagged by in-app Luau linters (such as Real's Monaco LSP) as hundreds of `UnknownGlobal` warnings.
* **Mandatory Directives**: The generated bundle must always have `--!nocheck` and `--!nolint` at lines 1–2 (before any non-comment tokens) to silence editor warnings.

### 4. Strict Block Nesting & Single Contiguous Edits
* In Luau, an unclosed `while`, `for`, or `if` statement will cascade across the entire file, producing misleading syntax errors hundreds of lines later at `<eof>`.
* When modifying code, make surgical, single-block contiguous replacements rather than rewriting entire functions or files.

### 5. No Polling Commands or Long Scaffolding
* Avoid creating disposable diagnostic scripts to check simple logic. Inspect the exact line numbers provided by compiler/runtime diagnostics directly, apply the fix, and verify once.

### 6. State Preservation & Ghost Thread Prevention
* Maintain central state dictionaries so that toggling features on and off cleanly terminates background loops and disconnects event connections without leaving ghost threads running in the client.

---

## 12. Clarifying Vague Requests & Testing Unknown Game Features

### 1. When to Ask vs. When to Just Code
* **If you have enough info**: Just write the code. Don't ask pointless questions or stall.
* **If the request is vague**: Don't guess what the user wants. Ask for clarification and lay out:
  1. The most standard way to do it.
  2. An alternative way to do it.
  3. The simplest / safest minimal change.
  4. An open option for the user to tell you what they want.

### 2. Handling Unknown or Undocumented Game Features (Mandatory Suggestion Rule)
> [!IMPORTANT]
> **MANDATORY SUGGESTION PROTOCOL FOR UNFAMILIAR MECHANICS**:
> If the user asks to create a function, automation, or hook for ANY game mechanic that is not documented in this specification or whose internal remotes, properties, and data structures are unknown or unverified:
> 1. **DO NOT write speculative production code or guess remotes/object paths.** Guessing triggers Adonis anti-cheat kicks, breaks client state, or causes silent failures.
> 2. **ALWAYS suggest and provide a small, safe diagnostic test script** designed to print the exact required game objects, attributes, or network signatures to the console.
> 3. **Present 4 Clear Options** to the user:
>    - **Option 1**: The standard approach based on how known BW systems work (e.g. InputHandlerClient virtual inputs).
>    - **Option 2**: An alternative approach (e.g. upvalue inspection / network table hook).
>    - **Option 3 (Recommended)**: Run a small, safe diagnostic test snippet to inspect the exact live game state first.
>    - **Option 4**: The user provides the exact names, remotes, or internal details directly.

### 3. Safe Diagnostic Test Script Rules
When providing a diagnostic test snippet for an unknown mechanic:
* **Strict Safety Boundaries**:
  - Never loop over `workspace:GetDescendants()` or iterate the entire Workspace tree.
  - Never run continuous background loops or spam `getgc`.
  - Never blindly fire server remotes with guessed arguments.
  - Scope all scans to the specific entity, equipped tool, or GUI container involved.
* **Console-and-Stop Pattern**:
  - The test script must inspect the targeted instance, print its attributes, children, or relevant upvalues cleanly using `print()` or `warn()`, and immediately terminate.
* **User Workflow**:
  - Ask the user to run the snippet in their console and share the output.
  - Only write the real production feature once the actual game structure is confirmed.

### 4. Communication Style: Maximum Conciseness & Zero Buzzwords
* **Never Acknowledge the Spec**: Do not confirm or state that you read, checked, or are following this document (e.g., never say "Understood", "I've reviewed the spec", or "Ready to write BW code"). If prompted with the spec or starting a chat, simply ask what the user wants. If given a task, execute it immediately without acknowledging the document.
* **Zero Fluff & No Buzzwords**: Ban corporate jargon and filler words (e.g., do not say "seamlessly", "robust", "leverage", "paradigm", "orchestrate", "cutting-edge").
* **Short & Direct Explanations**: Explain what code does in 1–2 plain English sentences. State only what changed and why.
* **Minimal Output Length**: Omit chatty conversational padding, pleasantries, and unnecessary preamble. Deliver clean code and brief, factual explanations.

