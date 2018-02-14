#pragma semicolon 1
#pragma tabsize 0

#include <bTimes-core>

public Plugin myinfo = 
{
	name = "[bTimes] Core",
    author = "Charles_(hypnos), rumour, blacky",
	description = "The root of bTimes",
	version = VERSION,
	url = ""
}

#include <sourcemod>
#include <sdktools>
#include <scp>
#include <smlib/clients>
#include <bTimes-timer>

enum
{
	GameType_CSS,
	GameType_CSGO
};

new g_GameType;

new 	Handle:g_hCommandList,
	bool:g_bCommandListLoaded;

new Handle:g_DB;

new 	String:g_sMapName[64],
	g_PlayerID[MAXPLAYERS+1],
	Handle:g_MapList,
	Handle:g_hDbMapNameList,
	Handle:g_hDbMapIdList,
	bool:g_bDbMapsLoaded,
	Float:g_fMapStart;
	
new	Float:g_fSpamTime[MAXPLAYERS + 1],
	Float:g_fJoinTime[MAXPLAYERS + 1];
	
// Chat
new 	String:g_msg_start[128] = {""};
new 	String:g_msg_varcol[128] = {"\x07"};
new 	String:g_msg_textcol[128] = {"\x01"};

// Forwards
new	Handle:g_fwdMapIDPostCheck,
	Handle:g_fwdMapListLoaded,
	Handle:g_fwdPlayerIDLoaded;

// PlayerID retrieval data
new	Handle:g_hPlayerID,
	Handle:g_hUser,
	bool:g_bPlayerListLoaded;

// Cvars
new	Handle:g_hChangeLogURL;

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
	
	// Database
	DB_Connect();
	
	// Cvars
	if(g_GameType == GameType_CSS)
	{
		g_hChangeLogURL = CreateConVar("timer_changelog", "http://textuploader.com/14vc/raw", "The URL in to the timer changelog, in case the current URL breaks for some reason.");
		RegConsoleCmdEx("sm_changes", SM_Changes, "See the changes in the newer timer version.");
	}
	
	AutoExecConfig(true, "core", "timer");
	
	// Events
	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	// Commands
	RegConsoleCmdEx("sm_mostplayed", SM_TopMaps, "Displays the most played maps");
	RegConsoleCmdEx("sm_lastplayed", SM_LastPlayed, "Shows the last played maps");
	RegConsoleCmdEx("sm_playtime", SM_Playtime, "Shows the people who played the most.");
	RegConsoleCmdEx("sm_search", SM_Search, "Search the command list for the given string of text.");
	RegConsoleCmdEx("sm_thelp", SM_THelp, "List all commands in console.");
	
	// Makes FindTarget() work properly
	LoadTranslations("common.phrases");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("GetClientID", Native_GetClientID);
	CreateNative("IsSpamming", Native_IsSpamming);
	CreateNative("SetIsSpamming", Native_SetIsSpamming);
	CreateNative("RegisterCommand", Native_RegisterCommand);
	CreateNative("GetMapIdFromMapName", Native_GetMapIdFromMapName);
	CreateNative("GetMapNameFromMapId", Native_GetMapNameFromMapId);
	CreateNative("GetNameFromPlayerID", Native_GetNameFromPlayerID);
	CreateNative("GetSteamIDFromPlayerID", Native_GetSteamIDFromPlayerID);
	
	g_fwdMapIDPostCheck = CreateGlobalForward("OnMapIDPostCheck", ET_Event);
	g_fwdPlayerIDLoaded = CreateGlobalForward("OnPlayerIDLoaded", ET_Event, Param_Cell);
	g_fwdMapListLoaded  = CreateGlobalForward("OnDatabaseMapListLoaded", ET_Event);
	
	return APLRes_Success;
}

public OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	
	g_fMapStart = GetEngineTime();
	
	if(g_MapList != INVALID_HANDLE)
	{
		CloseHandle(g_MapList);
	}
	
	g_MapList = ReadMapList();
	
	// Creates map if it doesn't exist, sets map as recently played, and loads map playtime
	CreateCurrentMapID();
}

public OnMapEnd()
{
	DB_SaveMapPlaytime();
	DB_SetMapLastPlayed();
}

