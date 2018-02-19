#include <sourcemod>
#include <cstrike>
#include <smlib>
#include <sdktools>
#include <csgocolors>
#include <bTimes-timer>
#include <bTimes-core>

//SPEED ISNT GOOD

public Plugin myinfo = 
{
	name = "[bTimes] TAS",
	author = "Charles_(hypnos)",
	description = "Allows for creation of Tool Assisted Speedrun styles.",
	version = "1.9.0",
	url = ""
};

#define RUN 0
#define PAUSED 1
#define BACKWARD 2
#define FORWARD 3

#define AutoStrafeTrigger 1

new gi_Status[MAXPLAYERS+1];
new Handle:gh_Frames[MAXPLAYERS+1];
new gi_IndexCounter[MAXPLAYERS+1];
new Float:gf_IndexCounter[MAXPLAYERS+1];
new Float:gf_CounterSpeed[MAXPLAYERS+1];
new bool:gb_TASMenu[MAXPLAYERS+1];
new bool:gb_inDuck[MAXPLAYERS+1];
new bool:gb_Ducked[MAXPLAYERS+1];
new Float:gf_TickRate;
new Float:gf_TASTime[MAXPLAYERS+1];
new Float:gf_TimeScale[MAXPLAYERS+1];
new Float:gf_RealFrameCounter[MAXPLAYERS+1];
float gf_LastDuckTime[MAXPLAYERS+1];

bool AutoStrafeEnabled[MAXPLAYERS + 1] = {false,...};
bool g_Strafing[MAXPLAYERS + 1];

float flYawBhop[MAXPLAYERS + 1];
float truevel[MAXPLAYERS + 1];
bool DirIsRight[MAXPLAYERS + 1];
int StrafeAxis[MAXPLAYERS + 1] = {1,...};
float AngDiff[MAXPLAYERS + 1];

public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}

	AddCommandListener(Listener, "");
	AddCommandListener(sm_tas, "sm_tas");
	RegConsoleCmd("sm_tasmenu", Command_TASMenu);

	gf_TickRate = (1.0 / GetTickInterval());
	
	RegConsoleCmd("sm_strafe", Command_AutoStrafe, "Autostrafer");
	
	RegConsoleCmd("+autostrafer", PlusStrafer, "");
	RegConsoleCmd("-autostrafer", MinusStrafer, "");
}

public Action PlusStrafer(int client, int args)
{
	g_Strafing[client] = true;
	return;
}

public Action MinusStrafer(int client, int args)
{
	g_Strafing[client] = false;
	return;
}

public Action Command_AutoStrafe(int client, int args)
{
	if (AutoStrafeEnabled[client] == false)
	{
		ReplyToCommand(client, "\x01\x08[\x07AutoStrafe\x08] \x01Autostrafer Enabled.");
		AutoStrafeEnabled[client] = true;
	}
	else
	{
		ReplyToCommand(client, "\x01\x08[\x07AutoStrafe\x08] \x01Autostrafer Disabled.");
		AutoStrafeEnabled[client] = false;
	}
	
	return Plugin_Handled;
}

public Action Command_TASMenu(int client, int args)
{
	gb_TASMenu[client] = !gb_TASMenu[client];
	return Plugin_Handled;
}

/* public OnMapStart()
{
	CreateTimer(0.1, PanelTimer, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
} */

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("bTimes-tas");
	CreateNative("Timer_DrawTASMenu", Native_DrawTASMenu);
	CreateNative("Timer_GetSpeedTAS", Native_GetSpeedTAS);
	CreateNative("Timer_GetTASTime", Native_GetTASTime);
	CreateNative("Timer_GetFrames", Native_GetFrames);
}

public Action sm_tas(client, const String:command[], args)
{
	gb_TASMenu[client] = true;
	return Plugin_Continue;
}

