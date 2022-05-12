#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

enum struct Storage {
	KeyValues Settings;
	ArrayList Modes;

	char CurrentRound[32];
	char NextRound[32];

	bool RoundEnd;

	bool ChangeMode()
	{
		int total = this.Modes.Length;
		int index = this.Modes.FindString(this.CurrentRound);

		if (total != 0)
		{
			index = (index == total - 1) ? 0 : index + 1;
			this.Modes.GetString(index, this.CurrentRound, 32);

			index = (index == total - 1) ? 0 : index + 1;
			this.Modes.GetString(index, this.NextRound, 32);
		}

		return (total != 0);
	}
}

enum struct Arsenal {
	void Add(char[] category, char[] weapon, char[] name, int clip)
	{
	}

	void Initialize()
	{
	}
}

Storage GameState;
Arsenal Weapons;

public Plugin myinfo =
{
	name = "Advanced Deathmatch",
	author = "alexey_gamov",
	description = "Enchantments for classic DM",
	version = "alpha",
	url = "https://github.com/alexey-gamov/csgo-advanced-dm"
}

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("ERROR: This plugin is designed only for CS:GO");
	}

	if (GetConVarInt(FindConVar("game_mode")) != 2 || GetConVarInt(FindConVar("game_type")) != 1)
	{
		SetFailState("ERROR: This plugin is designed only for DM game mode");
	}

	HookEvent("round_end", OnRoundPhase, EventHookMode_Post);
	HookEvent("round_prestart", OnRoundPhase, EventHookMode_Pre);
	HookEvent("cs_win_panel_round", OnWinPanel, EventHookMode_Pre);

	HookEvent("server_cvar", DisableMessages, EventHookMode_Pre);
	HookEvent("player_team", DisableMessages, EventHookMode_Pre);
	HookEvent("player_connect", DisableMessages, EventHookMode_Pre);
	HookEvent("player_disconnect", DisableMessages, EventHookMode_Pre);

	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	HookUserMessage(GetUserMessageId("TextMsg"), OnTextMsg, true);
	HookUserMessage(GetUserMessageId("RadioText"), OnRadioText, true);

	AddNormalSoundHook(EventSound);

	LoadSettings("advanced-dm.cfg");
	LoadTranslations("advanced-dm.phrases");
}

public void OnConfigsExecuted()
{
	if (GameState.Settings.JumpToKey("Settings") && GameState.Settings.GotoFirstSubKey(false))
	{
		char key[64], value[64];

		do
		{
			GameState.Settings.GetSectionName(key, sizeof(key));
			GameState.Settings.GetString(NULL_STRING, value, sizeof(value), "");

			ServerCommand("%s %s", key, value);
		} while (GameState.Settings.GotoNextKey(false));

		GameState.Settings.Rewind();
	}

	Weapons.Initialize();

	Weapons.Add("rifles", "weapon_ak47", "AK-47", 30);
	Weapons.Add("rifles", "weapon_m4a1", "M4A1", 30);
	Weapons.Add("rifles", "weapon_m4a1_silencer", "M4A1-S", 25);
	Weapons.Add("rifles", "weapon_sg556", "SG 553", 30);
	Weapons.Add("rifles", "weapon_aug", "AUG", 30);
	Weapons.Add("rifles", "weapon_galilar", "Galil AR", 35);
	Weapons.Add("rifles", "weapon_famas", "FAMAS", 25);
	Weapons.Add("rifles", "weapon_awp", "AWP", 10);
	Weapons.Add("rifles", "weapon_ssg08", "SSG 08", 10);
	Weapons.Add("rifles", "weapon_g3sg1", "G3SG1", 20);
	Weapons.Add("rifles", "weapon_scar20", "SCAR-20", 20);

	Weapons.Add("heavy", "weapon_m249", "M249", 100);
	Weapons.Add("heavy", "weapon_negev", "Negev", 150);
	Weapons.Add("heavy", "weapon_nova", "Nova", 8);
	Weapons.Add("heavy", "weapon_xm1014", "XM1014", 7);
	Weapons.Add("heavy", "weapon_sawedoff", "Sawed-Off", 7);
	Weapons.Add("heavy", "weapon_mag7", "MAG-7", 5);

	Weapons.Add("smgs", "weapon_mac10", "MAC-10", 30);
	Weapons.Add("smgs", "weapon_mp9", "MP9", 30);
	Weapons.Add("smgs", "weapon_mp7", "MP7", 30);
	Weapons.Add("smgs", "weapon_mp5sd", "MP5SD", 30); 
	Weapons.Add("smgs", "weapon_ump45", "UMP-45", 25);
	Weapons.Add("smgs", "weapon_p90", "P90", 50);
	Weapons.Add("smgs", "weapon_bizon", "PP-Bizon", 64);

	Weapons.Add("pistols", "weapon_glock", "Glock-18", 20);
	Weapons.Add("pistols", "weapon_p250", "P250", 13);
	Weapons.Add("pistols", "weapon_cz75a", "CZ75-A", 12);
	Weapons.Add("pistols", "weapon_usp_silencer", "USP-S", 12);
	Weapons.Add("pistols", "weapon_fiveseven", "Five-SeveN", 20);
	Weapons.Add("pistols", "weapon_deagle", "Desert Eagle", 7);
	Weapons.Add("pistols", "weapon_revolver", "R8", 8);
	Weapons.Add("pistols", "weapon_elite", "Dual Berettas", 30);
	Weapons.Add("pistols", "weapon_tec9", "Tec-9", 24);
	Weapons.Add("pistols", "weapon_hkp2000", "P2000", 13);
}