public OnClientPutInServer(client)
{
	g_fJoinTime[client] = GetEngineTime();
}

public OnClientDisconnect(client)
{
	// Save player's play time
	if(g_PlayerID[client] != 0 && !IsFakeClient(client))
	{
		DB_SavePlaytime(client);
	}
	
	// Reset the playerid for the client index
	g_PlayerID[client]   = 0;
}

public OnClientAuthorized(client)
{
	if(!IsFakeClient(client) && g_bPlayerListLoaded == true)
	{
		CreatePlayerID(client);
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

public Action:Event_PlayerTeam_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client  = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(0 < client <= MaxClients)
	{
		if(IsClientInGame(client))
		{
			new oldteam = GetEventInt(event, "oldteam");
			if(oldteam == 0)
			{	
				if(g_GameType == GameType_CSS)
				{
					PrintColorText(client, "%s%sType %s!thelp%s for a command list. %s!changes%s to see the changelog.",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						g_msg_textcol,
						g_msg_varcol,
						g_msg_textcol);
				}
				else if(g_GameType == GameType_CSGO)
				{
					PrintColorText(client, "%s%sType %s!thelp%s for a command list.",
						g_msg_start,
						g_msg_textcol,
						g_msg_varcol,
						g_msg_textcol);
				}
			}
		}
	}
}


public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
	if(IsChatTrigger())
	{
		return Plugin_Stop;
	}
	
	/*
	decl String:sType[16], String:sStyle[32], String:sCommand[48];
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeAbbr(Type, sType, sizeof(sType), true);
		for(new Style; Style < MAX_STYLES; Style++)
		{
			GetStyleAbbr(Style, sStyle, sizeof(sStyle), true);
			
			Format(sCommand, sizeof(sCommand), "%srank%s", sType, sStyle);
			
			if(StrEqual(message, sCommand, true))
			{
				FakeClientCommand(author, "sm_%s", message);
				return Plugin_Stop;
			}
		}
	}
	*/
	
	return Plugin_Continue;
}


public Action:SM_TopMaps(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		decl String:query[256];
		Format(query, sizeof(query), "SELECT MapName, MapPlaytime FROM maps ORDER BY MapPlaytime DESC");
		SQL_TQuery(g_DB, TopMaps_Callback, query, client);
	}
	
	return Plugin_Handled;
}

public TopMaps_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientInGame(client))
		{
			new Handle:menu = CreateMenu(Menu_TopMaps);
			SetMenuTitle(menu, "Most played maps\n---------------------------------------");
			
			new rows = SQL_GetRowCount(hndl);
			if(rows > 0)
			{
				decl String:mapname[64], String:timeplayed[32], String:display[128], iTime;
				for(new i, j; i < rows; i++)
				{
					SQL_FetchRow(hndl);
					iTime = SQL_FetchInt(hndl, 1);
					
					if(iTime != 0)
					{
						SQL_FetchString(hndl, 0, mapname, sizeof(mapname));
						
						if(FindStringInArray(g_MapList, mapname) != -1)
						{
							FormatPlayerTime(float(iTime), timeplayed, sizeof(timeplayed), false, 1);
							SplitString(timeplayed, ".", timeplayed, sizeof(timeplayed));
							Format(display, sizeof(display), "#%d: %s - %s", ++j, mapname, timeplayed);
							
							AddMenuItem(menu, display, display);
						}
					}
				}
				
				SetMenuExitButton(menu, true);
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
		}
	}
	else
	{
		LogError(error);
	}
}

public Menu_TopMaps(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_LastPlayed(client, argS)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		decl String:query[256];
		Format(query, sizeof(query), "SELECT MapName, LastPlayed FROM maps ORDER BY LastPlayed DESC");
		SQL_TQuery(g_DB, LastPlayed_Callback, query, client);
	}
	
	return Plugin_Handled;
}