public Action:Listener(client, const String:command[], args)
{
	if(!Timer_IsTAS(client))
	{
		return Plugin_Continue;
	}
	if(StrEqual(command, "+rewind"))
	{
		gi_Status[client] = BACKWARD;
		return Plugin_Handled;
	}
	else if(StrEqual(command, "+fastforward"))
	{
		gi_Status[client] = FORWARD;
		return Plugin_Handled;
	}
	else if(StrEqual(command, "-rewind") || StrEqual(command, "-fastforward"))
	{
		gb_Ducked[client] = bool:(GetEntProp(client, Prop_Send, "m_bDucked"));
		if(!(GetClientButtons(client) & IN_DUCK))
			gb_inDuck[client] = false;
		else if(GetClientButtons(client) & IN_DUCK)
		{
			gb_inDuck[client] = true;
			gf_LastDuckTime[client] = GetEntPropFloat(client, Prop_Send, "m_flLastDuckTime");
		}
		gi_Status[client] = PAUSED;
		return Plugin_Handled;
	}
	/* else if(StrEqual(command, "test"))
	{
		PrintToConsole(client, "%f, %d", gf_IndexCounter[client], gi_IndexCounter[client]);
	} */
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	if(gh_Frames[client] != INVALID_HANDLE)
		ClearArray(gh_Frames[client]);
	else
		gh_Frames[client] = CreateArray(8, 0);

	gf_CounterSpeed[client] = 1.0;
	gf_TASTime[client] = 0.0;
	gf_TimeScale[client] = 1.0;
	gi_Status[client] = RUN;
	gb_TASMenu[client] = true;
	AutoStrafeEnabled[client] = false;
	g_Strafing[client] = false;
}