public Action OnRoundPhase(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (!(GameState.RoundEnd = StrEqual(name, "round_end")) && GameState.ChangeMode())
	{
		char key[64], value[64];

		ConVar command;

		GameState.Settings.JumpToKey("Modes");
		GameState.Settings.JumpToKey(GameState.CurrentRound);
		GameState.Settings.GotoFirstSubKey(false);

		do
		{
			GameState.Settings.GetSectionName(key, sizeof(key));
			GameState.Settings.GetString(NULL_STRING, value, sizeof(value), "");

			if ((command = FindConVar(key)) != INVALID_HANDLE)
			{
				SetConVarString(command, value, true, false);
			}
		} while (GameState.Settings.GotoNextKey(false));

		GameState.Settings.Rewind();

		CreateTimer(1.5, ShowCurrentMode, -1);
	}
}

public Action OnWinPanel(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (GameState.NextRound[0])
	{
		char message[1024] = "<b><font color='#c9c9c9'>%T:</font> <font color='#e3e3e3'>%s</font></b>";

		Format(message, sizeof(message), message, "Next round", LANG_SERVER, GameState.NextRound);

		hEvent.SetString("funfact_token", message);
	}

	return Plugin_Changed;
}

public Action DisableMessages(Event hEvent, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}

public Action OnPlayerDeath(Event hEvent, const char[] name, bool dontBroadcast)
{
	int attack = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	SetEntProp(attack, Prop_Send, "m_bPlayerDominated", false, _, victim);
	SetEntProp(victim, Prop_Send, "m_bPlayerDominatingMe", false, _, attack);

	hEvent.SetBool("dominated", false);
	hEvent.SetBool("assister", false);
	hEvent.SetBool("revenge", false);

	hEvent.BroadcastDisabled = IsFakeClient(attack) || (attack == victim);

	// fixme: dirdy hack to disable bell on kill
	for (int i = 1; i <= 64; i++)
	{
		StopSound(attack, SNDCHAN_ITEM, "buttons/bell1.wav");
	}

	return Plugin_Changed;
}

public Action OnPlayerSpawn(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (IsPlayerAlive(client) && !IsFakeClient(client))
	{
		RequestFrame(RemoveRadar, client);
		CreateTimer(0.5, ShowCurrentMode, client);
	}
}

public Action OnTextMsg(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char text[64];

	PbReadString(msg, "params", text, sizeof(text), 0);

	static char text_messages[][] =
	{
		"#Player_Point_Award",
		"#Cannot_Carry_Anymore",
		"#Cstrike_TitlesTXT_Game_teammate",
		"#Hint_try_not_to_injure_teammates",
		"#Chat_SavePlayer"
	};

	for (int i = 0; i < sizeof(text_messages); i++)
	{
		if (StrContains(text, text_messages[i], false) != -1)
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action OnRadioText(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return Plugin_Handled;
}

public Action EventSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char entry[PLATFORM_MAX_PATH], int &seed)
{
	static char sound_effects[][] =
	{
		"player/death",
		"player/pl_respawn",
		"player/bhit_helmet",
		//"physics/body",
		//"player/kevlar",
	};

	for (int i = 0; i < sizeof(sound_effects); i++)
	{
		if (StrContains(sample, sound_effects[i]) != -1)
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action ShowCurrentMode(Handle timer, int client)
{
	Event Status = CreateEvent("show_survival_respawn_status");

	if (Status != null && !GameState.RoundEnd && GameState.CurrentRound[0])
	{
		Status.SetInt("duration", 3);
		Status.SetInt("userid", -1);

		int start = (client == -1) ? 1 : client;
		int total = (client == -1) ? MaxClients : client;

		for (int i = start; i <= total; i++)
		{
			char message[1024] = "<font color='#e0c675'>%T:</font><font color='#e3e3e3'>%s</font>";

			Format(message, sizeof(message), message, "Current round", i, GameState.CurrentRound);

			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				Status.SetString("loc_token", message);
				Status.FireToClient(i);
			}
		}

		Status.Cancel();
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "chicken"))
	{
		AcceptEntityInput(entity, "kill");
	}
}

void LoadSettings(char file[32])
{
	char path[PLATFORM_MAX_PATH], key[64];

	GameState.Settings = new KeyValues("server-commands");
	GameState.Modes = new ArrayList(ByteCountToCells(64));

	BuildPath(Path_SM, path, sizeof(path), "configs/%s", file);

	if (!FileToKeyValues(GameState.Settings, path))
	{
		SetFailState("The configuration file could not be read");
	}

	if (GameState.Settings.JumpToKey("Modes") && GameState.Settings.GotoFirstSubKey(true))
	{
		do
		{
			GameState.Settings.GetSectionName(key, sizeof(key));
			GameState.Settings.GoBack();

			if (GameState.Settings.JumpToKey(key) && GameState.Settings.GotoFirstSubKey(false))
			{
				GameState.Modes.PushString(key);
				GameState.Settings.GoBack();
			}
		} while (GameState.Settings.GotoNextKey(false));

		GameState.Settings.Rewind();
	}
}

void RemoveRadar(int client)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", 1 << 12);
}