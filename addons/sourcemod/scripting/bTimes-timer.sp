#pragma semicolon 1
#pragma tabsize 0

#include <bTimes-core>

public Plugin myinfo = 
{
	name = "[bTimes] Timer",
    author = "Charles_(hypnos), rumour, blacky",
	description = "The timer portion of the bTimes plugin",
	version = VERSION,
	url = ""
}

#include <sourcemod>
#include <bTimes-core>
#include <bTimes-timer>
#include <bTimes-ranks>
#include <bTimes-random>
#include <sdktools>
#include <sdkhooks>
#include <smlib/entities>
#include <cstrike>
#include <clientprefs>
#include <bTimes-tas>
#include <bTimes-zones>

#undef REQUIRE_PLUGIN
#include <bTimes-ghost>

enum
{
	GameType_CSS,
	GameType_CSGO
};

new	g_GameType;

#define EF_NODRAW 32

new bool:g_bCanReceiveWeapons[MAXPLAYERS] = {true, ...};

// database
new	Handle:g_DB;
 

// Current map info
new 	String:g_sMapName[64],
	Handle:g_MapList;

// Player timer info
new 	Float:g_fStartTime[MAXPLAYERS + 1],
	bool:g_bTiming[MAXPLAYERS + 1];

new g_StyleConfig[32][StyleConfig];
new g_TotalStyles;

new 	g_Type[MAXPLAYERS + 1];
new 	g_Style[MAXPLAYERS + 1][MAX_TYPES];
	
new	bool:g_bTimeIsLoaded[MAXPLAYERS + 1],
	Float:g_fTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES],
	String:g_sTime[MAXPLAYERS + 1][MAX_TYPES][MAX_STYLES][64];

new 	g_Strafes[MAXPLAYERS + 1],
	g_Jumps[MAXPLAYERS + 1],
	g_SWStrafes[MAXPLAYERS + 1][2],
	Float:g_HSWCounter[MAXPLAYERS + 1],
	Float:g_fSpawnTime[MAXPLAYERS + 1];
	
new g_Offset_m_fEffects = -1;
new bool:g_bShowTriggers[MAXPLAYERS+1];

new g_iTransmitCount;
	
new	Float:g_fNoClipSpeed[MAXPLAYERS + 1];

new 	g_Buttons[MAXPLAYERS + 1],
	g_UnaffectedButtons[MAXPLAYERS + 1];

new	Handle:g_hSoundsArray,
	Handle:g_hSound_Path_Record,
	Handle:g_hSound_Position_Record,
	Handle:g_hSound_Path_Personal,
	Handle:g_hSound_Path_Fail;

new	bool:g_bPaused[MAXPLAYERS + 1],
	Float:g_fPauseTime[MAXPLAYERS + 1],
	Float:g_fPausePos[MAXPLAYERS + 1][3];
	
new	Float:g_Fps[MAXPLAYERS + 1];
	
new	String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];
	
// Warning
new	Float:g_fWarningTime[MAXPLAYERS + 1];

// Sync measurement
new	Float:g_fOldAngle[MAXPLAYERS + 1],
	g_totalSync[MAXPLAYERS + 1],
	g_goodSync[MAXPLAYERS + 1],
	g_goodSyncVel[MAXPLAYERS + 1];
	
// Hint text
new 	Float:g_WorldRecord[MAX_TYPES][MAX_STYLES];
new 	String:g_sRecord[MAX_TYPES][MAX_STYLES][64];

// Cvars
new 	Handle:g_hTimerDisplay,
	Handle:g_hHintSpeed,
	Handle:g_hAllowYawspeed,
	Handle:g_hAllowPause,
	Handle:g_hChangeClanTag,
	Handle:g_hTimerChangeClanTag,
	Handle:g_hAdvancedSounds,
	Handle:g_hAllowNoClip,
	Handle:g_hVelocityCap,
	bool:g_bAllowVelocityCap,
	Handle:g_hAllowAuto,
	bool:g_bAllowAuto,
	Handle:g_hJumpInStartZone,
	bool:g_bJumpInStartZone,
	Handle:g_hAutoStopsTimer,
	bool:g_bAutoStopsTimer;
	
// Server Cvars
ConVar sv_autobunnyhopping = null;
	
// All map times
new	Handle:g_hTimes[MAX_TYPES][MAX_STYLES],
	Handle:g_hTimesUsers[MAX_TYPES][MAX_STYLES],
	bool:g_bTimesAreLoaded;
	
// Forwards
new	Handle:g_fwdOnTimerFinished_Pre,
	Handle:g_fwdOnTimerFinished_Post,
	Handle:g_fwdOnTimerStart_Pre,
	Handle:g_fwdOnTimerStart_Post,
	Handle:g_fwdOnTimesDeleted,
	Handle:g_fwdOnTimesUpdated,
	Handle:g_fwdOnStylesLoaded,
	Handle:g_fwdOnTimesLoaded,
	Handle:g_fwdOnStyleChanged;
	
// Admin
new	bool:g_bIsAdmin[MAXPLAYERS + 1];

new bool:JumpButtonsFix[65];



// Other plugins
new	bool:g_bGhostPluginLoaded;

// TAS
new bool:g_bTAS[MAXPLAYERS+1];
new Float:g_tastime[MAXPLAYERS + 1];

// WR/BWR Menu
new String:g_sChoosedMap[MAXPLAYERS + 1][64];

public OnPluginStart()
{
	decl String:sGame[64];
	GetGameFolderName(sGame, sizeof(sGame));
	
	if(StrEqual(sGame, "cstrike"))
		g_GameType = GameType_CSS;
	else if(StrEqual(sGame, "csgo"))
		g_GameType = GameType_CSGO;
	else
		SetFailState("This timer does not support this game (%s)", sGame);
	
	// Connect to the database
	DB_Connect();
	
	g_Offset_m_fEffects = FindSendPropInfo("CBaseEntity", "m_fEffects");
	
	if (g_Offset_m_fEffects == -1)
		SetFailState("[Show Triggers] Could not find CBaseEntity:m_fEffects");
	
	// Server cvars
	g_hHintSpeed       = CreateConVar("timer_hintspeed", "0.1", "Changes the hint text update speed (bottom center text)", 0, true, 0.1);
	g_hAllowYawspeed   = CreateConVar("timer_allowyawspeed", "0", "Lets players use +left/+right commands without stopping their timer.", 0, true, 0.0, true, 1.0);
	g_hAllowPause      = CreateConVar("timer_allowpausing", "1", "Lets players use the !pause/!unpause commands.", 0, true, 0.0, true, 1.0);
	g_hChangeClanTag   = CreateConVar("timer_changeclantag", "1", "Means player clan tags will show their current timer time.", 0, true, 0.0, true, 1.0);
	g_hAdvancedSounds  = CreateConVar("timer_advancedsounds", "1", "Reads record sound options from wrsounds_adv.txt", 0, true, 0.0, true, 1.0);
	g_hAllowNoClip     = CreateConVar("timer_noclip", "1", "Allows players to use the !p commands to noclip themselves.", 0, true, 0.0, true, 1.0);
	g_hVelocityCap     = CreateConVar("timer_velocitycap", "1", "Allows styles with a max velocity cap to cap player velocity.", 0, true, 0.0, true, 1.0);
	g_hJumpInStartZone = CreateConVar("timer_allowjumpinstart", "1", "Allows players to jump in the start zone. (This is not exactly anti-prespeed)", 0, true, 0.0, true, 1.0);
	g_hAllowAuto       = CreateConVar("timer_allowauto", "1", "Allows players to use auto bunnyhop.", 0, true, 0.0, true, 1.0);
	g_hAutoStopsTimer  = CreateConVar("timer_autostopstimer", "0", "Players can't get times with autohop on.");
	
	HookConVarChange(g_hHintSpeed, OnTimerHintSpeedChanged);
	HookConVarChange(g_hChangeClanTag, OnChangeClanTagChanged);
	HookConVarChange(g_hVelocityCap, OnVelocityCapChanged);
	HookConVarChange(g_hAutoStopsTimer, OnAutoStopsTimerChanged);
	HookConVarChange(g_hAllowAuto, OnAllowAutoChanged);
	HookConVarChange(g_hJumpInStartZone, OnAllowJumpInStartZoneChanged);
	
	AutoExecConfig(true, "timer", "timer");
	
	// Event hooks
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Pre);
	HookEvent("player_jump", Event_PlayerJump_Post, EventHookMode_Post);
	HookEvent("player_disconnect", Player_Disconnect, EventHookMode_Pre);
	HookEvent("player_changename", Player_ChangeName, EventHookMode_Pre);

	
	// Admin commands
	RegAdminCmd("sm_delete", SM_Delete, ADMFLAG_CHEATS, "Deletes map times.");
	RegAdminCmd("sm_spj", SM_SPJ, ADMFLAG_GENERIC, "Check the strafes per jump ratios for any player.");
	RegAdminCmd("sm_enablestyle", SM_EnableStyle, ADMFLAG_RCON, "Enables a style for players to use. (Resets to default setting on map change)");
	RegAdminCmd("sm_disablestyle", SM_DisableStyle, ADMFLAG_RCON, "Disables a style so players can no longer use it. (Resets to default setting on map change)");
	
	// Player commands
	RegConsoleCmdEx("sm_stop", SM_StopTimer, "Stops your timer.");
	RegConsoleCmdEx("sm_style", SM_Style, "Change your style.");
	RegConsoleCmdEx("sm_styles", SM_Style, "Change your style.");
	RegConsoleCmdEx("sm_mode", SM_Style, "Change your style.");
	RegConsoleCmdEx("sm_bstyle", SM_BStyle, "Change your bonus style.");
	RegConsoleCmdEx("sm_bmode", SM_BStyle, "Change your bonus style.");
	RegConsoleCmdEx("sm_practice", SM_Practice, "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_p", SM_Practice, "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_nc", SM_Practice, "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_noclipme", SM_Practice, "Puts you in noclip. Stops your timer.");
	RegConsoleCmdEx("sm_truevel", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
	RegConsoleCmdEx("sm_velocity", SM_TrueVelocity, "Toggles between 2D and 3D velocity velocity meters");
	RegConsoleCmdEx("sm_pause", SM_Pause, "Pauses your timer and freezes you.");
	RegConsoleCmdEx("sm_unpause", SM_Unpause, "Unpauses your timer and unfreezes you.");
	RegConsoleCmdEx("sm_resume", SM_Unpause, "Unpauses your timer and unfreezes you.");
	RegConsoleCmdEx("sm_fps", SM_Fps, "Shows a list of every player's fps_max value.");
	RegConsoleCmd("sm_showtriggers", SM_ShowTriggers, "Command to dynamically toggle trigger visibility");
	//RegConsoleCmdEx("sm_auto", SM_Auto, "Toggles auto bunnyhop");
	//RegConsoleCmdEx("sm_bhop", SM_Auto, "Toggles auto bunnyhop");
	
	
	sv_autobunnyhopping = FindConVar("sv_autobunnyhopping");
	sv_autobunnyhopping.Flags &= ~FCVAR_NOTIFY;
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			g_hTimes[Type][Style]      = CreateArray(2);
			g_hTimesUsers[Type][Style] = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
		}
	}
	
	g_hSoundsArray           = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSound_Path_Record     = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSound_Position_Record = CreateArray();
	g_hSound_Path_Personal   = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSound_Path_Fail       = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
}

public OnAllPluginsLoaded()
{
	if(LibraryExists("ghost"))
	{
		g_bGhostPluginLoaded = true;
	}
	
	ReadStyleConfig();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Natives
	CreateNative("StartTimer", Native_StartTimer);
	CreateNative("StopTimer", Native_StopTimer);
	CreateNative("IsBeingTimed", Native_IsBeingTimed);
	CreateNative("FinishTimer", Native_FinishTimer);
	CreateNative("GetClientStyle", Native_GetClientStyle);
	CreateNative("IsTimerPaused", Native_IsTimerPaused);
	CreateNative("GetStyleName", Native_GetStyleName);
	CreateNative("GetStyleAbbr", Native_GetStyleAbbr);
	CreateNative("Style_IsEnabled", Native_Style_IsEnabled);
	CreateNative("Style_IsTypeAllowed", Native_Style_IsTypeAllowed);
	CreateNative("Style_IsFreestyleAllowed", Native_Style_IsFreestyleAllowed);
	CreateNative("Style_GetTotal", Native_Style_GetTotal);
	CreateNative("Style_CanUseReplay", Native_Style_CanUseReplay);
	CreateNative("Style_CanReplaySave", Native_Style_CanReplaySave);
	CreateNative("GetTypeStyleFromCommand", Native_GetTypeStyleFromCommand);
	CreateNative("GetClientTimerType", Native_GetClientTimerType);
	CreateNative("Style_GetConfig", Native_GetStyleConfig);
	CreateNative("Timer_GetButtons", Native_GetButtons);
	CreateNative("Timer_IsTAS", Native_IsTAS);
	
	// Forwards
	g_fwdOnTimerStart_Pre     = CreateGlobalForward("OnTimerStart_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerStart_Post    = CreateGlobalForward("OnTimerStart_Post", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerFinished_Pre  = CreateGlobalForward("OnTimerFinished_Pre", ET_Hook, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimerFinished_Post = CreateGlobalForward("OnTimerFinished_Post", ET_Event, Param_Cell, Param_Float, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnTimesDeleted       = CreateGlobalForward("OnTimesDeleted", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Any);
	g_fwdOnTimesUpdated       = CreateGlobalForward("OnTimesUpdated", ET_Event, Param_String, Param_Cell, Param_Cell, Param_Any);
	g_fwdOnStylesLoaded       = CreateGlobalForward("OnStylesLoaded", ET_Event);
	g_fwdOnTimesLoaded        = CreateGlobalForward("OnMapTimesLoaded", ET_Event);
	g_fwdOnStyleChanged       = CreateGlobalForward("OnStyleChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	return APLRes_Success;
}

public OnMapStart()
{
	// Set the map id
	AddFileToDownloadsTable("sound/timer/female-godlike.mp3");
	AddFileToDownloadsTable("sound/timer/female-holyshit.mp3");
	AddFileToDownloadsTable("sound/timer/female-wickedsick.mp3");
	AddFileToDownloadsTable("sound/timer/improved.mp3");
	AddFileToDownloadsTable("sound/timer/male-godlike.mp3");
	AddFileToDownloadsTable("sound/timer/male-holyshit.mp3");
	AddFileToDownloadsTable("sound/timer/male-wickedsick.mp3");
	AddFileToDownloadsTable("sound/timer/buzzer.wav");
	
	
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	if(g_MapList != INVALID_HANDLE)
	{
		CloseHandle(g_MapList);
	}
	
	g_MapList = ReadMapList();
	
	g_bTimesAreLoaded = false;
	
	decl String:sTypeAbbr[32], String:sStyleAbbr[32];
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
		StringToUpper(sTypeAbbr);
		
		for(new Style; Style < g_TotalStyles; Style++)
		{
			GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr), true);
			StringToUpper(sStyleAbbr);
			
			FormatEx(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "%sWR%s: Loading..", sTypeAbbr, sStyleAbbr);
		}
	}
}

public OnStylesLoaded()
{
	RegConsoleCmdPerStyle("wr", SM_WorldRecord, "Show the world record info for {Type} timer on {Style} style.");
	RegConsoleCmdPerStyle("time", SM_Time, "Show your time for {Type} timer on {Style} style.");
	
	decl String:sType[32], String:sStyle[32], String:sTypeAbbr[32], String:sStyleAbbr[32], String:sCommand[64], String:sDescription[256];
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
		
		for(new Style; Style < g_TotalStyles; Style++)
		{
			if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][Type])
			{
				GetStyleName(Style, sStyle, sizeof(sStyle));
				GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr));
				
				FormatEx(sCommand, sizeof(sCommand), "sm_%s%s", sTypeAbbr, sStyleAbbr);
				FormatEx(sDescription, sizeof(sDescription), "Set your style to %s on the %s timer.", sStyle, sType);
				
				if(Type == TIMER_MAIN)
					RegConsoleCmdEx(sCommand, SM_SetStyle, sDescription);
				else if(Type == TIMER_BONUS)
					RegConsoleCmdEx(sCommand, SM_SetBonusStyle, sDescription);
			}
		}
	}
}

public OnConfigsExecuted()
{
	// Reset temporary enabled and disabled styles
	for(new Style; Style < g_TotalStyles; Style++)
	{
		g_StyleConfig[Style][TempEnabled] = g_StyleConfig[Style][Enabled];
	}
	
	if(GetConVarInt(g_hChangeClanTag) == 0)
	{
		KillTimer(g_hTimerChangeClanTag);
	}
	else
	{
		g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	
	if(GetConVarBool(g_hAdvancedSounds))
	{
		LoadRecordSounds_Advanced();
	}
	else
	{
		LoadRecordSounds();
	}
	
	g_hTimerDisplay = CreateTimer(GetConVarFloat(g_hHintSpeed), Timer_DrawHintText, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	
	g_bAllowVelocityCap = GetConVarBool(g_hVelocityCap);
	g_bAllowAuto        = GetConVarBool(g_hAllowAuto);
	g_bAutoStopsTimer   = GetConVarBool(g_hAutoStopsTimer);
	g_bJumpInStartZone  = GetConVarBool(g_hJumpInStartZone);
	
	ExecMapConfig();
}

public bool:OnClientConnect(client)
{
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			g_fTime[client][Type][Style] = 0.0;
            FormatEx(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "PR: <font color='#6078A8'>Loading</font>");
		}
	}
	
	// Set player times to null
	g_bTimeIsLoaded[client] = false;
	
	// Unpause timers
	g_bPaused[client] = false;
	
	// Reset noclip speed
	g_fNoClipSpeed[client] = 1.0;
	
	// Set style to first available style for each timer type
	for(new Type; Type < MAX_TYPES; Type++)
	{
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][Type])
			{
				g_Style[client][Type] = Style;
				break;
			}
		}
	}
	
	g_bIsAdmin[client] = false;
	
	g_fNoClipSpeed[client] = 1.0;
	
	return true;
}