float GetClientVelo(int client)
{
	float vVel[3];
	
	vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	
	
	return GetVectorLength(vVel);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsClientInGame(client) && !IsClientSourceTV(client) && !IsClientReplay(client) && IsClientConnected(client) && GetClientMenu(client) == MenuSource_None && Timer_IsTAS(client) && IsPlayerAlive(client))
	{
		DrawPanel(client);
	}

	if(IsClientInGame(client))
	{
		if(!Timer_IsTAS(client))
		{
			return Plugin_Continue;
		}
		truevel[client] = GetClientVelo(client);
		/*
					AUTO STRAFER START
												*/
		if(buttons & IN_FORWARD && vel[0] <= 50.0)
			vel[0] = 450.0;

		float yaw_change = 0.0;
		if(vel[0] > 50.0)
			yaw_change = 30.0 * FloatAbs(30.0 / vel[0]);

		if (AutoStrafeEnabled[client] == true && !(GetEntityFlags(client) & FL_ONGROUND) && (GetEntityMoveType(client) != MOVETYPE_NOCLIP) && !(buttons & IN_FORWARD) && !(buttons & IN_BACK) && !(buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT))
		{
			if(mouse[0] > 0)
			{
				angles[1] += yaw_change;
				//buttons |= IN_MOVERIGHT;
				vel[1] = 450.0;
			}
			else if(mouse[0] < 0)
			{
				angles[1] -= yaw_change;
				//buttons |= IN_MOVELEFT;
				vel[1] = -450.0;
			}
		}
		/*
					AUTO STRAFER END
												*/

		/*
					WIGGLEHACK START
												*/
		if (g_Strafing[client] == true && !(GetEntityFlags(client) & FL_ONGROUND) && (GetEntityMoveType(client) != MOVETYPE_NOCLIP) && !(buttons & IN_FORWARD) && !(buttons & IN_BACK) && !(buttons & IN_MOVELEFT) && !(buttons & IN_MOVERIGHT))
		{
			if(AngDiff[client] < AutoStrafeTrigger * -1)
			{
				vel[StrafeAxis[client]] = -450.0;
			}
			else if(AngDiff[client] > AutoStrafeTrigger)
			{
				vel[StrafeAxis[client]] = 450.0;
			}
			
			else if (!(GetEntityFlags(client) & FL_ONGROUND) && (GetEntityMoveType(client) != MOVETYPE_NOCLIP))
			{
				if (!(truevel[client] == 0.0))
				{
					flYawBhop[client] = 0.0;
					float x = 30.0;
					float y = truevel[client];
					float z = x/y;
					z = FloatAbs(z);
					flYawBhop[client] = x * z;
				}
				
				
				if (DirIsRight[client] == true)
				{
					angles[1] += flYawBhop[client];
					//buttons |= ~IN_MOVERIGHT;
					DirIsRight[client] = false;
					vel[StrafeAxis[client]] = 450.0;
				}
				else
				{
					angles[1] -= flYawBhop[client];
					//buttons |= ~IN_MOVELEFT;
					DirIsRight[client] = true;
					vel[StrafeAxis[client]] = -450.0;
				}
			}
		}
		/*
					WIGGLEHACK END
												*/

		if(!IsBeingTimed(client, TIMER_ANY))
		{
			return Plugin_Continue;
		}
		if(IsTimerPaused(client))
		{
			return Plugin_Continue;
		}
		else if(IsPlayerAlive(client) && !IsFakeClient(client))
		{
			if(gi_Status[client] == RUN)
			{
				gf_TASTime[client] += GetTickInterval() * gf_TimeScale[client];
				gf_RealFrameCounter[client] += GetTickInterval() * gf_TimeScale[client];
				if(gf_RealFrameCounter[client] >= GetTickInterval())
				{
					gf_RealFrameCounter[client] = 0.0;
				}
				new framenum = GetArraySize(gh_Frames[client])+1;
				if(gi_IndexCounter[client] != framenum-2)
				{
					//UnPaused in diff tick
					framenum = gi_IndexCounter[client]+1;
				}
				ResizeArray(gh_Frames[client], framenum);
				
				new Float:lpos[3], Float:lang[3];

				GetEntPropVector(client, Prop_Send, "m_vecOrigin", lpos);
				GetClientEyeAngles(client, lang);
				SetArrayCell(gh_Frames[client], framenum-1, lpos[0], 0);
				SetArrayCell(gh_Frames[client], framenum-1, lpos[1], 1);
				SetArrayCell(gh_Frames[client], framenum-1, lpos[2], 2);
				SetArrayCell(gh_Frames[client], framenum-1, lang[0], 3);
				SetArrayCell(gh_Frames[client], framenum-1, lang[1], 4);
				SetArrayCell(gh_Frames[client], framenum-1, buttons, 5);
				SetArrayCell(gh_Frames[client], framenum-1, impulse, 6);
				gi_IndexCounter[client] = framenum-1;
				gf_IndexCounter[client] = framenum-1.0;

				
				new CSWeaponID:SaveWeapon = CSWeapon_NONE;
				new iNewWeapon = Client_GetActiveWeapon(client);
			
				if(IsValidEntity(iNewWeapon) && IsValidEdict(iNewWeapon))
				{				
					new String:sClassName[64];
					GetEdictClassname(iNewWeapon, sClassName, sizeof(sClassName));
					ReplaceString(sClassName, sizeof(sClassName), "weapon_", "", false);
					
					new String:sWeaponAlias[64];
					CS_GetTranslatedWeaponAlias(sClassName, sWeaponAlias, sizeof(sWeaponAlias));
					new CSWeaponID:weaponId = CS_AliasToWeaponID(sWeaponAlias);
					
					SaveWeapon = weaponId;
				}
				SetArrayCell(gh_Frames[client], framenum-1, SaveWeapon, 7);
				
			}
			else if(gi_Status[client] == PAUSED)
			{
				vel[0] = 0.0;
				vel[1] = 0.0;
				vel[2] = 0.0;
				new frameSize = GetArraySize(gh_Frames[client]);
				new framenum = gi_IndexCounter[client];
				if(frameSize > 1 && framenum > 1)
				{
					new Float:fAng[3];
					fAng[0] = GetArrayCell(gh_Frames[client], framenum, 3);
					fAng[1] = GetArrayCell(gh_Frames[client], framenum, 4);
					
					new Float:pos[3];
					pos[0] = GetArrayCell(gh_Frames[client], framenum, 0);
					pos[1] = GetArrayCell(gh_Frames[client], framenum, 1);
					pos[2] = GetArrayCell(gh_Frames[client], framenum, 2);

					TeleportEntity(client, pos, fAng, Float:{0.0, 0.0, 0.0});
					//gf_TASTime[client] -= GetTickInterval();
				}

				if(GetEntityFlags(client) & FL_ONGROUND)
					buttons &= ~IN_JUMP;

				SetEntProp(client, Prop_Send, "m_bDucked", gb_Ducked[client]);
				SetEntProp(client, Prop_Send, "m_bDucking", false);

				if(GetArrayCell(gh_Frames[client], framenum, 5) & IN_DUCK)
				{
					SetEntProp(client, Prop_Send, "m_bDucked", true);
					SetEntProp(client, Prop_Send, "m_bDucking", false);
				}
				else
					SetEntProp(client, Prop_Send, "m_bDucked", false);
					SetEntProp(client, Prop_Send, "m_bDucking", false);

				if(!gb_inDuck[client])
					buttons &= ~IN_DUCK;
				else if(gb_inDuck[client])
				{
					buttons |= IN_DUCK;
					//SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);
				}
			}
			else if(gi_Status[client] == BACKWARD)
			{
				vel[0] = 0.0;
				vel[1] = 0.0;
				vel[2] = 0.0;
				new frameSize = GetArraySize(gh_Frames[client]);
				new framenum = gi_IndexCounter[client];
				if(frameSize > 1 && framenum > 2)
				{
					new Float:fAng[3];
					fAng[0] = GetArrayCell(gh_Frames[client], framenum, 3);
					fAng[1] = GetArrayCell(gh_Frames[client], framenum, 4);
					
					new Float:pos2[3];
					pos2[0] = GetArrayCell(gh_Frames[client], framenum, 0);
					pos2[1] = GetArrayCell(gh_Frames[client], framenum, 1);
					pos2[2] = GetArrayCell(gh_Frames[client], framenum, 2);

					new Float:pos[3];
					pos[0] = GetArrayCell(gh_Frames[client], framenum-1, 0);
					pos[1] = GetArrayCell(gh_Frames[client], framenum-1, 1);
					pos[2] = GetArrayCell(gh_Frames[client], framenum-1, 2);

					new Float:fVel[3];
					MakeVectorFromPoints(pos2, pos, fVel);

					for (int i = 0; i < 3; i++)
					{
						fVel[i] *= RoundToFloor(gf_TickRate);
					}

					TeleportEntity(client, pos, fAng, fVel);

					if(GetArrayCell(gh_Frames[client], framenum, 5) & IN_DUCK)
					{
						SetEntProp(client, Prop_Send, "m_bDucked", true);
						SetEntProp(client, Prop_Send, "m_bDucking", false);
					}
					else
						SetEntProp(client, Prop_Send, "m_bDucked", false);
						SetEntProp(client, Prop_Send, "m_bDucking", false);

					gf_IndexCounter[client] -= gf_CounterSpeed[client];
					if(isRound(gf_IndexCounter[client]))
						gi_IndexCounter[client]--;
					gf_TASTime[client] -= GetTickInterval() * gf_CounterSpeed[client];
				}
				else if(frameSize > 1)
				{
					if(!(buttons & IN_DUCK))
						gb_inDuck[client] = false;
					else if(buttons & IN_DUCK)
					{
						gb_inDuck[client] = true;
						gf_LastDuckTime[client] = GetEntPropFloat(client, Prop_Send, "m_flLastDuckTime");
					}
					gi_Status[client] = PAUSED;
				}
			}
			else if(gi_Status[client] == FORWARD)
			{
				vel[0] = 0.0;
				vel[1] = 0.0;
				vel[2] = 0.0;
				new frameSize = GetArraySize(gh_Frames[client]);
				new framenum = gi_IndexCounter[client];
				if(frameSize > 1 && framenum < frameSize-1)
				{
					new Float:fAng[3];
					fAng[0] = GetArrayCell(gh_Frames[client], framenum, 3);
					fAng[1] = GetArrayCell(gh_Frames[client], framenum, 4);
					
					new Float:pos2[3];
					pos2[0] = GetArrayCell(gh_Frames[client], framenum, 0);
					pos2[1] = GetArrayCell(gh_Frames[client], framenum, 1);
					pos2[2] = GetArrayCell(gh_Frames[client], framenum, 2);

					new Float:pos[3];
					pos[0] = GetArrayCell(gh_Frames[client], framenum-1, 0);
					pos[1] = GetArrayCell(gh_Frames[client], framenum-1, 1);
					pos[2] = GetArrayCell(gh_Frames[client], framenum-1, 2);

					new Float:fVel[3];
					MakeVectorFromPoints(pos, pos2, fVel);

					for (int i = 0; i < 3; i++)
					{
						fVel[i] *= RoundToFloor(gf_TickRate);
					}

					TeleportEntity(client, pos2, fAng, fVel);

					if(GetArrayCell(gh_Frames[client], framenum, 5) & IN_DUCK)
					{
						SetEntProp(client, Prop_Send, "m_bDucked", true);
						SetEntProp(client, Prop_Send, "m_bDucking", false);
					}
					else
						SetEntProp(client, Prop_Send, "m_bDucked", false);
						SetEntProp(client, Prop_Send, "m_bDucking", false);

					gf_IndexCounter[client] += gf_CounterSpeed[client];
					if(isRound(gf_IndexCounter[client]))
					{
						gi_IndexCounter[client]++;
					}
					gf_TASTime[client] += GetTickInterval() * gf_CounterSpeed[client];
				}
				else if(frameSize > 1)
				{
					if(!(buttons & IN_DUCK))
						gb_inDuck[client] = false;
					else if(buttons & IN_DUCK)
					{
						gb_inDuck[client] = true;
						gf_LastDuckTime[client] = GetEntPropFloat(client, Prop_Send, "m_flLastDuckTime");
					}
					gi_Status[client] = PAUSED;
				}
			}
		}
	}
	return Plugin_Continue;
}

