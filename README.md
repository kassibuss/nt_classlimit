# nt_classlimit
Class limit plugin for competitive Neotokyo play

## Build requirements
* SourceMod 1.8 or newer
  * **If using SourceMod older than 1.11**: you also need [the DHooks extension](https://forums.alliedmods.net/showpost.php?p=2588686). Download links are at the bottom of the opening post of the AlliedMods thread. Be sure to choose the correct one for your SM version! You don't need this if you're using SourceMod 1.11 or newer.
* [Neotokyo include](https://github.com/softashell/sourcemod-nt-include), version 1.0 or newer

## Installation
* Compile the plugin, and place the .smx binary file to `addons/sourcemod/plugins`

## Config
### Cvars
* `sm_maxrecons` (min 0, max 32, default 32) – Maximum amount of recons allowed per team
* `sm_maxassaults` (min 0, max 32, default 32) – Maximum amount of assaults allowed per team
* `sm_maxsupports` (min 0, max 32, default 32) – Maximum amount of supports allowed per team
* `sm_classlimit_infraction_mode` (min 0, max 1, default 1) – How should nt_classlimit react to class selection infractions\*. 0: do nothing, 1: slay the player

You can change these defaults at `cfg/sourcemod/plugin.nt_classlimit.cfg`; the config file will be automatically created using the default values if it doesn't exist already.

### Notes
Note that the sum of `(sm_maxrecons + sm_maxassaults + sm_maxsupports)` should **always** be larger or equal to the maximum amount of players per playable team (Jinrai or NSF) expected for your server. For example, if you restrict all teams to 1 player of each class (3 total), when a fourth player joins a playable team, their class restriction would be indeterminate.

\*The reason `sm_classlimit_infraction_mode` exists is that currently players can actually spawn with restricted classes with some clever chaining of commands, or by waiting out the forced spawn timer in some uncommon scenarios. Setting the mode as `1` ensures the player is slayed in such a case, but you can also opt for mode `0` to allow them to spawn. Adding a third mode which prevents the spawning entirely would be nice, but it's not implemented currently.
