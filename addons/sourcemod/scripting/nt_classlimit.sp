#include <sourcemod>
#include <dhooks>

#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

#define STATE_PICKINGCLASS 3

public Plugin myinfo = {
	name		= "Neotokyo Class Limits",
	author		= "kinoko, rain",
	description	= "Enables allowing class limits for competitive play without the need for manual tracking",
	version		= "1.0.0",
	url			= "https://github.com/kassibuss/nt_classlimit"
};

ConVar g_Cvar_MaxRecons, g_Cvar_MaxAssaults, g_Cvar_MaxSupports;

char g_s_PluginTag[] = "[CLASS-LIMITS]";

public void OnPluginStart()
{
	Handle gd = LoadGameConfigFile("neotokyo/block_spawn");
	if (!gd)
	{
		SetFailState("Failed to load GameData");
	}
	DynamicDetour dd = DynamicDetour.FromConf(gd, "Fn_CNEOPlayer__PlayerReady");
	if (!dd)
	{
		SetFailState("Failed to create dynamic detour");
	}
	if (!dd.Enable(Hook_Pre, Detour_PlayerReady))
	{
		SetFailState("Failed to detour");
	}
	CloseHandle(gd);

	g_Cvar_MaxRecons = CreateConVar("sm_maxrecons", "32",
		"Maximum amount of recons allowed per player per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxAssaults = CreateConVar("sm_maxassaults", "32",
		"Maximum amount of assaults allowed per player per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxSupports = CreateConVar("sm_maxsupports", "32",
		"Maximum amount of support allowed per player team",
		_, true, 0.0, true, float(MaxClients));

	AddCommandListener(Cmd_OnClass, "setclass");

	if (!HookEventEx("game_round_start", OnRoundStart, EventHookMode_Pre))
	{
		SetFailState("Failed to hook event");
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}
		// Force all players to go through the class selection each round
		// regardless of their previous round class selection, to avoid anyone
		// bypassing the spawn restrictions by defaulting to their previous
		// round class selection.
		if (GetClientTeam(client) > TEAM_SPECTATOR)
		{
			int fallback_class = GetAllowedClass(client);
			if (fallback_class != CLASS_NONE)
			{
				SetPlayerClass(client, fallback_class);
			}
			ClientCommand(client, "playerstate_reverse");
		}
	}
}

public MRESReturn Detour_PlayerReady(DHookReturn hReturn, DHookParam hParams)
{
	int client = hParams.Get(1);

	// Bots *must* be allowed to spawn here to prevent a server crash
	if (IsFakeClient(client))
	{
		return MRES_Ignored;
	}

	// Can't respawn with different class once already spawned in the world
	if (IsPlayerAlive(client))
	{
		hReturn.Value = false;
		return MRES_Supercede;
	}

	if (!IsClassAllowed(client, GetPlayerClass(client)))
	{
		// If this class was not allowed, see if there's any available class
		int fallback_class = GetAllowedClass(client);

		// If all the classes are full, just allow the player to spawn,
		// and print a warning to global chat. This is necessary because otherwise
		// this client would eventually spawn with no class, in a bugged state.
		// Another alternative would be to forcibly yeet them to spectator,
		// but this could be problematic in itself for competitive play due to
		// possible ghosting.
		// This can only happen if the sum of (sm_maxrecons + sm_maxassaults + sm_maxsupports)
		// cvars is less than the number of players in a player team (Jin or NSF).
		if (fallback_class == CLASS_NONE)
		{
			return MRES_Ignored;
		}

		// If there was a class available, force it as the player's default class.
		// This prevents a stubborn player from spawning with a forbidden class
		// if they just opt to wait out the max. spawn selection time without
		// choosing another class.
		SetPlayerClass(client, fallback_class);

		// Rewind the player state & prevent this spawn sequence from happening
		SetPlayerState(client, STATE_PICKINGCLASS);
		hReturn.Value = false;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

int GetAllowedClass(int client)
{
	for (int class = CLASS_RECON; class <= CLASS_SUPPORT; ++class)
	{
		if (IsClassAllowed(client, class))
		{
			return class;
		}
	}

	// This can happen if the sum of sm_maxrecons + sm_maxassaults + sm_maxsupports
	// is less than the number of players in a team. For example, if only 5 players
	// are allowed per class, but there's more than 3*5 players, the 16th player
	// would have no valid class left. This is not a plugin bug per se, but rather
	// a server misconfiguration regarding the abovementioned cvar limits.
	// TLDR: the sum of the 3 cvars should *always* be >= expected number of players
	// in a playable team (Jinrai or NSF).
	PrintToChatAll("%s WARNING: all class limits are exhausted!", g_s_PluginTag);

	return CLASS_NONE;
}

void SetPlayerState(int client, int state)
{
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(
			SDKLibrary_Server,
			"\x56\x8B\xF1\x8B\x86\x68\x0E\x00\x00",
			9
		);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			SetFailState("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client, state);
}

public Action Cmd_OnClass(int client, const char[] command, int argc)
{
	if (argc != 1)
	{
		return Plugin_Continue;
	}

	if (IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}

	int desired_class = GetCmdArgInt(1);

	if (!IsClassAllowed(client, desired_class))
	{
		PrintToChat(client, "%s Please select another class", g_s_PluginTag);
		PrintCenterText(client, "- CLASS IS FULL -");
		ClientCommand(client, "classmenu");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

bool IsClassAllowed(int client, int class)
{
	int num_players_in_class = GetNumPlayersOfClassInTeam(
		class, GetClientTeam(client)
	);

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
		if (GetClientTeam(client) != team)
		{
			continue;
		}
		if (!IsPlayerAlive(client))
		{
			continue;
		}
		if (GetPlayerClass(client) != class)
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