public LastPlayed_Callback(Handle:owner, Handle:hndl, String:error[], any:client)
{
	if(hndl != INVALID_HANDLE)
	{
		if(IsClientInGame(client))
		{
			new Handle:menu = CreateMenu(Menu_LastPlayed);
			SetMenuTitle(menu, "Last played maps\n---------------------------------------");
			
			decl String:sMapName[64], String:sDate[32], String:sTimeOfDay[32], String:display[256], iTime;
			
			new rows = SQL_GetRowCount(hndl);
			for(new i=1; i<=rows; i++)
			{
				SQL_FetchRow(hndl);
				iTime = SQL_FetchInt(hndl, 1);
				
				if(iTime != 0)
				{
					SQL_FetchString(hndl, 0, sMapName, sizeof(sMapName));
					
					if(FindStringInArray(g_MapList, sMapName) != -1)
					{
						FormatTime(sDate, sizeof(sDate), "%x", iTime);
						FormatTime(sTimeOfDay, sizeof(sTimeOfDay), "%X", iTime);
						
						Format(display, sizeof(display), "%s - %s - %s", sMapName, sDate, sTimeOfDay);
						
						AddMenuItem(menu, display, display);
					}
				}
			}
			
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		LogError(error);
	}
}

public Menu_LastPlayed(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		FakeClientCommand(param1, "sm_nominate %s", info);
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

public Action:Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!IsFakeClient(client) && g_PlayerID[client] != 0)
	{
		decl String:sNewName[MAX_NAME_LENGTH];
		GetEventString(event, "newname", sNewName, sizeof(sNewName));
		UpdateName(client, sNewName);
	}
}

public Action:SM_Changes(client, args)
{
	if(g_GameType == GameType_CSS)
	{
		decl String:sChangeLog[PLATFORM_MAX_PATH];
		GetConVarString(g_hChangeLogURL, sChangeLog, PLATFORM_MAX_PATH);
		
		ShowMOTDPanel(client, "Timer changelog", sChangeLog, MOTDPANEL_TYPE_URL);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

DB_Connect()
{	
	if(g_DB != INVALID_HANDLE)
		CloseHandle(g_DB);
	
	new String:error[255];
	g_DB = SQL_Connect("timer", true, error, sizeof(error));
	
	if(g_DB == INVALID_HANDLE)
	{
		LogError(error);
		CloseHandle(g_DB);
	}
	else
	{
		decl String:query[512];
		
		// Create maps table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS maps(MapID INTEGER NOT NULL AUTO_INCREMENT, MapName TEXT, MapPlaytime INTEGER NOT NULL, LastPlayed INTEGER NOT NULL, PRIMARY KEY (MapID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create zones table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS zones(RowID INTEGER NOT NULL AUTO_INCREMENT, MapID INTEGER, Type INTEGER, point00 REAL, point01 REAL, point02 REAL, point10 REAL, point11 REAL, point12 REAL, flags INTEGER, PRIMARY KEY (RowID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create players table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS players(PlayerID INTEGER NOT NULL AUTO_INCREMENT, SteamID TEXT, User Text, Playtime INTEGER NOT NULL, ccname TEXT, ccmsgcol TEXT, ccuse INTEGER, PRIMARY KEY (PlayerID))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		// Create times table
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS times(rownum INTEGER NOT NULL AUTO_INCREMENT, MapID INTEGER, Type INTEGER, Style INTEGER, PlayerID INTEGER, Time REAL, Jumps INTEGER, Strafes INTEGER, Points REAL, Timestamp INTEGER, Sync REAL, SyncTwo REAL, PRIMARY KEY (rownum))");
		SQL_TQuery(g_DB, DB_Connect_Callback, query);
		
		LoadPlayers();
		LoadDatabaseMapList();
	}
}

public DB_Connect_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError(error);
	}
}

LoadDatabaseMapList()
{	
	decl String:query[256];
	FormatEx(query, sizeof(query), "SELECT MapID, MapName FROM maps");
	SQL_TQuery(g_DB, LoadDatabaseMapList_Callback, query);
}

public LoadDatabaseMapList_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(g_bDbMapsLoaded == false)
		{
			g_hDbMapNameList = CreateArray(ByteCountToCells(64));
			g_hDbMapIdList   = CreateArray();
			g_bDbMapsLoaded  = true;
		}
		
		decl String:sMapName[64];
		
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 1, sMapName, sizeof(sMapName));
			
			PushArrayString(g_hDbMapNameList, sMapName);
			PushArrayCell(g_hDbMapIdList, SQL_FetchInt(hndl, 0));
		}
		
		Call_StartForward(g_fwdMapListLoaded);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
}

