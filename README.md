# Advanced Deathmatch [![--](https://img.shields.io/badge/visit-alliedmodders.net-success)](https://forums.alliedmods.net/showthread.php?t=337928) [![--](https://img.shields.io/badge/visit-hlmod.ru-informational)](https://hlmod.ru/resources/advanced-deathmatch.3735/)

This sourcemod plugin is made for original CS:GO Deathmatch game mode.

Main idea is to get rid of visual noise and add some warmup-style features.

No speacial cvars are implemented: everything works around built-in commands.

## Features

- Play modes *(multi_cfg & notifications)*
- Buy menu on <kbd>drop</kbd> key *(cookies & random)*
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