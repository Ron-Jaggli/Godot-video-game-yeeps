# Godot-video-game-yeeps
this wont actually be yeeps but it would just be a game inspired by yeeps that will be extremely optimized for wiring and other tasks and it would actually consider the community suggestions and it would be a lot more darker or like i like to say GRIM (shitty game reference) and idk hopefully i would be able to have a script uploader and PC companions and then YEEPS MONOPOLY nah I just hate trass for going down the tomahawk route so and everything would be open source but the anticheat and if you have root you do have to install a singularity magisk module and i mean all of the code will 100% be obf for the magisk module so

## Server structure

Godot 4.3+ project. A single codebase builds both the client and the dedicated server.

```
network/network.gd     autoload "Network": ENet peer + every client<->server RPC
server/server.gd       dedicated server: client registry, handshake, request routing
server/room_manager.gd room codes, quick play matchmaking, empty-room cleanup
server/anticheat.gd    server-side pose validation (swap for the closed one later)
shared/                constants + wire enums used by both sides
scenes/main.*          entry point, picks server or client from the command line
scenes/room/           a room; only replicated to its members
scenes/player/         server-owned avatar + client-owned Input node
client/main_menu.gd    placeholder flat menu (quick play / join code / private room)
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
