# Battletoads Ghost
A Lua script for FCEUX that provides a speedrun ghost for Battletoads.

## Why?
So you can run against yourself and see exactly where and how you gain or lose those precious frames. In real time!

## How does it work?
On each frame it records your X and Y position and the sprite your character has, and then draws a matching sprite in the same location on the next run. The ghost is just an image drawn on the screen, it does not interact with the game in any way.

## Instructions
1. Download and unzip https://github.com/juvester/battletoads-ghost/archive/master.zip
2. Open Battletoads in FCEUX
3. Open `battletoads-ghost.lua` in FCEUX (File -> Lua... -> New Lua Script Window... -> Browse...)
4. Make a savestate on whatever spot you want your runs to begin from
5. Load the savestate to beging a new run
6. If you want to save your current run to be the new ghost, press SELECT on your gamepad at any time during the run
7. Repeat steps 5 and 6
    * You should see a ghost on your screen that mimics every move you made!

## Ghost models
Currently there are three different ghost models to choose from:
1. Rash: the toad you normally play with. Very confusing if opacity is not lowered since there are two identical toads on the screen.
2. WireRash: a wire-frame model of Rash. A lot less distracting than the normal Rash.
3. Mario (default): a lot smaller than Rash so it doesn't distract much. My favourite of the three.

You can change the model by opening `battletoads-ghost.lua` in a text editor and editing the settings at the top of the file. You can also change the ghost opacity there.

## TODO
* Save the ghost to a file so you can load it later or share it with others.
* Level 12 (The Revolution) has some funky x-position magic that still needs to be figured out. A fixed x-position is used in the meantime.
* Toggle ghost saving on/off with each SELECT press. Show some indicator wheter it's on/off.

## Credits
* 3DI70R: For the idea of saving and replaying runs on FCEUX. https://github.com/3DI70R/mari-o-fceux-replay-edition
* feos: For most of the memory locations. https://github.com/spiiin/feos-tas/blob/master/LUA/BattletoadsHitbox.lua
