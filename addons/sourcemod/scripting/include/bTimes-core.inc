#if defined _timercore_included
  #endinput
#endif
#define _timercore_included

#define VERSION "1.9.0"

#define MAX_TYPES 2

#define TIMER_MAIN 0
#define TIMER_BONUS 1
#define TIMER_ANY 2

#define ALL -1

enum
{
	SQL_Column_Type = 2,
	SQL_Column_Style,
	SQL_Column_PlayerID,
	SQL_Column_Time,
	SQL_Column_Jumps,
	SQL_Column_Strafes,
	SQL_Column_Points,
	SQL_Column_Timestamp
};

// Core natives

/*
* Gets a client's player id in the database.
* 
* @param client		Client index.
* 
* @return			Client's player id.
*/
native GetClientID(client);

/*
* A better name for GetClientID()
* 
* @param client        Client index.
* 
* @return              Client's player id.
*/
stock GetPlayerID(client)
{
	return GetClientID(client);
}

/*
* Gets the name of a player in the database by their Player ID
* 
* @param PlayerID      Player ID in the database.
* @param sName         Buffer to store the given name.
* @param maxlength     Maxlength of the sName string.
*/
native GetNameFromPlayerID(PlayerID, String:sName[], maxlength);

/*
* Gets a SteamID given a PlayerID in the timer database
* 
* @param PlayerID      Player ID in the database.
* @param sAuth         Buffer to store the SteamID.
* @param maxlength     Maxlength of the sAuth string.
*/
native GetSteamIDFromPlayerID(PlayerID, String:sAuth[], maxlength);

/*
* Gets the map id in the timer database from a map name
* 
* @param sMapName      The name of the map to get the map id for.
* 
* @return              The map's map id, 0 if map not found.
*/
native GetMapIdFromMapName(const String:sMapName[]);

/*
* Gets the map name from a map id
* 
* @param MapID         The map id you use to get the map name for.
* @param sMapName      The buffer to hold the map name.
* @param maxlength     The max length of the sMapName buffer.
* 
* @return              True if the map was found, false otherwise.
*/
native bool:GetMapNameFromMapId(MapID, String:sMapName[], maxlength);

/*
* Gets if a client is spamming SQL related commands or not.
* 
* @param client		Client index.
* 
* @return 			True if client is spamming; false otherwise.
*/
native bool:IsSpamming(client);

/*
* Sets a client as spamming commands.
* 
* @param client		Client index.
* 
* @noreturn
*/
native SetIsSpamming(client, Float:BlockTime);

/*
* Adds a command to the timer's command list.
* 
* @param sCommand		The command to add to the command list.
* @param sDescription	The description of the command added to the command list.
* 
* @noreturn
*/
native RegisterCommand(const String:sCommand[], const String:sDescription[]);

#include <clientprefs>

/**
* A simpler way of getting the bool value of a client's cookie.
* 
* @param client        Client index.
* @param cookie        Handle to the cookie.
* 
* @return              Boolean value of the client's cookie, false if client's cookies are not cached.
*/
stock bool:GetCookieBool(client, Handle:cookie)
{
	if(AreClientCookiesCached(client))
	{
		decl String:sCookie[16];
		GetClientCookie(client, cookie, sCookie, sizeof(sCookie));
		
		if(strlen(sCookie) == 0)
			return true;
		else
			return bool:StringToInt(sCookie);
	}
	
	return true;
}

stock GetCookieInt(client, Handle:cookie)
{
	if(AreClientCookiesCached(client))
	{
		new String:sCookie[16];
		GetClientCookie(client, cookie, sCookie, sizeof(sCookie));
		
		if(strlen(sCookie) == 0)
			return 0;
		else
			return StringToInt(sCookie);
	}
	
	return true;
}

/**
* A simpler of of setting a client's cookie with a boolean value
* 
* @param client        Client index.
* @param cookie        Handle to the cookie.
* @param value         Value to set the client's cookie to.
* 
* @noreturn
*/
stock SetCookieBool(client, Handle:cookie, bool:value)
{
	if(AreClientCookiesCached(client))
	{
		decl String:sCookie[32];
		IntToString(value, sCookie, sizeof(sCookie));
		SetClientCookie(client, cookie, sCookie);
	}
}

stock SetCookieInt(client, Handle:cookie, value)
{
	if(AreClientCookiesCached(client))
	{
		decl String:sCookie[32];
		IntToString(value, sCookie, sizeof(sCookie));
		SetClientCookie(client, cookie, sCookie);
	}
}