/* public Action PanelTimer(Handle timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (client > 0 && IsClientInGame(client) && !IsClientSourceTV(client) && !IsClientReplay(client) && IsClientConnected(client) && GetClientMenu(client) == MenuSource_None && Timer_IsTAS(client) && IsPlayerAlive(client))
		{
			DrawPanel(client);
		}
	}
} */

bool DrawPanel(client)
{
	if(!gb_TASMenu[client] || !Timer_IsTAS(client))
		return false;
	new Handle:hPanel = CreatePanel();

	DrawPanelText(hPanel, "Tool Assisted Speedrun:\n ");
	if(gi_Status[client] == PAUSED)
		DrawPanelItem(hPanel, "Resume");
	else
		DrawPanelItem(hPanel, "Pause");

	if(gi_Status[client] != BACKWARD)
		DrawPanelItem(hPanel, "+rewind");
	else
		DrawPanelItem(hPanel, "-rewind");

	if(gi_Status[client] != FORWARD)
		DrawPanelItem(hPanel, "+fastforward");
	else
		DrawPanelItem(hPanel, "-fastforward");

	new String:sBuffer[256];
	/* FormatEx(sBuffer, sizeof(sBuffer), "Edit Speed: %.01f", gf_CounterSpeed[client]);
	DrawPanelItem(hPanel, sBuffer); */

	DrawPanelText(hPanel, " ");

	SetPanelCurrentKey(hPanel, 5);
	FormatEx(sBuffer, sizeof(sBuffer), "Toggle autostrafe %s", AutoStrafeEnabled[client]?"[ON]":"[OFF]");
	DrawPanelItem(hPanel, sBuffer);
	
	FormatEx(sBuffer, sizeof(sBuffer), "Toggle wigglehack %s", g_Strafing[client]?"[ON]":"[OFF]");
	DrawPanelItem(hPanel, sBuffer);
	
	DrawPanelText(hPanel, " ");
	DrawPanelText(hPanel, "----------------------------");
	DrawPanelText(hPanel, " ");
	
	/* FormatEx(sBuffer, sizeof(sBuffer), "Timescale: %.01f", gf_TimeScale[client]);
	DrawPanelItem(hPanel, sBuffer); */

	SetPanelCurrentKey(hPanel, 8);
	DrawPanelItem(hPanel, "Restart");
	DrawPanelItem(hPanel, "Exit");
	SendPanelToClient(hPanel, client, Panel_Handler, MENU_TIME_FOREVER);
	//hPanel.Send(client, Panel_Handler, MENU_TIME_FOREVER);
	return true;
}

