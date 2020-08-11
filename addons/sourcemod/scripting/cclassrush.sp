#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

#define MAJOR_REVISION	"1"
#define MINOR_REVISION	"0"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

public Plugin myinfo =
{
	name		=	"Class Rush",
	author		=	"Batfoxkid",
	description	=	"Class Rush for Team Fortress 2 Classic",
	version		=	PLUGIN_VERSION
};

#define TF2_GetPlayerClass(%1)	view_as<TFClassType>(GetEntProp(%1, Prop_Send, "m_iClass"))

enum TFTeam
{
	TFTeam_Unassigned = 0,
	TFTeam_Spectator,
	TFTeam_Red,
	TFTeam_Blue,
	TFTeam_Green,
	TFTeam_Yellow
};

static const int Color[][] =
{
	{ 0, 0, 0 },		// Unassigned
	{ 225, 225, 255 },	// Spectator
	{ 255, 0, 0 },		// Red
	{ 0, 0, 255 },		// Blue
	{ 0, 255, 0 },		// Green
	{ 255, 255, 0 }		// Yellow
};

static const char TeamName[][] =
{
	"BCK",
	"WIE",
	"RED",
	"BLU",
	"GRN",
	"YLW"
};

enum TFClassType
{
	TFClass_Unknown = 0,
	TFClass_Scout,
	TFClass_Sniper,
	TFClass_Soldier,
	TFClass_DemoMan,
	TFClass_Medic,
	TFClass_Heavy,
	TFClass_Pyro,
	TFClass_Spy,
	TFClass_Engineer,
	TFClass_Civilian
};

static const char ClassName[][] =
{
	"Mercenary",
	"Scout",
	"Sniper",
	"Soldier",
	"Demoman",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer",
	"Civilian"
};

TFClassType TeamClass[view_as<int>(TFTeam)];
Handle SyncHud[view_as<int>(TFTeam)];
float HideHudFor;

public void OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_changeclass", OnPlayerChangeClass);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_stalemate", OnRoundEnd, EventHookMode_PostNoCopy);

	AddCommandListener(OnJoinClass, "joinclass");
	AddCommandListener(OnJoinClass, "join_class");

	HideHudFor = 0.0;

	CreateTimer(2.0, HudTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	for(int i; i<view_as<int>(TFTeam); i++)
	{
		TeamClass[i] = view_as<TFClassType>(GetRandomInt(1, 10));
		SyncHud[i] = CreateHudSynchronizer();
	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client)
		return;

	int team = GetClientTeam(client);
	if(TF2_GetPlayerClass(client) == TeamClass[team])
		return;

	ClientCommand(client, "kill");
	SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(TeamClass[team]));
}

public Action OnPlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client)
		return Plugin_Continue;

	int team = GetClientTeam(client);
	if(event.GetInt("class") == view_as<int>(TeamClass[team]))
		return Plugin_Continue;

	event.SetInt("class", view_as<int>(TeamClass[team]));
	return Plugin_Changed;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	HideHudFor = GetGameTime()+15.0;

	for(int i; i<view_as<int>(TFTeam); i++)
	{
		TeamClass[i] = view_as<TFClassType>(GetRandomInt(1, 10));
	}

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client))
			SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(TeamClass[GetClientTeam(client)]));
	}
}

public Action OnJoinClass(int client, const char[] command, int args)
{
	if(!client)
		return Plugin_Continue;

	int team = GetClientTeam(client);
	if(GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass") != view_as<int>(TeamClass[team]))
		SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(TeamClass[team]));

	return Plugin_Handled;
}

public Action HudTimer(Handle timer)
{
	if(HideHudFor > GetGameTime())
		return Plugin_Continue;

	bool hasMember[6];
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsClientInGame(client))
			continue;

		bool alive = IsPlayerAlive(client);
		int team = GetClientTeam(client);
		if(team>1 || alive)
			hasMember[team] = true;

		if(alive && TeamClass[team]==TFClass_Civilian)
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 340.0);
	}

	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client))
			continue;

		bool isEngi = TeamClass[GetClientTeam(client)]==TFClass_Engineer;
		float size = 0.01;
		for(int i; i<view_as<int>(TFTeam); i++)
		{
			if(!hasMember[i])
				continue;

			SetHudTextParams(isEngi ? 0.16 : 0.01, size, 2.1, Color[i][0], Color[i][1], Color[i][2], 255);
			ShowSyncHudText(client, SyncHud[i], "%s: %s", TeamName[i], ClassName[TeamClass[i]]);
			size += 0.04;
		}
	}
	return Plugin_Continue;
}