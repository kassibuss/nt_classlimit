#include <sourcemod>
#include <sdktools>
#include <dhooks>

#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

enum PlayerState {
	STATE_ALIVE = 0,
	STATE_INTRO,
	STATE_PICKINGTEAM,
	STATE_PICKINGCLASS,
	STATE_PICKINGLOADOUT,
	STATE_PLAYERDEATH,
	STATE_DEAD,
	STATE_OBSERVERMODE,

	STATE_MAX_VALUE = STATE_OBSERVERMODE
};

enum PlayerStatePfn {
	PFN_ENTER_STATE = 0,
	PFN_LEAVE_STATE,
	PFN_PRETHINK,

	PFN_ENUM_COUNT
};
/*	PlayerStateInfo memory layout:
	0	CPlayerState m_iPlayerState;
	4	const char *m_pStateName;

	8	void (CPlayer::*pfnEnterState)();
	24	void (CPlayer::*pfnLeaveState)();

	40	void (CPlayer::*pfnPreThink)();
	56
*/
int g_i_PfnOffsets[view_as<int>(PFN_ENUM_COUNT)] = { 8, 24, 40 };

char g_s_PluginTag[] = "[CLASS-LIMITS]";
char g_s_classnames[][] = { "None", "Recon", "Assault", "Support" };

ConVar g_Cvar_MaxRecons, g_Cvar_MaxAssaults, g_Cvar_MaxSupports,
	g_Cvar_InfractionMode;

DHookCallback g_PfnCbIds[view_as<int>(PFN_ENUM_COUNT)] = { INVALID_FUNCTION, ... };
HookMode g_pfnHookMode = Hook_Pre;

PlayerState g_e_PlayerState[NEO_MAXPLAYERS + 1] = { STATE_OBSERVERMODE, ... };

// Infraction modes. These should not be reordered for config compatibility.
enum {
	IM_IGNORE = 0,
	IM_SLAY,
	IM_WARN,
	IM_ENUM_COUNT
}

void CNEOPlayer__State_Enter(int client, PlayerState state)
{
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(SDKLibrary_Server,
			"\x56\x8B\xF1\x8B\x86\x68\x0E\x00\x00", 9);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			SetFailState("Failed to prepare SDK call");
		}
	}
	SDKCall(call, client, state);
}

public Plugin myinfo = {
	name		= "Neotokyo Class Limits",
	author		= "kinoko, rain",
	description	= "Enables allowing class limits for competitive play without the need for manual tracking",
	version		= "1.5.1",
	url		= "https://github.com/kassibuss/nt_classlimit"
};

public void OnPluginStart()
{
	g_Cvar_MaxRecons = CreateConVar("sm_maxrecons", "32",
		"Maximum amount of recons allowed per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxAssaults = CreateConVar("sm_maxassaults", "32",
		"Maximum amount of assaults allowed per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxSupports = CreateConVar("sm_maxsupports", "32",
		"Maximum amount of supports allowed per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_InfractionMode = CreateConVar("sm_classlimit_infraction_mode", "2",
		"How should nt_classlimit react to class selection infractions. \
0: do nothing, 1: slay the player, 2: warn everyone",
		_, true, 0.0, true, float(IM_ENUM_COUNT - 1));

	AddCommandListener(Cmd_OnSetSkin, "SetVariant");
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);

	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}
		HookClassSelectionPfns(client);
		break;
	}
	
	RegAdminCmd("sm_classlimit", Command_Limit, ADMFLAG_GENERIC);
	RegAdminCmd("sm_classlimits", Command_Limit, ADMFLAG_GENERIC);
	
	// Create the default config file, if it doesn't exist yet
	AutoExecConfig();
}

public Action Command_Limit(int client, int args)
{
	if (args != 1)
	{
		char argName[32];
		if (!GetCmdArg(0, argName, sizeof(argName)))
		{
			ThrowError("Failed to get command name");
		}
		char triggers[1+1];
#if SOURCEMOD_V_MAJOR < 1 || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR <= 11)
		triggers[0] = '!';
#else
		if (!GetPublicChatTriggers(triggers, sizeof(triggers)))
		{
			ThrowError("Failed to get public chat triggers");
		}
#endif
		ReplyToCommand(client, "%s Usage \"%c%s x\" where x sets the limit for all classes",
			g_s_PluginTag, triggers[0], argName);
		return Plugin_Handled;
	}

	int limit = GetCmdArgInt(1);

	if(limit < 1 || limit > MaxClients)
	{
		ReplyToCommand(client, "%s Invalid limit, limits have not been changed", g_s_PluginTag);
		return Plugin_Handled;
	}

	g_Cvar_MaxRecons.SetInt(limit);
	g_Cvar_MaxAssaults.SetInt(limit);
	g_Cvar_MaxSupports.SetInt(limit);
	
	PrintToChatAll("%s Class limit set to %d each", g_s_PluginTag, limit);
	
	return Plugin_Handled;
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Cvar_InfractionMode.IntValue == IM_IGNORE)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client == 0 || GetClientTeam(client) <= TEAM_SPECTATOR)
	{
		return;
	}

	if (g_Cvar_InfractionMode.IntValue == IM_SLAY && !IsClassAllowed(client, GetPlayerClass(client)))
	{
		CreateTimer(0.1, Timer_DeferSlay, GetClientUserId(client));
	}
	
	char msg[128];
	
	if (g_Cvar_InfractionMode.IntValue == IM_WARN && !IsClassAllowed(client, GetPlayerClass(client)))
	{
		Format(msg, sizeof(msg), "%s %N spawned with disallowed class!", g_s_PluginTag, client);
		PrintToChatAll(msg);
		PrintToConsoleAll(msg);
		LogToGame(msg);
	}
}

