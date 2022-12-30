#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

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

		return !!total;
	}
}

enum struct Arsenal {
	Menu BuyMenu;

	KeyValues Slot;
	KeyValues Clip;

	Handle Cookies[2];
	ArrayList User[2];

	bool ListEnd[MAXPLAYERS];

	void Initialize()
	{
		this.Cookies[0] = RegClientCookie("deathmatch_slot0", "Primary Weapon", CookieAccess_Protected);
		this.Cookies[1] = RegClientCookie("deathmatch_slot1", "Secondary Weapon", CookieAccess_Protected);

		this.User[0] = new ArrayList(32, MAXPLAYERS);
		this.User[1] = new ArrayList(32, MAXPLAYERS);

		this.BuyMenu = new Menu(BuyMenuHandler, MenuAction_DrawItem);

		this.Slot = new KeyValues("weapon_slot");
		this.Clip = new KeyValues("weapon_clip");
	}

	void Add(char[] category, char[] weapon, char[] name, int clip)
	{
		char item[32];

		Format(item, sizeof(item), "%s:%s", category, weapon);

		this.BuyMenu.AddItem(item, name);

		this.Slot.SetNum(weapon, StrEqual(category, "pistols"));
		this.Clip.SetNum(weapon, clip);
	}

	void Store(int client, char[] item)
	{
		int slot = this.Slot.GetNum(item);

		this.User[slot].SetString(client, item);

		SetClientCookie(client, this.Cookies[slot], item);
	}

	void GetRandom(int slot, char[] weapon, int maxlength)
	{
		ArrayList Stack = new ArrayList(1, this.BuyMenu.ItemCount);

		for (int i = 0; i < Stack.Length; i++)
		{
			Stack.Set(i, i);
		}

		char income[32], choose[2][32];

		do
		{
			int random = GetRandomInt(0, Stack.Length - 1);

			this.BuyMenu.GetItem(Stack.Get(random), income, sizeof(income));

			ExplodeString(income, ":", choose, sizeof(choose), sizeof(choose[]));
			Format(income, sizeof(income), "mp_weapons_allow_%s", choose[0]);

			if (StrEqual(choose[0], "pistols") == !!slot && GetConVarInt(FindConVar(income)))
			{
				Format(weapon, maxlength, choose[1]);
				return;
			}
			else
			{
				Stack.Erase(random);
			}
		} while (Stack.Length);
	}
}

Storage GameState;
Arsenal Weapons;

