#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <sdkhooks>
#include <bTimes-core>

#define BHOP_TIME 15

#define SSJ_NONE				(0)
#define SSJ_ENABLED				(1 << 1) // master setting
#define SSJ_SPEEDD				(1 << 2) // speed difference
#define SSJ_HEIGHT				(1 << 3) // height difference
#define SSJ_GAIN				(1 << 4) // gain percentage
#define SSJ_TJP					(1 << 5) // trigger jump plus
#define SSJ_TJM					(1 << 6) // trigger jump minus
#define SSJ_RPT					(1 << 7) // repeat trigger jump stats
#define SSJ_PRESPEED			(1 << 8) // prespeed

#define SSJ_DEFAULT				(SSJ_NONE) // def. settings

public Plugin myinfo = 
{
	name = "[bTimes] SSJ",
	description = "SSJ for bTimes",
    author = "Charles_(hypnos), rumour, alkatraz",
	version = "1.9.0",
	url = ""
}

new	String:g_msg_start[128];
new	String:g_msg_varcol[128];
new	String:g_msg_textcol[128];

Handle gH_SSJCookie = null;
Handle gH_SSJCookie_jumps = null;
int gI_SSJJumps[MAXPLAYERS+1];
int gI_SSJSettings[MAXPLAYERS+1];
int gI_SSJSetting_jumpprint[MAXPLAYERS+1];
float gF_SSJStartingSpeed[MAXPLAYERS+1];
float gF_SSJStartingHeight[MAXPLAYERS+1];
float gF_HitGround[MAXPLAYERS+1];

new bool:g_bTouchesWall[129];
new g_iTicksOnGround[129];
new g_strafeTick[129];
new Float:g_flRawGain[129];
new Handle:g_hAirAccel;

public void OnPluginStart()
{
	RegConsoleCmd("sm_ssj", Command_SSJ, "SSJ ('speed sixth jump') menu.");
	gH_SSJCookie = RegClientCookie("ssj_setting", "SSJ settings", CookieAccess_Protected);
	gH_SSJCookie_jumps = RegClientCookie("ssj_setting_jumps", "SSJ jumps count settings", CookieAccess_Protected);
	
	g_hAirAccel = FindConVar("sv_airaccelerate");
	
	HookEvent("player_jump", Player_Jump);
}

public OnTimerChatChanged(int MessageType, char[] Message)
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

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1)
	{
		if(gF_HitGround[client] == 0.0)
		{
			gF_HitGround[client] = GetEngineTime();
		}

		else if(gI_SSJJumps[client] > 0 && (GetEngineTime() - gF_HitGround[client]) > 0.100)
		{
			ResetSSJ(client, true, false);
		}
	}

	else
	{
		gF_HitGround[client] = 0.0;
	}

	MoveType iMoveType = GetEntityMoveType(client);

	if(iMoveType == MOVETYPE_NOCLIP || iMoveType == MOVETYPE_LADDER)
	{
		ResetSSJ(client, true, false);
	}
	
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(g_iTicksOnGround[client] > BHOP_TIME)
		{
			gI_SSJJumps[client] = 0;
			g_strafeTick[client] = 0;
			g_flRawGain[client] = 0.0;
		}
		g_iTicksOnGround[client]++;
	}
	else
	{
		if(iMoveType != MOVETYPE_NONE && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2)
		{
			new Float:gaincoeff;
			g_strafeTick[client]++;
			if(g_strafeTick[client] == 1000)
			{
				g_flRawGain[client] *= 998.0/999.0;
				g_strafeTick[client]--;
			}
			
			if(GetConVarFloat(g_hAirAccel) > 0.0)
			{
			
				new Float:velocity[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
				
				new Float:fore[3], Float:side[3], Float:wishvel[3], Float:wishdir[3];
				new Float:wishspeed, Float:wishspd, Float:currentgain;
				
				GetAngleVectors(angles, fore, side, NULL_VECTOR);
				
				fore[2] = 0.0;
				side[2] = 0.0;
				NormalizeVector(fore, fore);
				NormalizeVector(side, side);
				
				for(new i = 0; i < 2; i++)
					wishvel[i] = fore[i] * vel[0] + side[i] * vel[1];
				
				wishspeed = NormalizeVector(wishvel, wishdir);
				if(wishspeed > GetEntPropFloat(client, Prop_Send, "m_flMaxspeed")) wishspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
				
				if(wishspeed)
				{
					wishspd = (wishspeed > 30.0) ? 30.0 : wishspeed;
					
					currentgain = GetVectorDotProduct(velocity, wishdir);
					if(currentgain < 30.0)
						gaincoeff = (wishspd - FloatAbs(currentgain)) / wishspd;
					if(g_bTouchesWall[client] && gaincoeff > 0.5)
					{
						gaincoeff -= 1;
						gaincoeff = FloatAbs(gaincoeff);
					}
					g_flRawGain[client] += gaincoeff;
				}
			}
		}
		g_iTicksOnGround[client] = 0;
	}
	g_bTouchesWall[client] = false;

	return Plugin_Continue;
}

