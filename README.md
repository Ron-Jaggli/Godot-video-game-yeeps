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
