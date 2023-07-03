# nt_classlimit
Class limit plugin for competitive Neotokyo play

## Build requirements
* SourceMod 1.8 or newer
  * **If using SourceMod older than 1.11**: you also need [the DHooks extension](https://forums.alliedmods.net/showpost.php?p=2588686). Download links are at the bottom of the opening post of the AlliedMods thread. Be sure to choose the correct one for your SM version! You don't need this if you're using SourceMod 1.11 or newer.
* [Neotokyo include](https://github.com/softashell/sourcemod-nt-include), version 1.0 or newer

## Config
### Cvars
* `sm_maxrecons` (min 0, max 32, default 32) – The maximum amount of recons allowed in a team
* `sm_maxassaults` (min 0, max 32, default 32) – The maximum amount of assaults allowed in a team
* `sm_maxsupports` (min 0, max 32, default 32) – The maximum amount of supports allowed in a team

Note that the sum of `(sm_maxrecons + sm_maxassaults + sm_maxsupports)` should **always** be larger or equal to the maximum amount of players per playable team (Jinrai or NSF) expected for your server. For example, if you restrict all teams to 1 player of each class (3 total), when a fourth player joins a playable team, their class restriction would be indeterminate.
