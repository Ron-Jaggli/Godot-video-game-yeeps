# Godot-video-game-yeeps
this wont actually be yeeps but it would just be a game inspired by yeeps that will be extremely optimized for wiring and other tasks and it would actually consider the community suggestions and it would be a lot more darker or like i like to say GRIM (shitty game reference) and idk hopefully i would be able to have a script uploader and PC companions and then YEEPS MONOPOLY nah I just hate trass for going down the tomahawk route so and everything would be open source but the anticheat and if you have root you do have to install a singularity magisk module and i mean all of the code will 100% be obf for the magisk module so

## Server structure

Godot **4.7** project. A single codebase builds both the client and the dedicated server.

```
network/network.gd     autoload "Network": ENet peer + every client<->server RPC
server/server.gd       dedicated server: client registry, handshake, request routing
server/room_manager.gd room codes, quick play matchmaking, empty-room cleanup
server/anticheat.gd    server-side pose validation (swap for the closed one later)
shared/                constants + wire enums used by both sides
scenes/main.*          entry point, picks server or client from the command line
scenes/room/           a room; only replicated to its members
scenes/player/         server-owned avatar + client-owned Input node
scenes/xr/             local VR rig (arm locomotion) + world-space UI panels
scenes/avatar/         procedural blob avatar (no art assets) + shared/avatar_style.gd
scenes/map/            "The Hollow" graveyard map + reusable editor props (scenes/map/props/)
scenes/building/       grid blocks: hand building (builder.gd), replicated PlacedBlock
scenes/hub/            "The Ossuary" shop hub: stalls, quest board, exit
shared/economy.gd      ALL economy numbers: currencies, prices, weekly Relic cap, block catalog
shared/quests.gd       daily / weekly quests
client/profile.gd      autoload "Profile": the local save (Teeth, Relics, owned items, quests)
client/main_menu.gd    placeholder flat menu (quick play / join code / private room)
tools/setup_quest.gd   installs the pinned Meta Quest plugin (not committed, ~86 MB)
export_presets.cfg     Meta Quest APK, dedicated Linux server, Windows PCVR
```

The server owns rooms and players. Clients only send their head and hand pose, which the server checks before replicating it to everyone else in the same room. Players in other rooms never receive it.

### Running

```sh
# dedicated server
godot --headless -- --server --port=7777

# normal client (menu)
godot

# headless test clients / bots
godot --headless -- --connect --name=Alice --bot          # quick play
godot --headless -- --connect --name=Bob --create-private  # prints its room code
godot --headless -- --connect --name=Carl --join=ABC123
```

### VR rig & controls

OpenXR is on in the project settings. With a headset connected (PCVR via Link/SteamVR) the game starts in VR. Otherwise it falls back to a desktop debug mode.

- **Movement (VR):** Gorilla Tag style. Hands can't go through the world, so push off or drag along surfaces to move. Let go mid-push to fling.
- **Snap turn:** right stick. **Leave room:** left menu button.
- **Menu (VR):** floating panel in the lobby. Point with the right controller and click with the trigger.
- **Desktop debug:** click to capture mouse, WASD + Space, Esc frees the mouse, Tab leaves the room.

### Avatars

Every player is a procedural blob creature built from simple shapes, so there are no art files and it stays cheap on Quest. It has:

- a head with glowing eyes, and a body that hangs below it and turns with you
- stretchy noodle arms out to mitten hands
- a floating name tag

Pick one of 8 colors and 5 hats (None, Horns, Top Hat, Halo, Antenna) in the menu. A preview in the lobby mirrors your choice, and it's saved between sessions. Changes sync to everyone, even mid-room. The server checks that the color and hat are valid. Remote players are smoothed between network updates.

