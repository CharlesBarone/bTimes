#pragma semicolon 1
#pragma tabsize 0

#include <bTimes-core>

public Plugin myinfo = 
{
	name = "[bTimes] Zones",
    author = "Charles_(hypnos), rumour, blacky",
	description = "Used to create map zones",
	version = VERSION,
	url = ""
}

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <smlib/entities>
#include <bTimes-timer>
#include <bTimes-random>
#include <bTimes-zones>

new    Handle:g_DB,
	Handle:g_MapList,
	String:g_sMapName[64],
	Float:g_fSpawnPos[3],
	g_TotalZoneAllMaps[ZONE_COUNT];

// Zone properties
enum Properties
{
	Max,
	Count,
	Entity[64],
	bool:Ready[64],
	RowID[64],
	Flags[64],
	bool:Replaceable,
	bool:TriggerBased,
	String:Name[64],
	Color[4],
	HaloIndex,
	ModelIndex,
	Offset
};

new    g_Properties[ZONE_COUNT][Properties]; // Properties for each type of zone

// Zone setup
enum Setup
{
	bool:InZonesMenu,
	bool:InSetFlagsMenu,
	CurrentZone,
	Handle:SetupTimer,
	bool:Snapping,
	GridSnap,
	bool:ViewAnticheats
};

new    g_Setup[MAXPLAYERS + 1][Setup];

new    g_Entities_ZoneType[2048] = {-1, ...}, // For faster lookup of zone type by entity number
	g_Entities_ZoneNumber[2048] = {-1, ...}; // For faster lookup of zone number by entity number
new    Float:g_Zones[ZONE_COUNT][64][8][3], // Zones that have been created
	g_TotalZoneCount;
	
new    bool:g_bInside[MAXPLAYERS + 1][ZONE_COUNT][64];

new    g_SnapModelIndex,
	g_SnapHaloIndex;
	
// Zone drawing
new    g_Drawing_Zone,
	g_Drawing_ZoneNumber;

// Cvars
new    Handle:g_hZoneColor[ZONE_COUNT],
	Handle:g_hZoneOffset[ZONE_COUNT],
	Handle:g_hZoneTexture[ZONE_COUNT],
	Handle:g_hZoneTrigger[ZONE_COUNT],
	Handle:g_hZoneWidth[ZONE_COUNT];
	Handle:g_hZoneStyle[ZONE_COUNT];
	Handle:g_hZoneSpeed[ZONE_COUNT];
	
// Forwards
new    Handle:g_fwdOnZonesLoaded,
	Handle:g_fwdOnZoneStartTouch,
	Handle:g_fwdOnZoneEndTouch;
	
// Chat
new    String:g_msg_start[128],
	String:g_msg_varcol[128],
	String:g_msg_textcol[128];