public OnClientPutInServer(client)
{
	QueryClientConVar(client, "fps_max", OnFpsMaxRetrieved);
	
	if (IsFakeClient(client)) return;
	decl String:name[32];
	
	GetClientName(client, name, sizeof(name));
	
	PrintToChatAll("\x01[\x05Connect\x01] - %s%s %shas joined the server.", g_msg_varcol, name, g_msg_textcol);
}


public Action Player_Disconnect(Handle:event, const char[] name, bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (0 >= client) return;
	if (IsFakeClient(client)) return;
	decl String:clientname[32];
	
	GetClientName(client, clientname, sizeof(clientname));
	
	g_bCanReceiveWeapons[client] = true;

	PrintToChatAll("\x01[\x07Disconnect\x01] - %s%s %shas left the server.", g_msg_varcol, clientname, g_msg_textcol);
	
}

public Action Player_ChangeName(Handle:event, const char[] name, bool:dontBroadcast)
{
	return Plugin_Continue;
}

public OnFpsMaxRetrieved(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	g_Fps[client] = StringToFloat(cvarValue);
	
	if(g_Fps[client] > 1000)
		g_Fps[client] = 1000.0;
}

public OnClientPostAdminCheck(client)
{
	g_bIsAdmin[client] = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);
}

public OnPlayerIDLoaded(client)
{
	if(g_bTimesAreLoaded == true)
	{
		DB_LoadPlayerInfo(client);
	}
}

public OnTimerChatChanged(MessageType, String:Message[])
{
	if(MessageType == 0)
	{
		Format(g_msg_start, sizeof(g_msg_start), Message);
		ReplaceMessage(g_msg_start, sizeof(g_msg_start));
	}
	else if(MessageType == 1)
	{
		Format(g_msg_varcol, sizeof(g_msg_varcol), Message);
		ReplaceMessage(g_msg_varcol, sizeof(g_msg_varcol));
	}
	else if(MessageType == 2)
	{
		Format(g_msg_textcol, sizeof(g_msg_textcol), Message);
		ReplaceMessage(g_msg_textcol, sizeof(g_msg_textcol));
	}
}

ReplaceMessage(String:message[], maxlength)
{
	if(g_GameType == GameType_CSS)
	{
		ReplaceString(message, maxlength, "^", "\x07", false);
	}
	else if(g_GameType == GameType_CSGO)
	{
		ReplaceString(message, maxlength, "^1", "\x01");
		ReplaceString(message, maxlength, "^2", "\x02");
		ReplaceString(message, maxlength, "^3", "\x03");
		ReplaceString(message, maxlength, "^4", "\x04");
		ReplaceString(message, maxlength, "^5", "\x05");
		ReplaceString(message, maxlength, "^6", "\x06");
		ReplaceString(message, maxlength, "^7", "\x07");
		ReplaceString(message, maxlength, "^8", "\x08");
		ReplaceString(message, maxlength, "^9", "\x09");
		ReplaceString(message, maxlength, "^A", "\x0A");
		ReplaceString(message, maxlength, "^B", "\x0B");
		ReplaceString(message, maxlength, "^C", "\x0C");
		ReplaceString(message, maxlength, "^D", "\x0D");
		ReplaceString(message, maxlength, "^E", "\x0E");
		ReplaceString(message, maxlength, "^F", "\x0F");
		ReplaceString(message, maxlength, "^0", "\x10");
	}
}

public OnZonesLoaded()
{	
	DB_LoadTimes(true);
}

public OnTimerHintSpeedChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	KillTimer(g_hTimerDisplay);
	
	g_hTimerDisplay = CreateTimer(GetConVarFloat(convar), Timer_DrawHintText, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public OnChangeClanTagChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(GetConVarInt(convar) == 0)
	{
		KillTimer(g_hTimerChangeClanTag);
	}
	else
	{
		g_hTimerChangeClanTag = CreateTimer(1.0, SetClanTag, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

public OnVelocityCapChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bAllowVelocityCap = bool:StringToInt(newValue);
}

public OnAutoStopsTimerChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if(StringToInt(newValue) == 1)
	{
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientInGame(client) && IsBeingTimed(client, TIMER_ANY) && (GetClientSettings(client) & AUTO_BHOP))
			{
				StopTimer(client);
			}
		}
	}
}

public OnAllowJumpInStartZoneChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bJumpInStartZone = bool:StringToInt(newValue);
}

public OnAllowAutoChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bAllowAuto = bool:StringToInt(newValue);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Player timers should stop when they die
	StopTimer(client);
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Player timers should stop when they switch teams
	StopTimer(client);
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Anti-time-cheat
	g_fSpawnTime[client] = GetEngineTime();
	
	// Player timers should stop when they spawn
	StopTimer(client);
}

public Action:Event_PlayerJump(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Increase jump count for the hud hint text, it resets to 0 when StartTimer for the client is called
	if(g_bTiming[client] == true)
	{
		g_Jumps[client]++;
	}
	
	new Style = g_Style[client][g_Type[client]];
	
	if(g_StyleConfig[Style][EzHop] == true)
	{
		SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	}
	else if(g_StyleConfig[Style][Freestyle] && g_StyleConfig[Style][Freestyle_EzHop])
	{
		if(Timer_InsideZone(client, FREESTYLE, 1 << Style) != -1)
		{
			SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
		}
	}

	return Plugin_Continue;
}

public Action:Event_PlayerJump_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Check max velocity on player jump event rather than OnPlayerRunCmd, rewards better strafing
	if(g_bAllowVelocityCap == true)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		new Style = g_Style[client][g_Type[client]];
		
		if(g_bAllowVelocityCap == true && g_StyleConfig[Style][MaxVel] != 0.0)
		{
			// Has to be on next game frame, TeleportEntity doesn't seem to work in event player_jump
			CreateTimer(0.0, Timer_CheckVel, client);
		}
	}
}

