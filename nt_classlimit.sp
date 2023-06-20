#include <sourcemod>
#include <neotokyo>

#pragma semicolon 1 
#pragma newdecls required

public Plugin myinfo = {
    name        = "Neotokyo Class Limits",
    author      = "kinoko",
    description = "Enables allowing class limits for competitive play without the need for manual tracking",
    version     = "0.1.0",
    url         = ""
};

#define DEBUG_HOOK_ALL false

int g_iPlayerClass[NEO_MAXPLAYERS + 1] = { CLASS_NONE, ... };
ConVar g_cvarMaxPlayersPerRecon;
ConVar g_cvarMaxPlayersPerAssault;
ConVar g_cvarMaxPlayersPerSupport;

public void OnPluginStart()
{



    g_Cvar_MaxRecons = CreateConVar("sm_maxrecons", "32", "Maximum amount of recons allowed per player per team", _, true, 1, true, float(MaxClients) );
	g_Cvar_MaxAssaults = CreateConVar("sm_maxassaults", "32", "Maximum amount of assaults allowed per player per team", _, true, 1, true, float(MaxClients));
	g_Cvar_MaxSupports = CreateConVar("sm_maxsupports", "32", "Maximum amount of support allowed per player team", _, true, 1, true, float(MaxClients));
    );
	
    HookEvent("game_round_start", OnRoundStart);
}	

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Clear any classes from the previous round
    for (int client = 1; client <= MaxClients; ++client)
    {
        g_iPlayerClass[client] = CLASS_NONE;
    }
}
