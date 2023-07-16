#include <sourcemod>
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

ConVar g_Cvar_MaxRecons, g_Cvar_MaxAssaults, g_Cvar_MaxSupports;

DHookCallback g_PfnCbIds[view_as<int>(PFN_ENUM_COUNT)] = { INVALID_FUNCTION, ... };
HookMode g_pfnHookMode = Hook_Pre;

PlayerState g_e_PlayerState[NEO_MAXPLAYERS + 1] = { STATE_OBSERVERMODE, ... };

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
	version		= "1.1.0",
	url			= "https://github.com/kassibuss/nt_classlimit"
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

	AddCommandListener(Cmd_OnSetSkin, "SetVariant");

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

public MRESReturn PfnHook_EnterState_PickingClass(int client)
{
	PrintToServer("PfnHook_EnterState_PickingClass: %N", client);
	SetPlayerState(client, STATE_PICKINGCLASS);
	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_PickingClass(int client)
{
	if (g_e_PlayerState[client] != STATE_PICKINGCLASS)
	{
		return MRES_Ignored;
	}

	//PrintToServer("Got here?");

	int class = GetPlayerClass(client);
	if (class == CLASS_NONE)
	{
		return MRES_Ignored;
	}

	if (!IsClassAllowed(client, class))
	{
		PrintToChat(client, "%s Please select another class", g_s_PluginTag);
		PrintCenterText(client, "- CLASS IS FULL -");

		CreateTimer(0.1, Timer_DeferStateReset, GetClientUserId(client),
			TIMER_FLAG_NO_MAPCHANGE);
		ClientCommand(client, "setclass 2");
	}

	return MRES_Ignored;
}

#if(0)
public MRESReturn PfnHook_EnterState_Unknown(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_Unknown (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_Intro(int client)
{
	if (client == -1)
	{
		PrintToServer("PfnHook_EnterState_Intro: client was %d", client);
		return MRES_Ignored;
	}

	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_Intro (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_PickingTeam(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_PickingTeam (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_PickingClass(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_PickingClass (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_PickingLoadout(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_PickingLoadout (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_PlayerDeath(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_PlayerDeath (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_Dead(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_Dead"); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_EnterState_ObserverMode(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_EnterState_ObserverMode (client %d)", client); }
	return MRES_Ignored;
}


public MRESReturn PfnHook_LeaveState_Unknown(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_Unknown (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_Intro(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_Intro (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_PickingTeam(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_PickingTeam (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_PickingClass(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_PickingClass (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_PickingLoadout(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_PickingLoadout (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_PlayerDeath(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_PlayerDeath (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_Dead(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_Dead (client %d)", client); }
	return MRES_Ignored;
}

public MRESReturn PfnHook_LeaveState_ObserverMode(int client)
{
	if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_LeaveState_ObserverMode (client %d)", client); }
	return MRES_Ignored;
}


public MRESReturn PfnHook_PreThink_Unknown(int client)
{
	bool once_only = false;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_Unknown (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_Intro(int client)
{
	bool once_only = true;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_Intro (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_PickingClass(int client)
{
	bool once_only = false;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_PickingClass (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_PickingTeam(int client)
{
	bool once_only = false;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_PickingTeam (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_PickingLoadout(int client)
{
	bool once_only = false;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_PickingLoadout (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_PlayerDeath(int client)
{
	bool once_only = true;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_PlayerDeath (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_Dead(int client)
{
	bool once_only = true;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_Dead (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}

public MRESReturn PfnHook_PreThink_ObserverMode(int client)
{
	bool once_only = true;
	if (IsFakeClient(client)) { return MRES_Ignored; }
	static bool triggered;
	if (!once_only || !triggered)
	{
		if (!IsFakeClient(client)) { PrintToServer("Hello from PfnHook_PreThink_ObserverMode (client %d)", client); }
		triggered = !triggered;
	}

	return MRES_Ignored;
}
#endif

// Hooks the player state change functions for the given client and state.
void HookClassSelectionPfns(int client)
{
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_ENTER_STATE,
		PfnHook_EnterState_PickingClass);
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_PRETHINK,
		PfnHook_PreThink_PickingClass);

#if(0)
	HookPlayerState(client, STATE_UNKNOWN, PFN_ENTER_STATE, PfnHook_EnterState_Unknown);
	HookPlayerState(client, STATE_UNKNOWN, PFN_LEAVE_STATE, PfnHook_LeaveState_Unknown);
	HookPlayerState(client, STATE_UNKNOWN, PFN_PRETHINK, PfnHook_PreThink_Unknown);

	HookPlayerState(client, STATE_INTRO, PFN_ENTER_STATE, PfnHook_EnterState_Intro);
	HookPlayerState(client, STATE_INTRO, PFN_LEAVE_STATE, PfnHook_LeaveState_Intro);
	HookPlayerState(client, STATE_INTRO, PFN_PRETHINK, PfnHook_PreThink_Intro);

	HookPlayerState(client, STATE_PICKINGTEAM, PFN_ENTER_STATE, PfnHook_EnterState_PickingTeam);
	HookPlayerState(client, STATE_PICKINGTEAM, PFN_LEAVE_STATE, PfnHook_LeaveState_PickingTeam);
	HookPlayerState(client, STATE_PICKINGTEAM, PFN_PRETHINK, PfnHook_PreThink_PickingTeam);

	HookPlayerState(client, STATE_PICKINGCLASS, PFN_ENTER_STATE, PfnHook_EnterState_PickingClass);
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_LEAVE_STATE, PfnHook_LeaveState_PickingClass);
	HookPlayerState(client, STATE_PICKINGCLASS, PFN_PRETHINK, PfnHook_PreThink_PickingClass);

	HookPlayerState(client, STATE_PLAYERDEATH, PFN_ENTER_STATE, PfnHook_EnterState_PlayerDeath);
	HookPlayerState(client, STATE_PLAYERDEATH, PFN_LEAVE_STATE, PfnHook_LeaveState_PlayerDeath);
	HookPlayerState(client, STATE_PLAYERDEATH, PFN_PRETHINK, PfnHook_PreThink_PlayerDeath);

	HookPlayerState(client, STATE_DEAD, PFN_ENTER_STATE, PfnHook_EnterState_Dead);
	HookPlayerState(client, STATE_DEAD, PFN_LEAVE_STATE, PfnHook_LeaveState_Dead);
	HookPlayerState(client, STATE_DEAD, PFN_PRETHINK, PfnHook_PreThink_Dead);

	HookPlayerState(client, STATE_OBSERVERMODE, PFN_ENTER_STATE, PfnHook_EnterState_ObserverMode);
	HookPlayerState(client, STATE_OBSERVERMODE, PFN_LEAVE_STATE, PfnHook_LeaveState_ObserverMode);
	HookPlayerState(client, STATE_OBSERVERMODE, PFN_PRETHINK, PfnHook_PreThink_ObserverMode);
#endif
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

	//CallPlayerStatePfn(client, STATE_PICKINGLOADOUT, PFN_LEAVE_STATE);
	//CallPlayerStatePfn(client, STATE_PLAYERDEATH, PFN_ENTER_STATE);
	//CallPlayerStatePfn(client, STATE_PLAYERDEATH, PFN_LEAVE_STATE);
	//CallPlayerStatePfn(client, STATE_OBSERVERMODE, PFN_ENTER_STATE);
	//CallPlayerStatePfn(client, STATE_OBSERVERMODE, PFN_LEAVE_STATE);

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
	PrintToServer("SetPlayerState (%d): %d", client, state);
	g_e_PlayerState[client] = state;
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

// TODO: needed?
stock void CallPlayerStatePfn(int client, PlayerState state, PlayerStatePfn pfn)
{
	Address fn = GetPfn(client, state, pfn);
	if (fn == Address_Null)
	{
		return;
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetAddress(fn);
	Handle call = EndPrepSDKCall();
	if (call == INVALID_HANDLE)
	{
		ThrowError("Failed to prepare SDK call for (%d, %d)", state, pfn);
	}
	SDKCall(call, client);
	CloseHandle(call);
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