public void ResetSSJ(int client, bool jumps, bool usecurrent)
{
	if(jumps)
	{
		gI_SSJJumps[client] = 0;
	}

	gF_SSJStartingSpeed[client] = (usecurrent)? GetClientSpeed(client):0.0;
	gF_SSJStartingHeight[client] = (usecurrent)? GetClientHeight(client):0.0;
	gF_HitGround[client] = 0.0;
	g_strafeTick[client] = 0;
	g_flRawGain[client] = 0.0;
	g_iTicksOnGround[client] = 0;
}

public float GetClientSpeed(int client)
{
	float fSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);

	return SquareRoot((Pow(fSpeed[0], 2.0) + Pow(fSpeed[1], 2.0)));
}

public float GetClientHeight(int client)
{
	float fPosition[3];
	GetClientAbsOrigin(client, fPosition);

	return fPosition[2];
}

public void OnClientDisconnect(int client)
{
	gI_SSJSettings[client] = SSJ_NONE;
}

public void OnClientPutInServer(int client)
{
	ResetSSJ(client, true, false);

	if(AreClientCookiesCached(client))
	{
		OnClientCookiesCached(client);
	}
	
	SDKHook(client, SDKHook_Touch, onTouch);
}

public Action:onTouch(client, entity) if(entity == 0) g_bTouchesWall[client] = true;

public void OnClientCookiesCached(int client)
{
	char[] sHUDSettings = new char[8];
	GetClientCookie(client, gH_SSJCookie, sHUDSettings, 8);

	if(strlen(sHUDSettings) == 0)
	{
		IntToString(SSJ_DEFAULT, sHUDSettings, 8);
		SetClientCookie(client, gH_SSJCookie, sHUDSettings);
		gI_SSJSettings[client] = SSJ_DEFAULT;
	}

	else
	{
		gI_SSJSettings[client] = StringToInt(sHUDSettings);
		GetClientCookie(client, gH_SSJCookie_jumps, sHUDSettings, 8);
		gI_SSJSetting_jumpprint[client] = StringToInt(sHUDSettings);
	}
}

public Action Command_SSJ(int client, int args)
{
	if(client != 0)
	{
		ShowSSJMenu(client);
	}

	return Plugin_Handled;
}

void ShowSSJMenu(int client, int Item = 0)
{
	Menu m = new Menu(MenuHandler_SSJ, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);
	m.SetTitle("Jump stats settings\n \n");

	char[] sInfo = new char[16];
	IntToString(SSJ_ENABLED, sInfo, 16);
	m.AddItem(sInfo, "Usage jump stats");

	IntToString(SSJ_RPT, sInfo, 16);
	m.AddItem(sInfo, "Repeat stats each");

	IntToString(SSJ_TJP, sInfo, 16);
	m.AddItem(sInfo, "Trigger jump ++");

	IntToString(SSJ_TJM, sInfo, 16);
	m.AddItem(sInfo, "Trigger jump --");

	m.AddItem("-", "-", ITEMDRAW_SPACER);
	m.AddItem("Edit settings on next page", "Edit settings on next page", ITEMDRAW_DISABLED);
	
	IntToString(SSJ_PRESPEED, sInfo, 16);
	m.AddItem(sInfo, "Show prespeed");

	IntToString(SSJ_SPEEDD, sInfo, 16);
	m.AddItem(sInfo, "Show speed difference");

	IntToString(SSJ_HEIGHT, sInfo, 16);
	m.AddItem(sInfo, "Show height difference");

	IntToString(SSJ_GAIN, sInfo, 16);
	m.AddItem(sInfo, "Show gain percentage");

	m.ExitButton = true;
	m.DisplayAt(client, Item, MENU_TIME_FOREVER);
}

