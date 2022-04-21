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

	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
}

public Action DisableMessages(Event hEvent, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}

public Action OnPlayerSpawn(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (IsPlayerAlive(client) && !IsFakeClient(client))
	{
		RequestFrame(RemoveRadar, client);
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