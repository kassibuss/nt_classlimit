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

public void OnClientDisconnect(int client)
{
    g_iPlayerClass[client] = CLASS_NONE; // Clear class of disconnecting player
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; ++client)
    {
        g_iPlayerClass[client] = CLASS_NONE;
    }
}

public Action Cmd_OnClass(int client, const char[] command, int argc)
{
#if(DEBUG_HOOK_ALL)

    PrintToServer("We've got: %s -> %d", command, argc);
    
    return Plugin_Continue;

#else

    if (argc !=1)
    {
    return Plugin_Continue;
    }

    int desired_class = GetCmdArgInt(1);
    
      if (!IsClassAllowed(client, desired_class))
    {
        // re-display the menu etc here
        return Plugin_Handled;
    }
    
    g_iPlayerClass[client] = desired_class;
    return Plugin_Continue;
#endif 
}

bool IsClassAllowed(int client, int class)
{
    int num_players_in_class = GetNumPlayersOfClassInTeam(class, GetClientTeam(client));

    return num_players_in_class < g_cvarMaxPlayersPerRecon.IntValue;
    return num_players_in_class < g_cvarMaxPlayersPerAssault.IntValue;
    return num_players_in_class < g_cvarMaxPlayersPerSupport.IntValue;
}



int GetNumPlayersOfClassInTeam(int class, int team)
{
    int number_of_players = 0;
for (int client = 1; client <= MaxClients; client++)
{
    if (!IsClientInGame(client))
    {
        continue; // means "stop this loop iteration and continue to the next"
    }
    // rest of the checks; "continue" if check didn't pass

    // all checks passed, increment value
    number_of_players += 1;
}
return number_of_players;
}

