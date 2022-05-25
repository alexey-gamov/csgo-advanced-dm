# Advanced Deathmatch

This sourcemod plugin is made for original CS:GO Deathmatch game mode.

Main idea is to get rid of visual noise and add some warmup-style features.

No speacial cvars are implemented - everything works around built-in commands.

## Features

- Cycle play modes *(configs & notifications)*
- Buy menu *(cookies & random)*
- Health/armor/clip restore on kill

#### What is disabled

- System messages and hints
- Radar & chickens
- Built-in sounds
- Bot kill feed

## Installation

1. Install latest [MetaMod](https://www.sourcemm.net/downloads.php?branch=stable) and [SourceMod](https://www.sourcemod.net/downloads.php?branch=stable) addons.
1. Download the `zip` archieve from **release** section and unpack everything to your server.
1. Edit `advanced-dm.cfg` file for your choise *(add  own play modes and set round time)*.
1. Set server launch options: `game_mode 2` and `game_type 1`
1. **Reboot server** and **start playing**.