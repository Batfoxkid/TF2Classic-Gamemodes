#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <sdkhooks>
#tryinclude <tf2c>
#pragma newdecls required

#define MAJOR_REVISION	"1"
#define MINOR_REVISION	"0"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

public Plugin myinfo =
{
	name		=	"Deathrun",
	author		=	"Batfoxkid",
	description	=	"Deathrun for Team Fortress 2 Classic",
	version		=	PLUGIN_VERSION
};

#define FAR_FUTURE	100000000.0
#define PREFIX		"\x01\x07666666[\x07ff7519Deathrun\x07666666]\x01"

#define CHARGE_BUTTON	IN_ATTACK2
#define HUD_Y		0.88
#define HUD_INTERVAL	0.2
#define HUD_LINGER	0.01
#define HUD_ALPHA	192
#define HUD_R_OK		255
#define HUD_G_OK		255
#define HUD_B_OK		255

#if !defined _tf2c_included
enum TFTeam
{
	TFTeam_Unassigned = 0,
	TFTeam_Spectator,
	TFTeam_Red,
	TFTeam_Blue,
	TFTeam_Green,
	TFTeam_Yellow
};
#endif

int RoundMode;

const int BossTeam = view_as<int>(TFTeam_Blue);
const int MercTeam = view_as<int>(TFTeam_Red);

bool SpeedMode;
int DeathHealth;
int Death;
int Queue[MAXPLAYERS+1];

Cookie Cookies;

ConVar CvarSpec;
ConVar CvarBonus;

public void OnPluginStart()
{
	HookEvent("teamplay_round_start", OnRoundSetup, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);

	LoadTranslations("common.phrases");

	Cookies = new Cookie("ff2_cookies_mk2", "Queue Points", CookieAccess_Protected);

	AddCommandListener(OnJoinTeam, "jointeam");
	AddCommandListener(BlockCommand, "build");
	AddCommandListener(BlockHaleCommand, "kill");
	AddCommandListener(BlockHaleCommand, "explode");

	RoundMode = -1;

	CvarSpec = FindConVar("mp_allowspectators");
	CvarBonus = FindConVar("mp_bonusroundtime");

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientPostAdminCheck(client);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if(AreClientCookiesCached(client))
	{
		static char buffer[8];
		Cookies.Get(client, buffer, sizeof(buffer));
		Queue[client] = StringToInt(buffer);
	}
	else
	{
		Queue[client] = 0;
	}

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnJoinTeam(int client, const char[] command, int args)
{
	if(!client || RoundMode<0)
		return Plugin_Continue;

	static char buffer[10];
	GetCmdArg(1, buffer, sizeof(buffer));
	if(!buffer[0])
		return Plugin_Continue;

	if(StrEqual(buffer, "red", false) || StrEqual(buffer, "blue", false) || StrEqual(buffer, "auto", false))
	{
		if(GetClientTeam(client) <= view_as<int>(TFTeam_Spectator))
		{
			if(Death == client)
			{
				ChangeClientTeam(client, BossTeam);
			}
			else
			{
				ChangeClientTeam(client, MercTeam);
				SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", 1);
			}
		}
	}
	else if(!Death && CvarSpec.BoolValue && StrEqual(buffer, "spectate", false))
	{
		ChangeClientTeam(client, view_as<int>(TFTeam_Spectator));
	}
	return Plugin_Handled;
}

public Action BlockHaleCommand(int client, const char[] command, int args)
{
	return (Death==client && RoundMode!=2) ? Plugin_Handled : Plugin_Continue;
}

public Action BlockCommand(int client, const char[] command, int args)
{
	return Plugin_Handled;
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(client == attacker)
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(Death != client)
		return Plugin_Continue;

	DeathHealth -= event.GetInt("damageamount");
	return Plugin_Continue;
}

public void OnRoundSetup(Event event, const char[] name, bool dontBroadcast)
{
	RoundMode = 0;
	SpeedMode = false;
	DeathHealth = 999;
	AssignTeams();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RoundMode = 1;
	AssignTeams();
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundMode = 2;

	for(int i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i))
			Queue[i] += 10;
	}
	CreateTimer(CvarBonus.FloatValue-0.5, OnRoundPre, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
	if(client && AreClientCookiesCached(client))
	{
		static char buffer[8];
		IntToString(Queue[client], buffer, sizeof(buffer));
		Cookies.Set(client, buffer);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(RoundMode!=1 || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if(Death == client)
	{
		static bool holding;
		if(holding)
		{
			if(!(buttons & IN_RELOAD))
				holding = false;
		}
		else if(buttons & IN_RELOAD)
		{
			SpeedMode = !SpeedMode;
			holding = true;
		}

		SetEntityHealth(client, DeathHealth);
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", SpeedMode ? 500.0 : 340.0);

		SetHudTextParams(-1.0, HUD_Y, HUD_INTERVAL+HUD_LINGER, HUD_R_OK, HUD_G_OK, HUD_B_OK, HUD_ALPHA);
		ShowHudText(client, 0, "Speed: %s (+reload)", SpeedMode ? "Enabled" : "Disabled");
	}
	else
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 300.0);
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
	}

	if((buttons & IN_JUMP) && !(GetEntityFlags(client) & FL_ONGROUND))
	{
		buttons &= ~IN_JUMP;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnRoundPre(Handle timer)
{
	int[] client = new int[MaxClients];
	int hale, points, clients;
	for(int i=1; i<=MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i)<=view_as<int>(TFTeam_Spectator))
			continue;

		client[clients++] = i;
		if(Queue[i] < points)
			continue;

		hale = i;
		points = Queue[i];
	}

	if(!hale)
	{
		ServerCommand("mp_timelimit 1");
		return Plugin_Continue;
	}

	Death = hale;
	Queue[hale] = 0;
	ChangeClientTeam(hale, BossTeam);
	for(int i; i<clients; i++)
	{
		if(client[i] != hale)
			ChangeClientTeam(client[i], MercTeam);
	}
	return Plugin_Continue;
}

void AssignTeams()
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i)<=view_as<int>(TFTeam_Spectator))
			continue;

		if(Death == i)
		{
			if(GetClientTeam(i) != BossTeam)
				ChangeClientTeam(i, BossTeam);

			#if defined _tf2c_included
			TF2_AddCondition(i, TFCond_RestrictToMelee);
			#endif
		}
		else if(GetClientTeam(i) != MercTeam)
		{
			ChangeClientTeam(i, MercTeam);
		}
	}
}