public Panel_Handler(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		if(!Timer_IsTAS(param1))
		{
			gb_TASMenu[param1] = false;
			return;
		}
		if(IsBeingTimed(param1, TIMER_ANY))
		{
			if(param2 == 1)
			{
				if(gi_Status[param1] == PAUSED)
				{
					ResumePlayer(param1);
					gi_Status[param1] = RUN;
				}
				else
				{
					gb_Ducked[param1] = bool:(GetEntProp(param1, Prop_Send, "m_bDucked"));
					if(!(GetClientButtons(param1) & IN_DUCK))
						gb_inDuck[param1] = false;
					else if(GetClientButtons(param1) & IN_DUCK)
					{
						gb_inDuck[param1] = true;
						gf_LastDuckTime[param1] = GetEntPropFloat(param1, Prop_Send, "m_flLastDuckTime");
					}
					gi_Status[param1] = PAUSED;
				}
			}
			else if(param2 == 2)
			{
				if(gi_Status[param1] != BACKWARD)
				{
					gi_Status[param1] = BACKWARD;
				}
				else
				{
					//ResumePlayer(param1);
					//gi_Status[param1] = RUN;
					gb_Ducked[param1] = bool:(GetEntProp(param1, Prop_Send, "m_bDucked"));
					if(!(GetClientButtons(param1) & IN_DUCK))
						gb_inDuck[param1] = false;
					else if(GetClientButtons(param1) & IN_DUCK)
					{
						gb_inDuck[param1] = true;
						gf_LastDuckTime[param1] = GetEntPropFloat(param1, Prop_Send, "m_flLastDuckTime");
					}
					gi_Status[param1] = PAUSED;
				}
			}
			else if(param2 == 3)
			{
				if(gi_Status[param1] != FORWARD)
				{
					gi_Status[param1] = FORWARD;
				}
				else
				{
					//ResumePlayer(param1);
					//gi_Status[param1] = RUN;
					gb_Ducked[param1] = bool:(GetEntProp(param1, Prop_Send, "m_bDucked"));
					if(!(GetClientButtons(param1) & IN_DUCK))
						gb_inDuck[param1] = false;
					else if(GetClientButtons(param1) & IN_DUCK)
					{
						gb_inDuck[param1] = true;
						gf_LastDuckTime[param1] = GetEntPropFloat(param1, Prop_Send, "m_flLastDuckTime");
					}
					gi_Status[param1] = PAUSED;
				}
			}
			/* else if(param2 == 4)
			{
				gf_IndexCounter[param1] = 1.0 * RoundToFloor(gf_IndexCounter[param1]);
				gf_CounterSpeed[param1] += 1.0;
				if(gf_CounterSpeed[param1] >= 4.0)
					gf_CounterSpeed[param1] = 1.0;
			} */
			else if(param2 == 5)
			{
				AutoStrafeEnabled[param1] = !AutoStrafeEnabled[param1];
			}
			else if(param2 == 6)
			{
				g_Strafing[param1] = !g_Strafing[param1];
			}
			/* else if(param2 == 5)
			{
				gf_TimeScale[param1] += 0.1;
				if(gf_TimeScale[param1] >= 1.1)
					gf_TimeScale[param1] = 0.2;
	
				SetEntPropFloat(param1, Prop_Send, "m_flLaggedMovementValue", gf_TimeScale[param1]);
			} */
			else if(param2 == 8)
			{
				FakeClientCommandEx(param1, "sm_r");
			}
			else if(param2 == 9)
			{
				gb_TASMenu[param1] = false;
				CPrintToChat(param1, "\x01\x08[\x0BTimer\x08] \x0B- \x08Type \x0B!tasmenu \x08to reopen the menu.");
			}
		}
	}
}