public Action Timer_DeferSlay(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0 || !IsPlayerAlive(client) ||
		GetClientTeam(client) <= TEAM_SPECTATOR)
	{
		return Plugin_Stop;
	}

	FakeClientCommand(client, "kill");
	SetPlayerXP(client, GetPlayerXP(client) + 1); // undo XP loss
	PrintToChatAll("%s Slayed player \"%N\" for class infraction",
		g_s_PluginTag, client);

	return Plugin_Stop;
}

public MRESReturn PfnHook_EnterState_PickingClass(int client)
{
	SetPlayerState(client, STATE_PICKINGCLASS);
	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_PickingClass(int client)
{
	if (g_e_PlayerState[client] != STATE_PICKINGCLASS &&
		g_e_PlayerState[client] != STATE_PICKINGLOADOUT)
	{
		return MRES_Ignored;
	}

	int class = GetPlayerClass(client);
	if (class < CLASS_RECON || class > CLASS_SUPPORT)
	{
		return MRES_Ignored;
	}

	if (!IsClassAllowed(client, class))
	{
		// Need to check because otherwise we'll endlessly attempt to revert
		// the class selection, eventually overflowing the client's memory.
		if (GetAllowedClass(client) == CLASS_NONE)
		{
			return MRES_Ignored;
		}

		if (CanPrintFor(client))
		{
			PrintToChat(
				client,
				"%s %s class is full! Please select another class",
				g_s_PluginTag, g_s_classnames[class]
			);
			PrintCenterText(
				client,
				"- CLASS %s IS FULL -",
				g_s_classnames[class]
			);
		}

		CreateTimer(0.1, Timer_DeferStateReset, GetClientUserId(client),
			TIMER_FLAG_NO_MAPCHANGE);
		ClientCommand(client, "setclass %d", GetAllowedClass(client));
	}

	return MRES_Ignored;
}

bool CanPrintFor(int client=0, float limit=1.0)
{
	static float last_print_time[NEO_MAXPLAYERS + 1];
	float time_now = GetTickedTime();
	float delta_time = time_now - last_print_time[client];
	bool res = delta_time >= limit;
	if (res)
	{
		last_print_time[client] = time_now;
	}
	return res;
}

// Hooks the class selection relevant state change functions for the given client
void HookClassSelectionPfns(int client)
{
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_ENTER_STATE,
		PfnHook_EnterState_PickingClass);
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_PRETHINK,
		PfnHook_PreThink_PickingClass);
}

// Retrieves the function pointer for the specified player state and ptr type
Address GetPfn(int client, PlayerState state, PlayerStatePfn pfn)
{
	Address base = State_LookupInfo(client, state);
	if (base == Address_Null)
	{
		ThrowError("Player state base address was null");
	}
	int offset = g_i_PfnOffsets[pfn];
	Address address = base + view_as<Address>(offset);
	return view_as<Address>(LoadFromAddress(address, NumberType_Int32));
}

void HookPlayerState(int client, PlayerState state, PlayerStatePfn pfn,
	DHookCallback cb)
{
	// only need to hook once
	if (g_PfnCbIds[pfn] != INVALID_FUNCTION)
	{
		return;
	}

	Address fn = GetPfn(client, state, pfn);
	// note that this is not an error; the function pointer can be null
	if (fn == Address_Null)
	{
		return;
	}

	DynamicDetour dd = DHookCreateDetour(fn, CallConv_THISCALL, ReturnType_Void,
		ThisPointer_CBaseEntity);
	if (!dd.Enable(g_pfnHookMode, cb))
	{
		ThrowError("Failed to detour pfn %d", pfn);
	}
	g_PfnCbIds[pfn] = cb;
	delete dd;
}