To use a real model later, give it the same three methods as `scenes/avatar/avatar.gd` (`set_style`, `set_display_name`, `set_pose`) and change what `Player` spawns. New colors and hats go at the end of the lists in `shared/avatar_style.gd` (players are sent the list position, so reordering would change existing players' looks).

### The map: The Hollow

An abandoned graveyard at night, about 44 × 44 m inside broken walls, laid out for arm locomotion:

- **Bell tower** in the middle. It's hollow, with staggered floors and wall ledges to climb inside, a hatch onto the roof deck, and a belfry with a bell. A fallen slab leans against it as a ramp.
- **Crypt** on the east side, with a flat roof to climb and columns out front.
- **Graveyard rows** on the west side, plus a ruined arch, broken columns and six dead trees with grabbable branches.
- **Lamps:** flickering lamp posts. The moon sits behind the tower, so it's backlit.
- **Spawning:** 8 spawn points around the plaza. Invisible walls keep flings inside the map, and falling below `kill_height` respawns you.

It's built from editor props that rebuild themselves when you change them in the inspector, so you can edit `scenes/map/graveyard.tscn` directly in Godot:

| Prop | Settings |
|---|---|
| `MapBlock` | box or cylinder, size, surface (stone, mossy, earth, wood, iron, bone) |
| `DeadTree` | seed, height, number of branches |
| `Gravestone` | seed (random size and tilt) |
| `Lamp` | height, light color |

At runtime, `GameMap` merges all props that share a material into one mesh. That takes the map from about 300 to 900 draw calls down to about 40 to 60, which Quest can handle. To make a new map, create a scene with a `GameMap` root and a `SpawnPoints` node full of `Marker3D`s.

### Building, currencies and the hub

**Currencies** (all numbers live in `shared/economy.gd`):

| | What it's for | Where it's kept |
|---|---|---|
| **Marrow** | placing blocks (each block type has its own price) | Server-side. Starts at 60 each session, refills 4/s up to 120, and picking a block back up refunds it. |
| **Teeth** | renting a block type for the room you're in | Saved on the device, permanent. Earned from quests. |
| **Relics** | owning a block type for good | Saved on the device, permanent. Earned from quests, with a weekly cap (`RELICS_WEEKLY_CAP`, resets Monday 00:00 UTC). |

**Blocks.** One grid cell is 0.6 × 0.9 × 0.6 m (a player wide and deep, half a player tall). Starting blocks:

| Block | Size | Marrow to place | Rent (Teeth) | Own (Relics) |
|---|---|---|---|---|
| Slab | 1×1×1 | 4 | n/a | free |
| Post | 1×2×1 | 6 | 10 | 40 |
| Coffer | 2×2×2 | 16 | 25 | 90 |
| Beam | 1×4×1 | 10 | 15 | 60 |

Controls:
- **VR:** squeeze grip to pull out your selected block, or grab one of your placed blocks to pick it up. It shrinks in your hand while a full-size preview snaps to the grid (green means it fits, red means it doesn't). Let go to place it. Tilt your hand to lay a block down. B/Y cycles the block, A/X drops the held one.
- **Desktop debug:** Q cycles the block, E takes, places or picks up, R turns the block, X drops it.

The server checks everything it can: Marrow, free space, map bounds, reach from your real hand position, and limits of 150 blocks per player and 400 per room. Your blocks are removed when you leave.

**The hub (The Ossuary).** Every map has a fresh grave. Scoop the earth out with your hands (or press F on desktop), then jump into the hole. Inside:
- a stall for each block: own it with Relics, or rent it for this room with Teeth
- the quest board
- a gadget wing, waiting for gadgets to be designed (add them to `Economy.GADGETS`)
- the arch that takes you back up

**Quests:** 3 daily and 3 weekly (lay blocks, reach the belfry, dig up graves). Each pays Teeth and Relics.

**Saves and tamper bans.** A random device ID is created on first launch until Meta login exists. The save is an obfuscated binary named from a hash of that ID and sealed against edits (`client/secure_store.gd`). Editing it wipes the profile and bans the device for 72 hours, both on the device and on the server (`user://bans.cfg` on the server). The report survives until it reaches the server, so deleting the local ban file doesn't help. A save that's corrupted by a crash falls back to its backup instead of banning the player. All of this is client-side, so someone who decompiles the game can still forge a save. The server is the only place balances couldn't be faked.

Testing several clients on one PC: each scripted client gets its own save from its `--name`, or pass `--profile=NAME`.

### Building for Meta Quest

One-time setup:

1. Install **Godot 4.7** and its export templates (Editor → Manage Export Templates).
2. Install **JDK 17** and the **Android SDK** (Android Studio is easiest), then set both paths in Editor Settings → Export → Android.
3. Install the Quest plugin ([Godot OpenXR Vendors](https://github.com/GodotVR/godot_openxr_vendors) 5.1.0, checksum-verified):
   ```sh
   godot --headless -s tools/setup_quest.gd
   ```
4. Set the server your Quest should connect to in Project Settings → `game/network/server_address`. The headset can't reach `127.0.0.1`, so use your PC's LAN IP or a hosted server.
5. Turn on developer mode on the headset (Meta Horizon app) and plug it in over USB.

Then export **Meta Quest** from Project → Export (Gradle build is already set up), or from the command line:

```sh
godot --headless --install-android-build-template --export-debug "Meta Quest" builds/quest/yeeps-like.apk
adb install -r builds/quest/yeeps-like.apk
```

Notes:
- Quest uses the Compatibility renderer (Meta's recommendation for performance), and desktop keeps Mobile.
- Text fields pop up the Quest system keyboard, so room codes can be typed in VR.
- The game runs at the headset's highest refresh rate, with physics ticking at the same rate.
- Release builds need your own keystore (Project → Export → Meta Quest → Keystore). Never commit it.

### Other exports

```sh
godot --headless --export-release "Dedicated Server (Linux)" builds/server/yeeps-like-server.x86_64
godot --headless --export-release "Windows Desktop (PCVR)" builds/windows/yeeps-like.exe
```

The server export strips graphics and always boots in server mode (`./yeeps-like-server.x86_64 -- --port=7777`).
