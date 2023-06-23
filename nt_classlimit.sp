#include <sourcemod>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name		= "Neotokyo Class Limits",
	author		= "kinoko, rain",
	description	= "Enables allowing class limits for competitive play without the need for manual tracking",
	version		= "0.1.0",
	url			= ""
};

ConVar g_Cvar_MaxRecons, g_Cvar_MaxAssaults, g_Cvar_MaxSupports;

public void OnPluginStart()
{
	g_Cvar_MaxRecons = CreateConVar("sm_maxrecons", "32", "Maximum amount of recons allowed per player per team", _, true, 1.0, true, float(MaxClients));
	g_Cvar_MaxAssaults = CreateConVar("sm_maxassaults", "32", "Maximum amount of assaults allowed per player per team", _, true, 1.0, true, float(MaxClients));
	g_Cvar_MaxSupports = CreateConVar("sm_maxsupports", "32", "Maximum amount of support allowed per player team", _, true, 1.0, true, float(MaxClients));

	AddCommandListener(Cmd_OnClass, "setclass");
}

public Action Cmd_OnClass(int client, const char[] command, int argc)
{
	if (argc != 1)
	{
		return Plugin_Continue;
	}

	int desired_class = GetCmdArgInt(1);

	if (!IsClassAllowed(client, desired_class))
	{
		// re-display the menu etc here
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsClassAllowed(int client, int class)
{
	int num_players_in_class = GetNumPlayersOfClassInTeam(class, GetClientTeam(client));

	switch (class)
	{
		case CLASS_RECON:
			return num_players_in_class < g_Cvar_MaxRecons.IntValue;
		case CLASS_ASSAULT:
			return num_players_in_class < g_Cvar_MaxAssaults.IntValue;
		case CLASS_SUPPORT:
			return num_players_in_class < g_Cvar_MaxSupports.IntValue;
		default:
			// player had class other than recon/assault/support?
			return false;
	}
}

int GetNumPlayersOfClassInTeam(int class, int team)
{
	int number_of_players = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) 
		{
			continue;
		}
		if (GetClientTeam(client)!= 1) // Spectator or no team assigned
		{
			continue;
		}
		if (!IsPlayerAlive(client)) // Player is not alive
		{
			continue;
		}
		if (!GetPlayerClass(client)) //player doesnt have class
		{
			continue;
		}

		number_of_players += 1;
	}
	return number_of_players;
}