#include <console>

/*
* Registers a console command and adds it to the timer's command list.
* 
* @param sCommand		The command to register and add to the command list.
* @param callback		The callback for the command.
* @param sDescription	The description of the command.
* 
* @noreturn
*/
stock RegConsoleCmdEx(const String:sCommand[], ConCmd:callback, const String:sDescription[])
{
	RegConsoleCmd(sCommand, callback, sDescription);
	
	RegisterCommand(sCommand, sDescription);
}

#include <bTimes-timer>

stock RegConsoleCmdPerStyle(const String:sBaseCmd[], ConCmd:callback, const String:sDescription[])
{
	decl String:sLiteralDesc[256], String:sType[32], String:sStyle[32], String:sTypeAbbr[32], String:sStyleAbbr[32], String:sLiteralBaseCmd[64];
	
	new TotalStyles = Style_GetTotal();
	for(new Type; Type < MAX_TYPES; Type++)
	{
		GetTypeName(Type, sType, sizeof(sType));
		GetTypeAbbr(Type, sTypeAbbr, sizeof(sTypeAbbr), true);
		
		for(new Style; Style < TotalStyles; Style++)
		{
			GetStyleName(Style, sStyle, sizeof(sStyle));
			GetStyleAbbr(Style, sStyleAbbr, sizeof(sStyleAbbr), true);
			
			if(Style_IsEnabled(Style) && Style_IsTypeAllowed(Style, Type))
			{
				strcopy(sLiteralDesc, sizeof(sLiteralDesc), sDescription);
				ReplaceString(sLiteralDesc, sizeof(sLiteralDesc), "{Type}", sType, false);
				ReplaceString(sLiteralDesc, sizeof(sLiteralDesc), "{Style}", sStyle, false);
				
				FormatEx(sLiteralBaseCmd, sizeof(sLiteralBaseCmd), "sm_%s%s%s", sTypeAbbr, sBaseCmd, sStyleAbbr);
				
				RegConsoleCmdEx(sLiteralBaseCmd, callback, sLiteralDesc);
			}
		}
	}
}
/*
* Called when a map's MapID is gauranteed to be in the database
*/
forward OnMapIDPostCheck();

/*
* Called when the list of maps from the maps table in the database has been loaded into memory
*/
forward OnDatabaseMapListLoaded();

/*
* Called when a player's PlayerID is retrieved and gauranteed to be in the database
*/
forward OnPlayerIDLoaded(client);

/*
* Used to print messages to all players and allows special colors without annoying hexadecimal spam in console
*/
stock PrintColorTextAll(const String:msg[], any:...)
{
	decl String:buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 2);
	new Handle:hMessage = StartMessageAll("SayText2"); 
	if (hMessage != INVALID_HANDLE) 
	{
		if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(hMessage, "ent_idx", 0);
			PbSetBool(hMessage, "chat", true);
			PbSetString(hMessage, "msg_name", buffer);
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
		}
		else
		{
			BfWriteByte(hMessage, 0);
			BfWriteByte(hMessage, true);
			BfWriteString(hMessage, buffer);
		}
		
		EndMessage();
	}
}

/*
* Used to print messages to a single player and allows special colors without annoying hexadecimal spam in console
*/
stock PrintColorText(client, const String:msg[], any:...)
{
	if(IsClientInGame(client))
	{
		new String:buffer[300];
		VFormat(buffer, sizeof(buffer), msg, 3);
		
		new Handle:hMessage = StartMessageOne("SayText2", client); 
		if (hMessage != INVALID_HANDLE) 
		{ 
			if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
			{
				PbSetInt(hMessage, "ent_idx", client);
				PbSetBool(hMessage, "chat", true);
				PbSetString(hMessage, "msg_name", buffer);
				PbAddString(hMessage, "params", "");
				PbAddString(hMessage, "params", "");
				PbAddString(hMessage, "params", "");
				PbAddString(hMessage, "params", "");
			}
			else
			{
				BfWriteByte(hMessage, client);
				BfWriteByte(hMessage, true);
				BfWriteString(hMessage, buffer);
			}
			
			EndMessage();
		}
	}
}