LoadPlayers()
{
	g_hPlayerID = CreateArray(ByteCountToCells(32));
	g_hUser     = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));
	
	decl String:query[128];
	FormatEx(query, sizeof(query), "SELECT SteamID, PlayerID, User FROM players");
	SQL_TQuery(g_DB, LoadPlayers_Callback, query);
}

public LoadPlayers_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		decl String:sName[32], String:sAuth[32];
		
		new RowCount = SQL_GetRowCount(hndl), PlayerID, iSize;
		for(new Row; Row < RowCount; Row++)
		{
			SQL_FetchRow(hndl);
			
			SQL_FetchString(hndl, 0, sAuth, sizeof(sAuth));
			PlayerID = SQL_FetchInt(hndl, 1);
			SQL_FetchString(hndl, 2, sName, sizeof(sName));
			
			iSize = GetArraySize(g_hPlayerID);
			
			if(PlayerID >= iSize)
			{
				ResizeArray(g_hPlayerID, PlayerID + 1);
				ResizeArray(g_hUser, PlayerID + 1);
			}
			
			SetArrayString(g_hPlayerID, PlayerID, sAuth);
			SetArrayString(g_hUser, PlayerID, sName);
		}
		
		g_bPlayerListLoaded = true;
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientConnected(client) && !IsFakeClient(client))
			{
				if(IsClientAuthorized(client))
				{
					CreatePlayerID(client);
				}
			}
		}
	}
	else
	{
		LogError(error);
	}
}

CreateCurrentMapID()
{
	new Handle:pack = CreateDataPack();
	WritePackString(pack, g_sMapName);
	
	decl String:query[512];
	FormatEx(query, sizeof(query), "INSERT INTO maps (MapName) SELECT * FROM (SELECT '%s') AS tmp WHERE NOT EXISTS (SELECT MapName FROM maps WHERE MapName = '%s') LIMIT 1",
		g_sMapName,
		g_sMapName);
	SQL_TQuery(g_DB, DB_CreateCurrentMapID_Callback, query, pack);
}

public DB_CreateCurrentMapID_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		if(SQL_GetAffectedRows(hndl) > 0)
		{
			ResetPack(data);
			
			decl String:sMapName[64];
			ReadPackString(data, sMapName, sizeof(sMapName));
			
			new MapID = SQL_GetInsertId(hndl);
			LogMessage("MapID for %s created (%d)", sMapName, MapID);
			
			if(g_bDbMapsLoaded == false)
			{
				g_hDbMapNameList = CreateArray(ByteCountToCells(64));
				g_hDbMapIdList   = CreateArray();
				g_bDbMapsLoaded  = true;
			}
			
			PushArrayString(g_hDbMapNameList, sMapName);
			PushArrayCell(g_hDbMapIdList, MapID);
		}
		
		Call_StartForward(g_fwdMapIDPostCheck);
		Call_Finish();
	}
	else
	{
		LogError(error);
	}
	
	CloseHandle(data);
}

CreatePlayerID(client)
{	
	decl String:sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	
	decl String:sAuth[32];
	GetClientAuthId(client, AuthId_Engine, sAuth, sizeof(sAuth));
	
	new idx = FindStringInArray(g_hPlayerID, sAuth);
	if(idx != -1)
	{
		g_PlayerID[client] = idx;
		
		decl String:sOldName[MAX_NAME_LENGTH];
		GetArrayString(g_hUser, idx, sOldName, sizeof(sOldName));
		
		if(!StrEqual(sName, sOldName))
		{
			UpdateName(client, sName);
		}
		
		Call_StartForward(g_fwdPlayerIDLoaded);
		Call_PushCell(client);
		Call_Finish();
	}
	else
	{
		decl String:sEscapeName[(2 * MAX_NAME_LENGTH) + 1];
		SQL_LockDatabase(g_DB);
		SQL_EscapeString(g_DB, sName, sEscapeName, sizeof(sEscapeName));
		SQL_UnlockDatabase(g_DB);
		
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, GetClientUserId(client));
		WritePackString(pack, sAuth);
		WritePackString(pack, sName);
		
		decl String:query[128];
		FormatEx(query, sizeof(query), "INSERT INTO players (SteamID, User) VALUES ('%s', '%s')",
			sAuth,
			sEscapeName);
		SQL_TQuery(g_DB, CreatePlayerID_Callback, query, pack);
	}
}