public void ResumePlayer(int client)
{
	new frameSize = GetArraySize(gh_Frames[client]);
	new framenum = gi_IndexCounter[client];
	if(frameSize > 1 && framenum > 1)
	{
		new Float:fAng[3];
		fAng[0] = GetArrayCell(gh_Frames[client], framenum, 3);
		fAng[1] = GetArrayCell(gh_Frames[client], framenum, 4);
		
		new Float:pos2[3];
		pos2[0] = GetArrayCell(gh_Frames[client], framenum, 0);
		pos2[1] = GetArrayCell(gh_Frames[client], framenum, 1);
		pos2[2] = GetArrayCell(gh_Frames[client], framenum, 2);

		new Float:pos[3];
		pos[0] = GetArrayCell(gh_Frames[client], framenum-1, 0);
		pos[1] = GetArrayCell(gh_Frames[client], framenum-1, 1);
		pos[2] = GetArrayCell(gh_Frames[client], framenum-1, 2);

		
		new Float:fVel[3];
		MakeVectorFromPoints(pos, pos2, fVel);

		for (int i = 0; i < 3; i++)
		{
			fVel[i] *= RoundToFloor(gf_TickRate);
		}

		TeleportEntity(client, pos2, fAng, fVel);

		SetEntPropFloat(client, Prop_Send, "m_flLastDuckTime", gf_LastDuckTime[client]);

	}
}

