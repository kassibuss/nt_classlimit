#include <sourcemod>
#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name		= "Neotokyo Class Limits",
	author		= "kinoko, rain",
	description	= "Enables allowing class limits for competitive play without the need for manual tracking",
	version		= "0.1.1",
	url			= ""
};

ConVar g_Cvar_MaxRecons, g_Cvar_MaxAssaults, g_Cvar_MaxSupports;

public void OnPluginStart()
{
	g_Cvar_MaxRecons = CreateConVar("sm_maxrecons", "32", "Maximum amount of recons allowed per player per team", _, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxAssaults = CreateConVar("sm_maxassaults", "32", "Maximum amount of assaults allowed per player per team", _, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxSupports = CreateConVar("sm_maxsupports", "32", "Maximum amount of support allowed per player team", _, true, 0.0, true, float(MaxClients));

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
		PrintToChat(client, "Please select another class");
		PrintCenterText(client, "Please select another class");
		ClientCommand(client, "classmenu");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsClassAllowed(int client, int class)
{
	int num_players_in_class = GetNumPlayersOfClassInTeam(class, GetClientTeam(client));

	ConVar cvar_limit;

	if (class == CLASS_RECON)
	{
		cvar_limit = g_Cvar_MaxRecons;
	}
	else if (class == CLASS_ASSAULT)
	{
		cvar_limit = g_Cvar_MaxAssaults;
	}
	else if (class == CLASS_SUPPORT)
	{
		cvar_limit = g_Cvar_MaxSupports;
	}
	else
	{
		return false;
	}

	// if class is completely banned
	if (cvar_limit.IntValue == 0)
	{
		return false;
	}

	return num_players_in_class < cvar_limit.IntValue;
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
		if (GetClientTeam(client)!= team) // Player doesn't not have team; continue
		{
			continue;
		}
		if (!IsPlayerAlive(client)) // Player is not alive
		{
			continue;
		}
		if (GetPlayerClass(client)!= class) //player doesn't have class
		{
			continue;
		}
		number_of_players += 1;
	}
	return number_of_players;
}
// Backported from SourceMod/SourcePawn SDK for SM < 1.11 compatibility.
// Used here under GPLv3 license: https://www.sourcemod.net/license.php
// SourceMod (C) AlliedModders LLC.  All rights reserved.
#if SOURCEMOD_V_MAJOR <= 1 && SOURCEMOD_V_MINOR < 11
/**
 * Retrieves a numeric command argument given its index, from the current
 * console or server command. Will return 0 if the argument can not be
 * parsed as a number. Use GetCmdArgIntEx to handle that explicitly.
 *
 * @param argnum		Argument number to retrieve.
 * @return			  	Value of the command argument.
 */
stock int GetCmdArgInt(int argnum)
{
	char str[12];
	GetCmdArg(argnum, str, sizeof(str));

	return StringToInt(str);
}
#endif