public CreatePlayerID_Callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client = GetClientOfUserId(ReadPackCell(data));
		
		decl String:sAuth[32];
		ReadPackString(data, sAuth, sizeof(sAuth));
		
		decl String:sName[MAX_NAME_LENGTH];
		ReadPackString(data, sName, sizeof(sName));
		
		new PlayerID = SQL_GetInsertId(hndl);
		
		new iSize = GetArraySize(g_hPlayerID);
		
		if(PlayerID >= iSize)
		{
			ResizeArray(g_hPlayerID, PlayerID + 1);
			ResizeArray(g_hUser, PlayerID + 1);
		}
		
		SetArrayString(g_hPlayerID, PlayerID, sAuth);
		SetArrayString(g_hUser, PlayerID, sName);
		
		if(client != 0)
		{
			g_PlayerID[client] = PlayerID;
			
			Call_StartForward(g_fwdPlayerIDLoaded);
			Call_PushCell(client);
			Call_Finish();
		}
	}
	else
	{
		LogError(error);
	}
}

UpdateName(client, const String:sName[])
{
	SetArrayString(g_hUser, g_PlayerID[client], sName);
	
	decl String:sEscapeName[(2 * MAX_NAME_LENGTH) + 1];
	SQL_LockDatabase(g_DB);
	SQL_EscapeString(g_DB, sName, sEscapeName, sizeof(sEscapeName));
	SQL_UnlockDatabase(g_DB);
	
	decl String:query[128];
	FormatEx(query, sizeof(query), "UPDATE players SET User='%s' WHERE PlayerID=%d",
		sEscapeName,
		g_PlayerID[client]);
	SQL_TQuery(g_DB, UpdateName_Callback, query);
}

public UpdateName_Callback(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

public Native_GetClientID(Handle:plugin, numParams)
{
	return g_PlayerID[GetNativeCell(1)];
}

DB_SavePlaytime(client)
{
	if(IsClientInGame(client))
	{
		new PlayerID = GetPlayerID(client);
		if(PlayerID != 0)
		{		
			decl String:query[128];
			Format(query, sizeof(query), "UPDATE players SET Playtime=(SELECT Playtime FROM (SELECT * FROM players) AS x WHERE PlayerID=%d)+%d WHERE PlayerID=%d",
				PlayerID,
				RoundToFloor(GetEngineTime() - g_fJoinTime[client]),
				PlayerID);
				
			SQL_TQuery(g_DB, DB_SavePlaytime_Callback, query);
		}
	}
}

public DB_SavePlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

DB_SaveMapPlaytime()
{
	decl String:query[256];

	Format(query, sizeof(query), "UPDATE maps SET MapPlaytime=(SELECT MapPlaytime FROM (SELECT * FROM maps) AS x WHERE MapName='%s' LIMIT 0, 1)+%d WHERE MapName='%s'",
		g_sMapName,
		RoundToFloor(GetEngineTime()-g_fMapStart),
		g_sMapName);
		
	SQL_TQuery(g_DB, DB_SaveMapPlaytime_Callback, query);
}

public DB_SaveMapPlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

DB_SetMapLastPlayed()
{
	decl String:query[128];
	
	Format(query, sizeof(query), "UPDATE maps SET LastPlayed=%d WHERE MapName='%s'",
		GetTime(),
		g_sMapName);
		
	SQL_TQuery(g_DB, DB_SetMapLastPlayed_Callback, query);
}

public DB_SetMapLastPlayed_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
		LogError(error);
}

