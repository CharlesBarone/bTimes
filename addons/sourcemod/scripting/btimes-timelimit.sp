#include <sourcemod>
#include <cstrike>

public Plugin myinfo = 
{
	name = "[bTimes] Timelimit",
	author = "Charles_(hypnos)",
	description = "",
	version = "1.9.0",
	url = ""
}

public void OnMapStart()
{
	CreateTimer(1.0, CheckRemainingTime, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckRemainingTime(Handle timer)
{
	Handle hTmp;	
	hTmp = FindConVar("mp_timelimit");
	int iTimeLimit = GetConVarInt(hTmp);			
	if (hTmp != INVALID_HANDLE)
		CloseHandle(hTmp);	
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