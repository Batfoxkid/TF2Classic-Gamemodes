#pragma semicolon 1
#include <sourcemod>
#pragma newdecls required

#define MAJOR_REVISION	"1"
#define MINOR_REVISION	"0"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION	MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

public Plugin myinfo =
{
	name		=	"TF2Cx10",
	author		=	"Batfoxkid",
	description	=	"TF2x10 for Team Fortress 2 Classic",
	version		=	PLUGIN_VERSION
};

public void OnConfigsExecuted()
{
	SetConVarInt(FindConVar("tf2c_randomizer"), 4);
	SetConVarString(FindConVar("tf2c_randomizer_script"), "cfg/randomizer_x10.cfg");
}