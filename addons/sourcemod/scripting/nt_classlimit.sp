#include <sourcemod>
#include <dhooks>

#include <neotokyo>

#pragma semicolon 1
#pragma newdecls required

enum PlayerState {
	STATE_UNKNOWN = 0,
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

ConVar g_Cvar_MaxRecons, g_Cvar_MaxAssaults, g_Cvar_MaxSupports;

DynamicDetour g_dd_Pfn = null;
DHookCallback g_PfnCbIds[view_as<int>(PFN_ENUM_COUNT)] = { INVALID_FUNCTION, ... };
HookMode g_pfnHookMode = Hook_Pre;

PlayerState g_e_PlayerState[NEO_MAXPLAYERS + 1] = { STATE_UNKNOWN, ... };

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
	g_e_PlayerState[client] = state;
}

public Plugin myinfo = {
	name		= "Neotokyo Class Limits",
	author		= "kinoko, rain",
	description	= "Enables allowing class limits for competitive play without the need for manual tracking",
	version		= "1.0.2",
	url			= "https://github.com/kassibuss/nt_classlimit"
};

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
		"Maximum amount of recons allowed per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxAssaults = CreateConVar("sm_maxassaults", "32",
		"Maximum amount of assaults allowed per team",
		_, true, 0.0, true, float(MaxClients));
	g_Cvar_MaxSupports = CreateConVar("sm_maxsupports", "32",
		"Maximum amount of supports allowed per team",
		_, true, 0.0, true, float(MaxClients));

	AddCommandListener(Cmd_OnClass, "setclass");

	if (!HookEventEx("game_round_start", OnRoundStart, EventHookMode_Post) ||
		!HookEventEx("player_spawn", OnPlayerSpawn, EventHookMode_Post))
	{
		SetFailState("Failed to hook event");
	}

	for (int client = 1; client <= MaxClients; ++client)
	{
		if (!IsClientInGame(client) || IsFakeClient(client))
		{
			continue;
		}
		HookClassSelectionPfns(client);
		break;
	}

	// Create the default config file, if it doesn't exist yet
	AutoExecConfig();
}

// Hooks the player state change functions for the given client and state.
void HookClassSelectionPfns(int client)
{
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_ENTER_STATE,
		PfnHook_EnterState_PickingClass);
	HookPlayerState(client, STATE_PICKINGLOADOUT, PFN_ENTER_STATE,
		PfnHook_EnterState_PickingLoadout);
	HookPlayerState(client, STATE_PICKINGLOADOUT, PFN_LEAVE_STATE,
		PfnHook_LeaveState_PickingLoadout);
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

	if (!g_dd_Pfn)
	{
		g_dd_Pfn = DHookCreateDetour(fn, CallConv_THISCALL, ReturnType_Void,
			ThisPointer_CBaseEntity);
		if (!g_dd_Pfn)
		{
			ThrowError("Failed to create detour for pfn %d", pfn);
		}
	}

	if (!g_dd_Pfn.Enable(g_pfnHookMode, cb))
	{
		ThrowError("Failed to detour pfn %d", pfn);
	}

	g_PfnCbIds[pfn] = cb;
}

// Detour for the player state ptr STATE_PICKINGCLASS -> PFN_ENTER_STATE
public MRESReturn PfnHook_EnterState_PickingClass(int client)
{
	g_e_PlayerState[client] = STATE_PICKINGCLASS;
	return MRES_Ignored;
}

// Detour for the player state ptr STATE_PICKINGLOADOUT -> PFN_ENTER_STATE
public MRESReturn PfnHook_EnterState_PickingLoadout(int client)
{
	g_e_PlayerState[client] = STATE_PICKINGLOADOUT;
	return MRES_Ignored;
}

// Detour for the player state ptr STATE_PICKINGLOADOUT -> PFN_LEAVE_STATE
public MRESReturn PfnHook_LeaveState_PickingLoadout(int client)
{
	// just labeling any other state as "unknown", since we're not interested
	// in keeping track of it
	g_e_PlayerState[client] = STATE_UNKNOWN;
	return MRES_Ignored;
}

public void OnClientPutInServer(int client)
{
	// Has to be a real client because the classes differ
	if (IsFakeClient(client))
	{
		return;
	}

	if (!g_dd_Pfn)
	{
		HookClassSelectionPfns(client);
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
			if (g_e_PlayerState[client] != STATE_PICKINGCLASS)
			{
				SetPlayerClass(client, CLASS_NONE);
				CNEOPlayer__State_Enter(client, STATE_PICKINGCLASS);
			}
		}
	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_e_PlayerState[client] = STATE_UNKNOWN;
}

public MRESReturn Detour_PlayerReady(DHookReturn hReturn, DHookParam hParams)
{
	int client = hParams.Get(1);

	// Bots *must* be allowed to spawn here to prevent a server crash
	if (IsFakeClient(client))
	{
		return MRES_Ignored;
	}

	// Already spawned in the world
	if (IsPlayerAlive(client))
	{
		return MRES_Ignored;
	}

	if (IsClassAllowed(client, GetPlayerClass(client)))
	{
		return MRES_Ignored;
	}

	// If this class was not allowed, see if there's any available class
	int fallback_class = GetAllowedClass(client);

	// If all the classes are full, just allow the player to spawn.
	// This is necessary because otherwise
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

	if (g_e_PlayerState[client] != STATE_PICKINGLOADOUT)
	{
		return MRES_Ignored;
	}

	// If there was a class available, force it as the player's default class.
	// This prevents a stubborn player from spawning with a forbidden class
	// if they just opt to wait out the max. spawn selection time without
	// choosing another class.
	SetPlayerClass(client, fallback_class);


	hReturn.Value = false;
	return MRES_Supercede;
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

	// This can happen if the sum of sm_maxrecons + sm_maxassaults +
	// sm_maxsupports is less than the number of players in a team.
	// For example, if only 5 players are allowed per class, but there's more
	// than 3*5 players, the 16th player would have no valid class left.
	// This is not a plugin bug per se, but rather a server misconfiguration
	// regarding the abovementioned cvar limits.
	//
	// TLDR: the sum of the 3 cvars should *always* be >= expected number of
	// players in a playable team (Jinrai or NSF).
	if (warn_if_none)
	{
		PrintToChatAll("%s WARNING: all class limits are exhausted!",
			g_s_PluginTag);
		PrintToChatAll("This is a server config error. Allowing all classes \
to spawn.");
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
		CNEOPlayer__State_Enter(client, STATE_PICKINGCLASS);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Returns whether the specified class is allowed for the given client based on
// class limits.
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

// Retrieves the number of players with the specified class in the given team.
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
