#pragma tabsize 0

#include <sourcemod>
#include <sdktools>
#include <smlib/clients>

public Plugin:myinfo = {
    name = "[bTimes] extras",
    description = "Weapon commands and cvar enforcement",
    author = "Charles_(hypnos), rumour, blacky",
    version = "1.9.0",
    url = ""
}

new bool:g_bCanReceiveWeapons[MAXPLAYERS] = {true, ...};

public SetConVar(String:cvar1[], String:n_val[])
{
    new Handle:cvar = FindConVar(cvar1);
    if(cvar){
        SetConVarString(cvar, n_val);
    }
}

GiveWeapon(client, String:wep[])
{
    if(IsPlayerAlive(client) && g_bCanReceiveWeapons[client]){
        new e_wep = GetPlayerWeaponSlot(client, 1);
        if(e_wep != -1){
            RemovePlayerItem(client, e_wep);
            AcceptEntityInput(e_wep, "Kill");
        }
        e_wep = GetPlayerWeaponSlot(client, 0);
        if(e_wep != -1){
            RemovePlayerItem(client, e_wep);
            AcceptEntityInput(e_wep, "Kill");
        }
        if(strcmp(wep, "weapon_knife") == 0)
        {
            e_wep = GetPlayerWeaponSlot(client, 2);
            if(e_wep != -1){
                RemovePlayerItem(client, e_wep);
                AcceptEntityInput(e_wep, "Kill");
            }
        }
        GivePlayerItem(client, wep, 0);
    }
}

public OnPluginStart()
{
    SetConVar("sv_enablebunnyhopping", "1");
    SetConVar("sv_airaccelerate", "1000");
    SetConVar("sv_maxvelocity", "100000");
    SetConVar("sv_friction", "4.2");
    SetConVar("sv_accelerate", "5.5");
    SetConVar("sv_alltalk", "1");
    SetConVar("sv_hibernate_when_empty", "0");
    SetConVar("bot_quota_mode", "normal");
    SetConVar("bot_join_after_player", "0");
    SetConVar("mp_ignore_round_win_conditions", "1");
    SetConVar("mp_maxrounds", "1");
    
    HookEvent("server_cvar", OnCvarChange, EventHookMode_Pre);
	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	
    RegConsoleCmd("sm_glock", GiveGlock, "Gives player glock");
    RegConsoleCmd("sm_usp", GiveUsp, "Gives player usp");
    RegConsoleCmd("sm_knife", GiveKnife, "Gives player knife");
    RegAdminCmd("sm_stripweps", StripWeapons, ADMFLAG_GENERIC, "Strips a player's weapons and blocks them from weapon commands");
    RegAdminCmd("sm_stripweapons", StripWeapons, ADMFLAG_GENERIC, "Strips a player's weapons and blocks them from weapon commands");
    ServerCommand("mp_warmup_end");
}

public OnConfigsExecuted()
{
	SetConVar("sv_enablebunnyhopping", "1");
    SetConVar("sv_airaccelerate", "1000");
    SetConVar("sv_maxvelocity", "100000");
    SetConVar("sv_friction", "4.2");
    SetConVar("sv_accelerate", "5.5");
    SetConVar("sv_alltalk", "1");
    SetConVar("sv_hibernate_when_empty", "0");
    SetConVar("bot_quota_mode", "normal");
    SetConVar("bot_join_after_player", "0");
    SetConVar("mp_autoteambalance", "0");
    SetConVar("mp_limitteams", "0");
    SetConVar("mp_ignore_round_win_conditions", "1");
    SetConVar("mp_maxrounds", "1");
}

public Action:OnPlayerDeath(Handle:hEvent, const String:strName[], bool:bBroadcast)
{
	{
		new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		if(IsFakeClient(iVictim))
			SetEventBroadcast(hEvent, true);
	}
	{
		new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
		if(IsFakeClient(iAttacker))
			SetEventBroadcast(hEvent, true);
	}
	return Plugin_Continue;
}

public Action:StripWeapons(client, args)
{
    decl String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    //Yes you can use this on bots
    new target = Client_FindByName(arg1);
    if(target == -1)
    {
        PrintToChat(client, "Could not find that player");
        return Plugin_Handled;
    }
    if(g_bCanReceiveWeapons[target])
    {
        g_bCanReceiveWeapons[target] = false;
        if(IsPlayerAlive(target)){
            new e_wep = GetPlayerWeaponSlot(target, 1);
            if(e_wep != -1){
                RemovePlayerItem(target, e_wep);
                AcceptEntityInput(e_wep, "Kill");
            }
        }
        PrintToChat(client, "Player '%N' can no longer use weapon commands", target);
        PrintToChat(target, "An admin has stripped your ability to use weapon commands!");
    }
    else
    {
        g_bCanReceiveWeapons[target] = true;
        PrintToChat(client, "Player '%N' can now use weapons commands again", target);
        PrintToChat(target, "Weapon command access has been restored.");
    }
    return Plugin_Handled;
}

public Action:GiveGlock(client, args)
{
    GiveWeapon(client, "weapon_glock");
    return Plugin_Handled;
}

public Action:GiveUsp(client, args)
{
    GiveWeapon(client, "weapon_usp_silencer");
    return Plugin_Handled;
}

public Action:GiveKnife(client, args)
{
    GiveWeapon(client, "weapon_knife");
    return Plugin_Handled;
}

public Action:OnCvarChange(Handle:event, const String:name[], bool:dontbroadcast)
{
    decl String:cvar_string[64];
    GetEventString(event, "cvarname", cvar_string, 64);
    if(StrEqual(cvar_string, "sv_airaccelerate"))
        SetConVar("sv_airaccelerate", "1000");
    else if(StrEqual(cvar_string, "sv_enablebunnyhopping"))
        SetConVar("sv_enablebunnyhopping", "1");
    else if(StrEqual(cvar_string, "sv_maxvelocity"))
        SetConVar("sv_maxvelocity", "1000000");
    else if(StrEqual(cvar_string, "sv_accelerate"))
        SetConVar("sv_accelerate", "5.5");
    else if(StrEqual(cvar_string, "sv_hibernate_when_empty"))
        SetConVar("sv_hibernate_when_empty", "0")
    else if(StrEqual(cvar_string, "sv_alltalk"))
        SetConVar("sv_alltalk", "1");
    else if(StrEqual(cvar_string, "bot_quota_mode"))
        SetConVar("bot_quota_mode", "normal");
    else if(StrEqual(cvar_string, "bot_join_after_player"))
        SetConVar("bot_join_after_player", "0");
    return Plugin_Handled;
}