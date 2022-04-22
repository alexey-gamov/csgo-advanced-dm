#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

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

	HookEvent("server_cvar", DisableMessages, EventHookMode_Pre);
	HookEvent("player_team", DisableMessages, EventHookMode_Pre);
	HookEvent("player_connect", DisableMessages, EventHookMode_Pre);
	HookEvent("player_disconnect", DisableMessages, EventHookMode_Pre);

	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	HookUserMessage(GetUserMessageId("TextMsg"), OnTextMsg, true);
	HookUserMessage(GetUserMessageId("RadioText"), OnRadioText, true);

	AddNormalSoundHook(EventSound);
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