public Action:SM_Playtime(client, args)
{
	if(!IsSpamming(client))
	{
		SetIsSpamming(client, 1.0);
		
		if(args == 0)
		{
			if(g_PlayerID[client] != 0)
			{
				DB_ShowPlaytime(client, g_PlayerID[client]);
			}
		}
		else
		{
			decl String:sArg[MAX_NAME_LENGTH];
			GetCmdArgString(sArg, sizeof(sArg));
			
			new target = FindTarget(client, sArg, true, false);
			if(target != -1)
			{
				if(g_PlayerID[target] != 0)
				{
					DB_ShowPlaytime(client, g_PlayerID[target]);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

DB_ShowPlaytime(client, PlayerID)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientUserId(client));
	WritePackCell(pack, PlayerID);
	
	decl String:query[512];
	Format(query, sizeof(query), "SELECT (SELECT Playtime FROM players WHERE PlayerID=%d) AS TargetPlaytime, User, Playtime, PlayerID FROM players ORDER BY Playtime DESC LIMIT 0, 100",
		PlayerID);
	SQL_TQuery(g_DB, DB_ShowPlaytime_Callback, query, pack);
}

public DB_ShowPlaytime_Callback(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl != INVALID_HANDLE)
	{
		ResetPack(data);
		new client = GetClientOfUserId(ReadPackCell(data));
		
		if(client != 0)
		{			
			new rows = SQL_GetRowCount(hndl);
			if(rows != 0)
			{
				new TargetPlayerID = ReadPackCell(data);
				
				new Handle:menu = CreateMenu(Menu_ShowPlaytime);
				
				decl String:sName[MAX_NAME_LENGTH], String:sTime[32], String:sDisplay[64], String:sInfo[16], PlayTime, PlayerID, TargetPlaytime;
				for(new i = 1; i <= rows; i++)
				{
					SQL_FetchRow(hndl);
					
					TargetPlaytime = SQL_FetchInt(hndl, 0);
					SQL_FetchString(hndl, 1, sName, sizeof(sName));
					PlayTime = SQL_FetchInt(hndl, 2);
					PlayerID = SQL_FetchInt(hndl, 3);
					
					// Set info
					IntToString(PlayerID, sInfo, sizeof(sInfo));
					
					// Set display
					FormatPlayerTime(float(PlayTime), sTime, sizeof(sTime), false, 1);
					SplitString(sTime, ".", sTime, sizeof(sTime));
					FormatEx(sDisplay, sizeof(sDisplay), "#%d: %s: %s", i, sName, sTime);
					if((i % 7) == 0 || i == rows)
					{
						Format(sDisplay, sizeof(sDisplay), "%s\n--------------------------------------", sDisplay);
					}
					
					// Add item
					AddMenuItem(menu, sInfo, sDisplay);
				}
				
				GetNameFromPlayerID(TargetPlayerID, sName, sizeof(sName));
				
				new Float:ConnectionTime, target;
				
				if((target = GetClientFromPlayerID(TargetPlayerID)) != 0)
				{
					ConnectionTime = GetEngineTime() - g_fJoinTime[target];
				}
				
				FormatPlayerTime(ConnectionTime + float(TargetPlaytime), sTime, sizeof(sTime), false, 1);
				SplitString(sTime, ".", sTime, sizeof(sTime));
				
				SetMenuTitle(menu, "Playtimes\n \n%s: %s\n--------------------------------------",
					sName,
					sTime);
				
				SetMenuExitButton(menu, true);
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
		}
	}
	else
	{
		LogError(error);
	}
	CloseHandle(data);
}

public Menu_ShowPlaytime(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
}

public Action:SM_THelp(client, args)
{	
	new iSize = GetArraySize(g_hCommandList);
	decl String:sResult[256];
	
	if(0 < client <= MaxClients)
	{
		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
			ReplyToCommand(client, "");
		
		decl String:sCommand[32];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		
		if(args == 0)
		{
			ReplyToCommand(client, "[SM] %s 10 for the next page.", sCommand);
			for(new i=0; i<10 && i < iSize; i++)
			{
				GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
				PrintToConsole(client, sResult);
			}
		}
		else
		{
			decl String:arg[250];
			GetCmdArgString(arg, sizeof(arg));
			new iStart = StringToInt(arg);
			
			if(iStart < (iSize-10))
			{
				ReplyToCommand(client, "[SM] %s %d for the next page.", sCommand, iStart + 10);
			}
			
			for(new i = iStart; i < (iStart + 10) && (i < iSize); i++)
			{
				GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
				PrintToConsole(client, sResult);
			}
		}
	}
	else if(client == 0)
	{
		for(new i; i < iSize; i++)
		{
			GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
			PrintToServer(sResult);
		}
	}
	
	return Plugin_Handled;
}

public Action:SM_Search(client, args)
{
	if(args > 0)
	{
		decl String:sArgString[255], String:sResult[256];
		GetCmdArgString(sArgString, sizeof(sArgString));
		
		new iSize = GetArraySize(g_hCommandList);
		for(new i=0; i<iSize; i++)
		{
			GetArrayString(g_hCommandList, i, sResult, sizeof(sResult));
			if(StrContains(sResult, sArgString, false) != -1)
			{
				PrintToConsole(client, sResult);
			}
		}
	}
	else
	{
		PrintColorText(client, "%s%ssm_search must have a string to search with after it.",
			g_msg_start,
			g_msg_textcol);
	}
	
	return Plugin_Handled;
}

GetClientFromPlayerID(PlayerID)
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && g_PlayerID[client] == PlayerID)
		{
			return client;
		}
	}
	
	return 0;
}