/*
* Used to print messages to a player's spectators and allows special colors without annoying hexadecimal spam in console
*/
stock PrintColorTextObservers(target, const String:msg[], any:...)
{
	new String:buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 3);
	
	new clients[MaxClients], observercount;
	
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsPlayerAlive(client) && !IsFakeClient(client))
		{
			new observee 		= GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			new ObserverMode 	= GetEntProp(client, Prop_Send, "m_iObserverMode");
			
			if(observee == target && (ObserverMode == 4 || ObserverMode == 5))
			{
				clients[observercount++] = client;
			}
		}
	}
	
	if(observercount == 0)
		return;
	
	new Handle:hMessage = StartMessage("SayText2", clients, observercount); 
	if (hMessage != INVALID_HANDLE) 
	{ 
		if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(hMessage, "ent_idx", 0);
			PbSetBool(hMessage, "chat", true);
			PbSetString(hMessage, "msg_name", buffer);
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
			PbAddString(hMessage, "params", "");
		}
		else
		{
			BfWriteByte(hMessage, 0);
			BfWriteByte(hMessage, true);
			BfWriteString(hMessage, buffer);
		}
		
		EndMessage();
	}
}

/*
* Converts a time into a formatted string
*/
stock FormatPlayerTime(Float:Time, String:result[], maxlength, bool:showDash, precision)
{
	if(Time <= 0.0 && showDash == true)
	{
		Format(result, maxlength, "-");
		return;
	}
	
	new hours 	= RoundToFloor(Time/3600);
	Time         -= hours*3600;
	new minutes 	= RoundToFloor(Time/60);
	Time         -= minutes*60;
	new Float:seconds = Time;
	
	decl String:sPrecision[16];
	
	if(precision == 0)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%04.1f":"%.1f", seconds);
	else if(precision == 1)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%06.3f":"%.3f", seconds);
	else if(precision == 2)
		Format(sPrecision, sizeof(sPrecision), (hours > 0 || minutes > 0)?"%09.6f":"%.6f", seconds);
	
	if(hours > 0)
		Format(result, maxlength, "%d:%02d:%s", hours, minutes, sPrecision);
	else if(minutes > 0)
		Format(result, maxlength, "%d:%s", minutes, sPrecision);
	else
		Format(result, maxlength, "%s", sPrecision);
}

/*
* Gets a client's velocity with extra settings to disallow velocity on certain axes
*/
stock Float:GetClientVelocity(client, bool:UseX, bool:UseY, bool:UseZ)
{
	new Float:vVel[3];
	
	if(UseX)
	{
		vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	}
	
	if(UseY)
	{
		vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	}
	
	if(UseZ)
	{
		vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	}
	
	return GetVectorLength(vVel);
}

/*
* Gets the name of a specified type
*/
stock GetTypeName(Type, String:sType[], maxlength, bool:bBlankIfMain = false)
{
	if((Type == TIMER_MAIN && bBlankIfMain == true) || Type == ALL)
	{
		FormatEx(sType, maxlength, "");
		return;
	}
	
	decl String:sTypeList[MAX_TYPES][] = {"Main", "Bonus"};
	
	FormatEx(sType, maxlength, sTypeList[Type]);
}

/*
* Gets the abbreviation of a specified type
*/
stock GetTypeAbbr(Type, String:sAbbr[], maxlength, bool:bBlankIfMain = false)
{
	if((Type == TIMER_MAIN && bBlankIfMain == true) || Type == ALL)
	{
		FormatEx(sAbbr, maxlength, "");
		return;
	}
	
	decl String:sAbbrList[MAX_TYPES][] = {"", "b"};
	
	FormatEx(sAbbr, maxlength, sAbbrList[Type]);
}

/*
* Turns all lowercase letters in a string to uppercase
*/
stock StringToUpper(String:buffer[])
{
	new len = strlen(buffer);
	
	for(new idx = 0; idx < len; idx++)
	{
		buffer[idx] = CharToUpper(buffer[idx]);
	}
}

/*
* Adds brackets to a string, might change so players can choose brackets
*/
stock AddBracketsToString(String:buffer[], maxlength)
{
	if(strlen(buffer) > 0)
		Format(buffer, maxlength, "[%s]", buffer);
}

/*
* Adds a space to the end of a string, probably gonna remove this
*/
stock AddSpaceToEnd(String:buffer[], maxlength)
{
	if(strlen(buffer) > 0)
		Format(buffer, maxlength, "%s ", buffer);
}

stock bool IsValidClient(int client, bool bAlive = false) // when bAlive is false = technical checks, when it's true = gameplay checks
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}