public bool:isRound(Float:num)
{
	return RoundToFloor(num) == num;
}

public Action OnTimerStart_Pre(client)
{
	if(gi_Status[client] == RUN)
	{
		gf_TASTime[client] = 0.0;
		gi_IndexCounter[client] = 0;
		ClearArray(gh_Frames[client]);
	}
}

public OnTimerFinished_Post(client)
{
	gi_Status[client] = RUN;
	gf_TASTime[client] = 0.0;
	gi_IndexCounter[client] = 0;
	//ClearArray(gh_Frames[client]);
}

public Native_DrawTASMenu(Handle handler, int numParams)
{
	return DrawPanel(GetNativeCell(1));
}

public Native_GetSpeedTAS(Handle handler, int numParams)
{
	new client = GetNativeCell(1);
	new bool:threeAxis = bool:GetNativeCell(2);
	new Float:fVelocity[3];
	if(gi_Status[client] == RUN)
	{
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	}	
	else
	{
		new frameSize = GetArraySize(gh_Frames[client]);
		new framenum = gi_IndexCounter[client];
		if(frameSize > 1 && framenum > 1)
		{	
			new Float:pos2[3];
			pos2[0] = GetArrayCell(gh_Frames[client], framenum, 0);
			pos2[1] = GetArrayCell(gh_Frames[client], framenum, 1);
			pos2[2] = GetArrayCell(gh_Frames[client], framenum, 2);

			new Float:pos[3];
			pos[0] = GetArrayCell(gh_Frames[client], framenum-1, 0);
			pos[1] = GetArrayCell(gh_Frames[client], framenum-1, 1);
			pos[2] = GetArrayCell(gh_Frames[client], framenum-1, 2);

			
			MakeVectorFromPoints(pos, pos2, fVelocity);

			for (int i = 0; i < 3; i++)
			{
				fVelocity[i] *= gf_TickRate;
			}
		}
		else
		{
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
		}
	}
	new Float:fSpeed = threeAxis 
		? SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0))
		: SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));

	SetNativeCellRef(3, fSpeed);
}

public Native_GetTASTime(Handle handler, int numParams)
{
	SetNativeCellRef(2, gf_TASTime[GetNativeCell(1)]);
}

public Native_GetFrames(Handle handler, int numParams)
{
	SetNativeCellRef(2, gh_Frames[GetNativeCell(1)]);
}