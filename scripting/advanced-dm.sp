#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

enum struct Storage {
	char CurrentRound[32];
	char NextRound[32];

	bool RoundEnd;
}

Storage GameState;

public Plugin myinfo =
{
	name = "Advanced Deathmatch",
	author = "alexey_gamov",
	description = "Enchantments for classic DM",
	version = "alpha",
	url = "https://github.com/alexey-gamov/csgo-advanced-dm"
};

public OnPluginStart()
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

	LoadTranslations("advanced-dm.phrases");
}

public Action OnRoundPhase(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (!(GameState.RoundEnd = StrEqual(name, "round_end")))
	{
		CreateTimer(1.5, ShowCurrentMode, -1);
	}
}

public Action OnWinPanel(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (GameState.NextRound[0])
	{
		char message[1024] = "<b><font color='#c9c9c9'>%t:</font> <font color='#e3e3e3'>%s</font></b>";

		Format(message, sizeof(message), message, "Next round", GameState.NextRound);

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

	hEvent.BroadcastDisabled = IsFakeClient(attack);

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

	if (StrContains(text, "#Player_Point_Award", false) != -1)
	{
		return Plugin_Handled;
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
	}

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
		char message[1024] = "<font color='#e0c675'>%t:</font><font color='#e3e3e3'>%s</font>";

		Format(message, sizeof(message), message, "Current round", GameState.CurrentRound);

		Status.SetString("loc_token", message);
		Status.SetInt("duration", 3);
		Status.SetInt("userid", -1);

		int start = (client == -1) ? 1 : client;
		int total = (client == -1) ? MaxClients : client;

		for (int i = start; i <= total; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
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

void RemoveRadar(int client)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", 1 << 12);
}