public Native_IsSpamming(Handle:plugin, numParams)
{
	return GetEngineTime() < g_fSpamTime[GetNativeCell(1)];
}

public Native_SetIsSpamming(Handle:plugin, numParams)
{
	g_fSpamTime[GetNativeCell(1)] = Float:GetNativeCell(2) + GetEngineTime();
}

public Native_RegisterCommand(Handle:plugin, numParams)
{
	if(g_bCommandListLoaded == false)
	{
		g_hCommandList = CreateArray(ByteCountToCells(256));
		g_bCommandListLoaded = true;
	}
	
	decl String:sListing[256], String:sCommand[32], String:sDesc[224];
	
	GetNativeString(1, sCommand, sizeof(sCommand));
	GetNativeString(2, sDesc, sizeof(sDesc));
	
	FormatEx(sListing, sizeof(sListing), "%s - %s", sCommand, sDesc);
	
	decl String:sIndex[256];
	new idx, idxlen, listlen = strlen(sListing), iSize = GetArraySize(g_hCommandList), bool:IdxFound;
	for(; idx < iSize; idx++)
	{
		GetArrayString(g_hCommandList, idx, sIndex, sizeof(sIndex));
		idxlen = strlen(sIndex);
		
		for(new cmpidx = 0; cmpidx < listlen && cmpidx < idxlen; cmpidx++)
		{
			if(sListing[cmpidx] < sIndex[cmpidx])
			{
				IdxFound = true;
				break;
			}
			else if(sListing[cmpidx] > sIndex[cmpidx])
			{
				break;
			}
		}
		
		if(IdxFound == true)
			break;
	}
	
	if(idx >= iSize)
		ResizeArray(g_hCommandList, idx + 1);
	else
		ShiftArrayUp(g_hCommandList, idx);
	
	SetArrayString(g_hCommandList, idx, sListing);
}

public Native_GetMapNameFromMapId(Handle:plugin, numParams)
{
	new Index = FindValueInArray(g_hDbMapIdList, GetNativeCell(1));
	
	if(Index != -1)
	{
		decl String:sMapName[64];
		GetArrayString(g_hDbMapNameList, Index, sMapName, sizeof(sMapName));
		SetNativeString(2, sMapName, GetNativeCell(3));
		
		return true;
	}
	else
	{
		return false;
	}
}

public Native_GetNameFromPlayerID(Handle:plugin, numParams)
{
	decl String:sName[MAX_NAME_LENGTH];
	
	GetArrayString(g_hUser, GetNativeCell(1), sName, sizeof(sName));
	
	SetNativeString(2, sName, GetNativeCell(3));
}

public Native_GetSteamIDFromPlayerID(Handle:plugin, numParams)
{
	decl String:sAuth[32];
	
	GetArrayString(g_hPlayerID, GetNativeCell(1), sAuth, sizeof(sAuth));
	
	SetNativeString(2, sAuth, GetNativeCell(3));
}

public Native_GetMapIdFromMapName(Handle:plugin, numParams)
{
	decl String:sMapName[64];
	GetNativeString(1, sMapName, sizeof(sMapName));
	
	new Index = FindStringInArray(g_hDbMapNameList, sMapName);
	
	if(Index != -1)
	{
		return GetArrayCell(g_hDbMapIdList, Index);
	}
	else
	{
		return 0;
	}
}