public Plugin myinfo =
{
	name = "Advanced Deathmatch",
	author = "alexey_gamov",
	description = "Enchantments for classic DM",
	version = "1.0.2",
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

	HookEvent("round_end", OnRoundPhase, EventHookMode_Pre);
	HookEvent("round_prestart", OnRoundPhase, EventHookMode_Pre);
	HookEvent("cs_win_panel_round", OnWinPanel, EventHookMode_Pre);
	HookEvent("round_freeze_end", DisableMessages, EventHookMode_Pre);

	HookEvent("server_cvar", DisableMessages, EventHookMode_Pre);
	HookEvent("player_team", DisableMessages, EventHookMode_Pre);
	HookEvent("player_connect", DisableMessages, EventHookMode_Pre);
	HookEvent("player_disconnect", DisableMessages, EventHookMode_Pre);

	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	HookUserMessage(GetUserMessageId("TextMsg"), DisableChat, true);
	HookUserMessage(GetUserMessageId("RadioText"), DisableRadio, true);

	AddCommandListener(BuyCommand, "buyrandom");
	AddCommandListener(BuyCommand, "rebuy");
	AddCommandListener(BuyCommand, "drop");
	AddCommandListener(BuyCommand, "buy");

	AddNormalSoundHook(DisableSound);
	AddTempEntHook("Sparks", DisableEffect);

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

	Weapons.BuyMenu.RemoveAllItems();

	Weapons.Add("rifles", "weapon_ak47", "AK-47", 30);
	Weapons.Add("rifles", "weapon_m4a1", "M4A1", 30);
	Weapons.Add("rifles", "weapon_m4a1_silencer", "M4A1-S", 20);
	Weapons.Add("rifles", "weapon_sg556", "SG 553", 30);
	Weapons.Add("rifles", "weapon_aug", "AUG", 30);
	Weapons.Add("rifles", "weapon_galilar", "Galil AR", 35);
	Weapons.Add("rifles", "weapon_famas", "FAMAS", 25);
	Weapons.Add("rifles", "weapon_awp", "AWP", 5);
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

public void OnClientCookiesCached(int client)
{
	char item[32];

	for (int slot = 1; slot >= 0; slot--)
	{
		GetClientCookie(client, Weapons.Cookies[slot], item, sizeof(item));
		Weapons.User[slot].SetString(client, item);
	}

	Weapons.ListEnd[client] = false;
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
	else
	{
		hEvent.SetInt("reason", 16);
		hEvent.SetInt("winner", 1);
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

public Action OnPlayerDeath(Event hEvent, const char[] name, bool dontBroadcast)
{
	int attack = GetClientOfUserId(hEvent.GetInt("attacker"));
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	int weapon = GetEntPropEnt(attack, Prop_Data, "m_hActiveWeapon");

	SetEntProp(attack, Prop_Send, "m_iHealth", 100);
	SetEntProp(attack, Prop_Send, "m_ArmorValue", GetConVarBool(FindConVar("mp_max_armor")) ? 100 : 0);

	SetEntProp(attack, Prop_Send, "m_bPlayerDominated", false, _, victim);
	SetEntProp(victim, Prop_Send, "m_bPlayerDominatingMe", false, _, attack);

	if (IsValidEntity(weapon))
	{
		char weaponName[32];

		GetEventString(hEvent, "weapon", weaponName, sizeof(weaponName));
		Format(weaponName, sizeof(weaponName), "weapon_%s", weaponName);

		SetEntProp(weapon, Prop_Send, "m_iClip1", Weapons.Clip.GetNum(weaponName) + 1);
	}

	if (IsClientInGame(attack))
	{
		RemoveSound(attack);
		RequestFrame(RemoveSound, attack);
	}

	if (!IsFakeClient(attack))
	{
		Handle fade = StartMessageOne("Fade", attack);

		PbSetInt(fade, "duration", 250);
		PbSetInt(fade, "hold_time", 0);
		PbSetInt(fade, "flags", 0x0001);
		PbSetColor(fade, "clr", {150, 150, 150, 75});

		EndMessage();
	}

	hEvent.SetBool("dominated", false);
	hEvent.SetBool("assister", false);
	hEvent.SetBool("revenge", false);

	hEvent.BroadcastDisabled = IsFakeClient(attack) || (attack == victim);

	return Plugin_Changed;
}

public Action OnPlayerSpawn(Event hEvent, const char[] name, bool dontBroadcast)
{
	int entity, client = GetClientOfUserId(hEvent.GetInt("userid"));

	for (int slot = 1; slot >= 0; slot--)
	{
		if ((entity = GetPlayerWeaponSlot(client, slot)) != -1)
		{
			RemovePlayerItem(client, entity);
			AcceptEntityInput(entity, "kill");
		}
	}

	if (!IsFakeClient(client))
	{
		RequestFrame(RemoveRadar, client);
		CreateTimer(0.5, ShowCurrentMode, client);
	}
	else if (Weapons.BuyMenu.ItemCount)
	{
		FakeClientCommand(client, "buyrandom");
	}
}

public Action ShowCurrentMode(Handle timer, int client)
{
	Event hEvent = CreateEvent("show_survival_respawn_status");

	if (hEvent != null && !GameState.RoundEnd && GameState.Modes.Length > 0)
	{
		hEvent.SetInt("duration", 3);
		hEvent.SetInt("userid", -1);

		int start = (client == -1) ? 1 : client;
		int total = (client == -1) ? MaxClients : client;

		for (int i = start; i <= total; i++)
		{
			char message[1024] = "<font color='#e0c675'>%T:</font><font color='#e3e3e3'>%s</font>";

			Format(message, sizeof(message), message, "Current round", i, GameState.CurrentRound);

			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				hEvent.SetString("loc_token", message);
				hEvent.FireToClient(i);
			}
		}

		hEvent.Cancel();
	}
}

public int BuyMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	char income[32], choose[2][32];

	if (action != MenuAction_End)
	{
		GetMenuItem(menu, item, income, sizeof(income));
		ExplodeString(income, ":", choose, sizeof(choose), sizeof(choose[]));
	}

	if (action == MenuAction_DrawItem)
	{
		if (StrEqual(choose[0], "pistols") != Weapons.ListEnd[client])
		{
			return ITEMDRAW_RAWLINE;
		}

		Format(income, sizeof(income), "mp_weapons_allow_%s", choose[0]);

		if (!GetConVarInt(FindConVar(income)))
		{
			return ITEMDRAW_RAWLINE;
		}
	}

	if (action == MenuAction_Select)
	{
		if (GetEntProp(client, Prop_Send, "m_bGunGameImmunity"))
		{
			GiveWeapon(client, choose[1]);
		}
		else if (Weapons.ListEnd[client])
		{
			PrintToChat(client, " %T", "Wait respawn", client, 0x07);
		}

		Weapons.Store(client, choose[1]);
	}

	if (action == MenuAction_Select || action == MenuAction_Cancel)
	{
		bool next = !Weapons.ListEnd[client];

		ClientCommand(client, next ? "drop" : NULL_STRING);

		Weapons.ListEnd[client] = next;
	}

	return 0;
}

public Action BuyCommand(int client, const char[] command, int args)
{
	if (StrEqual(command, "drop"))
	{
		if (GameRules_GetProp("m_bDMBonusActive"))
		{
			return Plugin_Continue;
		}

		if (!GetClientMenu(client))
		{
			Weapons.BuyMenu.SetTitle("%T", "Buy menu", client, GameState.CurrentRound, "G");
			Weapons.BuyMenu.Display(client, MENU_TIME_FOREVER);
		}
		else if(!Weapons.ListEnd[client])
		{
			CancelClientMenu(client);
		}
	}
	else if (!StrEqual(command, "buy") && (GetEntProp(client, Prop_Send, "m_bGunGameImmunity") || IsFakeClient(client)))
	{
		char weapon[32];
		bool random;

		for (int slot = 1; slot >= 0; slot--)
		{
			if ((random = StrEqual(command, "buyrandom")))
			{
				Weapons.GetRandom(slot, weapon, sizeof(weapon));
			}
			else
			{
				Weapons.User[slot].GetString(client, weapon, sizeof(weapon));
			}

			if ((!StrEqual(weapon, NULL_STRING) && !random) || random)
			{
				GiveWeapon(client, weapon);
			}
			else
			{
				Weapons.ListEnd[client] = !!slot;
				ClientCommand(client, "drop");
			}
		}

		if (!StrEqual(weapon, NULL_STRING))
		{
			PrintToChat(client, "%T", "How to buy", client, 0x08, "G");
		}
	}

	return Plugin_Handled;
}

public Action DisableMessages(Event hEvent, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}

public Action DisableChat(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
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

public Action DisableRadio(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return Plugin_Handled;
}

public Action DisableSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char entry[PLATFORM_MAX_PATH], int &seed)
{
	static char sound_effects[][] =
	{
		"player/death",
		"player/pl_respawn",
		"player/bhit_helmet",
		"buttons/button14"
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

public Action DisableEffect(const char[] name, const int[] clients, int num, float delay)
{
	return Plugin_Handled;
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

	Format(GameState.CurrentRound, sizeof(GameState.CurrentRound), "DM");

	BuildPath(Path_SM, path, sizeof(path), "configs/%s", file);

	if (FileExists(path) && !FileToKeyValues(GameState.Settings, path))
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

	Weapons.Initialize();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

void RemoveSound(int client)
{
	StopSound(client, SNDCHAN_ITEM, "buttons/bell1.wav");
}

void RemoveRadar(int client)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", 1 << 12);
}

void GiveWeapon(int client, char[] weapon, bool fast_switch = true)
{
	int entity;

	if ((entity = GetPlayerWeaponSlot(client, Weapons.Slot.GetNum(weapon))) != -1)
	{
		RemovePlayerItem(client, entity);
		AcceptEntityInput(entity, "kill");
	}

	GivePlayerItem(client, weapon);

	if (fast_switch)
	{
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime());
		
		entity = GetPlayerWeaponSlot(client, Weapons.Slot.GetNum(weapon));
		client = GetEntPropEnt(client, Prop_Send, "m_hViewModel");

		if (IsValidEntity(client) && entity != -1)
		{
			SetEntProp(client, Prop_Send, "m_nSequence", StrEqual(weapon, "weapon_m4a1_silencer"));
		}
	}
}