public void OnClientPutInServer(int client)
{
	// Has to be a real client because the classes differ
	if (IsFakeClient(client))
	{
		return;
	}

	SetPlayerState(client, STATE_OBSERVERMODE);
	HookClassSelectionPfns(client);
}

public Action Timer_DeferStateReset(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == 0 || IsPlayerAlive(client) ||
		GetClientTeam(client) <= TEAM_SPECTATOR)
	{
		return Plugin_Stop;
	}

	CNEOPlayer__State_Enter(client, STATE_PICKINGCLASS);

	return Plugin_Stop;
}

// Retrieves the first allowed class for the given client based on class limits,
// or CLASS_NONE if no such class exists.
int GetAllowedClass(int client, bool warn_if_none=true)
{
	for (int class = CLASS_RECON; class <= CLASS_SUPPORT; ++class)
	{
		if (IsClassAllowed(client, class))
		{
			return class;
		}
	}

	// This can happen if the sum of (sm_maxrecons + sm_maxassaults +
	// sm_maxsupports) is less than the number of players in a team.
	// For example, if only 5 players are allowed per class, but there's more
	// than 3 * 5 players, the 16th player would have no valid class left.
	// This is not a plugin bug per se, but rather a server misconfiguration
	// regarding the abovementioned cvar limits.
	//
	// TLDR: the sum of the 3 cvars should *always* be >= expected number of
	// players in a playable team (Jinrai or NSF).
	if (warn_if_none)
	{
		if (CanPrintFor(0, 15.0))
		{
			PrintToChatAll(
				"%s WARNING: all class limits are exhausted!",
				g_s_PluginTag
			);
			static bool has_logged_error = false;
			if (!has_logged_error)
			{
				LogError("All class limits are exhausted! \
This is a config error, please see the plugin docs for details.");
				has_logged_error = true;
			}
		}
	}

	return CLASS_NONE;
}

// Returns the raw memory address of the player state info for the specified
// client and state.
// Can return 0 (nullptr) for ptrfunctions with no value set.
Address State_LookupInfo(int client, PlayerState state)
{
	static Handle call = INVALID_HANDLE;
	if (call == INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetSignature(
			SDKLibrary_Server,
			"\xF6\x05\x2A\x2A\x2A\x2A\x01\x0F\x85\x2A\x2A\x2A\x2A\xB8\x2A\x2A\x2A\x2A",
			18
		);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		call = EndPrepSDKCall();
		if (call == INVALID_HANDLE)
		{
			SetFailState("Failed to prepare SDK call");
		}
	}

	return SDKCall(call, client, view_as<int>(state));
}

// Command callback function for the "setclass" command.
public Action Cmd_OnSetSkin(int client, const char[] command, int argc)
{
	if (argc != 1 || IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if (GetClientTeam(client) <= TEAM_SPECTATOR)
	{
		return Plugin_Continue;
	}

	SetPlayerState(client, STATE_PICKINGLOADOUT);
	return Plugin_Continue;
}

void SetPlayerState(int client, PlayerState state)
{
	g_e_PlayerState[client] = state;
}

// Returns whether the specified class is allowed for the given client based on
// class limits.
bool IsClassAllowed(int client, int class)
{
	int num_players_in_class = GetNumPlayersOfClassInTeam(
		class, GetClientTeam(client), client
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

// Retrieves the number of players with the specified class in the given team.
int GetNumPlayersOfClassInTeam(int class, int team, int ignore_client=-1)
{
	int number_of_players = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client == ignore_client)
		{
			continue;
		}
		if (!IsClientInGame(client))
		{
			continue;
		}
		if (GetClientTeam(client) != team)
		{
			continue;
		}
		if (GetPlayerClass(client) != class)
		{
			continue;
		}
		// Consider someone who's chosen the class and is currently in the
		// loadout selection screen as having reserved the right to spawn
		// with this class.
		if (!IsPlayerAlive(client) &&
			g_e_PlayerState[client] != STATE_PICKINGLOADOUT)
		{
			continue;
		}
		number_of_players += 1;
	}
	return number_of_players;
}

// Functions backported from SourceMod/SourcePawn SDK for older SM compatibility.
// Used here under GPLv3 license: https://www.sourcemod.net/license.php
// SourceMod (C) AlliedModders LLC.  All rights reserved.
#if SOURCEMOD_V_MAJOR < 1 || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR <= 10)
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

#if SOURCEMOD_V_MAJOR < 1 || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR <= 8)
/**
 * Sends a message to every client's console.
 *
 * @param format		Formatting rules.
 * @param ...		   Variable number of format parameters.
 */
stock void PrintToConsoleAll(const char[] format, any ...)
{
	char buffer[254];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToConsole(i, "%s", buffer);
		}
	}
}
#endif
