#include <sourcemod>
#include <cstrike>
#include <bTimes-core>

ConVar mp_timelimit;
int iTimeLimit;

char g_msg_start[128];
char g_msg_varcol[128];
char g_msg_textcol[128];

public Plugin myinfo = 
{
	name = "[bTimes] Timelimit",
	author = "Charles_(hypnos)",
	description = "",
	version = "1.9.0",
	url = ""
}

public void OnPluginStart()
{
	RegAdminCmd("sm_extend", admcmd_extend, ADMFLAG_CHANGEMAP, "sm_extend <minutes> - Extend map time or -short");

	mp_timelimit = FindConVar("mp_timelimit");
	iTimeLimit = mp_timelimit.IntValue;
	mp_timelimit.Flags = mp_timelimit.Flags &~ FCVAR_NOTIFY;
	mp_timelimit.AddChangeHook(OnConVarChanged);
}

public void OnMapStart()
{
	CreateTimer(1.0, CheckRemainingTime, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckRemainingTime(Handle timer)
{
	if (iTimeLimit > 0)
	{
		int timeleft;
		GetMapTimeLeft(timeleft);
		
		switch(timeleft)
		{
			case 1800: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B30\x08 minutes");
			case 1200: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B20\x08 minutes");
			case 600: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B10\x08 minutes");
			case 300: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B5\x08 minutes");
			case 120: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B2\x08 minutes");
			case 60: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B60\x08 seconds");
			case 30: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B30\x08 seconds");
			case 15: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B15\x08 seconds");
			case -1: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B3\x08");
			case -2: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B2\x08");
			case -3: 	PrintToChatAll("\x01\x08[\x0BTimer\x08] \x0B- \x08Timeleft: \x0B1\x08");
		}
		
		if(timeleft < -3)
			CS_TerminateRound(0.0, CSRoundEnd_Draw, true);
	}
	
	return Plugin_Continue;
}

public Action CS_OnTerminateRound(float &fDelay, CSRoundEndReason &iReason)
{
	return Plugin_Continue;
}

public void OnTimerChatChanged(int MessageType, char[] Message)
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

void ReplaceMessage(char[] message, int maxlength)
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

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iTimeLimit = mp_timelimit.IntValue;
}

public Action admcmd_extend(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_extend <minutes>");
		return Plugin_Handled;
	}
	
	char arg[10];
	GetCmdArg(1, arg, sizeof(arg));
	
	int time;
	if((time = StringToInt(arg)) != 0)
	{
		mp_timelimit.IntValue = iTimeLimit + time;
		if(time > 0)
		{
			PrintColorTextAll("%s%sAdmin %s%N %shas extended map time for %s%i %sminutes.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			client,
			g_msg_textcol,
			g_msg_varcol,
			time,
			g_msg_textcol);
		}
		else
		{
			PrintColorTextAll("%s%sAdmin %s%N %shas shortened map time for %s%i %sminutes.",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			client,
			g_msg_textcol,
			g_msg_varcol,
			time,
			g_msg_textcol);
		}
	}
	return Plugin_Handled;
}