public Action:Timer_CheckVel(Handle:timer, any:client)
{
	new Style = g_Style[client][g_Type[client]];
	
	new Float:fVel = GetClientVelocity(client, true, true, false);
		
	if(fVel > g_StyleConfig[Style][MaxVel])
	{
		new Float:vVel[3];
		Entity_GetAbsVelocity(client, vVel);
		
		new Float:fTemp = vVel[2];
		ScaleVector(vVel, g_StyleConfig[Style][MaxVel]/fVel);
		vVel[2] = fTemp;
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

// Auto bhop
public Action:SM_Auto(client, args)
{
	if(g_bAllowAuto == true)
	{
		if (args < 1)
		{
			SetClientSettings(client, GetClientSettings(client) ^ AUTO_BHOP);
			
			if(g_bAutoStopsTimer && (GetClientSettings(client) & AUTO_BHOP))
			{
				StopTimer(client);
			}
			
			if(GetClientSettings(client) & AUTO_BHOP)
			{
				PrintToChat(client, "%s%sAuto bhop %senabled",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol);
			}
			else
			{
				PrintToChat(client, "%s%sAuto bhop %sdisabled",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol);
			}
		}
		else if (args == 1)
		{
			decl String:TargetArg[128];
			GetCmdArgString(TargetArg, sizeof(TargetArg));
			new TargetID = FindTarget(client, TargetArg, true, false);
			if(TargetID != -1)
			{
				decl String:TargetName[128];
				GetClientName(TargetID, TargetName, sizeof(TargetName));
				if(GetClientSettings(TargetID) & AUTO_BHOP)
				{
					PrintToChat(client, "%s%sPlayer %s%s%s has auto bhop %senabled",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						TargetName,
						g_msg_textcol,
						g_msg_varcol);
				}
				else
				{
					PrintToChat(client, "%s%sPlayer %s%s%s has auto bhop %sdisabled",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						TargetName,
						g_msg_textcol,
						g_msg_varcol);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

// Toggles between 2d vector and 3d vector velocity
public Action:SM_TrueVelocity(client, args)
{	
	SetClientSettings(client, GetClientSettings(client) ^ SHOW_2DVEL);
	
	if(GetClientSettings(client) & SHOW_2DVEL)
	{
		PrintToChat(client, "%s%sShowing %strue %svelocity",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	else
	{
		PrintToChat(client, "%s%sShowing %snormal %svelocity",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action:SM_SPJ(client, args)
{
	// Get target
	decl String:sArg[255];
	GetCmdArgString(sArg, sizeof(sArg));
	
	// Write data to send to query callback
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientUserId(client));
	WritePackString(pack, sArg);
	
	// Do query
	decl String:query[512];
	Format(query, sizeof(query), "SELECT User, SPJ, SteamID, MStrafes, MJumps FROM (SELECT t2.User, t2.SteamID, AVG(t1.Strafes/t1.Jumps) AS SPJ, SUM(t1.Strafes) AS MStrafes, SUM(t1.Jumps) AS MJumps FROM times AS t1, players AS t2 WHERE t1.PlayerID=t2.PlayerID  AND t1.Style=0 GROUP BY t1.PlayerID ORDER BY AVG(t1.Strafes/t1.Jumps) DESC) AS x WHERE MStrafes > 100");
	SQL_TQuery(g_DB, SPJ_Callback, query, pack);
	
	return Plugin_Handled;
}

public SPJ_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		// Get data from command arg
		decl String:sTarget[MAX_NAME_LENGTH];
		
		ResetPack(pack);
		new client = GetClientOfUserId(ReadPackCell(pack));
		ReadPackString(pack, sTarget, sizeof(sTarget));
		
		new len = strlen(sTarget);
		
		decl String:item[255], String:info[255], String:sAuth[32], String:sName[MAX_NAME_LENGTH];
		new 	Float:SPJ, Strafes, Jumps;
		
		// Create menu
		new Handle:menu = CreateMenu(Menu_ShowSPJ);
		SetMenuTitle(menu, "Showing strafes per jump\nSelect an item for more info\n ");
		
		new 	rows = SQL_GetRowCount(hndl);
		for(new i=0; i<rows; i++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sName, sizeof(sName));
			SPJ = SQL_FetchFloat(hndl, 1);
			SQL_FetchString(hndl, 2, sAuth, sizeof(sAuth));
			Strafes = SQL_FetchInt(hndl, 3);
			Jumps = SQL_FetchInt(hndl, 4);
			
			if(StrContains(sName, sTarget) != -1 || len == 0)
			{
				Format(item, sizeof(item), "%.1f - %s",
					SPJ,
					sName);
				
				Format(info, sizeof(info), "%s <%s> SPJ: %.1f, Strafes: %d, Jumps: %d",
					sName,
					sAuth,
					SPJ,
					Strafes,
					Jumps);
					
				AddMenuItem(menu, info, item);
			}
		}
		
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

public Menu_ShowSPJ(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[255];
		GetMenuItem(menu, param2, info, sizeof(info));
		PrintToChat(param1, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

// Admin command for deleting times
public Action:SM_Delete(client, args)
{
	if(args == 0)
	{
		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
			PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
	}
	else if(args == 1)
	{
		decl String:input[128];
		GetCmdArgString(input, sizeof(input));
		new value = StringToInt(input);
		if(value != 0)
		{
			AdminCmd_DeleteRecord(client, value, value);
		}
	}
	else if(args == 2)
	{
		decl String:sValue0[128], String:sValue1[128];
		GetCmdArg(1, sValue0, sizeof(sValue0));
		GetCmdArg(2, sValue1, sizeof(sValue1));
		AdminCmd_DeleteRecord(client, StringToInt(sValue0), StringToInt(sValue1));
	}
	
	return Plugin_Handled;
}

AdminCmd_DeleteRecord(client, value1, value2)
{
	new Handle:menu = CreateMenu(AdminMenu_DeleteRecord);
	
	if(value1 == value2)
		SetMenuTitle(menu, "Delete record %d", value1);
	else
		SetMenuTitle(menu, "Delete records %d to %d", value1, value2);
	
	new String:sDisplay[64], String:sInfo[32], String:sStyle[32], String:sType[32];
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		
		for(new Style; Style < g_TotalStyles; Style++)
		{
			if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][Type])
			{
				Format(sInfo, sizeof(sInfo), "%d;%d;%d;%d", value1, value2, Type, Style);
				
				GetStyleName(Style, sStyle, sizeof(sStyle));
				
				FormatEx(sDisplay, sizeof(sDisplay), "%s (%s)", sStyle, sType);
				
				AddMenuItem(menu, sInfo, sDisplay);
			}
		}
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AdminMenu_DeleteRecord(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32], String:sTypeStyle[4][8];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			ExplodeString(info, ";", sTypeStyle, 4, 8);
			
			new RecordOne = StringToInt(sTypeStyle[0]);
			new RecordTwo = StringToInt(sTypeStyle[1]);
			new Type      = StringToInt(sTypeStyle[2]);
			new Style     = StringToInt(sTypeStyle[3]);
			
			DB_DeleteRecord(param1, Type, Style, RecordOne, RecordTwo);
			//DB_UpdateRanks(g_sMapName, Type, Style);
		}
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_StopTimer(client, args)
{
	StopTimer(client);
	
	return Plugin_Handled;
}

public Action:SM_WorldRecord(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("wr", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			if(args == 0)
			{
				g_sChoosedMap[client] = g_sMapName;

				if(Type == TIMER_MAIN && Style == 0)
					WorldRecordMenu(client);
				else
					DB_DisplayRecords(client, g_sMapName, Type, Style);
			}
			else if(args == 1)
			{
				decl String:arg[64];
				GetCmdArgString(arg, sizeof(arg));
				if(FindStringInArray(g_MapList, arg) != -1)
				{
					g_sChoosedMap[client] = arg;

					if(Type == TIMER_MAIN && Style == 0)
						WorldRecordMenu(client);
					else
						DB_DisplayRecords(client, arg, Type, Style);
				}
				else
				{
					PrintToChat(client, "%s%sNo map found named %s%s",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						arg);
				}
			}
		}
	}

	return Plugin_Handled;
}

void WorldRecordMenu(int client)
{
	Menu WRMenu = new Menu(Menu_Handler_WorldRecordMenu);
	
	WRMenu.SetTitle("World Record Menu - Main (%s)", g_sChoosedMap[client]);
	
	decl String:sDisplay[64], String:sStyle[32], String:sInfo[8];
	decl String:sTime[32];
	
	int TotalStyles = Style_GetTotal();
	
    for(int Type; Type == TIMER_MAIN ; Type++)
    {
	    for(int Style; Style < TotalStyles; Style++)
	    {
			FormatPlayerTime(g_WorldRecord[Type][Style], sTime, sizeof(sTime), false, 1);
			GetStyleName(Style, sStyle, sizeof(sStyle));

			FormatEx(sDisplay, sizeof(sDisplay), "%s - %s", sStyle, sTime);

			if(g_WorldRecord[Type][Style] == 0.0)
				FormatEx(sDisplay, sizeof(sDisplay), "%s - NO RECORD", sStyle);

			Format(sInfo, sizeof(sInfo), "\n%d;%d", Type, Style);
			AddMenuItem(WRMenu, sInfo, sDisplay);
    	}
    }
    DisplayMenu(WRMenu, client, 0);
}

public int Menu_Handler_WorldRecordMenu(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		decl String:info[16], String:sTypeStyle[2][8];
		GetMenuItem(menu, item, info, sizeof(info));
		
		if (StrContains(info, ";") != -1)
		{
			ExplodeString(info, ";", sTypeStyle, 2, 8);
			
			int iSelection = StringToInt(sTypeStyle[0]);
			int iSelection2 = StringToInt(sTypeStyle[1]);
			
			DB_DisplayRecords(client, g_sChoosedMap[client], iSelection, iSelection2);
		}
	}
	
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

public Action:SM_Time(client, args)
{
	new Type, Style;
	if(GetTypeStyleFromCommand("time", Type, Style))
	{
		if(!IsSpamming(client))
		{
			SetIsSpamming(client, 1.0);
			
			if(args == 0)
			{
				DB_ShowTime(client, client, g_sMapName, Type, Style);
			}
			else if(args == 1)
			{
				decl String:arg[250];
				GetCmdArgString(arg, sizeof(arg));
				if(arg[0] == '@')
				{
					ReplaceString(arg, 250, "@", "");
					DB_ShowTimeAtRank(client, g_sMapName, StringToInt(arg), Type, Style);
				}
				else
				{
					new target = FindTarget(client, arg, true, false);
					new bool:mapValid = (FindStringInArray(g_MapList, arg) != -1);
					if(mapValid == true)
					{
						DB_ShowTime(client, client, arg, Type, Style);
					}
					if(target != -1)
					{
						DB_ShowTime(client, target, g_sMapName, Type, Style);
					}
					if(!mapValid && target == -1)
					{
						PrintToChat(client, "%s%sNo map or player found named %s%s",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							arg);
					}
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Style(client, args)
{
	new Handle:menu = CreateMenu(Menu_Style);
	
	SetMenuTitle(menu, "Change Style");
	decl String:sStyle[32], String:sInfo[16];
	
	for(new Style; Style < g_TotalStyles; Style++)
	{
		if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_MAIN])
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			FormatEx(sInfo, sizeof(sInfo), "%d;%d", TIMER_MAIN, Style);
			
			AddMenuItem(menu, sInfo, sStyle);
		}
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action:SM_BStyle(client, args)
{
	new Handle:menu = CreateMenu(Menu_Style);
	
	SetMenuTitle(menu, "Change Bonus Style");
	decl String:sStyle[32], String:sInfo[16];
	
	for(new Style; Style < g_TotalStyles; Style++)
	{
		if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_BONUS])
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			FormatEx(sInfo, sizeof(sInfo), "%d;%d", TIMER_BONUS, Style);
			
			AddMenuItem(menu, sInfo, sStyle);
		}
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action:SM_SetStyle(client, args)
{
	decl String:sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	ReplaceStringEx(sCommand, sizeof(sCommand), "sm_", "");
	
	decl String:sStyle[32];
	for(new Style; Style < g_TotalStyles; Style++)
	{
		if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_MAIN])
		{
			GetStyleAbbr(Style, sStyle, sizeof(sStyle));
			
			if(StrEqual(sCommand, sStyle))
			{
				SetStyle(client, TIMER_MAIN, Style);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_SetBonusStyle(client, args)
{
	decl String:sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	ReplaceStringEx(sCommand, sizeof(sCommand), "sm_b", "");
	
	decl String:sStyle[32];
	for(new Style; Style < g_TotalStyles; Style++)
	{
		if(Style_IsEnabled(Style) && g_StyleConfig[Style][AllowType][TIMER_BONUS])
		{
			GetStyleAbbr(Style, sStyle, sizeof(sStyle));
			
			if(StrEqual(sCommand, sStyle))
			{
				SetStyle(client, TIMER_BONUS, Style);
			}
		}
	}
	
	return Plugin_Handled;
}

public Menu_Style(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, ";") != -1)
		{
			decl String:sInfoExplode[2][16];
			ExplodeString(info, ";", sInfoExplode, sizeof(sInfoExplode), sizeof(sInfoExplode[]));
			
			SetStyle(client, StringToInt(sInfoExplode[0]), StringToInt(sInfoExplode[1]));
		}
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

SetStyle(client, Type, Style)
{
	new OldStyle = g_Style[client][Type];
	
	g_Style[client][Type] = Style;
	
	StopTimer(client);
	
	if(Type == TIMER_MAIN)
		Timer_TeleportToZone(client, MAIN_START, 0, true);
	else if(Type == TIMER_BONUS)
		Timer_TeleportToZone(client, BONUS_START, 0, true);
	
	Call_StartForward(g_fwdOnStyleChanged);
	Call_PushCell(client);
	Call_PushCell(OldStyle);
	Call_PushCell(Style);
	Call_PushCell(Type);
	Call_Finish();
}

public Action:SM_Practice(client, args)
{
	if(GetConVarBool(g_hAllowNoClip))
	{
		if(args == 0)
		{
			StopTimer(client);
			
			new MoveType:movetype = GetEntityMoveType(client);
			if (movetype != MOVETYPE_NOCLIP)
			{
				SetEntityMoveType(client, MOVETYPE_NOCLIP);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fNoClipSpeed[client]);
			}
			else
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
			}
		}
		else
		{
			decl String:sArg[250];
			GetCmdArgString(sArg, sizeof(sArg));
			
			new Float:fSpeed = StringToFloat(sArg);
			
			if(!(0 <= fSpeed <= 10))
			{
				PrintToChat(client, "%s%sYour noclip speed must be between 0 and 10",
					g_msg_start,
					g_msg_textcol);
					
				return Plugin_Handled;
			}
			
			g_fNoClipSpeed[client] = fSpeed;
		
			PrintToChat(client, "%s%sNoclip speed changed to %s%f%s%s",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				fSpeed,
				g_msg_textcol,
				(fSpeed != 1.0)?" (Default is 1)":" (Default)");
				
			if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
			{
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
			}
		}
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:SM_Pause(client, args)
{
	if(GetConVarBool(g_hAllowPause))
	{
		if(Timer_InsideZone(client, MAIN_START, -1) == -1 && Timer_InsideZone(client, BONUS_START, -1) == -1)
		{
			if(g_bTiming[client] == true)
			{
				if(g_bPaused[client] == false)
				{
					if(GetClientVelocity(client, true, true, true) == 0.0)
					{
						GetEntPropVector(client, Prop_Send, "m_vecOrigin", g_fPausePos[client]);
						g_fPauseTime[client]	= GetEngineTime();
						g_bPaused[client] 	= true;
						
						PrintToChat(client, "%s%sTimer paused.",
							g_msg_start,
							g_msg_textcol);
					}
					else
					{
						PrintToChat(client, "%s%sYou can't pause while moving.",
							g_msg_start,
							g_msg_textcol);
					}
				}
				else
				{
					PrintToChat(client, "%s%sYou are already paused.",
						g_msg_start,
						g_msg_textcol);
				}
			}
			else
			{
				PrintToChat(client, "%s%sYou have no timer running.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else
		{
			PrintToChat(client, "%s%sYou can't pause while inside a starting zone.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Unpause(client, args)
{
	if(GetConVarBool(g_hAllowPause))
	{
		if(g_bTiming[client] == true)
		{
			if(g_bPaused[client] == true)
			{
				// Teleport player to the position they paused at
				TeleportEntity(client, g_fPausePos[client], NULL_VECTOR, Float:{0, 0, 0});
				
				// Set their new start time
				g_fStartTime[client] = GetEngineTime() - (g_fPauseTime[client] - g_fStartTime[client]);
				
				// Unpause
				g_bPaused[client] = false;
				
				PrintToChat(client, "%s%sTimer unpaused.",
					g_msg_start,
					g_msg_textcol);
			}
			else
			{
				PrintToChat(client, "%s%sYou are not currently paused.",
					g_msg_start,
					g_msg_textcol);
			}
		}
		else
		{
			PrintToChat(client, "%s%sYou have no timer running.",
				g_msg_start,
				g_msg_textcol);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Fps(client, args)
{
	new Handle:hMenu = CreateMenu(Menu_Fps);
	SetMenuTitle(hMenu, "List of player fps_max values");
	
	decl String:sFps[64];
	for(new target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target) && !IsFakeClient(target))
		{
			FormatEx(sFps, sizeof(sFps), "%N - %.3f", target, g_Fps[target]);
			AddMenuItem(hMenu, "", sFps);
		}
	}
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action:SM_ShowTriggers(client, args)
{
	// Can't use this cmd from within the server console
	if (!client)
		return Plugin_Handled;
	
	g_bShowTriggers[client] = !g_bShowTriggers[client];
	
	if (g_bShowTriggers[client]) {
		++g_iTransmitCount;
		PrintToChat(client, "%s%s Triggers %svisible", g_msg_start, g_msg_textcol, g_msg_varcol);
	} else {
		--g_iTransmitCount;
		PrintToChat(client, "%s%s Triggers %sinvisible", g_msg_start, g_msg_textcol, g_msg_varcol);
	}
	
	transmitTriggers( g_iTransmitCount > 0 );
	return Plugin_Handled;
}

public OnClientDisconnect_Post(client)
{
	// Has this player been still using the feature before he left?
	if (g_bShowTriggers[client])
	{
		g_bShowTriggers[client] = false;
		--g_iTransmitCount;
		transmitTriggers( g_iTransmitCount > 0 );
	}
}

transmitTriggers(bool:transmit)
{
	// Hook only once
	static bool:s_bHooked = false;
	
	// Have we done this before?
	if (s_bHooked == transmit)
		return;
	
	// Loop through entities
	decl String:sBuffer[8];
	new lastEdictInUse = GetEntityCount();
	for (new entity = MaxClients+1; entity <= lastEdictInUse; ++entity)
	{
		if ( !IsValidEdict(entity) )
			continue;
		
		// Is this entity a trigger?
		GetEdictClassname(entity, sBuffer, sizeof(sBuffer));
		if (strcmp(sBuffer, "trigger") != 0)
			continue;
		
		// Is this entity's model a VBSP model?
		GetEntPropString(entity, Prop_Data, "m_ModelName", sBuffer, 2);
		if (sBuffer[0] != '*') {
			// The entity must have been created by a plugin and assigned some random model.
			// Skipping in order to avoid console spam.
			continue;
		}
		
		// Get flags
		new effectFlags = GetEntData(entity, g_Offset_m_fEffects);
		new edictFlags = GetEdictFlags(entity);
		
		// Determine whether to transmit or not
		if (transmit) {
			effectFlags &= ~EF_NODRAW;
			edictFlags &= ~FL_EDICT_DONTSEND;
		} else {
			effectFlags |= EF_NODRAW;
			edictFlags |= FL_EDICT_DONTSEND;
		}
		
		// Apply state changes
		SetEntData(entity, g_Offset_m_fEffects, effectFlags);
		ChangeEdictState(entity, g_Offset_m_fEffects);
		SetEdictFlags(entity, edictFlags);
		
		// Should we hook?
		if (transmit)
			SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		else
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
	}
	s_bHooked = transmit;
}

public Action:Hook_SetTransmit(entity, client)
{
	if (!g_bShowTriggers[client])
	{
		// I will not display myself to this client :(
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Menu_Fps(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_EnableStyle(client, args)
{
	if(args == 1)
	{
		decl String:sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		new Style = StringToInt(sArg);
		
		if(0 <= Style < g_TotalStyles)
		{
			g_StyleConfig[Style][TempEnabled] = true;
			ReplyToCommand(client, "[Timer] - Style '%d' has been enabled.", Style);
		}
		else
		{
			ReplyToCommand(client, "[Timer] - Style '%d' is not a valid style number. It will not be enabled.", Style);
		}
	}
	else
	{
		ReplyToCommand(client, "[Timer] - Example: \"sm_enablestyle 1\" will enable the style with number value of 1 in the styles.cfg");
	}
	
	return Plugin_Handled;
}

public Action:SM_DisableStyle(client, args)
{
	if(args == 1)
	{
		decl String:sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		new Style = StringToInt(sArg);
		
		if(0 <= Style < g_TotalStyles)
		{
			g_StyleConfig[Style][TempEnabled] = false;
			ReplyToCommand(client, "[Timer] - Style '%d' has been disabled.", Style);
		}
		else
		{
			ReplyToCommand(client, "[Timer] - Style '%d' is not a valid style number. It will not be disabled.", Style);
		}
	}
	else
	{
		ReplyToCommand(client, "[Timer] - Example: \"sm_disablestyle 1\" will disable the style with number value of 1 in the styles.cfg");
	}
	
	return Plugin_Handled;
}

public Action:SetClanTag(Handle:timer, any:data)
{
	decl String:sTag[32];
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client) && !IsFakeClient(client))
			{
				GetClanTagString(client, sTag, sizeof(sTag));
				CS_SetClientClanTag(client, sTag);
			//return;
			}
		}
	}
}

GetClanTagString(client, String:tag[], maxlength)
{
	if(g_bTiming[client] == true)
	{
		if(Timer_InsideZone(client, MAIN_START, -1) != -1 || Timer_InsideZone(client, BONUS_START, -1) != -1 || Timer_InsideZone(client, MAIN_END, -1) != -1 || Timer_InsideZone(client, BONUS_END, -1) != -1)
		{
			if(Timer_InsideZone(client, MAIN_START) != -1)
				FormatEx(tag, maxlength, "Main Start");
			else if(Timer_InsideZone(client, BONUS_START) != -1)
				FormatEx(tag, maxlength, "Bonus Start");
			else if(Timer_InsideZone(client, MAIN_END) != -1)
				FormatEx(tag, maxlength, "Main End");
			else if(Timer_InsideZone(client, BONUS_END) != -1)
				FormatEx(tag, maxlength, "Bonus End");	
			return;
		}
		else if(g_bPaused[client])
		{
			FormatEx(tag, maxlength, "Paused");
			return;
		}
		else
		{
			GetTypeAbbr(g_Type[client], tag, maxlength, true);
			Format(tag, maxlength, "%s%s: ", tag, g_StyleConfig[g_Style[client][g_Type[client]]][Name_Short]);
			StringToUpper(tag);
			
			decl String:sTime[32];
			new Float:fTime = GetClientTimer(client);
			FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 1);
			SplitString(sTime, ".", sTime, sizeof(sTime));
			Format(tag, maxlength, "%s%s", tag, sTime);
		}
	}
	else
	{
		FormatEx(tag, maxlength, "No timer");
	}
}

public Action:Timer_DrawHintText(Handle:timer, any:data)
{
	decl String:sHintMessage[256];
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			new Time = RoundToFloor(g_fTime[client][TIMER_MAIN][0]);
			if(g_fTime[client][TIMER_MAIN][0] == 0.0 || g_fTime[client][TIMER_MAIN][0] > 2000.0)
				Time = 2000;
			SetEntProp(client, Prop_Data, "m_iFrags", -Time);
			
			if(GetHintMessage(client, sHintMessage, sizeof(sHintMessage)))
			{
				if(g_GameType == GameType_CSS)
					PrintHintText(client, sHintMessage);
				else if(g_GameType == GameType_CSGO)
					PrintHintText(client, sHintMessage);
			}
		}
	}
}

//HUD
bool:GetHintMessage(client, String:buffer[], maxlength)
{
    FormatEx(buffer, maxlength, "");
	
	new target;
    
    if(IsPlayerAlive(client))
    {
        target = client;
    }
    else
    {
        target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        new mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        if(!((0 < target <= MaxClients) && (mode == 4 || mode == 5)))
            return false;
        
        if(IsFakeClient(target))
            return false;
    }
    
    new settings = GetClientSettings(client);
    
	//START ZONE
	//if(Timer_InsideZone(target, MAIN_START) != -1 || Timer_InsideZone(target, BONUS_START) != -1)
    if(Timer_GetTASTime(target, g_tastime[target]) <= 0.1 && GetClientTimer(target) <= 0.1)
    {
		//Style things
		new Type = g_Type[target];
		new Style = g_Style[target][g_Type[target]];
		
		//Specs
		new SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
		SpecCountToArrays(SpecCount, AdminSpecCount);
		
		//Keys
		new buttons = GetClientButtons(target);
		new String:sForward[1], String:sBack[1], String:sMoveleft[2], String:sMoveright[2];

		FormatEx(buffer, maxlength, "");
			
		/* if(strlen(g_StyleConfig[Style][Name]) <= 5)
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t\t\t%sStart Zone\n", buffer, g_StyleConfig[Style][Name], buffer);
		}
			else
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t\t%sStart Zone\n", buffer, g_StyleConfig[Style][Name], buffer);
		} */
		
		Format(buffer, maxlength, "<font size=\"16\">%s\t\t<font color='#FFA500' size=\"16\">Timer</font>\n", buffer);
		
			
		if(!IsFakeClient(client))
		{
			if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 40)
			{
				Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
			else
			{
				Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
		}
		
		Format(buffer, maxlength, "%sWR: <font color=\"#6078A8\">%s</font>", buffer, g_sRecord[Type][Style]);
		
		if(buttons & IN_FORWARD)
			sForward[0] = 'W';
		else
			sForward[0] = '_';	
			
		Format(buffer, maxlength, "%s\nSpecs: %d\t\t%s\t", buffer, g_bIsAdmin[client]?AdminSpecCount[target]:SpecCount[target], sForward);

		Format(buffer, maxlength, "%s%d u/s\n", buffer, RoundToFloor(GetClientVelocity(target, true, true, !bool:(settings & SHOW_2DVEL))));

		
		if(buttons & IN_MOVELEFT)
		{
			sMoveleft[0] = 'A';
			sMoveleft[1] = 0;
		}
		else
		{
			sMoveleft[0] = '_';
			sMoveleft[1] = 0;
		}
		
		if(buttons & IN_MOVERIGHT)
		{
			sMoveright[0] = 'D';
			sMoveright[1] = 0;
		}
		else
		{
			sMoveright[0] = '_';
			sMoveright[1] = 0;
		}
		
		if(buttons & IN_BACK)
			sBack[0] = 'S';
		else
			sBack[0] = '_';
		
		{
		if (buttons & IN_JUMP && JumpButtonsFix[client])
			Format(buffer, maxlength, "%sJump\t\t", buffer);
		else
			Format(buffer, maxlength, "%s \t\t", buffer);
		}  
		
		Format(buffer, maxlength, "%s        %s %s %s\t", buffer, sMoveleft, sBack, sMoveright);
		
		if(buttons & IN_DUCK)
			Format(buffer, maxlength, "%sDuck", buffer);
		else
			Format(buffer, maxlength, "%s ", buffer);
	}
    
	//END ZONE
	else if(Timer_InsideZone(target, MAIN_END) != -1 || Timer_InsideZone(target, BONUS_END) != -1)
    {
		//Style things
		new Type = g_Type[target];
		new Style = g_Style[target][g_Type[target]];
		
		//Specs
		new SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
		SpecCountToArrays(SpecCount, AdminSpecCount);
		
		//Keys
		new buttons = GetClientButtons(target);
		new String:sForward[1], String:sBack[1], String:sMoveleft[2], String:sMoveright[2];
		
		FormatEx(buffer, maxlength, "");
			
		if(strlen(g_StyleConfig[Style][Name]) <= 5)
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t\t\t%sEnd Zone\n", buffer, g_StyleConfig[Style][Name], buffer);
		}
		else if(strlen(g_StyleConfig[Style][Name]) <= 12)
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t\t%sEnd Zone\n", buffer, g_StyleConfig[Style][Name], buffer);
		}
		else
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t%sEnd Zone\n", buffer, g_StyleConfig[Style][Name], buffer);
		}
		
		if(!IsFakeClient(client))
		{
			if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 40)
			{
				Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
			else
			{
				Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
		}
		
		Format(buffer, maxlength, "%sWR: <font color=\"#6078A8\">%s</font>", buffer, g_sRecord[Type][Style]);
		
		if(buttons & IN_FORWARD)
			sForward[0] = 'W';
		else
			sForward[0] = '_';	
			
		Format(buffer, maxlength, "%s\nSpecs: %d\t\t%s\t", buffer, g_bIsAdmin[client]?AdminSpecCount[target]:SpecCount[target], sForward);

		Format(buffer, maxlength, "%s%d u/s\n", buffer, RoundToFloor(GetClientVelocity(target, true, true, !bool:(settings & SHOW_2DVEL))));

		
		if(buttons & IN_MOVELEFT)
		{
			sMoveleft[0] = 'A';
			sMoveleft[1] = 0;
		}
		else
		{
			sMoveleft[0] = '_';
			sMoveleft[1] = 0;
		}
		
		if(buttons & IN_MOVERIGHT)
		{
			sMoveright[0] = 'D';
			sMoveright[1] = 0;
		}
		else
		{
			sMoveright[0] = '_';
			sMoveright[1] = 0;
		}
		
		if(buttons & IN_BACK)
			sBack[0] = 'S';
		else
			sBack[0] = '_';
		
		{
		if (buttons & IN_JUMP && JumpButtonsFix[client])
			Format(buffer, maxlength, "%sJump\t\t", buffer);
		else
			Format(buffer, maxlength, "%s \t\t", buffer);
		}  
		
		Format(buffer, maxlength, "%s        %s %s %s\t", buffer, sMoveleft, sBack, sMoveright);
		
		if(buttons & IN_DUCK)
			Format(buffer, maxlength, "%sDuck", buffer);
		else
			Format(buffer, maxlength, "%s ", buffer);
	}
		//NOT RUNNING
		else
    {
        if(g_bTiming[target])
        {
            if(g_bPaused[target] == false)
            {
                GetTimerAdvancedString(target, buffer, maxlength);

            }
            else
            {
                GetTimerPauseString(target, buffer, maxlength);
            }
        }
        else
        {
		//Style things
		new Type = g_Type[target];
		new Style = g_Style[target][g_Type[target]];
		
		//Specs
		new SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
		SpecCountToArrays(SpecCount, AdminSpecCount);
		
		//Keys
		new buttons = GetClientButtons(target);
		new String:sForward[1], String:sBack[1], String:sMoveleft[2], String:sMoveright[2];
		
		//Format
		FormatEx(buffer, maxlength, "");
			
		if(strlen(g_StyleConfig[Style][Name]) < 6)
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t\t\t%sNot Running\n", buffer, g_StyleConfig[Style][Name], buffer);
		}
			else
		{
			Format(buffer, maxlength, "<font size=\"16\">%sStyle: %s\t\t%sNot Running\n", buffer, g_StyleConfig[Style][Name], buffer);
		}
		
		if(!IsFakeClient(client))
		{
			if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 40)
			{
				Format(buffer, maxlength, "%s%s\t\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
			else
			{
				Format(buffer, maxlength, "%s%s\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
		}
		
		Format(buffer, maxlength, "%sWR: <font color=\"#6078A8\">%s</font>", buffer, g_sRecord[Type][Style]);
		
		if(buttons & IN_FORWARD)
			sForward[0] = 'W';
		else
			sForward[0] = '_';	
			
		Format(buffer, maxlength, "%s\nSpecs: %d\t\t%s\t", buffer, g_bIsAdmin[client]?AdminSpecCount[target]:SpecCount[target], sForward);

		Format(buffer, maxlength, "%s%d u/s\n", buffer, RoundToFloor(GetClientVelocity(target, true, true, !bool:(settings & SHOW_2DVEL))));

		
		if(buttons & IN_MOVELEFT)
		{
			sMoveleft[0] = 'A';
			sMoveleft[1] = 0;
		}
		else
		{
			sMoveleft[0] = '_';
			sMoveleft[1] = 0;
		}
		
		if(buttons & IN_MOVERIGHT)
		{
			sMoveright[0] = 'D';
			sMoveright[1] = 0;
		}
		else
		{
			sMoveright[0] = '_';
			sMoveright[1] = 0;
		}
		
		if(buttons & IN_BACK)
			sBack[0] = 'S';
		else
			sBack[0] = '_';
		
		{
		if (buttons & IN_JUMP && JumpButtonsFix[client])
			Format(buffer, maxlength, "%sJump\t\t", buffer);
		else
			Format(buffer, maxlength, "%s \t\t", buffer);
		}  
		
		Format(buffer, maxlength, "%s        %s %s %s\t", buffer, sMoveleft, sBack, sMoveright);
		
		if(buttons & IN_DUCK)
			Format(buffer, maxlength, "%sDuck", buffer);
		else
			Format(buffer, maxlength, "%s ", buffer);
        }
    }
	return true;
}

//Timer string
GetTimerAdvancedString(client, String:sResult[], maxlength)
{
    FormatEx(sResult, maxlength, "");
	
    new Style = g_Style[client][g_Type[client]];
	new target;
	new String:sForward[1], String:sBack[1], String:sMoveleft[2], String:sMoveright[2];
	new buttons = GetClientButtons(client);
	new SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
	SpecCountToArrays(SpecCount, AdminSpecCount);
   
    if(IsPlayerAlive(client))
    {
        target = client;
    }
    else
    {
        target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        new mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        if(!((0 < target <= MaxClients) && (mode == 4 || mode == 5)))
            return false;
       
        if(IsFakeClient(target))
            return false;
    }
    
    if(g_Type[client] == TIMER_BONUS)
        FormatEx(sResult, maxlength, "Style: ");
	else if (g_Type[client] == TIMER_MAIN)
        FormatEx(sResult, maxlength, "Style: ");
    
    if(strlen(g_StyleConfig[Style][Name]) <= 5)
    {
        Format(sResult, maxlength, "<font size=\"16\">%s%s\t\t\t", sResult, g_StyleConfig[Style][Name]);
    }
		else
	{
		Format(sResult, maxlength, "<font size=\"16\">%s%s\t\t", sResult, g_StyleConfig[Style][Name]);
	}
	
	new Float:fTime = GetClientTimer(client);
	new String:sTime[32], String:sColor[7];
	FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 1);
	GetTimeColor(fTime, g_WorldRecord[g_Type[client]][Style], sColor, sizeof(sColor));
	
	Format(sResult, maxlength, "%sSync: %.2f%\n", sResult, GetClientSync(target));
	
		if(!IsFakeClient(client))
		{
			if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 40)
			{
				Format(sResult, maxlength, "%s%s\t\t\t", sResult, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
			else
			{
				Format(sResult, maxlength, "%s%s\t\t", sResult, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
		}
	
	Format(sResult, maxlength, "%sTime: <font color='#%s'>%s</font> #%d", sResult, sColor, sTime, GetPlayerPosition(fTime, g_Type[client], Style));
    
	if(buttons & IN_FORWARD)
		sForward[0] = 'W';
	else
		sForward[0] = '_';	
		
	Format(sResult, maxlength, "%s\nSpecs: %d\t\t%s\t", sResult, g_bIsAdmin[client]?AdminSpecCount[target]:SpecCount[target], sForward);

	Format(sResult, maxlength, "%s%d u/s\n", sResult, RoundToFloor(GetClientVelocity(client, true, true, (GetClientSettings(client) & SHOW_2DVEL) == 0)));

    
	if(buttons & IN_MOVELEFT)
	{
		sMoveleft[0] = 'A';
		sMoveleft[1] = 0;
	}
	else
	{
		sMoveleft[0] = '_';
		sMoveleft[1] = 0;
	}
    
	if(buttons & IN_MOVERIGHT)
	{
		sMoveright[0] = 'D';
		sMoveright[1] = 0;
	}
	else
	{
		sMoveright[0] = '_';
		sMoveright[1] = 0;
	}
    
	if(buttons & IN_BACK)
		sBack[0] = 'S';
	else
		sBack[0] = '_';
	
	{
	if (buttons & IN_JUMP && JumpButtonsFix[client])
		Format(sResult, maxlength, "%sJump\t\t", sResult);
	else
		Format(sResult, maxlength, "%s \t\t", sResult);
	}  
	
	Format(sResult, maxlength, "%s        %s %s %s\t", sResult, sMoveleft, sBack, sMoveright);
    
	if(buttons & IN_DUCK)
		Format(sResult, maxlength, "%sDuck", sResult);
	else
		Format(sResult, maxlength, "%s ", sResult);
	

	return true;
}


//Timer pause string
GetTimerPauseString(client, String:buffer[], maxlen)
{
    FormatEx(buffer, maxlen, "");
	
	new target;
    new Style = g_Style[client][g_Type[client]];
	new Type = g_Type[target];

	new String:sForward[1], String:sBack[1], String:sMoveleft[2], String:sMoveright[2];
	new buttons = GetClientButtons(client);
	new SpecCount[MaxClients+1], AdminSpecCount[MaxClients+1];
	SpecCountToArrays(SpecCount, AdminSpecCount);
   
    if(IsPlayerAlive(client))
    {
        target = client;
    }
    else
    {
        target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        new mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        if(!((0 < target <= MaxClients) && (mode == 4 || mode == 5)))
            return false;
       
        if(IsFakeClient(target))
            return false;
    }
    
    if(g_Type[client] == TIMER_BONUS)
        FormatEx(buffer, maxlen, "Style: ");
	else if (g_Type[client] == TIMER_MAIN)
        FormatEx(buffer, maxlen, "Style: ");
    
    if(strlen(g_StyleConfig[Style][Name]) <= 5)
    {
        Format(buffer, maxlen, "<font size=\"16\">%s%s\t\t\t", buffer, g_StyleConfig[Style][Name]);
    }
		else
	{
		Format(buffer, maxlen, "<font size=\"16\">%s%s\t\t", buffer, g_StyleConfig[Style][Name]);
	}
	
	Format(buffer, maxlen, "%sPaused\n", buffer, GetClientSync(target));
	
		if(!IsFakeClient(client))
		{
			if(strlen(g_sTime[client][g_Type[client]][GetStyle(client)]) <= 40)
			{
				Format(buffer, maxlen, "%s%s\t\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
			else
			{
				Format(buffer, maxlen, "%s%s\t\t", buffer, g_sTime[client][g_Type[client]][GetStyle(client)]);
			}
		}
	
		Format(buffer, maxlen, "%sWR: <font color=\"#6078A8\">%s</font>", buffer, g_sRecord[Type][Style]);	
    
	if(buttons & IN_FORWARD)
		sForward[0] = 'W';
	else
		sForward[0] = '_';	
		
	Format(buffer, maxlen, "%s\nSpecs: %d\t\t%s\t", buffer, g_bIsAdmin[client]?AdminSpecCount[target]:SpecCount[target], sForward);

	Format(buffer, maxlen, "%s%d u/s\n", buffer, RoundToFloor(GetClientVelocity(client, true, true, (GetClientSettings(client) & SHOW_2DVEL) == 0)));

    
	if(buttons & IN_MOVELEFT)
	{
		sMoveleft[0] = 'A';
		sMoveleft[1] = 0;
	}
	else
	{
		sMoveleft[0] = '_';
		sMoveleft[1] = 0;
	}
    
	if(buttons & IN_MOVERIGHT)
	{
		sMoveright[0] = 'D';
		sMoveright[1] = 0;
	}
	else
	{
		sMoveright[0] = '_';
		sMoveright[1] = 0;
	}
    
	if(buttons & IN_BACK)
		sBack[0] = 'S';
	else
		sBack[0] = '_';
	
	{
	if (buttons & IN_JUMP && JumpButtonsFix[client])
		Format(buffer, maxlen, "%sJump\t\t", buffer);
	else
		Format(buffer, maxlen, "%s \t\t", buffer);
	}  
	
	Format(buffer, maxlen, "%s        %s %s %s\t", buffer, sMoveleft, sBack, sMoveright);
    
	if(buttons & IN_DUCK)
		Format(buffer, maxlen, "%sDuck", buffer);
	else
		Format(buffer, maxlen, "%s ", buffer);
	

	return true;
}

GetPlayerPosition(const Float:fTime, Type, Style)
{	
	if(g_bTimesAreLoaded == true)
	{
		new iSize = GetArraySize(g_hTimes[Type][Style]);
		
		for(new idx; idx < iSize; idx++)
		{
			if(fTime <= GetArrayCell(g_hTimes[Type][Style], idx, 1))
			{
				return idx + 1;
			}
		}
		
		return iSize + 1;
	}
	
	return 0;
}

GetPlayerPositionByID(PlayerID, Type, Style)
{
	if(g_bTimesAreLoaded == true)
	{
		new iSize = GetArraySize(g_hTimes[Type][Style]);
		
		for(new idx = 0; idx < iSize; idx++)
		{
			if(PlayerID == GetArrayCell(g_hTimes[Type][Style], idx, 0))
			{
				return idx + 1;
			}
		}
		
		return iSize + 1;
	}
	
	return 0;
}

public OnRadarAlphaRetrieved(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{	
	if(StringToInt(cvarValue) == 0)
	{
		decl String:sMessage[128];
		if(GetSyncHudMessage(client, sMessage, sizeof(sMessage)))
		{
			new Handle:hText = CreateHudSynchronizer();
			
			if(hText != INVALID_HANDLE)
			{
				SetHudTextParams(0.01, 0.01, 1.0, 255, 255, 255, 255);
				ShowSyncHudText(client, hText, sMessage);
				CloseHandle(hText);
			}
		}
	}
}

bool:GetSyncHudMessage(client, String:message[], maxlength)
{
	FormatEx(message, maxlength, "");
	
	new target;
	
	if(!IsPlayerAlive(client))
	{
		target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		new mode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if(!((0 < target <= MaxClients) && (mode == 4 || mode == 5)))
		{
			return false;
		}
	}
	else
	{
		target = client;
		//return false;
	}
	
	if(!IsFakeClient(target))
	{
		new Type = g_Type[target];
		new Style = g_Style[target][g_Type[target]];
		
		Format(message, maxlength, g_sRecord[Type][Style]);
		
		new position;
		Format(message, maxlength, "%s\n%s", message, g_sTime[target][g_Type[target]][GetStyle(target)]);
		if(g_fTime[target][g_Type[target]][GetStyle(target)] != 0.0)
		{
			position = GetPlayerPositionByID(GetPlayerID(target), g_Type[target], GetStyle(target));
			Format(message, maxlength, "%s (#%d)", message, position);
		}
		
		return true;
	}
	else
	{
		if(g_bGhostPluginLoaded == true)
		{
			new Type, Style;
			if(GetBotInfo(target, Type, Style))
			{
				Format(message, maxlength, g_sRecord[Type][Style]);
				return true;
			}
			else
			{
				return false;
			}
		}
		else
		{
			return false;
		}
	}
}

SpecCountToArrays(clients[], admins[])
{
    for(new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && !IsFakeClient(client))
        {
            if(!IsPlayerAlive(client))
            {
                new Target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
                new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
                if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
                {
                    if(g_bIsAdmin[client] == false)
                        clients[Target]++;
                    admins[Target]++;
                }
            }
        }
    }
}

Float:GetClientSync(client)
{
	if(g_totalSync[client] == 0)
		return 0.0;
	
	return float(g_goodSync[client])/float(g_totalSync[client]) * 100.0;
}

Float:GetClientSync2(client)
{
	if(g_totalSync[client] == 0)
		return 0.0;
	
	return float(g_goodSyncVel[client])/float(g_totalSync[client]) * 100.0;
}

public Action:OnTimerStart_Pre(client, Type, Style)
{
	if(!IsClientInGame(client))
	{
		return Plugin_Handled;
	}
		
	if(!IsPlayerAlive(client))
	{
		return Plugin_Handled;
	}
	
	// Fixes a bug for players to completely cheat times by spawning in weird parts of the map
	if(GetEngineTime() < (g_fSpawnTime[client] + 0.1))
	{
		return Plugin_Handled;
	}
	
	// Don't start if their speed isn't default
	if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1.0 && !Timer_IsTAS(client))
	{
		WarnClient(client, "%s%sYour movement speed is off. Type %s!normalspeed%s to set it to default.", 30.0,
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_msg_textcol);
		return Plugin_Handled;
	}
	
	// Don't start if they are in noclip
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Handled;
	}
	
	// Don't start if they are a fake client
	if(IsFakeClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!g_StyleConfig[Style][AllowType][Type] || !Style_IsEnabled(Style))
	{
		return Plugin_Handled;
	}
	
	if(g_StyleConfig[Style][MinFps] != 0 && g_Fps[client] < g_StyleConfig[Style][MinFps] && g_Fps[client] != 0.0)
	{
		WarnClient(client, "%s%sPlease set your fps_max to a higher value (Minimum %s%.1f%s).", 30.0, 
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_StyleConfig[Style][MinFps],
			g_msg_textcol);
		return Plugin_Handled;
	}
	
	if((GetClientSettings(client) & AUTO_BHOP) && g_bAutoStopsTimer)
	{
		return Plugin_Handled;
	}
	
	CheckPrespeed(client, Style);
	
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnTimerStart_Post(client, Type, Style)
{
	// For an always convenient starting jump
	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	
	if(g_StyleConfig[Style][RunSpeed] != 0.0)
	{
		SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", g_StyleConfig[Style][RunSpeed]);
	}
	
	// Set to correct gravity
	if(GetEntityGravity(client) != g_StyleConfig[Style][Gravity])
	{
		SetEntityGravity(client, g_StyleConfig[Style][Gravity]);
	}
}

public Native_StartTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Type   = GetNativeCell(2);
	new Style  = g_Style[client][Type];
	
	Call_StartForward(g_fwdOnTimerStart_Pre);
	Call_PushCell(client);
	Call_PushCell(Type);
	Call_PushCell(Style);
	
	new Action:fResult;
	Call_Finish(fResult);
	
	if(fResult != Plugin_Handled)
	{		
		g_Jumps[client]          = 0;
		g_Strafes[client]        = 0;
		g_SWStrafes[client][0]   = 1;
		g_SWStrafes[client][1]   = 1;
		g_bPaused[client]        = false;
		g_totalSync[client]      = 0;
		g_goodSync[client]       = 0;
		g_goodSyncVel[client]    = 0;
		
		g_Type[client]        = Type;
		g_bTiming[client]     = true;
		g_fStartTime[client]  = GetEngineTime();
		
		Call_StartForward(g_fwdOnTimerStart_Post);
		Call_PushCell(client);
		Call_PushCell(Type);
		Call_PushCell(Style);
		Call_Finish();
	}
}

CheckPrespeed(client, Style)
{	
	if(g_StyleConfig[Style][PreSpeed] != 0.0)
	{
		new Float:fVel = GetClientVelocity(client, true, true, true);
		
		if(fVel > g_StyleConfig[Style][PreSpeed])
		{
			new Float:vVel[3];
			Entity_GetAbsVelocity(client, vVel);
			ScaleVector(vVel, g_StyleConfig[Style][SlowedSpeed]/fVel);
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		}
	}
}

WarnClient(client, const String:message[], Float:WarnTime, any:...)
{
	if(GetEngineTime() > g_fWarningTime[client])
	{
		decl String:buffer[300];
		VFormat(buffer, sizeof(buffer), message, 4);
		PrintToChat(client, buffer);
		
		g_fWarningTime[client] = GetEngineTime() + WarnTime;	
	}
}

public Native_StopTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	// stop timer
	if(0 < client <= MaxClients)
	{
		g_bTiming[client] = false;
		g_bPaused[client] = false;
		
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			if(GetEntityMoveType(client) == MOVETYPE_NONE)
			{
				SetEntityMoveType(client, MOVETYPE_WALK);
			}
		}
	}
}

public Native_IsBeingTimed(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Type   = GetNativeCell(2);
	
	if(g_bTiming[client] == true)
	{
		if(Type == TIMER_ANY)
		{
			return true;
		}
		else
		{
			return g_Type[client] == Type;
		}
	}
	
	return false;
}

public Action:OnTimerFinished_Pre(client, Type, Style)
{
	if(g_bTimeIsLoaded[client] == false)
	{
		return Plugin_Handled;
	}
	
	if(GetPlayerID(client) == 0)
	{
		return Plugin_Handled;
	}
	
	if(g_bPaused[client] == true)
	{
		return Plugin_Handled;
	}
	
	// Anti-cheat sideways
	if(g_StyleConfig[Style][Special] == true)
	{
		if(StrEqual(g_StyleConfig[Style][Special_Key], "sw"))
		{
			new Float:WSRatio = float(g_SWStrafes[client][0])/float(g_SWStrafes[client][1]);
			if((WSRatio > 2.0) || (g_Strafes[client] < 10))
			{
				PrintToChat(client, "%s%sThat time did not count because you used W-Only too much",
					g_msg_start,
					g_msg_textcol);
				StopTimer(client);
				return Plugin_Handled;
			}
		}
	}
	
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnTimerFinished_Post(client, Float:Time, Type, Style, bool:NewTime, OldPosition, NewPosition)
{
	PlayFinishSound(client, NewTime, NewPosition);
}

public Native_FinishTimer(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Type   = g_Type[client];
	new Style  = g_Style[client][Type];
	
	
	Call_StartForward(g_fwdOnTimerFinished_Pre);
	Call_PushCell(client);
	Call_PushCell(Type);
	Call_PushCell(Style);
	
	new Action:fResult;
	Call_Finish(fResult);
	
	if(fResult != Plugin_Handled)
	{
		StopTimer(client);
		
		new Float:fTime = GetClientTimer(client);
		decl String:sTime[32];
		FormatPlayerTime(fTime, sTime, sizeof(sTime), false, 1);
		
		new String:sType[32];
		if(Type != TIMER_MAIN)
		{
			GetTypeName(Type, sType, sizeof(sType));
		}
		
		new String:sStyle[32];
		if(Style != 0)
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
		}
		
		new String:sTypeStyle[64];
			FormatEx(sTypeStyle, sizeof(sTypeStyle), "%s%s ", sType, sStyle);
		
		new OldPosition, NewPosition, bool:NewTime = false;
		
		if(fTime < g_fTime[client][Type][Style] || g_fTime[client][Type][Style] == 0.0)
		{
			NewTime = true;
			
			if(g_fTime[client][Type][Style] == 0.0)
				OldPosition = 0;
			else
				OldPosition = GetPlayerPositionByID(GetPlayerID(client), Type, Style);
			
			NewPosition = DB_UpdateTime(client, Type, Style, fTime, g_Jumps[client], g_Strafes[client], GetClientSync(client), GetClientSync2(client));
			
			g_fTime[client][Type][Style] = fTime;
			
            FormatEx(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "PR: <font color='#6078A8'>%s</font>", sTime);
			
			if(NewPosition == 1)
			{
				g_WorldRecord[Type][Style] = fTime;
				
				decl String:sTypeAbbr[8];
				GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
				StringToUpper(sTypeAbbr);
				
				decl String:sStyleAbbr[8];
				GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr), true);
				StringToUpper(sStyleAbbr);
				
                Format(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "%s", sTime);
				
				if(g_Type[client] == TIMER_MAIN)
				{
					PrintColorTextAll("\x01[\x05%s - %s\x01] \x0B World record by",
						g_StyleConfig[Style][Name],
						g_sMapName);
						
						PrintColorTextAll(" \x02%N\x01: \x02%s\x01 - \x07%d \x0BJumps, \x07%d \x0BStrafes", 
						client,
						sTime,
						g_Jumps[client],
						g_Strafes[client]);
				}
				else if(g_Type[client] == TIMER_BONUS)
				{
						PrintColorTextAll("\x01[\x05Bonus %s - %s\x01] \x0B World record by",
						g_StyleConfig[Style][Name],
						g_sMapName);
						
						PrintColorTextAll(" \x02%N\x01: \x02%s\x01 - \x07%d \x0BJumps, \x07%d \x0BStrafes",
						client,
						sTime,
						g_Jumps[client],
						g_Strafes[client]);
				}
			}
			else
			{
				if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
				{
					PrintColorTextAll("\x01[\x05%s\x01] %s%N %sfinished in %s%s%s Rank: %s#%d", 
						g_StyleConfig[Style][Name],
						g_msg_varcol,
						client, 
						g_msg_textcol,
						g_msg_varcol,
						sTime,
						g_msg_textcol,
						g_msg_varcol,
						NewPosition);
				}
				else
				{
					PrintColorTextAll("\x01[\x05%s\x01] %s%N %sfinished in %s%s%s Rank: %s#%d", 
						g_StyleConfig[Style][Name],
						g_msg_varcol,
						client, 
						g_msg_textcol,
						g_msg_varcol,
						sTime,
						g_msg_textcol,
						g_msg_varcol,
						NewPosition);
				}
			}
		}
		else
		{
			OldPosition = GetPlayerPositionByID(GetPlayerID(client), Type, Style);
			NewPosition = OldPosition;
			
			decl String:sPersonalBest[32];
			FormatPlayerTime(g_fTime[client][Type][Style], sPersonalBest, sizeof(sPersonalBest), false, 1);
			
			PrintToChat(client, "%s%s%s%sYou finished in %s%s%s, but did not improve on your previous time of %s%s",
				g_msg_start,
				g_msg_varcol,
				sTypeStyle,
				g_msg_textcol,
				g_msg_varcol,
				sTime,
				g_msg_textcol,
				g_msg_varcol,
				sPersonalBest);
				
			PrintColorTextObservers(client, "%s%s%s%N %sfinished in %s%s%s, but did not improve on their previous time of %s%s",
				g_msg_start,
				g_msg_varcol,
				sTypeStyle,
				client,
				g_msg_textcol,
				g_msg_varcol,
				sTime,
				g_msg_textcol,
				g_msg_varcol,
				sPersonalBest);
		}
		
		Call_StartForward(g_fwdOnTimerFinished_Post);
		Call_PushCell(client);
		Call_PushFloat(fTime);
		Call_PushCell(Type);
		Call_PushCell(Style);
		Call_PushCell(NewTime);
		Call_PushCell(OldPosition);
		Call_PushCell(NewPosition);
		Call_Finish();
	}
}

GetStyle(client)
{
	return g_Style[client][g_Type[client]];
}

Float:GetClientTimer(client)
{
	new Float:fTime = -1.0;
	if(Timer_IsTAS(client))
	{
		Timer_GetTASTime(client, fTime);
		return fTime;
	}
	else
	{
		return GetEngineTime() - g_fStartTime[client];
	}
}

ReadStyleConfig()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/styles.cfg");
	
	new Handle:kv = CreateKeyValues("Styles");
	FileToKeyValues(kv, sPath);
	
	if(kv != INVALID_HANDLE)
	{
		new Key, bool:KeyExists = true, String:sKey[32];
		
		do
		{
			IntToString(Key, sKey, sizeof(sKey));
			KeyExists = KvJumpToKey(kv, sKey);
			
			if(KeyExists == true)
			{
				KvGetString(kv, "name", g_StyleConfig[Key][Name], 32);
				KvGetString(kv, "abbr", g_StyleConfig[Key][Name_Short], 32);
				g_StyleConfig[Key][Enabled]                = bool:KvGetNum(kv, "enable");
				g_StyleConfig[Key][AllowType][TIMER_MAIN]  = bool:KvGetNum(kv, "main");
				g_StyleConfig[Key][AllowType][TIMER_BONUS] = bool:KvGetNum(kv, "bonus");
				g_StyleConfig[Key][Freestyle]              = bool:KvGetNum(kv, "freestyle");
				g_StyleConfig[Key][Freestyle_Unrestrict]   = bool:KvGetNum(kv, "freestyle_unrestrict");
				g_StyleConfig[Key][Freestyle_EzHop]        = bool:KvGetNum(kv, "freestyle_ezhop");
				g_StyleConfig[Key][Freestyle_Auto]         = bool:KvGetNum(kv, "freestyle_auto");
				g_StyleConfig[Key][Auto]                   = bool:KvGetNum(kv, "auto");
				g_StyleConfig[Key][EzHop]                  = bool:KvGetNum(kv, "ezhop");
				g_StyleConfig[Key][Gravity]                = KvGetFloat(kv, "gravity");
				g_StyleConfig[Key][RunSpeed]               = KvGetFloat(kv, "runspeed");
				g_StyleConfig[Key][MaxVel]                 = KvGetFloat(kv, "maxvel");
				g_StyleConfig[Key][MinFps]                 = KvGetFloat(kv, "minfps");
				g_StyleConfig[Key][CalcSync]               = bool:KvGetNum(kv, "sync");
				g_StyleConfig[Key][Prevent_Left]           = bool:KvGetNum(kv, "prevent_left");
				g_StyleConfig[Key][Prevent_Right]          = bool:KvGetNum(kv, "prevent_right");
				g_StyleConfig[Key][Prevent_Back]           = bool:KvGetNum(kv, "prevent_back");
				g_StyleConfig[Key][Prevent_Forward]        = bool:KvGetNum(kv, "prevent_forward");
				g_StyleConfig[Key][Require_Left]           = bool:KvGetNum(kv, "require_left");
				g_StyleConfig[Key][Require_Right]          = bool:KvGetNum(kv, "require_right");
				g_StyleConfig[Key][Require_Back]           = bool:KvGetNum(kv, "require_back");
				g_StyleConfig[Key][Require_Forward]        = bool:KvGetNum(kv, "require_forward");
				g_StyleConfig[Key][Hud_Style]              = bool:KvGetNum(kv, "hud_style");
				g_StyleConfig[Key][Hud_Strafes]            = bool:KvGetNum(kv, "hud_strafes");
				g_StyleConfig[Key][Hud_Jumps]              = bool:KvGetNum(kv, "hud_jumps");
				g_StyleConfig[Key][Count_Left_Strafe]      = bool:KvGetNum(kv, "count_left_strafe");
				g_StyleConfig[Key][Count_Right_Strafe]     = bool:KvGetNum(kv, "count_right_strafe");
				g_StyleConfig[Key][Count_Back_Strafe]      = bool:KvGetNum(kv, "count_back_strafe");
				g_StyleConfig[Key][Count_Forward_Strafe]   = bool:KvGetNum(kv, "count_forward_strafe");
				g_StyleConfig[Key][Ghost_Use][0]           = bool:KvGetNum(kv, "ghost_use");
				g_StyleConfig[Key][Ghost_Save][0]          = bool:KvGetNum(kv, "ghost_save");
				g_StyleConfig[Key][Ghost_Use][1]           = bool:KvGetNum(kv, "ghost_use_b");
				g_StyleConfig[Key][Ghost_Save][1]          = bool:KvGetNum(kv, "ghost_save_b");
				g_StyleConfig[Key][PreSpeed]               = KvGetFloat(kv, "prespeed");
				g_StyleConfig[Key][SlowedSpeed]            = KvGetFloat(kv, "slowedspeed");
				g_StyleConfig[Key][Special]                = bool:KvGetNum(kv, "special");
				KvGetString(kv, "specialid", g_StyleConfig[Key][Special_Key], 32);
				g_StyleConfig[Key][GunJump]                = bool:KvGetNum(kv, "gunjump");
				KvGetString(kv, "gunjump_weapon", g_StyleConfig[Key][GunJump_Weapon], 64);
				g_StyleConfig[Key][UnrealPhys]             = bool:KvGetNum(kv, "unrealphys");
				g_StyleConfig[Key][TAS]					   = bool:KvGetNum(kv, "tas");
				
				KvGoBack(kv);
				Key++;
			}
		}
		while(KeyExists == true && Key < MAX_STYLES);
			
		CloseHandle(kv);
	
		g_TotalStyles = Key;
		
		// Reset temporary enabled and disabled styles
		for(new Style; Style < g_TotalStyles; Style++)
		{
			g_StyleConfig[Style][TempEnabled] = g_StyleConfig[Style][Enabled];
		}
		
		Call_StartForward(g_fwdOnStylesLoaded);
		Call_Finish();
	}
	else
	{
		LogError("Something went wrong reading from the styles.cfg file.");
	}
}

LoadRecordSounds()
{	
	ClearArray(g_hSoundsArray);
	
	// Create path and file variables
	decl	String:sPath[PLATFORM_MAX_PATH]; 
	new	Handle:hFile;
	
	// Build a path to check if it exists
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer");
	
	// If it doesn't exist, create it
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);
	
	// Build a path to check if the config file exists
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/wrsounds.cfg");
	
	// If the wrsounds exists, load the sounds
	if(FileExists(sPath))
	{
		hFile = OpenFile(sPath, "r");
		
		if(hFile != INVALID_HANDLE)
		{
			decl String:sSound[PLATFORM_MAX_PATH], String:sPSound[PLATFORM_MAX_PATH];
			while(!IsEndOfFile(hFile))
			{
				// get the next line in the file
				ReadFileLine(hFile, sSound, sizeof(sSound));
				ReplaceString(sSound, sizeof(sSound), "\n", "");
				
				if(StrContains(sSound, ".") != -1)
				{					
					// precache the sound
					Format(sPSound, sizeof(sPSound), "timer/%s", sSound);
					PrecacheSound(sPSound);
					
					// make clients download it
					Format(sPSound, sizeof(sPSound), "sound/%s", sPSound);
					AddFileToDownloadsTable(sPSound);
					
					// add it to array for later downloading
					PushArrayString(g_hSoundsArray, sSound);
				}
			}
		}
	}
	else
	{
		// Create the file if it doesn't exist
		hFile = OpenFile(sPath, "w");
	}
	
	// Close it if it was opened succesfully
	if(hFile != INVALID_HANDLE)
		CloseHandle(hFile);
	
}

LoadRecordSounds_Advanced()
{	
	ClearArray(g_hSound_Path_Record);
	ClearArray(g_hSound_Position_Record);
	ClearArray(g_hSound_Path_Personal);
	ClearArray(g_hSound_Path_Fail);
	
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/timer/sounds.txt");
	
	new Handle:kv = CreateKeyValues("Sounds", "Sounds");
	FileToKeyValues(kv, sPath);
	
	new Key, bool:KeyExists = true;
	decl String:sKey[64], String:sPrecache[PLATFORM_MAX_PATH], String:sDownload[PLATFORM_MAX_PATH];
	
	if(KvJumpToKey(kv, "World Record"))
	{
		do
		{
			IntToString(++Key, sKey, sizeof(sKey));
			KeyExists = KvJumpToKey(kv, sKey);
			
			if(KeyExists == true)
			{
				new Position = KvGetNum(kv, "Position");
				KvGetString(kv, "Sound", sKey, sizeof(sKey));
				
				// precache the sound
				Format(sPrecache, sizeof(sPrecache), "*timer/%s", sKey);
				PrecacheSound(sPrecache);
				
				// make clients download it
				Format(sDownload, sizeof(sDownload), "sound/timer/%s", sKey);
				AddFileToDownloadsTable(sDownload);
				
				// add it to array
				PushArrayString(g_hSound_Path_Record, sPrecache);
				PushArrayCell(g_hSound_Position_Record, Position);
				
				KvGoBack(kv);
			}
		}
		while(KeyExists == true);
	}
	KvRewind(kv);
	
	if(KvJumpToKey(kv, "Personal Record"))
	{
		Key = 0;
		KeyExists = true;
		
		do
		{
			IntToString(++Key, sKey, sizeof(sKey));
			KeyExists = KvJumpToKey(kv, sKey);
			
			if(KeyExists == true)
			{
				KvGetString(kv, "Sound", sKey, sizeof(sKey));
				
				// precache the sound
				Format(sPrecache, sizeof(sPrecache), "*timer/%s", sKey);
				PrecacheSound(sPrecache);
				
				// make clients download it
				Format(sDownload, sizeof(sDownload), "sound/timer/%s", sKey);
				AddFileToDownloadsTable(sDownload);
				
				// add it to array for later downloading
				PushArrayString(g_hSound_Path_Personal, sPrecache);
				
				KvGoBack(kv);
			}
		}
		while(KeyExists == true);
	}
	KvRewind(kv);
	
	if(KvJumpToKey(kv, "No New Time"))
	{
		Key = 0;
		KeyExists = true;
		
		do
		{
			IntToString(++Key, sKey, sizeof(sKey));
			KeyExists = KvJumpToKey(kv, sKey);
			
			if(KeyExists == true)
			{
				KvGetString(kv, "Sound", sKey, sizeof(sKey));
				
				// precache the sound
				Format(sPrecache, sizeof(sPrecache), "*timer/%s", sKey);
				PrecacheSound(sPrecache);
				
				// make clients download it
				Format(sDownload, sizeof(sDownload), "sound/timer/%s", sKey);
				AddFileToDownloadsTable(sDownload);
				
				// add it to array for later downloading
				PushArrayString(g_hSound_Path_Fail, sPrecache);
				
				KvGoBack(kv);
			}
		}
		while(KeyExists == true);
	}
	
	CloseHandle(kv);
}

PlayFinishSound(client, bool:NewTime, Position)
{
	decl String:sSound[64];
	
	if(GetConVarBool(g_hAdvancedSounds))
	{
		if(NewTime == true)
		{
			new iSize = GetArraySize(g_hSound_Position_Record);
			
			new Handle:IndexList = CreateArray();
			
			for(new idx; idx < iSize; idx++)
			{
				if(GetArrayCell(g_hSound_Position_Record, idx) == Position)
				{
					PushArrayCell(IndexList, idx);
				}
			}
			
			iSize = GetArraySize(IndexList);
			
			if(iSize > 0)
			{
				new Rand = GetRandomInt(0, iSize - 1);
				GetArrayString(g_hSound_Path_Record, GetArrayCell(IndexList, Rand), sSound, sizeof(sSound));
				
				new numClients, clients[MaxClients + 1];
				for(new target = 1; target <= MaxClients; target++)
				{
					if(IsClientInGame(target) && !(GetClientSettings(target) & STOP_RECSND))
						clients[numClients++] = target;
				}
				EmitSound(clients, numClients, sSound);
			}
			else
			{
				iSize = GetArraySize(g_hSound_Path_Personal);
				
				if(iSize > 0)
				{
					new Rand = GetRandomInt(0, iSize - 1);
					GetArrayString(g_hSound_Path_Personal, Rand, sSound, sizeof(sSound));
					if(!(GetClientSettings(client) & STOP_PBSND))
						EmitSoundToClient(client, sSound);
				}
			}
			
			CloseHandle(IndexList);
		}
		else
		{
			new iSize = GetArraySize(g_hSound_Path_Fail);
			
			if(iSize > 0)
			{
				new Rand = GetRandomInt(0, iSize - 1);
				GetArrayString(g_hSound_Path_Fail, Rand, sSound, sizeof(sSound));
				if(!(GetClientSettings(client) & STOP_FAILSND))
					EmitSoundToClient(client, sSound);
			}
		}
	}
	else
	{
		if(NewTime == true && Position == 1)
		{
			new iSize = GetArraySize(g_hSoundsArray);
			
			if(iSize > 0)
			{
				new Rand = GetRandomInt(0, iSize - 1);
				GetArrayString(g_hSoundsArray, Rand, sSound, sizeof(sSound));
				if(!(GetClientSettings(client) & STOP_RECSND))
					EmitSoundToClient(client, sSound);
			}
		}
	}
}

ExecMapConfig()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "cfg/timer/maps");
	
	if(DirExists(sPath))
	{
		FormatEx(sPath, sizeof(sPath), "cfg/timer/maps/%s.cfg", g_sMapName);
		
		if(FileExists(sPath))
		{
			ServerCommand("exec timer/maps/%s.cfg", g_sMapName);
		}
	}
	else
	{
		CreateDirectory(sPath, 511);
	}
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
	{
		CloseHandle(g_DB);
	}
	
	decl String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
}

DB_LoadPlayerInfo(client)
{
	new PlayerID = GetPlayerID(client);
	if(IsClientConnected(client) && PlayerID != 0)
	{
		if(!IsFakeClient(client))
		{
			new iSize;
			for(new Type; Type < MAX_TYPES; Type++)
			{
				for(new Style; Style < MAX_STYLES; Style++)
				{
					if(g_StyleConfig[Style][AllowType][Type])
					{
                        FormatEx(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "PR: <font color='#6078A8'>N/A</font>");
						
						iSize = GetArraySize(g_hTimes[Type][Style]);
						
						for(new idx = 0; idx < iSize; idx++)
						{
							if(GetArrayCell(g_hTimes[Type][Style], idx) == PlayerID)
							{
								g_fTime[client][Type][Style] = GetArrayCell(g_hTimes[Type][Style], idx, 1);
								FormatPlayerTime(g_fTime[client][Type][Style], g_sTime[client][Type][Style], sizeof(g_sTime[][][]), false, 1);
                                Format(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "PR: <font color='#6078A8'>%s</font>", g_sTime[client][Type][Style]);
							}
						}
					}
				}
			}
			
			g_bTimeIsLoaded[client] = true;
		}
	}
}

public Native_GetClientStyle(Handle:plugin, numParams)
{
	return GetStyle(GetNativeCell(1));
}

public Native_IsTimerPaused(Handle:plugin, numParams)
{
	return g_bPaused[GetNativeCell(1)];
}

public Native_GetStyleName(Handle:plugin, numParams)
{
	new Style     = GetNativeCell(1);
	new maxlength = GetNativeCell(3);
	
	if(Style == 0 && GetNativeCell(4) == true)
	{
		SetNativeString(2, "", maxlength);
		return;
	}
	
	SetNativeString(2, g_StyleConfig[Style][Name], maxlength);
}

public Native_GetStyleAbbr(Handle:plugin, numParams)
{
	new Style     = GetNativeCell(1);
	new maxlength = GetNativeCell(3);
	
	if(Style == 0 && GetNativeCell(4) == true)
	{
		SetNativeString(2, "", maxlength);
		return;
	}
	
	SetNativeString(2, g_StyleConfig[Style][Name_Short], maxlength);
}

public Native_GetStyleConfig(Handle:plugin, numParams)
{
	new Style = GetNativeCell(1);
	
	if(Style < g_TotalStyles)
	{
		SetNativeArray(2, g_StyleConfig[Style], StyleConfig);
		return true;
	}
	else
	{
		return false;
	}
}

public Native_Style_IsEnabled(Handle:plugin, numParams)
{
	// Return 'TempEnabled' value because styles can be dynamically changed, 'Enabled' holds the setting from the config always
	return g_StyleConfig[GetNativeCell(1)][TempEnabled];
}

public Native_Style_IsTypeAllowed(Handle:plugin, numParams)
{
	return g_StyleConfig[GetNativeCell(1)][AllowType][GetNativeCell(2)];
}

public Native_Style_IsFreestyleAllowed(Handle:plugin, numParams)
{
	return g_StyleConfig[GetNativeCell(1)][Freestyle];
}

public Native_Style_GetTotal(Handle:plugin, numParams)
{
	return g_TotalStyles;
}

public Native_Style_CanUseReplay(Handle:plugin, numParams)
{
	return g_StyleConfig[GetNativeCell(1)][Ghost_Use][GetNativeCell(2)];
}

public Native_Style_CanReplaySave(Handle:plugin, numParams)
{
	return g_StyleConfig[GetNativeCell(1)][Ghost_Save][GetNativeCell(2)];
}

public Native_GetClientTimerType(Handle:plugin, numParams)
{
	return g_Type[GetNativeCell(1)];
}

public Native_GetTypeStyleFromCommand(Handle:plugin, numParams)
{
	decl String:sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));
	ReplaceStringEx(sCommand, sizeof(sCommand), "sm_", "");
	
	new DelimiterLen;
	GetNativeStringLength(1, DelimiterLen);
	
	decl String:sDelimiter[DelimiterLen + 1];
	GetNativeString(1, sDelimiter, DelimiterLen + 1);
	
	new String:sTypeStyle[2][64];
	ExplodeString(sCommand, sDelimiter, sTypeStyle, 2, 64);
	
	if(StrEqual(sTypeStyle[0], ""))
	{
		SetNativeCellRef(2, TIMER_MAIN);
	}
	else if(StrEqual(sTypeStyle[0], "b"))
	{
		SetNativeCellRef(2, TIMER_BONUS);
	}
	else
	{
		return false;
	}
	
	for(new Style; Style < g_TotalStyles; Style++)
	{
		if(Style_IsEnabled(Style))
		{
			if(StrEqual(sTypeStyle[1], g_StyleConfig[Style][Name_Short]) || (Style == 0 && StrEqual(sTypeStyle[1], "")))
			{
				SetNativeCellRef(3, Style);
				return true;
			}
		}
	}
	
	return false;
}

public Native_GetButtons(Handle:plugin, numParams)
{
	return g_UnaffectedButtons[GetNativeCell(1)];
}

public Native_IsTAS(Handle:plugin, numParams)
{
	return g_bTAS[GetNativeCell(1)];
}

// Adds or updates a player's record on the map
DB_UpdateTime(client, Type, Style, Float:Time, Jumps, Strafes, Float:Sync, Float:Sync2)
{
	new PlayerID = GetPlayerID(client);
	if(PlayerID != 0)
	{
		if(!IsFakeClient(client))
		{
			new Handle:data = CreateDataPack();
			WritePackString(data, g_sMapName);
			WritePackCell(data, client);
			WritePackCell(data, PlayerID);
			WritePackCell(data, Type);
			WritePackCell(data, Style);
			WritePackFloat(data, Time);
			WritePackCell(data, Jumps);
			WritePackCell(data, Strafes);
			WritePackFloat(data, Sync);
			WritePackFloat(data, Sync2);
			
			decl String:query[256];
			Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d",
				g_sMapName,
				Type,
				Style,
				PlayerID);
			SQL_TQuery(g_DB, DB_UpdateTime_Callback1, query, data);
			
			// Get player position
			new iSize = GetArraySize(g_hTimes[Type][Style]), Position = -1;
			
			for(new idx = 0; idx < iSize; idx++)
			{
				if(GetArrayCell(g_hTimes[Type][Style], idx) == PlayerID)
				{
					Position = idx;
					break;
				}
			}
			
			// Remove existing time from array if position exists
			if(Position != -1)
			{
				RemoveFromArray(g_hTimes[Type][Style], Position);
				RemoveFromArray(g_hTimesUsers[Type][Style], Position);
			}
			
			iSize = GetArraySize(g_hTimes[Type][Style]);
			Position = -1;
			
			for(new idx = 0; idx < iSize; idx++)
			{
				if(Time < GetArrayCell(g_hTimes[Type][Style], idx, 1))
				{
					Position = idx;
					break;
				}
			}
			
			if(Position == -1)
				Position = iSize;
			
			if(Position >= iSize)
			{
				ResizeArray(g_hTimes[Type][Style], Position + 1);
				ResizeArray(g_hTimesUsers[Type][Style], Position + 1);
			}
			else
			{
				ShiftArrayUp(g_hTimes[Type][Style], Position);
				ShiftArrayUp(g_hTimesUsers[Type][Style], Position);
			}
				
			SetArrayCell(g_hTimes[Type][Style], Position, PlayerID, 0);
			SetArrayCell(g_hTimes[Type][Style], Position, Time, 1);
			
			decl String:sName[MAX_NAME_LENGTH];
			GetClientName(client, sName, sizeof(sName));
			SetArrayString(g_hTimesUsers[Type][Style], Position, sName);
			
			return Position + 1;
		}
	}
	
	return 0;
}

public DB_UpdateTime_Callback1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:sMapName[64];
		
		ResetPack(data);
		ReadPackString(data, sMapName, sizeof(sMapName));
		ReadPackCell(data);
		new PlayerID     = ReadPackCell(data);
		new Type         = ReadPackCell(data);
		new Style        = ReadPackCell(data);
		new Float:Time   = ReadPackFloat(data);
		new Jumps        = ReadPackCell(data);
		new Strafes      = ReadPackCell(data);
		new Float:Sync   = ReadPackFloat(data);
		new Float:Sync2  = ReadPackFloat(data);
		
		decl String:query[512];
		Format(query, sizeof(query), "INSERT INTO times (MapID, Type, Style, PlayerID, Time, Jumps, Strafes, Points, Timestamp, Sync, SyncTwo) VALUES ((SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1), %d, %d, %d, %f, %d, %d, 0, %d, %f, %f)", 
			sMapName,
			Type,
			Style,
			PlayerID,
			Time,
			Jumps,
			Strafes,
			GetTime(),
			Sync,
			Sync2);
		SQL_TQuery(g_DB, DB_UpdateTime_Callback2, query, data);
	}
	else
	{
		CloseHandle(data);
		LogError(error);
	}
}

public DB_UpdateTime_Callback2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		
		decl String:sMapName[64];
		ReadPackString(data, sMapName, sizeof(sMapName));
		ReadPackCell(data);
		ReadPackCell(data);
		new Type  = ReadPackCell(data);
		new Style = ReadPackCell(data);
		
		Call_StartForward(g_fwdOnTimesUpdated);
		Call_PushString(sMapName);
		Call_PushCell(Type);
		Call_PushCell(Style);
		Call_PushCell(g_hTimes[Type][Style]);
		Call_Finish();
		//DB_UpdateRanks(sMapName, Type, Style);
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

// Opens a menu that displays the records on the given map
DB_DisplayRecords(client, String:sMapName[], Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	WritePackString(pack, sMapName);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT Time, User, Jumps, Strafes, Points, Timestamp, T.PlayerID, Sync, SyncTwo FROM times AS T JOIN players AS P ON T.PlayerID=P.PlayerID AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d ORDER BY Time, Timestamp",
		sMapName,
		Type,
		Style);
	SQL_TQuery(g_DB, DB_DisplayRecords_Callback1, query, pack);
}

public DB_DisplayRecords_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{		
		ResetPack(data);
		new client = ReadPackCell(data);
		new Type   = ReadPackCell(data);
		new Style  = ReadPackCell(data);
		
		decl String:sMapName[64];
		ReadPackString(data, sMapName, sizeof(sMapName));
		
		new rowcount = SQL_GetRowCount(hndl);
		if(rowcount != 0)
		{	
			decl String:name[(MAX_NAME_LENGTH*2)+1], String:title[128], String:item[256], String:info[256], String:sTime[32];
			new Float:time, Float:points, jumps, strafes, timestamp, PlayerID, Float:ClientTime, MapRank, Float:Sync[2];
			
			new Handle:menu = CreateMenu(Menu_WorldRecord);	
			new RowCount = SQL_GetRowCount(hndl);
			for(new i = 1; i <= RowCount; i++)
			{
				SQL_FetchRow(hndl);
				time      = SQL_FetchFloat(hndl, 0);
				SQL_FetchString(hndl, 1, name, sizeof(name));
				jumps     = SQL_FetchInt(hndl, 2);
				FormatPlayerTime(time, sTime, sizeof(sTime), false, 1);
				strafes   = SQL_FetchInt(hndl, 3);
				points    = SQL_FetchFloat(hndl, 4);
				timestamp = SQL_FetchInt(hndl, 5);
				PlayerID  = SQL_FetchInt(hndl, 6);
				Sync[0]   = SQL_FetchFloat(hndl, 7);
				Sync[1]   = SQL_FetchFloat(hndl, 8);
				
				if(PlayerID == GetPlayerID(client))
				{
					ClientTime	= time;
					MapRank		= i;
				}
				
				Format(info, sizeof(info), "%d;%d;%d;%s;%.1f;%d;%d;%d;%d;%d;%s;%f;%f",
					PlayerID,
					Type,
					Style,
					sTime,
					points,
					i,
					rowcount,
					timestamp,
					jumps,
					strafes,
					sMapName,
					Sync[0],
					Sync[1]);
					
				Format(item, sizeof(item), "#%d: %s - %s",
					i,
					sTime,
					name);
				
				if((i % 7) == 0 || i == RowCount)
					Format(item, sizeof(item), "%s\n--------------------------------------", item);
				
				AddMenuItem(menu, info, item);
			}
			
			decl String:sType[32];
			GetTypeName(Type, sType, sizeof(sType));
			
			decl String:sStyle[32];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			if(ClientTime != 0.0)
			{
				decl String:sClientTime[32];
				FormatPlayerTime(ClientTime, sClientTime, sizeof(sClientTime), false, 1);
				FormatEx(title, sizeof(title), "%s records [%s] - [%s]\n \nYour time: %s ( %d / %d )\n--------------------------------------",
					sMapName,
					sType,
					sStyle,
					sClientTime,
					MapRank,
					rowcount);
			}
			else
			{
				FormatEx(title, sizeof(title), "%s records [%s] - [%s]\n \n%d total\n--------------------------------------",
					sMapName,
					sType,
					sStyle,
					rowcount);
			}
			
			SetMenuTitle(menu, title);
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			if(Type == TIMER_MAIN)
				PrintToChat(client, "%s%sNo one has beaten the map yet",
					g_msg_start,
					g_msg_textcol);
			else
				PrintToChat(client, "%s%sNo one has beaten the bonus on this map yet.",
					g_msg_start,
					g_msg_textcol);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

public Menu_WorldRecord(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:sInfo[256];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		ShowRecordInfo(param1, sInfo);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

/*
PlayerID, 0
Type, 1
Style, 2
sTime, 3
points, 4
map rank, 5
total map ranks, 6
timestamp, 7
jumps, 8
strafes, 9
sMapName, 10
Sync[0], 11
Sync[1] 12
*/

ShowRecordInfo(client, const String:sInfo[256])
{
	decl String:sInfoExploded[13][64];
	ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
	
	new Handle:menu = CreateMenu(Menu_ShowRecordInfo);
	
	new PlayerID = StringToInt(sInfoExploded[0]);
	decl String:sName[MAX_NAME_LENGTH];
	GetNameFromPlayerID(PlayerID, sName, sizeof(sName));
	
	decl String:sTitle[256];
	FormatEx(sTitle, sizeof(sTitle), "Record details of %s\n \n", sName);
	
	Format(sTitle, sizeof(sTitle), "%sMap: %s\n \n", sTitle, sInfoExploded[10]);
	
	Format(sTitle, sizeof(sTitle), "%sTime: %s (%s / %s)\n \n", sTitle, sInfoExploded[3], sInfoExploded[5], sInfoExploded[6]);
	
	Format(sTitle, sizeof(sTitle), "%sPoints: %s\n \n", sTitle, sInfoExploded[4]);
	
	new Type = StringToInt(sInfoExploded[1]);
	decl String:sType[32];
	GetTypeName(Type, sType, sizeof(sType));
	
	new Style = StringToInt(sInfoExploded[2]);
	decl String:sStyle[32];
	GetStyleName(Style, sStyle, sizeof(sStyle));
	
	Format(sTitle, sizeof(sTitle), "%sTimer: %s\nStyle: %s\n \n", sTitle, sType, sStyle);
	
	if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
	{
		Format(sTitle, sizeof(sTitle), "%sJumps/Strafes: %s/%s\n \n", sTitle, sInfoExploded[8], sInfoExploded[9]);
	}
	else
	{
		Format(sTitle, sizeof(sTitle), "%sJumps: %s\n \n", sTitle, sInfoExploded[8]);
	}
	
	decl String:sTimeStamp[32];
	FormatTime(sTimeStamp, sizeof(sTimeStamp), "%x %X", StringToInt(sInfoExploded[7]));
	Format(sTitle, sizeof(sTitle), "%sDate: %s\n \n", sTitle, sTimeStamp);
	
	if(g_StyleConfig[Style][CalcSync])
	{
		if(g_bIsAdmin[client] == true)
		{
			Format(sTitle, sizeof(sTitle), "%sSync 1: %.3f%%\n", sTitle, StringToFloat(sInfoExploded[11]));
			Format(sTitle, sizeof(sTitle), "%sSync 2: %.3f%%\n \n", sTitle, StringToFloat(sInfoExploded[12]));
		}
		else
		{
			Format(sTitle, sizeof(sTitle), "%sSync: %.3f%%\n \n", sTitle, StringToFloat(sInfoExploded[11]));
		}
	}
	
	SetMenuTitle(menu, sTitle);
	
	decl String:sItemInfo[32];
	FormatEx(sItemInfo, sizeof(sItemInfo), "%d;%d;%d", PlayerID, Type, Style);
	
	AddMenuItem(menu, sItemInfo, "Show player stats");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_ShowRecordInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:sInfo[32];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		
		decl String:sInfoExploded[3][16];
		ExplodeString(sInfo, ";", sInfoExploded, sizeof(sInfoExploded), sizeof(sInfoExploded[]));
		
		Timer_OpenStatsMenu(param1, StringToInt(sInfoExploded[0]), StringToInt(sInfoExploded[1]), StringToInt(sInfoExploded[2]));
	}
	if(action == MenuAction_End)
		CloseHandle(menu);
}

DB_ShowTimeAtRank(client, const String:MapName[], rank, Type, Style)
{		
	if(rank < 1)
	{
		PrintToChat(client, "%s%s%d%s is not a valid rank.",
			g_msg_start,
			g_msg_varcol,
			rank,
			g_msg_textcol);
			
		return;
	}
	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, rank);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT t2.User, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp FROM times AS t1, players AS t2 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1",
		MapName,
		Type,
		Style,
		rank-1);
	SQL_TQuery(g_DB, DB_ShowTimeAtRank_Callback1, query, pack);
}

public DB_ShowTimeAtRank_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{		
		ResetPack(pack);
		new client = ReadPackCell(pack);
		ReadPackCell(pack);
		new Type   = ReadPackCell(pack);
		new Style  = ReadPackCell(pack);
		
		if(SQL_GetRowCount(hndl) == 1)
		{
			decl String:sUserName[MAX_NAME_LENGTH], String:sTimeStampDay[255], String:sTimeStampTime[255], String:sfTime[255];
			new Float:fTime, iJumps, iStrafes, Float:fPoints, iTimeStamp;
			
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sUserName, sizeof(sUserName));
			fTime      = SQL_FetchFloat(hndl, 1);
			iJumps     = SQL_FetchInt(hndl, 2);
			iStrafes   = SQL_FetchInt(hndl, 3);
			fPoints    = SQL_FetchFloat(hndl, 4);
			iTimeStamp = SQL_FetchInt(hndl, 5);
			
			FormatPlayerTime(fTime, sfTime, sizeof(sfTime), false, 1);
			FormatTime(sTimeStampDay, sizeof(sTimeStampDay), "%x", iTimeStamp);
			FormatTime(sTimeStampTime, sizeof(sTimeStampTime), "%X", iTimeStamp);
			
			decl String:sType[32];
			GetTypeName(Type, sType, sizeof(sType));
			
			decl String:sStyle[32];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
			{
				PrintToChat(client, "%s%s[%s] %s-%s [%s] %s%s has time %s%s%s\n(%s%d%s jumps, %s%.1f%s points)\nDate: %s%s %s%s.",
					g_msg_start,
					g_msg_varcol,
					sType,
					g_msg_textcol,
					g_msg_varcol,
					sStyle,
					sUserName,
					g_msg_textcol,
					g_msg_varcol,
					sfTime,
					g_msg_textcol,
					g_msg_varcol,
					iJumps,
					g_msg_textcol,
					g_msg_varcol,
					fPoints,
					g_msg_textcol,
					g_msg_varcol,
					sTimeStampDay,
					sTimeStampTime,
					g_msg_textcol);
			}
			else
			{
				PrintToChat(client, "%s%s[%s] %s-%s [%s] %s%s has time %s%s%s\n(%s%d%s jumps, %s%d%s strafes, %s%.1f%s points)\nDate: %s%s %s%s.",
					g_msg_start,
					g_msg_varcol,
					sType,
					g_msg_textcol,
					g_msg_varcol,
					sStyle,
					sUserName,
					g_msg_textcol,
					g_msg_varcol,
					sfTime,
					g_msg_textcol,
					g_msg_varcol,
					iJumps,
					g_msg_textcol,
					g_msg_varcol,
					iStrafes,
					g_msg_textcol,
					g_msg_varcol,
					fPoints,
					g_msg_textcol,
					g_msg_varcol,
					sTimeStampDay,
					sTimeStampTime,
					g_msg_textcol);
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

DB_ShowTime(client, target, const String:MapName[], Type, Style)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, target);
	WritePackCell(pack, Type);
	WritePackCell(pack, Style);
	
	new PlayerID = GetPlayerID(target);
	
	decl String:query[800];
	FormatEx(query, sizeof(query), "SELECT (SELECT count(*) FROM times WHERE Time<=(SELECT Time FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d) AND MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d) AS Rank, (SELECT count(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d) AS Timescount, Time, Jumps, Strafes, Points, Timestamp FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND PlayerID=%d", 
		MapName, 
		Type, 
		Style, 
		PlayerID, 
		MapName, 
		Type, 
		Style, 
		MapName, 
		Type, 
		Style, 
		MapName, 
		Type, 
		Style, 
		PlayerID);	
	SQL_TQuery(g_DB, DB_ShowTime_Callback1, query, pack);
}

public DB_ShowTime_Callback1(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(pack);
		new client	= ReadPackCell(pack);
		new target	= ReadPackCell(pack);
		new Type		= ReadPackCell(pack);
		new Style 	= ReadPackCell(pack);
		
		new TargetID = GetPlayerID(target);
		
		if(IsClientInGame(client) && IsClientInGame(target) && TargetID)
		{
			decl String:sTime[32], String:sDate[32], String:sDateDay[32], String:sName[MAX_NAME_LENGTH];
			GetClientName(target, sName, sizeof(sName));
			
			decl String:sType[32];
			GetTypeName(Type, sType, sizeof(sType));
			
			decl String:sStyle[32];
			GetStyleName(Style, sStyle, sizeof(sStyle));
			
			if(SQL_GetRowCount(hndl) == 1)
			{
				SQL_FetchRow(hndl);
				new Rank 		 = SQL_FetchInt(hndl, 0);
				new Timescount   	 = SQL_FetchInt(hndl, 1);
				new Float:Time 	 = SQL_FetchFloat(hndl, 2);
				new Jumps 		 = SQL_FetchInt(hndl, 3);
				new Strafes 	 	 = SQL_FetchInt(hndl, 4);
				new Float:Points 	 = SQL_FetchFloat(hndl, 5);
				new TimeStamp 	 = SQL_FetchInt(hndl, 6);
				
				FormatPlayerTime(Time, sTime, sizeof(sTime), false, 1);
				FormatTime(sDate, sizeof(sDate), "%x", TimeStamp);
				FormatTime(sDateDay, sizeof(sDateDay), "%X", TimeStamp);
				
				if(g_StyleConfig[Style][Count_Left_Strafe] || g_StyleConfig[Style][Count_Right_Strafe] || g_StyleConfig[Style][Count_Back_Strafe] || g_StyleConfig[Style][Count_Forward_Strafe])
				{
					PrintToChat(client, "%s%s[%s] %s-%s [%s] %s %shas time %s%s%s (%s%d%s / %s%d%s)",
						g_msg_start,
						g_msg_varcol,
						sType,
						g_msg_textcol,
						g_msg_varcol,
						sStyle,
						sName,
						g_msg_textcol,
						g_msg_varcol,
						sTime,
						g_msg_textcol,
						g_msg_varcol,
						Rank,
						g_msg_textcol,
						g_msg_varcol,
						Timescount,
						g_msg_textcol);
					
					PrintToChat(client, "%sDate: %s%s %s",
						g_msg_textcol,
						g_msg_varcol,
						sDate,
						sDateDay);
					
					PrintToChat(client, "%s(%s%d%s jumps, %s%d%s strafes, and %s%4.1f%s points)",
						g_msg_textcol,
						g_msg_varcol,
						Jumps,
						g_msg_textcol,
						g_msg_varcol,
						Strafes,
						g_msg_textcol,
						g_msg_varcol,
						Points,
						g_msg_textcol);
				}
				else
				{
					PrintToChat(client, "%s%s[%s] %s-%s [%s] %s %shas time %s%s%s (%s%d%s / %s%d%s)",
						g_msg_start,
						g_msg_varcol,
						sType,
						g_msg_textcol,
						g_msg_varcol,
						sStyle,
						sName,
						g_msg_textcol,
						g_msg_varcol,
						sTime,
						g_msg_textcol,
						g_msg_varcol,
						Rank,
						g_msg_textcol,
						g_msg_varcol,
						Timescount,
						g_msg_textcol);
					
					PrintToChat(client, "%sDate: %s%s %s",
						g_msg_textcol,
						g_msg_varcol,
						sDate,
						sDateDay);
					
					PrintToChat(client, "%s(%s%d%s jumps and %s%4.1f%s points)",
						g_msg_textcol,
						g_msg_varcol,
						Jumps,
						g_msg_textcol,
						g_msg_varcol,
						Points,
						g_msg_textcol);
				}
			}
			else
			{
				if(GetPlayerID(client) != TargetID)
				{
					PrintToChat(client, "%s%s[%s] %s-%s [%s] %s %shas no time on the map.",
						g_msg_start,
						g_msg_varcol,
						sType,
						g_msg_textcol,
						g_msg_varcol,
						sStyle,
						sName,
						g_msg_textcol);
				}
				else
					PrintToChat(client, "%s%s[%s] %s-%s [%s] %sYou have no time on the map.",
						g_msg_start,
						g_msg_varcol,
						sType,
						g_msg_textcol,
						g_msg_varcol,
						sStyle,
						g_msg_textcol);
			}
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(pack);
}

DB_DeleteRecord(client, Type, Style, RecordOne, RecordTwo)
{
	new Handle:data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, Type);
	WritePackCell(data, Style);
	WritePackCell(data, RecordOne);
	WritePackCell(data, RecordTwo);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT COUNT(*) FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d",
		g_sMapName,
		Type,
		Style);
	SQL_TQuery(g_DB, DB_DeleteRecord_Callback1, query, data);
}

public DB_DeleteRecord_Callback1(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client		= ReadPackCell(data);
		new Type      	= ReadPackCell(data);
		new Style 	   	= ReadPackCell(data);
		new RecordOne 	= ReadPackCell(data);
		new RecordTwo 	= ReadPackCell(data);
		
		SQL_FetchRow(hndl);
		new timesCount = SQL_FetchInt(hndl, 0);
		
		new String:sInfo[32];
		if(Type == TIMER_BONUS)
		{
			GetTypeName(Type, sInfo, sizeof(sInfo), true);
			StringToUpper(sInfo);
			Format(sInfo, sizeof(sInfo), "[%s] ", sInfo);
		}
		else if(Style != 0)
		{
			GetStyleName(Style, sInfo, sizeof(sInfo), true);
			StringToUpper(sInfo);
			Format(sInfo, sizeof(sInfo), "[%s] ", sInfo);
		}
		
		if(RecordTwo > timesCount)
		{
			PrintToChat(client, "%s%s%s%sThere is no record %s%d%s.", 
				g_msg_start,
				g_msg_varcol,
				sInfo, 
				g_msg_textcol,
				g_msg_varcol,
				RecordTwo,
				g_msg_textcol);
				
			PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
			
			return;
		}
		if(RecordOne < 1)
		{
			PrintToChat(client, "%s%sThe minimum record number is 1.",
				g_msg_start,
				g_msg_textcol);
				
			PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
			
			return;
		}
		if(RecordOne > RecordTwo)
		{
			PrintToChat(client, "%s%sRecord 1 can't be larger than record 2.",
				g_msg_start,
				g_msg_textcol);
				
			PrintToConsole(client, "[SM] Usage:\nsm_delete record - Deletes a specific record.\nsm_delete record1 record2 - Deletes all times from record1 to record2.");
			
			return;
		}
		
		decl String:query[700];
		Format(query, sizeof(query), "DELETE FROM times WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND Type=%d AND Style=%d AND Time BETWEEN (SELECT t1.Time FROM (SELECT * FROM times) AS t1 WHERE t1.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.Type=%d AND t1.Style=%d ORDER BY t1.Time LIMIT %d, 1) AND (SELECT t2.Time FROM (SELECT * FROM times) AS t2 WHERE t2.MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t2.Type=%d AND t2.Style=%d ORDER BY t2.Time LIMIT %d, 1)",
			g_sMapName,
			Type,
			Style,
			g_sMapName,
			Type,
			Style,
			RecordOne-1,
			g_sMapName,
			Type,
			Style,
			RecordTwo-1);
		SQL_TQuery(g_DB, DB_DeleteRecord_Callback2, query, data);
	}
	else
	{
		CloseHandle(data);
		LogError(error);
	}
}

public DB_DeleteRecord_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{

	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		ReadPackCell(data);
		new Type      = ReadPackCell(data);
		new Style     = ReadPackCell(data);
		new RecordOne = ReadPackCell(data);
		new RecordTwo = ReadPackCell(data);
		
		new PlayerID;
		for(new client = 1; client <= MaxClients; client++)
		{
			PlayerID = GetPlayerID(client);
			if(GetPlayerID(client) != 0 && IsClientInGame(client))
			{
				for(new idx = RecordOne - 1; idx < RecordTwo; idx++)
				{
					if(GetArrayCell(g_hTimes[Type][Style], idx, 0) == PlayerID)
					{
						g_fTime[client][Type][Style] = 0.0;
                        Format(g_sTime[client][Type][Style], sizeof(g_sTime[][][]), "PR: <font color='#6078A8'>N/A</font>");
					}
				}
			}
		}
		
		// Start the OnTimesDeleted forward
		Call_StartForward(g_fwdOnTimesDeleted);
		Call_PushCell(Type);
		Call_PushCell(Style);
		Call_PushCell(RecordOne);
		Call_PushCell(RecordTwo);
		Call_PushCell(g_hTimes[Type][Style]);
		Call_Finish();
		
		// Reload the times because some were deleted
		DB_LoadTimes(false);
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

DB_LoadTimes(bool:FirstTime)
{	
	#if defined DEBUG
		LogMessage("Attempting to load map times");
	#endif
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT t1.rownum, t1.MapID, t1.Type, t1.Style, t1.PlayerID, t1.Time, t1.Jumps, t1.Strafes, t1.Points, t1.Timestamp, t2.User FROM times AS t1, players AS t2 WHERE MapID=(SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1) AND t1.PlayerID=t2.PlayerID ORDER BY t1.Type, t1.Style, t1.Time, t1.Timestamp",
		g_sMapName);
		
	new	Handle:pack = CreateDataPack();
	WritePackCell(pack, FirstTime);
	WritePackString(pack, g_sMapName);
	
	SQL_TQuery(g_DB, LoadTimes_Callback, query, pack);
}

public LoadTimes_Callback(Handle:owner, Handle:hndl, String:error[], any:pack)
{
	if(hndl != INVALID_HANDLE)
	{
		#if defined DEBUG
			LogMessage("Loading times successful");
		#endif
		
		ResetPack(pack);
		new	bool:FirstTime = bool:ReadPackCell(pack);
		
		decl String:sMapName[64];
		ReadPackString(pack, sMapName, sizeof(sMapName));
		
		if(StrEqual(g_sMapName, sMapName))
		{
			for(new Type; Type < MAX_TYPES; Type++)
			{
				for(new Style; Style < g_TotalStyles; Style++)
				{
					ClearArray(g_hTimes[Type][Style]);
					ClearArray(g_hTimesUsers[Type][Style]);
				}
			}
			
			new rows = SQL_GetRowCount(hndl), Type, Style, iSize, String:sUser[MAX_NAME_LENGTH];
			for(new i = 0; i < rows; i++)
			{
				SQL_FetchRow(hndl);
				
				Type  = SQL_FetchInt(hndl, SQL_Column_Type);
				Style = SQL_FetchInt(hndl, SQL_Column_Style);
				
				iSize = GetArraySize(g_hTimes[Type][Style]);
				ResizeArray(g_hTimes[Type][Style], iSize + 1);
				
				SetArrayCell(g_hTimes[Type][Style], iSize, SQL_FetchInt(hndl, SQL_Column_PlayerID), 0);
				
				SetArrayCell(g_hTimes[Type][Style], iSize, SQL_FetchFloat(hndl, SQL_Column_Time), 1);
				
				SQL_FetchString(hndl, 10, sUser, sizeof(sUser));
				PushArrayString(g_hTimesUsers[Type][Style], sUser);
			}
			
			LoadWorldRecordInfo();
			
			g_bTimesAreLoaded  = true;
			
			Call_StartForward(g_fwdOnTimesLoaded);
			Call_Finish();
			
			if(FirstTime)
			{
				for(new client = 1; client <= MaxClients; client++)
				{
					DB_LoadPlayerInfo(client);
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
}

LoadWorldRecordInfo()
{
	decl String:sUser[MAX_NAME_LENGTH], String:sStyleAbbr[8], String:sTypeAbbr[8], iSize;
	
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
		StringToUpper(sTypeAbbr);
		
		for(new Style; Style < MAX_STYLES; Style++)
		{
			if(g_StyleConfig[Style][AllowType][Type])
			{
				GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr), true);
				StringToUpper(sStyleAbbr);
				
				iSize = GetArraySize(g_hTimes[Type][Style]);
				if(iSize > 0)
				{
					g_WorldRecord[Type][Style] = GetArrayCell(g_hTimes[Type][Style], 0, 1);
					
					FormatPlayerTime(g_WorldRecord[Type][Style], g_sRecord[Type][Style], sizeof(g_sRecord[][]), false, 1);
					
					GetArrayString(g_hTimesUsers[Type][Style], 0, sUser, MAX_NAME_LENGTH);
					
                    Format(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "%s", g_sRecord[Type][Style]);
				}
				else
				{
					g_WorldRecord[Type][Style] = 0.0;
					
                    Format(g_sRecord[Type][Style], sizeof(g_sRecord[][]), "N/A");
				}
			}
		}
	}
}

VectorAngles(Float:vel[3], Float:angles[3])
{
	new Float:tmp, Float:yaw, Float:pitch;
	
	if (vel[1] == 0 && vel[0] == 0)
	{
		yaw = 0.0;
		if (vel[2] > 0)
			pitch = 270.0;
		else
			pitch = 90.0;
	}
	else
	{
		yaw = (ArcTangent2(vel[1], vel[0]) * (180 / 3.141593));
		if (yaw < 0)
			yaw += 360;

		tmp = SquareRoot(vel[0]*vel[0] + vel[1]*vel[1]);
		pitch = (ArcTangent2(-vel[2], tmp) * (180 / 3.141593));
		if (pitch < 0)
			pitch += 360;
	}
	
	angles[0] = pitch;
	angles[1] = yaw;
	angles[2] = 0.0;
}

GetDirection(client)
{
	new Float:vVel[3];
	Entity_GetAbsVelocity(client, vVel);
	
	new Float:vAngles[3];
	GetClientEyeAngles(client, vAngles);
	new Float:fTempAngle = vAngles[1];

	VectorAngles(vVel, vAngles);

	if(fTempAngle < 0)
		fTempAngle += 360;

	new Float:fTempAngle2 = fTempAngle - vAngles[1];

	if(fTempAngle2 < 0)
		fTempAngle2 = -fTempAngle2;
	
	if(fTempAngle2 < 22.5 || fTempAngle2 > 337.5)
		return 1; // Forwards
	if(fTempAngle2 > 22.5 && fTempAngle2 < 67.5 || fTempAngle2 > 292.5 && fTempAngle2 < 337.5 )
		return 2; // Half-sideways
	if(fTempAngle2 > 67.5 && fTempAngle2 < 112.5 || fTempAngle2 > 247.5 && fTempAngle2 < 292.5)
		return 3; // Sideways
	if(fTempAngle2 > 112.5 && fTempAngle2 < 157.5 || fTempAngle2 > 202.5 && fTempAngle2 < 247.5)
		return 4; // Backwards Half-sideways
	if(fTempAngle2 > 157.5 && fTempAngle2 < 202.5)
		return 5; // Backwards
	
	return 0; // Unknown
}

CheckSync(client, buttons, Float:vel[3], Float:angles[3])
{
	new Direction = GetDirection(client);
	
	if(Direction == 1 && GetClientVelocity(client, true, true, false) != 0)
	{	
		new flags = GetEntityFlags(client);
		new MoveType:movetype = GetEntityMoveType(client);
		if(!(flags & (FL_ONGROUND|FL_INWATER)) && (movetype != MOVETYPE_LADDER))
		{
			// Normalize difference
			new Float:fAngleDiff = angles[1] - g_fOldAngle[client];
			if (fAngleDiff > 180)
				fAngleDiff -= 360;
			else if(fAngleDiff < -180)
				fAngleDiff += 360;
			
			// Add to good sync if client buttons match up
			if(fAngleDiff > 0)
			{
				g_totalSync[client]++;
				if((buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT))
				{
					g_goodSync[client]++;
				}
				if(vel[1] < 0)
				{
					g_goodSyncVel[client]++;
				}
			}
			else if(fAngleDiff < 0)
			{
				g_totalSync[client]++;
				if((buttons & IN_MOVERIGHT) && !(buttons & IN_MOVELEFT))
				{
					g_goodSync[client]++;
				}
				if(vel[1] > 0)
				{
					g_goodSyncVel[client]++;
				}
			}
		}
	}
	
	g_fOldAngle[client] = angles[1];
}

void GetTimeColor(Float:time, Float:wr, String:color[], maxlength)
{
	if (wr == 0.0) 
	{
		FormatEx(color, maxlength, "00FF00");
		return;
	}

	new Float:ratio = time / wr;
	if (ratio < 1.0)
	{
		if (ratio <= 0.5)
			FormatEx(color, maxlength, "%02XFF00", RoundFloat(510.0 * ratio));
		else
			FormatEx(color, maxlength, "FF%02X00", RoundFloat(510.0 * (1.0 - ratio))); // 255 - 510 * (ratio - 0.5)
	}
	else
		FormatEx(color, maxlength, "6078A8");
}

bool:CheckRestrict(Float:vel[3], Style)
{
    if(g_StyleConfig[Style][Prevent_Left] && vel[1] < 0)
        return true;
    if(g_StyleConfig[Style][Prevent_Right] && vel[1] > 0)
        return true;
    if(g_StyleConfig[Style][Prevent_Back] && vel[0] < 0)
        return true;
    if(g_StyleConfig[Style][Prevent_Forward] && vel[0] > 0)
        return true;

    if(g_StyleConfig[Style][Require_Left] && vel[1] >= 0)
        return true;
    if(g_StyleConfig[Style][Require_Right] && vel[1] <= 0)
        return true;
    if(g_StyleConfig[Style][Require_Back] && vel[0] >= 0)
        return true;
    if(g_StyleConfig[Style][Require_Forward] && vel[0] <= 0)
        return true;
    return false;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{	
	g_UnaffectedButtons[client] = buttons;
	
	if(IsPlayerAlive(client))
	{
		new Style = g_Style[client][g_Type[client]];
		
		// Key restriction
		new bool:bRestrict = CheckRestrict(vel, Style);
		
		
		if(GetEntityFlags(client) & FL_ONGROUND)
			bRestrict = false;
		
		if(g_StyleConfig[Style][Special])
		{
			if(StrEqual(g_StyleConfig[Style][Special_Key], "hsw"))
			{
				if(vel[0] > 0 && vel[1] != 0)
					g_HSWCounter[client] = GetEngineTime();
				
				if(((GetEngineTime() - g_HSWCounter[client] > 0.4) || vel[0] <= 0) && !(GetEntityFlags(client) & FL_ONGROUND))
				{
					bRestrict = true;
				}
			}
			if (StrEqual(g_StyleConfig[Style][Special_Key], "surfhsw-aw-sd"))
			{
				if (vel[0] > 0 && vel[1] < 0)
				{
					g_HSWCounter[client] = GetEngineTime();
				}
				else
				{
					if (vel[0] < 0 && vel[1] > 0)
					{
						g_HSWCounter[client] = GetEngineTime();
					}
					if((GetEngineTime() - g_HSWCounter[client] > 0.4) && !(GetEntityFlags(client) & FL_ONGROUND))
					{
						bRestrict = true;
					}
				}
			}
			if (StrEqual(g_StyleConfig[Style][Special_Key], "surfhsw-as-wd"))
			{
				if (vel[0] < 0 && vel[1] < 0)
				{
					g_HSWCounter[client] = GetEngineTime();
				}
				else{
					if (vel[0] > 0 && vel[1] > 0)
					{
						g_HSWCounter[client] = GetEngineTime();
					}
					if((GetEngineTime() - g_HSWCounter[client] > 0.4) && !(GetEntityFlags(client) & FL_ONGROUND))
					{
						bRestrict = true;
					}
				}
			}
		}
		
		if(g_StyleConfig[Style][Freestyle] && g_StyleConfig[Style][Freestyle_Unrestrict])
			if(Timer_InsideZone(client, FREESTYLE, 1 << Style) != -1)
				bRestrict = false;
			
		if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
			bRestrict = false;
		
		if(bRestrict == true)
		{
			if(!(GetEntityFlags(client) & FL_ATCONTROLS))
				SetEntityFlags(client, GetEntityFlags(client) | FL_ATCONTROLS);
		}
		else
		{
			if(GetEntityFlags(client) & FL_ATCONTROLS)
				SetEntityFlags(client, GetEntityFlags(client) &  ~FL_ATCONTROLS);
		}
		
		// Count strafes
		if(g_StyleConfig[Style][Count_Left_Strafe] && !(g_Buttons[client] & IN_MOVELEFT) && (buttons & IN_MOVELEFT))
			g_Strafes[client]++;
		if(g_StyleConfig[Style][Count_Right_Strafe] && !(g_Buttons[client] & IN_MOVERIGHT) && (buttons & IN_MOVERIGHT))
			g_Strafes[client]++;
		if(g_StyleConfig[Style][Count_Back_Strafe] && !(g_Buttons[client] & IN_BACK) && (buttons & IN_BACK))
			g_Strafes[client]++;
		if(g_StyleConfig[Style][Count_Forward_Strafe] && !(g_Buttons[client] & IN_FORWARD) && (buttons & IN_FORWARD))
			g_Strafes[client]++;
		
		// Calculate sync
		if(g_StyleConfig[Style][CalcSync] == true)
		{
			CheckSync(client, buttons, vel, angles);
		}
		
		// Check gravity
		if(g_StyleConfig[Style][Gravity] != 0.0)
		{
			if(GetEntityGravity(client) == 0.0)
			{
				SetEntityGravity(client, g_StyleConfig[Style][Gravity]);
			}
		}
		
		// Check TAS
		if(g_StyleConfig[Style][TAS] != false)
		{
			if(g_StyleConfig[Style][TAS] == true)
			{
				g_bTAS[client] = g_StyleConfig[Style][TAS];
			}
		}
		else
		{
			g_bTAS[client] = g_StyleConfig[Style][TAS];
		}
			
		if(g_bTiming[client] == true)
		{
			// Anti - +left/+right
			if(GetConVarBool(g_hAllowYawspeed) == false)
			{
				if(buttons & (IN_LEFT|IN_RIGHT))
				{
					StopTimer(client);
					
					if(Timer_InsideZone(client, MAIN_START, -1) == -1 && Timer_InsideZone(client, BONUS_START, -1) == -1)
					{
						PrintToChat(client, "%s%sYour timer was stopped for using +left/+right",
							g_msg_start,
							g_msg_textcol);
					}
				}
			}
			
			// Pausing
			if(g_bPaused[client] == true)
			{
				if(GetEntityMoveType(client) == MOVETYPE_WALK)
				{
					SetEntityMoveType(client, MOVETYPE_NONE);
				}
			}
			else
			{
				if(GetEntityMoveType(client) == MOVETYPE_NONE)
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
				}
			}
		}
		
		// auto bhop check
		if(g_bAllowAuto)
		{
			JumpButtonsFix[client] = bool:(buttons & IN_JUMP);
			
			if(sv_autobunnyhopping == null)
			{
				return;
			}

			sv_autobunnyhopping.BoolValue = (g_StyleConfig[Style][Auto] || (g_StyleConfig[Style][Freestyle] && g_StyleConfig[Style][Freestyle_Auto] && Timer_InsideZone(client, FREESTYLE, 1 << Style) != -1));

		}
		
		if(g_bJumpInStartZone == false)
		{
			if(Timer_InsideZone(client, MAIN_START, -1) != -1 || Timer_InsideZone(client, BONUS_START, -1) != -1)
			{
				buttons &= ~IN_JUMP;
			}
		}
	}
	
	g_Buttons[client] = buttons;
}