public OnPluginStart()
{
	// Connect to database
	DB_Connect();

	// Cvars
	g_hZoneStyle[MAIN_START]    = CreateConVar("timer_mainstart_zonestyle", "1.0", "Set the main start zone drawing style. 0.0 = 2D, 1.0 = 3D", 0, true, 0.0, true, 1.0);
	g_hZoneStyle[MAIN_END]      = CreateConVar("timer_mainend_zonestyle", "1.0", "Set the main start zone drawing style. 0.0 = 2D, 1.0 = 3D", 0, true, 0.0, true, 1.0);
	g_hZoneStyle[BONUS_START]   = CreateConVar("timer_bonusstart_zonestyle", "1.0", "Set the main start zone drawing style. 0.0 = 2D, 1.0 = 3D", 0, true, 0.0, true, 1.0);
	g_hZoneStyle[BONUS_END]     = CreateConVar("timer_bonusend_zonestyle", "1.0", "Set the main start zone drawing style. 0.0 = 2D, 1.0 = 3D", 0, true, 0.0, true, 1.0);
	g_hZoneStyle[ANTICHEAT]     = CreateConVar("timer_ac_zonestyle", "1.0", "Set the main start zone drawing style. 0.0 = 2D, 1.0 = 3D", 0, true, 0.0, true, 1.0);
	g_hZoneStyle[FREESTYLE]     = CreateConVar("timer_fs_zonestyle", "1.0", "Set the main start zone drawing style. 0.0 = 2D, 1.0 = 3D", 0, true, 0.0, true, 1.0);
	
	g_hZoneSpeed[MAIN_START]    = CreateConVar("timer_mainstart_zonespeed", "1.0", "Set the main start zone's speed.", 0, true, 0.0, true, 1.0);
	g_hZoneSpeed[MAIN_END]      = CreateConVar("timer_mainend_zonespeed", "1.0", "Set the main start zone's speed.", 0, true, 0.0, true, 1.0);
	g_hZoneSpeed[BONUS_START]   = CreateConVar("timer_bonusstart_zonespeed", "1.0", "Set the main start zone's speed.", 0, true, 0.0, true, 1.0);
	g_hZoneSpeed[BONUS_END]     = CreateConVar("timer_bonusend_zonespeed", "1.0", "Set the main start zone's speed.", 0, true, 0.0, true, 1.0);
	g_hZoneSpeed[ANTICHEAT]     = CreateConVar("timer_ac_zonespeed", "1.0", "Set the main start zone's speed.", 0, true, 0.0, true, 1.0);
	g_hZoneSpeed[FREESTYLE]     = CreateConVar("timer_fs_zonespeed", "1.0", "Set the main start zone's speed.", 0, true, 0.0, true, 1.0);
	
	g_hZoneWidth[MAIN_START]    = CreateConVar("timer_mainstart_zonewidth", "1.0", "Set the main start zone's width.", 0, true, 1.0, true, 10.0);
	g_hZoneWidth[MAIN_END]      = CreateConVar("timer_mainend_zonewidth", "1.0", "Set the main start zone's width.", 0, true, 1.0, true, 10.0);
	g_hZoneWidth[BONUS_START]   = CreateConVar("timer_bonusstart_zonewidth", "1.0", "Set the main start zone's width.", 0, true, 1.0, true, 10.0);
	g_hZoneWidth[BONUS_END]     = CreateConVar("timer_bonusend_zonewidth", "1.0", "Set the main start zone's width.", 0, true, 1.0, true, 10.0);
	g_hZoneWidth[ANTICHEAT]     = CreateConVar("timer_ac_zonewidth", "1.0", "Set the main start zone's width.", 0, true, 1.0, true, 10.0);
	g_hZoneWidth[FREESTYLE]     = CreateConVar("timer_fs_zonewidth", "1.0", "Set the main start zone's width.", 0, true, 1.0, true, 10.0);
	
	g_hZoneColor[MAIN_START]    = CreateConVar("timer_mainstart_color", "0 255 0 255", "Set the main start zone's RGBA color");
	g_hZoneColor[MAIN_END]      = CreateConVar("timer_mainend_color", "255 0 0 255", "Set the main end zone's RGBA color");
	g_hZoneColor[BONUS_START]   = CreateConVar("timer_bonusstart_color", "0 255 255 255", "Set the bonus start zone's RGBA color");
	g_hZoneColor[BONUS_END]     = CreateConVar("timer_bonusend_color", "165 19 194 255", "Set the bonus end zone's RGBA color");
	g_hZoneColor[ANTICHEAT]     = CreateConVar("timer_ac_color", "255 255 0 255", "Set the anti-cheat zone's RGBA color");
	g_hZoneColor[FREESTYLE]     = CreateConVar("timer_fs_color", "0 0 255 255", "Set the freestyle zone's RGBA color");

	g_hZoneOffset[MAIN_START]   = CreateConVar("timer_mainstart_offset", "110", "Set the the default height for the main start zone.");
	g_hZoneOffset[MAIN_END]     = CreateConVar("timer_mainend_offset", "110", "Set the the default height for the main end zone.");
	g_hZoneOffset[BONUS_START]  = CreateConVar("timer_bonusstart_offset", "110", "Set the the default height for the bonus start zone.");
	g_hZoneOffset[BONUS_END]    = CreateConVar("timer_bonusend_offset", "110", "Set the the default height for the bonus end zone.");
	g_hZoneOffset[ANTICHEAT]    = CreateConVar("timer_ac_offset", "0", "Set the the default height for the anti-cheat zone.");
	g_hZoneOffset[FREESTYLE]    = CreateConVar("timer_fs_offset", "0", "Set the the default height for the freestyle zone.");

	g_hZoneTexture[MAIN_START]  = CreateConVar("timer_mainstart_tex", "materials/sprites/trails/bluelightningscroll3", "Texture for main start zone. (Exclude the file types like .vmt/.vtf)");
	g_hZoneTexture[MAIN_END]    = CreateConVar("timer_mainend_tex", "materials/sprites/trails/bluelightningscroll3", "Texture for main end zone.");
	g_hZoneTexture[BONUS_START] = CreateConVar("timer_bonusstart_tex", "materials/sprites/trails/bluelightningscroll3", "Texture for bonus start zone.");
	g_hZoneTexture[BONUS_END]   = CreateConVar("timer_bonusend_tex", "materials/sprites/trails/bluelightningscroll3", "Texture for main end zone.");
	g_hZoneTexture[ANTICHEAT]   = CreateConVar("timer_ac_tex", "materials/sprites/trails/bluelightningscroll3", "Texture for anti-cheat zone.");
	g_hZoneTexture[FREESTYLE]   = CreateConVar("timer_fs_tex", "materials/sprites/trails/bluelightningscroll3", "Texture for freestyle zone.");

	g_hZoneTrigger[MAIN_START]  = CreateConVar("timer_mainstart_trigger", "0", "Main start zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[MAIN_END]    = CreateConVar("timer_mainend_trigger", "0", "Main end zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[BONUS_START] = CreateConVar("timer_bonusstart_trigger", "0", "Bonus start zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[BONUS_END]   = CreateConVar("timer_bonusend_trigger", "0", "Bonus end zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[ANTICHEAT]   = CreateConVar("timer_ac_trigger", "0", "Anti-cheat zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);
	g_hZoneTrigger[FREESTYLE]   = CreateConVar("timer_fs_trigger", "1", "Freestyle zone trigger based (1) or uses old player detection method (0)", 0, true, 0.0, true, 1.0);

	AutoExecConfig(true, "zones", "timer");

	// Hook changes
	for(new Zone = 0; Zone < ZONE_COUNT; Zone++)
	{
		HookConVarChange(g_hZoneColor[Zone], OnZoneColorChanged);
		HookConVarChange(g_hZoneOffset[Zone], OnZoneOffsetChanged);    
		HookConVarChange(g_hZoneTrigger[Zone], OnZoneTriggerChanged);
	}

    // Admin Commands
    RegAdminCmd("sm_zones", SM_Zones, ADMFLAG_CHEATS, "Opens the zones menu.");
	RegAdminCmd("sm_zone", SM_Zones, ADMFLAG_CHEATS, "Opens the zones menu.");
	RegAdminCmd("sm_zonemenu", SM_Zones, ADMFLAG_CHEATS, "Opens the zones menu.");

	// Player Commands
	RegConsoleCmdEx("sm_b", SM_B, "Teleports you to the bonus area");
	RegConsoleCmdEx("sm_bonus", SM_B, "Teleports you to the bonus area");
	RegConsoleCmdEx("sm_br", SM_B, "Teleports you to the bonus area");
	RegConsoleCmdEx("sm_r", SM_R, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_restart", SM_R, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_respawn", SM_R, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_start", SM_R, "Teleports you to the starting zone");
	RegConsoleCmdEx("sm_end", SM_End, "Teleports your to the end zone");
	RegConsoleCmdEx("sm_endb", SM_EndB, "Teleports you to the bonus end zone");
	RegConsoleCmdEx("sm_showac", SM_ShowAC, "Toggles anticheats being visible");
	RegConsoleCmdEx("sm_showacs", SM_ShowAC, "Toggles anticheats being visible");
	
	    // Command listeners for easier team joining

    AddCommandListener(Command_Jointeam, "jointeam");
    AddCommandListener(Command_Jointeam, "spectate");

	// Events
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Natives
	CreateNative("Timer_InsideZone", Native_InsideZone);
	CreateNative("Timer_IsPointInsideZone", Native_IsPointInsideZone);
	CreateNative("Timer_TeleportToZone", Native_TeleportToZone);
	CreateNative("GetTotalZonesAllMaps", Native_GetTotalZonesAllMaps);
	
	// Forwards
	g_fwdOnZonesLoaded    = CreateGlobalForward("OnZonesLoaded", ET_Event);
	g_fwdOnZoneStartTouch = CreateGlobalForward("OnZoneStartTouch", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	g_fwdOnZoneEndTouch   = CreateGlobalForward("OnZoneEndTouch", ET_Event, Param_Cell, Param_Cell, Param_Cell);
}

/*
* Teleports a client to a zone, commented cause I think it causes my IDE to crash if I don't
*/
TeleportToZone(client, Zone, ZoneNumber, bool:bottom = false)
{
	StopTimer(client);
	
	if(g_Properties[Zone][Ready][ZoneNumber] == true)
	{
		new Float:vPos[3];
		GetZonePosition(Zone, ZoneNumber, vPos);
		
		if(bottom)
		{
			new Float:fBottom = (g_Zones[Zone][ZoneNumber][0][2] < g_Zones[Zone][ZoneNumber][7][2])?g_Zones[Zone][ZoneNumber][0][2]:g_Zones[Zone][ZoneNumber][7][2];
			
			TR_TraceRayFilter(vPos, Float:{90.0, 0.0, 0.0}, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
			
			if(TR_DidHit())
			{
				new Float:vHitPos[3];
				TR_GetEndPosition(vHitPos);
				
				if(vHitPos[2] < fBottom)
					vPos[2] = fBottom;
				else
					vPos[2] = vHitPos[2] + 0.5;
			}
			else
			{
				vPos[2] = fBottom;
			}
		}
		
		
		TeleportEntity(client, vPos, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	}
	else
	{
		TeleportEntity(client, g_fSpawnPos, NULL_VECTOR, Float:{0.0, 0.0, 0.0});
	}
}

public OnMapStart()
{
	if(g_MapList != INVALID_HANDLE)
		CloseHandle(g_MapList);

	g_MapList = ReadMapList();
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));

	g_SnapHaloIndex = PrecacheModel("materials/sprites/light_glow02.vmt");
	g_SnapModelIndex = PrecacheModel("materials/sprites/trails/bluelightningscroll3.vmt");
	PrecacheModel("models/props/cs_office/vending_machine.mdl");

	CreateTimer(0.1, Timer_SnapPoint, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, Timer_DrawBeams, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	// Check for t/ct spawns
	new t  = FindEntityByClassname(-1, "info_player_terrorist");
	new ct = FindEntityByClassname(-1, "info_player_counterterrorist");

	// Set map team and get spawn position
	if(t != -1)
		Entity_GetAbsOrigin(t, g_fSpawnPos);
	else
		Entity_GetAbsOrigin(ct, g_fSpawnPos);
}

public OnMapIDPostCheck()
{
	DB_LoadZones();
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	InitializePlayerProperties(client);
	
	return true;
}

public OnConfigsExecuted()
{
	for(new client = 1; client <= MaxClients; client++)
		InitializePlayerProperties(client);
	
	InitializeZoneProperties();
	ResetEntities();
}

public OnClientDisconnect(client)
{
	g_Setup[client][CurrentZone]    = -1;
	g_Setup[client][InZonesMenu]    = false;
	g_Setup[client][InSetFlagsMenu] = false;
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
	ReplaceString(message, maxlength, "^A", "\x0A");
	ReplaceString(message, maxlength, "^B", "\x0B");
	ReplaceString(message, maxlength, "^C", "\x0C");
	ReplaceString(message, maxlength, "^D", "\x0D");
	ReplaceString(message, maxlength, "^E", "\x0E");
	ReplaceString(message, maxlength, "^F", "\x0F");
	ReplaceString(message, maxlength, "^1", "\x01");
	ReplaceString(message, maxlength, "^2", "\x02");
	ReplaceString(message, maxlength, "^3", "\x03");
	ReplaceString(message, maxlength, "^4", "\x04");
	ReplaceString(message, maxlength, "^5", "\x05");
	ReplaceString(message, maxlength, "^6", "\x06");
	ReplaceString(message, maxlength, "^7", "\x07");
	ReplaceString(message, maxlength, "^8", "\x08");
	ReplaceString(message, maxlength, "^9", "\x09");
	ReplaceString(message, maxlength, "^0", "\x10");
}

public OnZoneColorChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for(new Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneColor[Zone] == convar)
		{
			UpdateZoneColor(Zone);
			break;
		}
	}
}

public OnZoneOffsetChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for(new Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneOffset[Zone] == convar)
		{
			g_Properties[Zone][Offset] = StringToInt(newValue);
			break;
		}
	}
}

public OnZoneTriggerChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for(new Zone; Zone < ZONE_COUNT; Zone++)
	{
		if(g_hZoneTrigger[Zone] == convar)
		{
			g_Properties[Zone][TriggerBased] = bool:StringToInt(newValue);
			break;
		}
	}
}

InitializeZoneProperties()
{
	g_TotalZoneCount     = 0;
	g_Drawing_Zone       = 0;
	g_Drawing_ZoneNumber = 0;
	
	for(new Zone; Zone < ZONE_COUNT; Zone++)
	{
		GetZoneName(Zone, g_Properties[Zone][Name], 64);
		UpdateZoneColor(Zone);
		UpdateZoneBeamTexture(Zone);
		UpdateZoneSpriteTexture(Zone);
		g_Properties[Zone][Offset]       = GetConVarInt(g_hZoneOffset[Zone]);
		g_Properties[Zone][TriggerBased] = GetConVarBool(g_hZoneTrigger[Zone]);
		g_Properties[Zone][Count]        = 0;
		
		switch(Zone)
		{
			case MAIN_START, MAIN_END, BONUS_START, BONUS_END:
			{
				g_Properties[Zone][Max]         = 1;
				g_Properties[Zone][Replaceable] = true;
			}
			case ANTICHEAT, FREESTYLE:
			{
				g_Properties[Zone][Max]         = 64;
				g_Properties[Zone][Replaceable] = false;
			}
		}
		
		for(new i; i < g_Properties[Zone][Max]; i++)
		{
			g_Properties[Zone][Ready][i]  = false;
			g_Properties[Zone][RowID][i]  = 0;
			g_Properties[Zone][Entity][i] = -1;
			g_Properties[Zone][Flags][i]  = 0;
		}
	}
}

InitializePlayerProperties(client)
{
	g_Setup[client][CurrentZone]    = -1;
	g_Setup[client][ViewAnticheats] = false;
	g_Setup[client][Snapping]       = true;
	g_Setup[client][GridSnap]       = 64;
	g_Setup[client][InZonesMenu]    = false;
	g_Setup[client][InSetFlagsMenu] = false;
}

GetZoneName(Zone, String:buffer[], maxlength)
{
	switch(Zone)
	{
		case MAIN_START:
		{
			FormatEx(buffer, maxlength, "Main Start");
		}
		case MAIN_END:
		{
			FormatEx(buffer, maxlength, "Main End");
		}
		case BONUS_START:
		{
			FormatEx(buffer, maxlength, "Bonus Start");
		}
		case BONUS_END:
		{
			FormatEx(buffer, maxlength, "Bonus End");
		}
		case ANTICHEAT:
		{
			FormatEx(buffer, maxlength, "Anti-cheat");
		}
		case FREESTYLE:
		{
			FormatEx(buffer, maxlength, "Freestyle");
		}
		default:
		{
			FormatEx(buffer, maxlength, "Unknown");
		}
	}
}

UpdateZoneColor(Zone)
{
	decl String:sColor[32], String:sColorExp[4][8];
	
	GetConVarString(g_hZoneColor[Zone], sColor, sizeof(sColor));
	ExplodeString(sColor, " ", sColorExp, 4, 8);
	
	for(new i; i < 4; i++)
		g_Properties[Zone][Color][i] = StringToInt(sColorExp[i]);
}

UpdateZoneBeamTexture(Zone)
{
	decl String:sBuffer[PLATFORM_MAX_PATH];
	GetConVarString(g_hZoneTexture[Zone], sBuffer, PLATFORM_MAX_PATH);
	
	decl String:sBeam[PLATFORM_MAX_PATH];
	FormatEx(sBeam, PLATFORM_MAX_PATH, "%s.vmt", sBuffer);
	g_Properties[Zone][ModelIndex] = PrecacheModel(sBeam);
	AddFileToDownloadsTable(sBeam);
	
	FormatEx(sBeam, PLATFORM_MAX_PATH, "%s.vtf", sBuffer);
	AddFileToDownloadsTable(sBeam);
}

UpdateZoneSpriteTexture(Zone)
{
	g_Properties[Zone][HaloIndex] = PrecacheModel("materials/sprites/light_glow02.vmt");
}

ResetEntities()
{
	for(new entity; entity < 2048; entity++)
	{
		g_Entities_ZoneType[entity]   = -1;
		g_Entities_ZoneNumber[entity] = -1;
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{    
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientInGame(client))
	{
		if(g_Properties[MAIN_START][Ready][0] == true)
		{
			TeleportToZone(client, MAIN_START, 0, true);
		}
		else
		{
			TeleportEntity(client, g_fSpawnPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	return Plugin_Continue;
}

public Action:SM_ShowAC(client, args)
{
	g_Setup[client][ViewAnticheats] = !g_Setup[client][ViewAnticheats];
	return Plugin_Handled;
}

public Action:SM_R(client, args)
{
    if(g_Properties[MAIN_START][Ready][0] == true)
    {
		if(!IsPlayerAlive(client))
		{
		CS_SwitchTeam(client, GetRandomInt(2, 3));
		CS_RespawnPlayer(client);
		}
		StopTimer(client);
        TeleportToZone(client, MAIN_START, 0, true);
		
        
        if(g_Properties[MAIN_END][Ready][0] == true)
        {
            StartTimer(client, TIMER_MAIN);
        }
    }
    else
    {
        PrintColorText(client, "%s%sThe main start zone is not ready yet.",
            g_msg_start,
            g_msg_textcol);
    }
    
    return Plugin_Handled;
}

public Action:SM_End(client, args)
{
	if(g_Properties[MAIN_END][Ready][0] == true)
	{
		if(GetClientTeam(client) <= 1)
		{
			ChangeClientTeam(client, 2);
			StopTimer(client);
			TeleportToZone(client, MAIN_END, 0, true);
		}
		else
		{
			StopTimer(client);
			TeleportToZone(client, MAIN_END, 0, true);
		}
	}
	else
	{
		PrintColorText(client, "%s%sThe main end zone is not ready yet.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action:SM_B(client, args)
{
    if(g_Properties[BONUS_START][Ready][0] == true)
    {
		if(!IsPlayerAlive(client))
		{
		CS_SwitchTeam(client, GetRandomInt(2, 3));
		CS_RespawnPlayer(client);
		}
		StopTimer(client);
        TeleportToZone(client, BONUS_START, 0, true);
        
        if(g_Properties[BONUS_END][Ready][0] == true)
        {
            StartTimer(client, TIMER_BONUS);
        }
    }
    else
    {
        PrintColorText(client, "%s%sThe bonus zone has not been created.",
            g_msg_start,
            g_msg_textcol);
    }
    
    return Plugin_Handled;
}

public Action:SM_EndB(client, args)
{
	if(g_Properties[BONUS_END][Ready][0] == true)
	{
		if(GetClientTeam(client) <= 1)
		{	
			ChangeClientTeam(client, 3);
			StopTimer(client);
			TeleportToZone(client, BONUS_END, 0, true);
		}
		else
		{
			StopTimer(client);
			TeleportToZone(client, BONUS_END, 0, true);
		}
	}
	else
	{
		PrintColorText(client, "%s%sThe bonus end zone has not been created.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

public Action:SM_Zones(client, args)
{
	OpenZonesMenu(client);
	
	return Plugin_Handled;
}

OpenZonesMenu(client)
{
	new Handle:menu = CreateMenu(Menu_Zones);
	
	SetMenuTitle(menu, "Zone Control");
	
	AddMenuItem(menu, "add", "Add a zone");
	AddMenuItem(menu, "goto", "Go to zone");
	AddMenuItem(menu, "del", "Delete a zone");
	AddMenuItem(menu, "set", "Set zone flags");
	AddMenuItem(menu, "snap", g_Setup[client][Snapping]?"Wall Snapping: On":"Wall Snapping: Off");
	
	decl String:sDisplay[64];
	IntToString(g_Setup[client][GridSnap], sDisplay, sizeof(sDisplay));
	Format(sDisplay, sizeof(sDisplay), "Grid Snapping: %s", sDisplay);
	AddMenuItem(menu, "grid", sDisplay);
	AddMenuItem(menu, "ac", g_Setup[client][ViewAnticheats]?"Anti-cheats: Visible":"Anti-cheats: Invisible");
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	g_Setup[client][InZonesMenu] = true;
}

public Menu_Zones(Handle:menu, MenuAction:action, client, param2)
{
	if(action & MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "add"))
		{
			OpenAddZoneMenu(client);
		}
		else if(StrEqual(info, "goto"))
		{
			OpenGoToMenu(client);
		}
		else if(StrEqual(info, "del"))
		{
			OpenDeleteMenu(client);
		}
		else if(StrEqual(info, "set"))
		{
			OpenSetFlagsMenu(client);
		}
		else if(StrEqual(info, "snap"))
		{
			g_Setup[client][Snapping] = !g_Setup[client][Snapping];
			OpenZonesMenu(client);
		}
		else if(StrEqual(info, "grid"))
		{
			g_Setup[client][GridSnap] *= 2;
				
			if(g_Setup[client][GridSnap] > 64)
				g_Setup[client][GridSnap] = 1;
			
			OpenZonesMenu(client);
		}
		else if(StrEqual(info, "ac"))
		{
			g_Setup[client][ViewAnticheats] = !g_Setup[client][ViewAnticheats];
			OpenZonesMenu(client);
		}
	}
	
	if(action & MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu] = false;
		}
	}
}

OpenAddZoneMenu(client)
{
	new Handle:menu = CreateMenu(Menu_AddZone);
	SetMenuTitle(menu, "Add a Zone");
	
	decl String:sInfo[8];
	for(new Zone; Zone < ZONE_COUNT; Zone++)
	{
		IntToString(Zone, sInfo, sizeof(sInfo));
		AddMenuItem(menu, sInfo, g_Properties[Zone][Name]);
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_AddZone(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		CreateZone(client, StringToInt(info));
		
		OpenAddZoneMenu(client);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenZonesMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu] = false;
		}
	}
}

CreateZone(client, Zone)
{
	if(ClientCanCreateZone(client, Zone))
	{
		if((g_Properties[Zone][Count] < g_Properties[Zone][Max]) || g_Properties[Zone][Replaceable] == true)
		{
			new ZoneNumber;
			
			if(g_Properties[Zone][Count] >= g_Properties[Zone][Max])
				ZoneNumber = 0;
			else
				ZoneNumber = g_Properties[Zone][Count];
			
			if(g_Setup[client][CurrentZone] == -1)
			{
				if(g_Properties[Zone][Ready][ZoneNumber] == true)
					DB_DeleteZone(client, Zone, ZoneNumber);
				
				if(Zone == ANTICHEAT)
					g_Setup[client][ViewAnticheats] = true;
				
				g_Setup[client][CurrentZone] = Zone;
				
				GetZoneSetupPosition(client, g_Zones[Zone][ZoneNumber][0]);
				
				new Handle:data;
				g_Setup[client][SetupTimer] = CreateDataTimer(0.1, Timer_ZoneSetup, data, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				WritePackCell(data, GetClientUserId(client));
				WritePackCell(data, ZoneNumber);
			}
			else if(g_Setup[client][CurrentZone] == Zone)
			{    
				if(g_Properties[Zone][Count] < g_Properties[Zone][Max])
				{
					g_Properties[Zone][Count]++;
					g_TotalZoneCount++;
				}
				
				KillTimer(g_Setup[client][SetupTimer], true);
				
				GetZoneSetupPosition(client, g_Zones[Zone][ZoneNumber][7]);
					
				g_Zones[Zone][ZoneNumber][7][2] += g_Properties[Zone][Offset];
				
				g_Setup[client][CurrentZone] = -1;
				g_Properties[Zone][Ready][ZoneNumber] = true;
				
				DB_SaveZone(Zone, ZoneNumber);
				
				if(g_Properties[Zone][TriggerBased] == true)
					CreateZoneTrigger(Zone, ZoneNumber);
			}
			else
			{
				PrintColorText(client, "%s%sYou are already setting up a different zone (%s%s%s).",
					g_msg_start,
					g_msg_textcol,
					g_msg_varcol,
					g_Properties[g_Setup[client][CurrentZone]][Name],
					g_msg_textcol);
			}
		}
		else
		{
			PrintColorText(client, "%s%sThere are too many of this zone (Max %s%d%s).",
				g_msg_start,
				g_msg_textcol,
				g_msg_varcol,
				g_Properties[Zone][Max],
				g_msg_textcol);
		}
	}
	else
	{
		PrintColorText(client, "%s%sSomeone else is already creating this zone (%s%s%s).",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			g_Properties[Zone][Name],
			g_msg_textcol);
	}
}

bool:ClientCanCreateZone(client, Zone)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(g_Setup[i][CurrentZone] == Zone && client != i)
		{
			return false;
		}
	}
	
	return true;
}

public Action:Timer_ZoneSetup(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = GetClientOfUserId(ReadPackCell(pack));
	
	if(client != 0)
	{
		new ZoneNumber = ReadPackCell(pack);
		new Zone       = g_Setup[client][CurrentZone];
		
		// Get setup position
		GetZoneSetupPosition(client, g_Zones[Zone][ZoneNumber][7]);
		g_Zones[Zone][ZoneNumber][7][2] += g_Properties[Zone][Offset];
		
		// Draw zone
		CreateZonePoints(g_Zones[Zone][ZoneNumber]);
		DrawZone(Zone, ZoneNumber, 0.1);
	}
	else
	{
		KillTimer(timer, true);
	}
}

CreateZonePoints(Float:Zone[8][3])
{
	for(new i=1; i<7; i++)
	{
		for(new j=0; j<3; j++)
		{
			Zone[i][j] = Zone[((i >> (2 - j)) & 1) * 7][j];
		}
	}
}

DrawZone(Zone, ZoneNumber, Float:life)
{
	new color[4];
	
	for(new i = 0; i < 4; i++)
		color[i] = g_Properties[Zone][Color][i];


	float ZoneDrawBuffer[8][3];
	float Correction = GetConVarFloat(g_hZoneWidth[Zone]) / 2;
	for (new xyz = 0; xyz <= 7; xyz++)
	{
		ZoneDrawBuffer[xyz][0] = g_Zones[Zone][ZoneNumber][xyz][0];
		ZoneDrawBuffer[xyz][1] = g_Zones[Zone][ZoneNumber][xyz][1];
		ZoneDrawBuffer[xyz][2] = g_Zones[Zone][ZoneNumber][xyz][2] + Correction;
	}
		
	if(GetConVarFloat(g_hZoneWidth[Zone]) > 1.0)
	{
		if((ZoneDrawBuffer[0][0] - ZoneDrawBuffer[4][0]) > 0)
		{
			ZoneDrawBuffer[0][0] -= Correction;
			ZoneDrawBuffer[2][0] -= Correction;
			ZoneDrawBuffer[4][0] += Correction;
			ZoneDrawBuffer[6][0] += Correction;
		}
		else
		{
			ZoneDrawBuffer[0][0] += Correction;
			ZoneDrawBuffer[2][0] += Correction;
			ZoneDrawBuffer[4][0] -= Correction;
			ZoneDrawBuffer[6][0] -= Correction;
		}
			
		if((ZoneDrawBuffer[0][1] - ZoneDrawBuffer[2][1]) > 0)
		{
			ZoneDrawBuffer[0][1] -= Correction;
			ZoneDrawBuffer[4][1] -= Correction;
			ZoneDrawBuffer[2][1] += Correction;
			ZoneDrawBuffer[6][1] += Correction;
		}
		else
		{
			ZoneDrawBuffer[0][1] += Correction;
			ZoneDrawBuffer[4][1] += Correction;
			ZoneDrawBuffer[2][1] -= Correction;
			ZoneDrawBuffer[6][1] -= Correction;
		}
	}
	
	TE_SetupBeamPoints(ZoneDrawBuffer[0], ZoneDrawBuffer[2], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 1, 10, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 0, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
	Beam_SendToAll(Zone);
	TE_SetupBeamPoints(ZoneDrawBuffer[2], ZoneDrawBuffer[6], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 1, 10, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 0, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
	Beam_SendToAll(Zone);
	TE_SetupBeamPoints(ZoneDrawBuffer[6], ZoneDrawBuffer[4], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 1, 10, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 0, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
	Beam_SendToAll(Zone);
	TE_SetupBeamPoints(ZoneDrawBuffer[4], ZoneDrawBuffer[0], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 1, 10, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 0, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
	Beam_SendToAll(Zone);
			

	if(GetConVarBool(g_hZoneStyle[Zone]))
	{
		TE_SetupBeamPoints(ZoneDrawBuffer[0], ZoneDrawBuffer[1], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		TE_SetupBeamPoints(ZoneDrawBuffer[2], ZoneDrawBuffer[3], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		TE_SetupBeamPoints(ZoneDrawBuffer[4], ZoneDrawBuffer[5], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		TE_SetupBeamPoints(ZoneDrawBuffer[6], ZoneDrawBuffer[7], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		
		TE_SetupBeamPoints(ZoneDrawBuffer[1], ZoneDrawBuffer[3], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		TE_SetupBeamPoints(ZoneDrawBuffer[3], ZoneDrawBuffer[7], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		TE_SetupBeamPoints(ZoneDrawBuffer[7], ZoneDrawBuffer[5], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		TE_SetupBeamPoints(ZoneDrawBuffer[5], ZoneDrawBuffer[1], g_Properties[Zone][ModelIndex], g_Properties[Zone][HaloIndex], 0, 0, (life < 0.1)?0.1:life, GetConVarFloat(g_hZoneWidth[Zone]), GetConVarFloat(g_hZoneWidth[Zone]), 10, 0.0, color, GetConVarInt(g_hZoneSpeed[Zone]));
		Beam_SendToAll(Zone);
		
		

	}
}

Beam_SendToAll(Zone)
{
	new clients[MaxClients], numClients;
	
	switch(Zone)
	{
		case MAIN_START, MAIN_END, BONUS_START, BONUS_END, FREESTYLE:
		{
			TE_SendToAll();
		}
		case ANTICHEAT:
		{
			for(new client = 1; client <= MaxClients; client++)
				if(IsClientInGame(client) && g_Setup[client][ViewAnticheats] == true)
					clients[numClients++] = client;
			
			if(numClients > 0)
				TE_Send(clients, numClients);
		}
	
	
	}
}

public Action:Timer_DrawBeams(Handle:timer, any:data)
{
	// Draw 4 zones (32 temp ents limit) per timer frame so all zones will draw
	if(g_TotalZoneCount > 0)
	{
		new ZonesDrawnThisFrame;
		
		for(new cycle; cycle < ZONE_COUNT; g_Drawing_Zone = (g_Drawing_Zone + 1) % ZONE_COUNT, cycle++)
		{
			for(; g_Drawing_ZoneNumber < g_Properties[g_Drawing_Zone][Count]; g_Drawing_ZoneNumber++)
			{    
				if(g_Properties[g_Drawing_Zone][Ready][g_Drawing_ZoneNumber] == true)
				{
					DrawZone(g_Drawing_Zone, g_Drawing_ZoneNumber, (float(g_TotalZoneCount)/40.0) + 0.3);
					
					if(++ZonesDrawnThisFrame == 4)
					{
						g_Drawing_ZoneNumber++;
						
						return Plugin_Continue;
					}
				}
			}
			
			g_Drawing_ZoneNumber = 0;
		}
	}
	
	return Plugin_Continue;
}

// Might remove this or place into a separate plugin
public Action Command_Jointeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	char[] arg1 = new char[8];
	GetCmdArg(1, arg1, 8);

	int iTeam = StringToInt(arg1);

	// client is trying to join the same team he's in now.
	// i'll let the game handle it.
	if(GetClientTeam(client) == iTeam)
	{
		return Plugin_Continue;
	}

	bool bRespawn = false;

	switch(iTeam)
	{
		case CS_TEAM_T:
		{
			// if T spawns are available in the map
			bRespawn = true;

			CS_SwitchTeam(client, CS_TEAM_T);
		}

		case CS_TEAM_CT:
		{
			bRespawn = true;

			CS_SwitchTeam(client, CS_TEAM_CT);
		}

		// if they chose to spectate, i'll force them to join the spectators
		case CS_TEAM_SPECTATOR:
		{
			CS_SwitchTeam(client, CS_TEAM_SPECTATOR);
		}

		default:
		{
			return Plugin_Continue;
		}
	}

	if(bRespawn)
	{
		CS_RespawnPlayer(client);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

CreateZoneTrigger(Zone, ZoneNumber)
{    
	new entity = CreateEntityByName("trigger_multiple");
	if(entity != -1)
	{
		DispatchKeyValue(entity, "spawnflags", "4097");
		
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		new Float:fPos[3];
		GetZonePosition(Zone, ZoneNumber, fPos);
		TeleportEntity(entity, fPos, NULL_VECTOR, NULL_VECTOR);
		
		SetEntityModel(entity, "models/props/cs_office/vending_machine.mdl");
		
		new Float:fBounds[2][3];
		GetMinMaxBounds(Zone, ZoneNumber, fBounds);
		SetEntPropVector(entity, Prop_Send, "m_vecMins", fBounds[0]);
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", fBounds[1]);
		
		SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
		SetEntProp(entity, Prop_Send, "m_fEffects", GetEntProp(entity, Prop_Send, "m_fEffects") | 32);
		
		g_Entities_ZoneType[entity]            = Zone;
		g_Entities_ZoneNumber[entity]          = ZoneNumber;
		g_Properties[Zone][Entity][ZoneNumber] = entity;
		
		SDKHook(entity, SDKHook_StartTouch, Hook_StartTouch);
		SDKHook(entity, SDKHook_EndTouch, Hook_EndTouch);
		SDKHook(entity, SDKHook_Touch, Hook_Touch);
	}
}

public Action:Hook_StartTouch(entity, other)
{
	// Anti-cheats, freestyles, and end zones
	new Zone       = g_Entities_ZoneType[entity];
	new ZoneNumber = g_Entities_ZoneNumber[entity];
	
	if(0 < other <= MaxClients)
	{
		if(IsClientInGame(other))
		{
			if(IsPlayerAlive(other))
			{
				if(g_Properties[Zone][TriggerBased] == true)
				{
					g_bInside[other][Zone][ZoneNumber] = true;
					
					switch(Zone)
					{
						case MAIN_END:
						{
							if(IsBeingTimed(other, TIMER_MAIN))
								FinishTimer(other);
						}
						case BONUS_END:
						{
							if(IsBeingTimed(other, TIMER_BONUS))
								FinishTimer(other);
						}
						case ANTICHEAT:
						{
							if(IsBeingTimed(other, TIMER_MAIN) && (g_Properties[Zone][Flags][ZoneNumber] & FLAG_ANTICHEAT_MAIN))
							{
								StopTimer(other);
								
								PrintColorText(other, "%s%sYour timer was stopped for using a shortcut.",
									g_msg_start,
									g_msg_textcol);
							}
							
							if(IsBeingTimed(other, TIMER_BONUS) && (g_Properties[Zone][Flags][ZoneNumber] & FLAG_ANTICHEAT_BONUS))
							{
								StopTimer(other);
								
								PrintColorText(other, "%s%sYour timer was stopped for using a shortcut.",
									g_msg_start,
									g_msg_textcol);
							}
						}
					}
				}
			}
			
			if(g_Setup[other][InSetFlagsMenu] == true)
				if(Zone == ANTICHEAT || Zone == FREESTYLE)
					OpenSetFlagsMenu(other, Zone, ZoneNumber);
				
			Call_StartForward(g_fwdOnZoneStartTouch);
			Call_PushCell(other);
			Call_PushCell(Zone);
			Call_PushCell(ZoneNumber);
			Call_Finish();
		}
	}
}

public Action:Hook_EndTouch(entity, other)
{
	new Zone       = g_Entities_ZoneType[entity];
	new ZoneNumber = g_Entities_ZoneNumber[entity];
	
	if(0 < other <= MaxClients)
	{
		if(g_Properties[Zone][TriggerBased] == true)
		{
			g_bInside[other][Zone][ZoneNumber] = false;
		}
		
		Call_StartForward(g_fwdOnZoneEndTouch);
		Call_PushCell(other);
		Call_PushCell(Zone);
		Call_PushCell(ZoneNumber);
		Call_Finish();
	}
}

public Action:Hook_Touch(entity, other)
{
	// Anti-prespeed (Start zones)
	new Zone = g_Entities_ZoneType[entity];
	
	if(g_Properties[Zone][TriggerBased] == true && (0 < other <= MaxClients))
	{
		if(IsClientInGame(other))
		{    
			if(IsPlayerAlive(other))
			{
				switch(Zone)
				{
					case MAIN_START:
					{                        
						if(g_Properties[MAIN_END][Ready][0] == true)
							StartTimer(other, TIMER_MAIN);
					}
					case BONUS_START:
					{
						if(g_Properties[BONUS_END][Ready][0] == true)
							StartTimer(other, TIMER_BONUS);
					}
				}
			}
		}
	}
}

GetZoneSetupPosition(client, Float:fPos[3])
{
	new bool:bSnapped;
	
	if(g_Setup[client][Snapping] == true)
		bSnapped = GetWallSnapPosition(client, fPos);
		
	if(bSnapped == false)
		GetGridSnapPosition(client, fPos);
}

GetGridSnapPosition(client, Float:fPos[3])
{
	Entity_GetAbsOrigin(client, fPos);
	
	for(new i = 0; i < 2; i++)
		fPos[i] = float(RoundFloat(fPos[i] / float(g_Setup[client][GridSnap])) * g_Setup[client][GridSnap]);
	
	// Snap to z axis only if the client is off the ground
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		fPos[2] = float(RoundFloat(fPos[2] / float(g_Setup[client][GridSnap])) * g_Setup[client][GridSnap]);
}

public Action:Timer_SnapPoint(Handle:timer, any:data)
{
	new Float:fSnapPos[3], Float:fClientPos[3];
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && g_Setup[client][InZonesMenu])
		{
			Entity_GetAbsOrigin(client, fClientPos);
			GetZoneSetupPosition(client, fSnapPos);
			
			if(GetVectorDistance(fClientPos, fSnapPos) > 0)
			{
				TE_SetupBeamPoints(fClientPos, fSnapPos, g_SnapModelIndex, g_SnapHaloIndex, 0, 0, 0.1, 1.0, 1.0, 0, 0.0, {0, 255, 255, 255}, 0);
				TE_SendToAll();
			}
		}
	}
}

bool:GetWallSnapPosition(client, Float:fPos[3])
{
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
	
	new Float:fHitPos[3], Float:vAng[3], bool:bSnapped;
	
	for(; vAng[1] < 360; vAng[1] += 90)
	{
		TR_TraceRayFilter(fPos, vAng, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
		
		if(TR_DidHit())
		{
			TR_GetEndPosition(fHitPos);
			
			if(GetVectorDistance(fPos, fHitPos) < 17)
			{
				if(vAng[1] == 0 || vAng[1] == 180)
				{
					// Change x
					fPos[0] = fHitPos[0];
				}
				else
				{
					// Change y
					fPos[1] = fHitPos[1];
				}
				
				bSnapped = true;
			}
		}
	}
	
	return bSnapped;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

GetZonePosition(Zone, ZoneNumber, Float:fPos[3])
{
	for(new i = 0; i < 3; i++)
		fPos[i] = (g_Zones[Zone][ZoneNumber][0][i] + g_Zones[Zone][ZoneNumber][7][i]) / 2;
}

GetMinMaxBounds(Zone, ZoneNumber, Float:fBounds[2][3])
{
	new Float:length;
	
	for(new i = 0; i < 3; i++)
	{
		length = FloatAbs(g_Zones[Zone][ZoneNumber][0][i] - g_Zones[Zone][ZoneNumber][7][i]);
		fBounds[0][i] = -(length / 2);
		fBounds[1][i] = length / 2;
	}
}

DB_Connect()
{
	if(g_DB != INVALID_HANDLE)
		CloseHandle(g_DB);
	
	decl String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
}

DB_LoadZones()
{
	decl String:query[512];
	FormatEx(query, sizeof(query), "SELECT Type, RowID, flags, point00, point01, point02, point10, point11, point12 FROM zones WHERE MapID = (SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1)",
		g_sMapName);
	SQL_TQuery(g_DB, LoadZones_Callback, query);
}

public LoadZones_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		new Zone, ZoneNumber;
		
		while(SQL_FetchRow(hndl))
		{
			Zone       = SQL_FetchInt(hndl, 0);
			ZoneNumber = g_Properties[Zone][Count];
			
			g_Properties[Zone][RowID][ZoneNumber] = SQL_FetchInt(hndl, 1);
			g_Properties[Zone][Flags][ZoneNumber] = SQL_FetchInt(hndl, 2);
			
			for(new i = 0; i < 6; i++)
			{
				g_Zones[Zone][ZoneNumber][(i / 3) * 7][i % 3] = SQL_FetchFloat(hndl, i + 3);
			}
			
			CreateZonePoints(g_Zones[Zone][ZoneNumber]);
			CreateZoneTrigger(Zone, ZoneNumber);
			
			g_Properties[Zone][Ready][ZoneNumber] = true;
			g_Properties[Zone][Count]++;
			g_TotalZoneCount++;
		}
		
		decl String:sQuery[128];
		FormatEx(sQuery, sizeof(sQuery), "SELECT MapID, Type FROM zones");
		SQL_TQuery(g_DB, LoadZones_Callback2, sQuery);
	}
	else
	{
		LogError(error);
	}
}

public LoadZones_Callback2(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		for(new Zone; Zone < ZONE_COUNT; Zone++)
			g_TotalZoneAllMaps[Zone] = 0;
		
		new MapID;
		decl String:sMapName[64];
		while(SQL_FetchRow(hndl))
		{
			MapID = SQL_FetchInt(hndl, 0);
			
			GetMapNameFromMapId(MapID, sMapName, sizeof(sMapName));
			
			if(g_MapList != INVALID_HANDLE && FindStringInArray(g_MapList, sMapName) != -1)
			{
				g_TotalZoneAllMaps[SQL_FetchInt(hndl, 1)]++;
			}
		}
		
		Call_StartForward(g_fwdOnZonesLoaded);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
}

DB_SaveZone(Zone, ZoneNumber)
{
	new Handle:data = CreateDataPack();
	WritePackCell(data, Zone);
	WritePackCell(data, ZoneNumber);
	
	decl String:query[512];
	FormatEx(query, sizeof(query), "INSERT INTO zones (MapID, Type, point00, point01, point02, point10, point11, point12, flags) VALUES ((SELECT MapID FROM maps WHERE MapName='%s' LIMIT 0, 1), %d, %f, %f, %f, %f, %f, %f, %d)", 
		g_sMapName,
		Zone,
		g_Zones[Zone][ZoneNumber][0][0], g_Zones[Zone][ZoneNumber][0][1], g_Zones[Zone][ZoneNumber][0][2], 
		g_Zones[Zone][ZoneNumber][7][0], g_Zones[Zone][ZoneNumber][7][1], g_Zones[Zone][ZoneNumber][7][2],
		g_Properties[Zone][Flags][ZoneNumber]);
	SQL_TQuery(g_DB, SaveZone_Callback, query, data);
}

public SaveZone_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new Zone       = ReadPackCell(data);
		new ZoneNumber = ReadPackCell(data);
		
		g_Properties[Zone][RowID][ZoneNumber] = SQL_GetInsertId(hndl);
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

DB_DeleteZone(client, Zone, ZoneNumber, bool:ManualDelete = false)
{
	if(g_Properties[Zone][Ready][ZoneNumber] == true)
	{        
		// Delete from database
		new Handle:data = CreateDataPack();
		WritePackCell(data, GetClientUserId(client));
		WritePackCell(data, Zone);
		
		decl String:query[512];
		FormatEx(query, sizeof(query), "DELETE FROM zones WHERE RowID = %d",
			g_Properties[Zone][RowID][ZoneNumber]);
		SQL_TQuery(g_DB, DeleteZone_Callback, query, data);
		
		
		// Delete in memory
		for(new client2 = 1; client2 <= MaxClients; client2++)
		{
			g_bInside[client2][Zone][ZoneNumber] = false;
			
			if(ManualDelete == true)
			{
				if(Zone == MAIN_START || Zone == MAIN_END)
				{
					if(IsBeingTimed(client2, TIMER_MAIN))
					{
						StopTimer(client2);
						
						PrintColorText(client2, "%s%sYour timer was stopped because the %s%s%s zone was deleted.",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							g_Properties[Zone][Name],
							g_msg_textcol);
					}
				}
				
				if(Zone == BONUS_START || Zone == BONUS_END)
				{
					if(IsBeingTimed(client2, TIMER_BONUS))
					{
						StopTimer(client2);
						
						PrintColorText(client2, "%s%sYour timer was stopped because the %s%s%s zone was deleted.",
							g_msg_start,
							g_msg_textcol,
							g_msg_varcol,
							g_Properties[Zone][Name],
							g_msg_textcol);
					}
				}
			}
		}
		
		if(IsValidEntity(g_Properties[Zone][Entity][ZoneNumber]))
		{
			AcceptEntityInput(g_Properties[Zone][Entity][ZoneNumber], "Kill");
		}
		
		if(-1 < g_Properties[Zone][Entity][ZoneNumber] < 2048)
		{
			g_Entities_ZoneNumber[g_Properties[Zone][Entity][ZoneNumber]] = -1;
			g_Entities_ZoneType[g_Properties[Zone][Entity][ZoneNumber]]   = -1;
		}
		
		for(new i = ZoneNumber; i < g_Properties[Zone][Count] - 1; i++)
		{
			for(new point = 0; point < 8; point++)
				for(new axis = 0; axis < 3; axis++)
					g_Zones[Zone][i][point][axis] = g_Zones[Zone][i + 1][point][axis];
			
			g_Properties[Zone][Entity][i] = g_Properties[Zone][Entity][i + 1];
			
			if(-1 < g_Properties[Zone][Entity][i] < 2048)
			{
				g_Entities_ZoneNumber[g_Properties[Zone][Entity][i]]--;
			}
			
			g_Properties[Zone][RowID][i]  = g_Properties[Zone][RowID][i + 1];
			g_Properties[Zone][Flags][i]  = g_Properties[Zone][Flags][i + 1];
			
		}
		
		g_Properties[Zone][Ready][g_Properties[Zone][Count] - 1] = false;
		
		g_Properties[Zone][Count]--;
		g_TotalZoneCount--;
	}
	else
	{
		PrintColorText(client, "%s%sAttempted to delete a zone that doesn't exist.",
			g_msg_start,
			g_msg_textcol);
	}
}

public DeleteZone_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new userid = ReadPackCell(data);
		new client = GetClientOfUserId(userid);
		
		if(client != 0)
		{
			new Zone = ReadPackCell(data);
			LogMessage("%L deleted zone %s", client, g_Properties[Zone][Name]);
		}
		else
		{
			LogMessage("Player with UserID %d deleted a zone.", userid);
		}
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

OpenGoToMenu(client)
{
	if(g_TotalZoneCount > 0)
	{
		new Handle:menu = CreateMenu(Menu_GoToZone);
		
		SetMenuTitle(menu, "Go to a Zone");
		
		decl String:sInfo[8];
		for(new Zone; Zone < ZONE_COUNT; Zone++)
		{
			if(g_Properties[Zone][Count] > 0)
			{
				IntToString(Zone, sInfo, sizeof(sInfo));
				AddMenuItem(menu, sInfo, g_Properties[Zone][Name]);
			}
		}
		
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		OpenZonesMenu(client);
	}
}

public Menu_GoToZone(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		new Zone = StringToInt(info);
		
		switch(Zone)
		{
			case MAIN_START, MAIN_END, BONUS_START, BONUS_END:
			{
				TeleportToZone(client, Zone, 0);
				OpenGoToMenu(client);
			}
			case ANTICHEAT, FREESTYLE:
			{
				ListGoToZones(client, Zone);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenZonesMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu] = false;
		}
	}
}

ListGoToZones(client, Zone)
{
	new Handle:menu = CreateMenu(Menu_GoToList);
	SetMenuTitle(menu, "Go to %s zones", g_Properties[Zone][Name]);
	
	decl String:sInfo[16], String:sDisplay[16];
	for(new ZoneNumber; ZoneNumber < g_Properties[Zone][Count]; ZoneNumber++)
	{
		FormatEx(sInfo, sizeof(sInfo), "%d;%d", Zone, ZoneNumber);
		IntToString(ZoneNumber + 1, sDisplay, sizeof(sDisplay));
		
		AddMenuItem(menu, sInfo, sDisplay);
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_GoToList(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:sZoneAndNumber[2][16];
		ExplodeString(info, ";", sZoneAndNumber, 2, 16);
		
		new Zone       = StringToInt(sZoneAndNumber[0]);
		new ZoneNumber = StringToInt(sZoneAndNumber[1]);
		
		TeleportToZone(client, Zone, ZoneNumber);
		
		ListGoToZones(client, Zone);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenGoToMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu] = false;
		}
	}
}

OpenDeleteMenu(client)
{
	if(g_TotalZoneCount > 0)
	{
		new Handle:menu = CreateMenu(Menu_DeleteZone);
		
		SetMenuTitle(menu, "Delete a Zone");
		
		AddMenuItem(menu, "sel", "Selected Zone");
		
		decl String:sInfo[8];
		for(new Zone = 0; Zone < ZONE_COUNT; Zone++)
		{
			if(g_Properties[Zone][Count] > 0)
			{
				IntToString(Zone, sInfo, sizeof(sInfo));
				
				AddMenuItem(menu, sInfo, g_Properties[Zone][Name]);
			}
		}
		
		SetMenuExitBackButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	else
	{
		OpenZonesMenu(client);
	}
}

public Menu_DeleteZone(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "sel"))
		{
			for(new Zone = 0; Zone < ZONE_COUNT; Zone++)
			{
				for(new ZoneNumber = 0; ZoneNumber < g_Properties[Zone][Count]; ZoneNumber++)
				{
					if(g_bInside[client][Zone][ZoneNumber] == true)
					{
						DB_DeleteZone(client, Zone, ZoneNumber, true);
					}
				}
			}
			
			OpenDeleteMenu(client);
		}
		else
		{
			new Zone = StringToInt(info);
			
			switch(Zone)
			{
				case MAIN_START, MAIN_END, BONUS_START, BONUS_END:
				{
					DB_DeleteZone(client, Zone, 0, true);
					
					OpenDeleteMenu(client);
				}
				case ANTICHEAT, FREESTYLE:
				{
					ListDeleteZones(client, Zone);
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenZonesMenu(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu] = false;
		}
	}
}

ListDeleteZones(client, Zone)
{
	new Handle:menu = CreateMenu(Menu_DeleteList);
	SetMenuTitle(menu, "Delete %s zones", g_Properties[Zone][Name]);
	
	decl String:sInfo[16], String:sDisplay[16];
	for(new ZoneNumber = 0; ZoneNumber < g_Properties[Zone][Count]; ZoneNumber++)
	{
		FormatEx(sInfo, sizeof(sInfo), "%d;%d", Zone, ZoneNumber);
		IntToString(ZoneNumber + 1, sDisplay, sizeof(sDisplay));
		
		AddMenuItem(menu, sInfo, sDisplay);
	}
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Menu_DeleteList(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		decl String:sZoneAndNumber[2][16];
		ExplodeString(info, ";", sZoneAndNumber, 2, 16);
		
		new Zone       = StringToInt(sZoneAndNumber[0]);
		new ZoneNumber = StringToInt(sZoneAndNumber[1]);
		
		DB_DeleteZone(client, Zone, ZoneNumber);
		
		ListDeleteZones(client, Zone);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenGoToMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu] = false;
		}
	}
}

OpenSetFlagsMenu(client, Zone = -1, ZoneNumber = -1)
{
	g_Setup[client][InSetFlagsMenu] = true;
	g_Setup[client][ViewAnticheats] = true;
	
	new Handle:menu = CreateMenu(Menu_SetFlags);
	SetMenuExitBackButton(menu, true);
	
	if(Zone == -1 && ZoneNumber == -1)
	{
		for(Zone = ANTICHEAT; Zone <= FREESTYLE; Zone++)
		{
			if((ZoneNumber = Timer_InsideZone(client, Zone)) != -1)
			{
				break;
			}
		}
	}
	
	if(ZoneNumber != -1)
	{
		SetMenuTitle(menu, "Set %s flags", g_Properties[Zone][Name]);
				
		decl String:sInfo[16];
		
		switch(Zone)
		{
			case ANTICHEAT:
			{
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ANTICHEAT, ZoneNumber, FLAG_ANTICHEAT_MAIN);
				AddMenuItem(menu, sInfo, (g_Properties[Zone][Flags][ZoneNumber] & FLAG_ANTICHEAT_MAIN)?"Main: Yes":"Main: No");
				
				FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", ANTICHEAT, ZoneNumber, FLAG_ANTICHEAT_BONUS);
				AddMenuItem(menu, sInfo, (g_Properties[Zone][Flags][ZoneNumber] & FLAG_ANTICHEAT_BONUS)?"Bonus: Yes":"Bonus: No");
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
				
				return;
			}
			case FREESTYLE:
			{
				decl String:sStyle[32], String:sDisplay[128];
				for(new Style; Style < MAX_STYLES; Style++)
				{
					if(Style_IsEnabled(Style) && Style_IsFreestyleAllowed(Style))
					{
						GetStyleName(Style, sStyle, sizeof(sStyle));
						
						FormatEx(sDisplay, sizeof(sDisplay), (g_Properties[Zone][Flags][ZoneNumber] & (1 << Style))?"%s: Yes":"%s: No", sStyle);
						
						FormatEx(sInfo, sizeof(sInfo), "%d;%d;%d", FREESTYLE, ZoneNumber, 1 << Style);
						
						AddMenuItem(menu, sInfo, sDisplay);
					}
				}
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
				
				return;
			}
		}
	}
	else
	{
		SetMenuTitle(menu, "Not in Anti-cheat nor Freestyle zone");
		AddMenuItem(menu, "choose", "Go to a zone", ITEMDRAW_DISABLED);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public Menu_SetFlags(Handle:menu, MenuAction:action, client, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrEqual(info, "choose"))
		{
			OpenSetFlagsMenu(client);
		}
		else
		{
			decl String:sExplode[3][16];
			ExplodeString(info, ";", sExplode, 3, 16);
			
			new Zone       = StringToInt(sExplode[0]);
			new ZoneNumber = StringToInt(sExplode[1]);
			new flags      = StringToInt(sExplode[2]);
			
			SetZoneFlags(Zone, ZoneNumber, g_Properties[Zone][Flags][ZoneNumber] ^ flags);
			
			OpenSetFlagsMenu(client, Zone, ZoneNumber);
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
			OpenGoToMenu(client);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	if(action & MenuAction_Cancel)
	{        
		if(param2 == MenuCancel_Exit)
		{
			g_Setup[client][InZonesMenu]    = false;
			g_Setup[client][InSetFlagsMenu] = false;
		}
		else if(param2 == MenuCancel_ExitBack)
		{
			g_Setup[client][InSetFlagsMenu] = false;
			
			OpenZonesMenu(client);
		}
	}
}

SetZoneFlags(Zone, ZoneNumber, flags)
{
	g_Properties[Zone][Flags][ZoneNumber] = flags;
	
	decl String:query[128];
	FormatEx(query, sizeof(query), "UPDATE zones SET flags = %d WHERE RowID = %d",
		g_Properties[Zone][Flags][ZoneNumber],
		g_Properties[Zone][RowID][ZoneNumber]);
	SQL_TQuery(g_DB, SetZoneFlags_Callback, query);
}

public SetZoneFlags_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

bool:IsClientInsideZone(client, Float:point[8][3])
{
	new Float:fPos[3];
	Entity_GetAbsOrigin(client, fPos);
	
	// Add 5 units to a player's height or it won't work
	fPos[2] += 5.0;
	
	return IsPointInsideZone(fPos, point);
}

bool:IsPointInsideZone(Float:pos[3], Float:point[8][3])
{
	for(new i = 0; i < 3; i++)
	{
		if(point[0][i] >= pos[i] == point[7][i] >= pos[i])
		{
			return false;
		}
	}
	
	return true;
}

public Native_InsideZone(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new Zone   = GetNativeCell(2);
	new flags  = GetNativeCell(3);
	
	for(new ZoneNumber; ZoneNumber < g_Properties[Zone][Count]; ZoneNumber++)
	{
		if(g_bInside[client][Zone][ZoneNumber] == true)
		{
			if(flags != -1)
			{
				if(g_Properties[Zone][Flags][ZoneNumber] & flags)
					return ZoneNumber;
			}
			else
			{
				return ZoneNumber;
			}
		}
	}
		
	return -1;
}

public Native_IsPointInsideZone(Handle:plugin, numParams)
{
	new Float:fPos[3];
	GetNativeArray(1, fPos, 3);
	
	new Zone       = GetNativeCell(2);
	new ZoneNumber = GetNativeCell(3);
	
	if(g_Properties[Zone][Ready][ZoneNumber] == true)
	{
		return IsPointInsideZone(fPos, g_Zones[Zone][ZoneNumber]);
	}
	else
	{
		return false;
	}
}

public Native_TeleportToZone(Handle:plugin, numParams)
{
	new client      = GetNativeCell(1);
	new Zone        = GetNativeCell(2);
	new ZoneNumber  = GetNativeCell(3);
	new bool:bottom = GetNativeCell(4);
	
	TeleportToZone(client, Zone, ZoneNumber, bottom);
}

public Native_GetTotalZonesAllMaps(Handle:plugin, numParams)
{
	return g_TotalZoneAllMaps[GetNativeCell(1)];
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{    
	if(IsPlayerAlive(client) && !IsFakeClient(client))
	{
		for(new Zone = 0; Zone < ZONE_COUNT; Zone++)
		{
			if(g_Properties[Zone][TriggerBased] == false)
			{
				for(new ZoneNumber = 0; ZoneNumber < g_Properties[Zone][Count]; ZoneNumber++)
				{
					g_bInside[client][Zone][ZoneNumber] = IsClientInsideZone(client, g_Zones[Zone][ZoneNumber]);
					
					if(g_bInside[client][Zone][ZoneNumber] == true)
					{
						switch(Zone)
						{
							case MAIN_START:
							{
								if(g_Properties[MAIN_END][Ready][0] == true)
									StartTimer(client, TIMER_MAIN);
							}
							case MAIN_END:
							{
								if(IsBeingTimed(client, TIMER_MAIN))
									FinishTimer(client);
							}
							case BONUS_START:
							{
								if(g_Properties[BONUS_END][Ready][0] == true)
									StartTimer(client, TIMER_BONUS);
							}
							case BONUS_END:
							{
								if(IsBeingTimed(client, TIMER_BONUS))
									FinishTimer(client);
							}
							case ANTICHEAT:
							{
								if(IsBeingTimed(client, TIMER_MAIN) && g_Properties[Zone][Flags][ZoneNumber] & FLAG_ANTICHEAT_MAIN)
								{
									StopTimer(client);
									
									PrintColorText(client, "%s%sYour timer was stopped for using a shortcut.",
										g_msg_start,
										g_msg_textcol);
								}
								else if(IsBeingTimed(client, TIMER_BONUS) && g_Properties[Zone][Flags][ZoneNumber] & FLAG_ANTICHEAT_BONUS)
								{
									StopTimer(client);
									
									PrintColorText(client, "%s%sYour timer was stopped for using a shortcut.",
										g_msg_start,
										g_msg_textcol);
								}
							}
						}
					}
				}
			}
		}
	}
}