public int MenuHandler_SSJ(Menu m, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char[] sCookie = new char[16];
		m.GetItem(param2, sCookie, 16);
		int iSelection = StringToInt(sCookie);
		
		if (!(iSelection & SSJ_TJP || iSelection & SSJ_TJM))
		{
			gI_SSJSettings[param1] ^= iSelection;
			IntToString(gI_SSJSettings[param1], sCookie, 16);

			SetClientCookie(param1, gH_SSJCookie, sCookie);

			if(iSelection == SSJ_ENABLED)
			{
				ResetSSJ(param1, true, false);
			}
		}
		else
		{
			if(iSelection & SSJ_TJP)							gI_SSJSetting_jumpprint[param1]++;
			else if(gI_SSJSetting_jumpprint[param1] != 0)	gI_SSJSetting_jumpprint[param1]--;
			
			IntToString(gI_SSJSetting_jumpprint[param1], sCookie, 16);
			SetClientCookie(param1, gH_SSJCookie_jumps, sCookie);			
		}

		ShowSSJMenu(param1, GetMenuSelectionPosition());
	}

	else if(action == MenuAction_DisplayItem)
	{
		char[] sInfo = new char[16];
		char[] sDisplay = new char[64];
		int style = 0;
		m.GetItem(param2, sInfo, 16, style, sDisplay, 64);

		
		switch (StringToInt(sInfo))
		{
			case SSJ_ENABLED:		Format(sDisplay, 64, "%s: %s\n \nTrigger jump: %i", sDisplay, (gI_SSJSettings[param1] & StringToInt(sInfo))? "On":"Off", gI_SSJSetting_jumpprint[param1]);
			case SSJ_RPT:			Format(sDisplay, 64, "%s %i jump: %s", sDisplay, gI_SSJSetting_jumpprint[param1], (gI_SSJSettings[param1] & SSJ_RPT)? "On":"Off");
			case SSJ_PRESPEED:		Format(sDisplay, 64, "%s: %s", sDisplay, (gI_SSJSettings[param1] & SSJ_PRESPEED)? "On":"Off");
			case SSJ_SPEEDD:		Format(sDisplay, 64, "%s: %s", sDisplay, (gI_SSJSettings[param1] & SSJ_SPEEDD)? "On":"Off");
			case SSJ_HEIGHT:		Format(sDisplay, 64, "%s: %s", sDisplay, (gI_SSJSettings[param1] & SSJ_HEIGHT)? "On":"Off");
			case SSJ_GAIN:			Format(sDisplay, 64, "%s: %s", sDisplay, (gI_SSJSettings[param1] & SSJ_GAIN)? "On":"Off");
		}

		return RedrawMenuItem(sDisplay);
	}

	else if(action == MenuAction_End)
	{
		delete m;
	}

	return 0;
}

public void Player_Jump(Event event, const char[] name, bool dB)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	gI_SSJJumps[client]++;

	if(gI_SSJJumps[client] == 1)
	{
		ResetSSJ(client, false, true);
	}
	
	if(gI_SSJSettings[client] & SSJ_PRESPEED && gI_SSJJumps[client] == 1 && RoundToFloor(GetClientSpeed(client)) > 100)
	{
		PrintPrespeed(client, client);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(i == client || !IsValidClient(i) || !IsClientObserver(i) || IsFakeClient(i))
			{
				continue;
			}

			int iObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

			if(iObserverMode >= 3 && iObserverMode <= 5)
			{
				if(GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client)
				{
					PrintPrespeed(i, client);
				}
			}
		}
	}

	if(gI_SSJJumps[client] == gI_SSJSetting_jumpprint[client] || (gI_SSJSettings[client] & SSJ_RPT && gI_SSJSetting_jumpprint[client] > 0 && gI_SSJJumps[client] % gI_SSJSetting_jumpprint[client] == 0))
	{
		new Float:gain = g_flRawGain[client];
		gain /= g_strafeTick[client];
		gain *= 100.0;
		gain = RoundToFloor(gain * 100.0 + 0.5) / 100.0;

		PrintSSJ(client, client, gain);

		for(int i = 1; i <= MaxClients; i++)
		{
			if(i == client || !IsValidClient(i) || !IsClientObserver(i) || IsFakeClient(i))
			{
				continue;
			}

			int iObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

			if(iObserverMode >= 3 && iObserverMode <= 5)
			{
				if(GetEntPropEnt(i, Prop_Send, "m_hObserverTarget") == client)
				{
					PrintSSJ(i, client, gain);
				}
			}
		}

		ResetSSJ(client, false, true);
	}
}

public void PrintSSJ(int client, int target, float gain)
{
	if(!(gI_SSJSettings[client] & SSJ_ENABLED))
	{
		return;
	}

	char[] sMessage = new char[256];
	FormatEx(sMessage, 256, "%s%sJump: %s%d %s| Speed: %s%d", g_msg_start, g_msg_textcol, g_msg_varcol, gI_SSJJumps[target], g_msg_textcol, g_msg_varcol, RoundToFloor(GetClientSpeed(target)));

	if(gI_SSJSettings[client] & SSJ_SPEEDD && gI_SSJJumps[target] > 1)
	{
		Format(sMessage, 256, "%s %s| Speed Δ: %s%d", sMessage, g_msg_textcol, g_msg_varcol, RoundToFloor(GetClientSpeed(target) - gF_SSJStartingSpeed[target]));
	}

	if(gI_SSJSettings[client] & SSJ_HEIGHT && gI_SSJJumps[target] > 1)
	{
		Format(sMessage, 256, "%s %s| Height Δ: %s%d", sMessage, g_msg_textcol, g_msg_varcol, RoundToFloor(GetClientHeight(target) - gF_SSJStartingHeight[target]));
	}

	if(gI_SSJSettings[client] & SSJ_GAIN && gI_SSJJumps[target] > 1)
	{
		Format(sMessage, 256, "%s %s| Gain: %s%.01f%%", sMessage, g_msg_textcol, g_msg_varcol, gain);
	}

	PrintToChat(client, "%s", sMessage);
}

public void PrintPrespeed(int client, int target)
{
	if(!(gI_SSJSettings[client] & SSJ_ENABLED))
	{
		return;
	}
	
	PrintToChat(client, "%s%sPrespeed: %s%d", g_msg_start, g_msg_textcol, g_msg_varcol, RoundToFloor(GetClientSpeed(target)));
}