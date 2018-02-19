#pragma semicolon 1

#include <bTimes-core>

public Plugin myinfo =
{
	name = "[bTimes] Random",
    author = "Charles_(hypnos), blacky",
	description = "Handles events and modifies them to fit bTimes' needs",
	version = "1.9.0",
	url = ""
}

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <bTimes-timer>
#include <bTimes-zones>
#include <bTimes-random>
#include <clientprefs>

/*
#undef REQUIRE_PLUGIN
#include <bTimes-gunjump>
*/

#define HUD_OFF (1<<0|1<<3|1<<4|1<<8)
#define HUD_ON  0
#define HUD_FUCK (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9|1<<10|1<<11)

new	g_Settings[MAXPLAYERS+1] = {SHOW_HINT, ...},
	bool:g_bHooked;

new 	Float:g_fMapStart;

new 	Handle:g_hSettingsCookie;

new 	g_iSoundEnts[2048];
new 	g_iNumSounds;

// Settings
new 	Handle:g_hAllowKnifeDrop,
	Handle:g_WeaponDespawn,
	Handle:g_hNoDamage,
	Handle:g_hAllowHide,
	Handle:g_HideChatTriggers,
	Handle:g_DisableRadio;

new	Handle:g_MessageStart,
	Handle:g_MessageVar,
	Handle:g_MessageText,
	Handle:g_fwdChatChanged;

new 	String:g_msg_start[128] = {""};
new 	String:g_msg_varcol[128] = {"\x07B4D398"};
new 	String:g_msg_textcol[128] = {"\x01"};

//new bool:g_TimerGunJump;

// block radio
char gS_RadioCommands[][] = {"coverme", "takepoint", "holdpos", "regroup", "followme", "takingfire", "go", "fallback", "sticktog",
	"getinpos", "stormfront", "report", "roger", "enemyspot", "needbackup", "sectorclear", "inposition", "reportingin",
	"getout", "negative", "enemydown", "compliment", "thanks", "cheer"};

public OnPluginStart(){

	// Server settings
	g_hAllowKnifeDrop  = CreateConVar("timer_allowknifedrop", "1", "Allows players to drop any weapons (including knives and grenades)", 0, true, 0.0, true, 1.0);
	g_WeaponDespawn    = CreateConVar("timer_weapondespawn", "1", "Kills weapons a second after spawning to prevent flooding server.", 0, true, 0.0, true, 1.0);
	g_hNoDamage        = CreateConVar("timer_nodamage", "1", "Blocks all player damage when on", 0, true, 0.0, true, 1.0);
	g_hAllowHide       = CreateConVar("timer_allowhide", "1", "Allows players to use the !hide command", 0, true, 0.0, true, 1.0);
	g_HideChatTriggers = CreateConVar("timer_hidechatcmds", "1", "Hide any chat triggers", 0, true, 0.0, true, 1.0);
	g_DisableRadio     = CreateConVar("timer_blockradio", "1", "Block radio commands", 0, true, 0.0, true, 1.0);

	g_MessageStart     = CreateConVar("timer_msgstart", "^3^A^3[^4Timer^3] ^2- ", "Sets the start of all timer messages. (Always keep the ^A after the first color code)");
	g_MessageVar       = CreateConVar("timer_msgvar", "^4", "Sets the color of variables in timer messages such as player names.");
	g_MessageText      = CreateConVar("timer_msgtext", "^5", "Sets the color of general text in timer messages.");

	// Hook specific convars
	HookConVarChange(g_MessageStart, OnMessageStartChanged);
	HookConVarChange(g_MessageVar, OnMessageVarChanged);
	HookConVarChange(g_MessageText, OnMessageTextChanged);
	HookConVarChange(g_hNoDamage, OnNoDamageChanged);
	HookConVarChange(g_hAllowHide, OnAllowHideChanged);

	// Create config file if it doesn't exist
	AutoExecConfig(true, "random", "timer");

	// Event hooks
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	AddNormalSoundHook(NormalSHook);
	AddAmbientSoundHook(AmbientSHook);
	AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);

	// Command hooks
	AddCommandListener(DropItem, "drop");
	AddCommandListener(HookPlayerChat, "say");
	AddCommandListener(HookPlayerChat, "say_team");
	// hook radio commands instead of a global listener
	for(int i = 0; i < sizeof(gS_RadioCommands); i++)
	{
		AddCommandListener(Command_Radio, gS_RadioCommands[i]);
	}

	// Player commands
	RegConsoleCmdEx("sm_hide", SM_Hide, "Toggles hide");
	RegConsoleCmdEx("sm_unhide", SM_Hide, "Toggles hide");
	RegConsoleCmdEx("sm_spec", SM_Spec, "Be a spectator");
	RegConsoleCmdEx("sm_spectate", SM_Spec, "Be a spectator");
	RegConsoleCmdEx("sm_maptime", SM_Maptime, "Shows how long the current map has been on.");
	RegConsoleCmdEx("sm_sound", SM_Sound, "Choose different sounds to stop when they play.");
	RegConsoleCmdEx("sm_sounds", SM_Sound, "Choose different sounds to stop when they play.");
	RegConsoleCmdEx("sm_specinfo", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_specs", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_speclist", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_spectators", SM_Specinfo, "Shows who is spectating you.");
	RegConsoleCmdEx("sm_normalspeed", SM_Normalspeed, "Sets your speed to normal speed.");
	RegConsoleCmdEx("sm_speed", SM_Speed, "Changes your speed to the specified value.");
	RegConsoleCmdEx("sm_setspeed", SM_Speed, "Changes your speed to the specified value.");

	RegConsoleCmdEx("sm_flashlight", SM_FlashLight, "Enables or disables the flashlight");

	// Admin commands
	RegAdminCmd("sm_move", SM_Move, ADMFLAG_CUSTOM5, "For getting players out of places they are stuck in");
	RegAdminCmd("sm_hudfuck", SM_Hudfuck, ADMFLAG_CUSTOM5, "Removes a player's hud so they can only leave the server/game through task manager (Use only on players who deserve it)");
	RegAdminCmd("sm_randomplayer", SM_SelectRandom, ADMFLAG_ROOT, "Selects a random player in the server");

	// Client settings
	g_hSettingsCookie = RegClientCookie("timer", "Timer settings", CookieAccess_Public);

	// Makes FindTarget() work properly..
	LoadTranslations("common.phrases");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Native functions
	CreateNative("GetClientSettings", Native_GetClientSettings);
	CreateNative("SetClientSettings", Native_SetClientSettings);

	// Forwards
	g_fwdChatChanged = CreateGlobalForward("OnTimerChatChanged", ET_Event, Param_Cell, Param_String);

	return APLRes_Success;
}

/*
public OnAllPluginsLoaded()
{
	if(LibraryExists("gunjump"))
	{
		g_TimerGunJump = true;
	}
}
*/

public OnMapStart()
{
	//set map start time
	g_fMapStart = GetEngineTime();
}

public OnClientPutInServer(client)
{
	// for !hide
	if(GetConVarBool(g_hAllowHide))
	{
		SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	}

	// prevents damage
	if(GetConVarBool(g_hNoDamage))
	{
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
}

public OnNoDamageChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(newValue[0] == '0')
			{
				SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			}
			else
			{
				SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
			}
		}
	}
}

public OnAllowHideChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(newValue[0] == '0')
			{
				SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
			}
			else
			{
				SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
			}
		}
	}
}

public Action Command_Radio(int client, const char[] command, int args)
{
	if(GetConVarBool(g_DisableRadio))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:HookPlayerChat(int client, const String:command[], int args)
{
	if(GetConVarBool(g_HideChatTriggers))
	{
		decl String:text[2];
		GetCmdArg(1, text, 2);
		return text[0] == '!' || text[0] == '/' ? Plugin_Handled:Plugin_Continue;
	}
	return Plugin_Continue;
}

public OnClientDisconnect_Post(client)
{
	CheckHooks();
}

public OnClientCookiesCached(client)
{
	// get client settings
	decl String:cookies[16];
	GetClientCookie(client, g_hSettingsCookie, cookies, sizeof(cookies));

	if(strlen(cookies) == 0)
	{
		g_Settings[client] = SHOW_HINT|AUTO_BHOP;
	}
	else
	{
		g_Settings[client] = StringToInt(cookies);
	}


	if((g_Settings[client] & STOP_GUNS) && g_bHooked == false)
	{
		g_bHooked = true;
	}
}

public OnConfigsExecuted()
{
	// load timer message colors
	GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(0);
	Call_PushString(g_msg_start);
	Call_Finish();

	GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(1);
	Call_PushString(g_msg_varcol);
	Call_Finish();

	GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(2);
	Call_PushString(g_msg_textcol);
	Call_Finish();
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
}

public OnMessageStartChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_MessageStart, g_msg_start, sizeof(g_msg_start));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(0);
	Call_PushString(g_msg_start);
	Call_Finish();
	ReplaceString(g_msg_start, sizeof(g_msg_start), "^", "\x07", false);
}

public OnMessageVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_MessageVar, g_msg_varcol, sizeof(g_msg_varcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(1);
	Call_PushString(g_msg_varcol);
	Call_Finish();
	ReplaceString(g_msg_varcol, sizeof(g_msg_varcol), "^", "\x07", false);
}

public OnMessageTextChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(g_MessageText, g_msg_textcol, sizeof(g_msg_textcol));
	Call_StartForward(g_fwdChatChanged);
	Call_PushCell(2);
	Call_PushString(g_msg_textcol);
	Call_Finish();
	ReplaceString(g_msg_textcol, sizeof(g_msg_textcol), "^", "\x07", false);
}

public Action:Timer_StopMusic(Handle:timer, any:data)
{
	new ientity, String:sSound[128];
	for (new i = 0; i < g_iNumSounds; i++)
	{
		ientity = EntRefToEntIndex(g_iSoundEnts[i]);

		if (ientity != INVALID_ENT_REFERENCE)
		{
			for(new client=1; client<=MaxClients; client++)
			{
				if(IsClientInGame(client))
				{
					if(g_Settings[client] & STOP_MUSIC)
					{
						GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
						EmitSoundToClient(client, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
					}
				}
			}
		}
	}
}

// Credits to GoD-Tony for everything related to stopping gun sounds
public Action:CSS_Hook_ShotgunShot(const String:te_name[], const Players[], numClients, Float:delay)
{
	if(!g_bHooked)
		return Plugin_Continue;

	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	new newTotal = 0;

	for (i = 0; i < numClients; i++)
	{
		client = Players[i];

		if(!(g_Settings[client] & STOP_GUNS) || !(g_Settings[client] & HIDE_PLAYERS))
			newClients[newTotal++] = client;
	}

	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;

	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;

	// Re-broadcast to clients that still need it.
	decl Float:vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);

	return Plugin_Stop;
}

CheckHooks()
{
	new bool:bShouldHook = false;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(g_Settings[i] & STOP_GUNS)
			{
				bShouldHook = true;
				break;
			}
		}
	}

	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action:AmbientSHook(String:sample[PLATFORM_MAX_PATH], &entity, &Float:volume, &level, &pitch, Float:pos[3], &flags, &Float:delay){
	// Stop music next frame
	CreateTimer(0.0, Timer_StopMusic);
}

public Action:NormalSHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags){
	//PrintToServer("[SOUND DEBUG] Sound played: %s", sample);

	if(0 < entity <= MaxClients && IsClientConnected(entity) && IsPlayerAlive(entity) &&
		((StrContains(sample, "player/damage", false) != -1)
		|| (StrContains(sample, "player/footstep", false) != -1)
		|| (StrContains(sample, "physics/", false) != -1)
		|| (StrContains(sample, "player/death", false) != -1)
		|| (StrContains(sample, "player/land", false) != -1)))
	{

		for (new i = 0; i < numClients; i++)
		{
			if(g_Settings[clients[i]] & HIDE_PLAYERS)
			{
				for (new j = i; j < numClients-1; j++)
				{
					clients[j] = clients[j+1];
				}
				numClients--;
				i--;
			}
		}
	}

	if(IsValidEntity(entity) && IsValidEdict(entity)){
		decl String:sClassName[128];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));

		new iSoundType;
		if(StrEqual(sClassName, "func_door"))
			iSoundType = STOP_DOORS;
		else if(StrContains(sample, "weapons", false) != -1)
			iSoundType = STOP_GUNS;
		else
			return Plugin_Continue;

		for (new i = 0; i < numClients; i++)
		{
			if((g_Settings[clients[i]] & iSoundType) || ((g_Settings[clients[i]] & HIDE_PLAYERS) && iSoundType == STOP_GUNS)){
				// Remove the client from the array.
				for (new j = i; j < numClients-1; j++)
				{
					clients[j] = clients[j+1];
				}
				numClients--;
				i--;
			}


		}

		return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
	}

	return (numClients > 0) ? Plugin_Changed : Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[]){
	if(GetConVarBool(g_WeaponDespawn) == true)
	{
		if(IsValidEdict(entity) && IsValidEntity(entity))
		{
			CreateTimer(0.5, KillEntity, EntIndexToEntRef(entity));
		}
	}
}

public Action:KillEntity(Handle:timer, any:ref)
{
	// anti-weapon spam
	new ent = EntRefToEntIndex(ref);
	if(IsValidEdict(ent) && IsValidEntity(ent))
	{
		decl String:entClassname[128];
		GetEdictClassname(ent, entClassname, sizeof(entClassname));
		if(StrContains(entClassname, "weapon_") != -1 || StrContains(entClassname, "item_") != -1)
		{
			new m_hOwnerEntity = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
			if(m_hOwnerEntity == -1)
				AcceptEntityInput(ent, "Kill");
		}
	}
}

public Action:Event_PlayerSpawn_Post(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// no block
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);

	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Ents are recreated every round.
	g_iNumSounds = 0;

	// Find all ambient sounds played by the map.
	decl String:sSound[PLATFORM_MAX_PATH];
	new entity = INVALID_ENT_REFERENCE;

	while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
	{
		GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));

		new len = strlen(sSound);
		if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
		{
			g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
		}
	}
}

// drop any weapon
public Action:DropItem(client, const String:command[], argc)
{
	new weaponIndex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	// Allow ghosts to drop all weapons and allow players if the cvar allows them to
	if(GetConVarBool(g_hAllowKnifeDrop) || IsFakeClient(client))
	{
		if(IsValidEdict(weaponIndex) && weaponIndex != -1){
			SDKHooks_DropWeapon(client, weaponIndex);
			AcceptEntityInput(weaponIndex, "KillHierarchy");
			AcceptEntityInput(weaponIndex, "Kill");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

// kill weapon and weapon attachments on drop
public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
	if(weaponIndex != -1)
	{
		AcceptEntityInput(weaponIndex, "KillHierarchy");
		AcceptEntityInput(weaponIndex, "Kill");
	}
}

// Tells a player who is spectating them
public Action:SM_Specinfo(client, args)
{
	if(IsPlayerAlive(client))
	{
		ShowSpecinfo(client, client);
	}
	else
	{
		new Target       = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if((0 < Target <= MaxClients) && (ObserverMode == 4 || ObserverMode == 5))
		{
			ShowSpecinfo(client, Target);
		}
		else
		{
			PrintColorText(client, "%s%sYou are not spectating anyone.",
				g_msg_start,
				g_msg_textcol);
		}
	}

	return Plugin_Handled;
}

ShowSpecinfo(client, target)
{
	decl String:sNames[MaxClients + 1][MAX_NAME_LENGTH];
	new index = 0;
	new bool:bClientHasAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic, Access_Effective);

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && target != i)
		{
			if(!bClientHasAdmin && GetAdminFlag(GetUserAdmin(i), Admin_Generic, Access_Effective))
			{
				continue;
			}

			if(!IsPlayerAlive(i))
			{
				new iTarget 	 = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
				new ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

				if((ObserverMode == 4 || ObserverMode == 5) && (iTarget == target))
				{
					GetClientName(i, sNames[index], MAX_NAME_LENGTH);
					index++;
				}
			}
		}
	}

	decl String:sTarget[MAX_NAME_LENGTH];
	GetClientName(target, sTarget, sizeof(sTarget));

	if(index != 0)
	{
		decl String:sString[1024];
		Format(sString, sizeof(sString), "%s%s%s%s has %d spectators: ", g_msg_start, g_msg_varcol, sTarget, g_msg_textcol, index);
		for(new i = 0; i < index; i++){
			if(index == i)
				Format(sString, sizeof(sString), "%s%s%s%s.", sString, g_msg_varcol, sNames[i], g_msg_textcol);
			else
				Format(sString, sizeof(sString), "%s%s%s%s, ", sString, g_msg_varcol, sNames[i], g_msg_textcol);
		}
		PrintColorText(client, "%s", sString);
	}
	else
	{
		PrintColorText(client, "%s%s%s%s has no spectators.",
			g_msg_start,
			g_msg_varcol,
			sTarget,
			g_msg_textcol);
	}
}

public Menu_SpecInfo(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
}

// Hide other players
public Action:SM_Hide(client, args)
{
	SetClientSettings(client, GetClientSettings(client) ^ HIDE_PLAYERS);

	if(g_Settings[client] & HIDE_PLAYERS)
	{
		PrintColorText(client, "%s%sPlayers are now %sinvisible",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol);
	}
	else
	{
		PrintColorText(client, "%s%sPlayers are now %svisible",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol);
	}

	return Plugin_Handled;
}

// Spectate command
public Action:SM_Spec(client, args)
{
	StopTimer(client);
	ForcePlayerSuicide(client);
	ChangeClientTeam(client, 1);
	if(args != 0)
	{
		decl String:arg[128];
		GetCmdArgString(arg, sizeof(arg));
		new target = FindTarget(client, arg, true, false);
		if(target != -1)
		{
			if(client != target)
			{
				if(IsPlayerAlive(target))
				{
					SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", target);
				}
				else
				{
					decl String:name[MAX_NAME_LENGTH];
					GetClientName(target, name, sizeof(name));
					PrintColorText(client, "%s%s%s %sis not alive.",
						g_msg_start,
						g_msg_varcol,
						name,
						g_msg_textcol);
				}
			}
			else
			{
				PrintColorText(client, "%s%sYou can't spectate yourself.",
					g_msg_start,
					g_msg_textcol);
			}
		}
	}
	return Plugin_Handled;
}

// Move stuck players
public Action:SM_Move(client, args)
{
	if(args != 0)
	{
		decl String:name[MAX_NAME_LENGTH];
		GetCmdArgString(name, sizeof(name));

		new Target = FindTarget(client, name, true, false);

		if(Target != -1)
		{
			new Float:angles[3], Float:pos[3];
			GetClientEyeAngles(Target, angles);
			GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
			GetEntPropVector(Target, Prop_Send, "m_vecOrigin", pos);

			for(new i=0; i<3; i++)
				pos[i] += (angles[i] * 50);

			TeleportEntity(Target, pos, NULL_VECTOR, NULL_VECTOR);

			LogMessage("%L moved %L", client, Target);
		}
	}
	else
	{
		PrintToChat(client, "[SM] Usage: sm_move <target>");
	}

	return Plugin_Handled;
}

// Punish players
public Action:SM_Hudfuck(client, args)
{
	decl String:arg[250];
	GetCmdArgString(arg, sizeof(arg));

	new target = FindTarget(client, arg, false, false);

	if(target != -1)
	{
		SetEntProp(target, Prop_Send, "m_iHideHUD", HUD_FUCK);

		decl String:targetname[MAX_NAME_LENGTH];
		GetClientName(target, targetname, sizeof(targetname));
		PrintColorTextAll("%s%s%s %shas been HUD-FUCKED for their negative actions",
			g_msg_start,
			g_msg_varcol,
			targetname,
			g_msg_textcol);

		// Log the hudfuck event
		LogMessage("%L executed sm_hudfuck command on %L", client, target);
	}
	else
	{
		new Handle:menu = CreateMenu(Menu_HudFuck);
		SetMenuTitle(menu, "Select player to HUD FUCK");

		decl String:sAuth[32], String:sDisplay[64], String:sInfo[8];
		for(new iTarget = 1; iTarget <= MaxClients; iTarget++)
		{
			if(IsClientInGame(iTarget))
			{
				GetClientAuthId(iTarget, AuthId_Steam2, sAuth, sizeof(sAuth));
				Format(sDisplay, sizeof(sDisplay), "%N <%s>", iTarget, sAuth);
				IntToString(GetClientUserId(iTarget), sInfo, sizeof(sInfo));
				AddMenuItem(menu, sInfo, sDisplay);
			}
		}

		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public Menu_HudFuck(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));

		new target = GetClientOfUserId(StringToInt(info));
		if(target != 0)
		{
			PrintColorTextAll("%s%s%N %shas been HUD-FUCKED for their negative actions",
				g_msg_start,
				g_msg_varcol,
				target,
				g_msg_textcol);
			SetEntProp(target, Prop_Send, "m_iHideHUD", HUD_FUCK);

			// Log the hudfuck event
			LogMessage("%L executed sm_hudfuck command on %L", param1, target);
		}
		else
		{
			PrintColorText(param1, "%s%sTarget not in game",
				g_msg_start,
				g_msg_textcol);
		}
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

// Display current map session time
public Action:SM_Maptime(client, args)
{
	new Float:mapTime = GetEngineTime() - g_fMapStart;
	new hours, minutes, seconds;
	hours    = RoundToFloor(mapTime/3600);
	mapTime -= (hours * 3600);
	minutes  = RoundToFloor(mapTime/60);
	mapTime -= (minutes * 60);
	seconds  = RoundToFloor(mapTime);

	PrintColorText(client, "%s%sCurrent map has been on for: %s%d%s %s, %s%d%s %s, %s%d%s %s",
		g_msg_start,
		g_msg_textcol,
		g_msg_varcol,
		hours,
		g_msg_textcol,
		(hours==1)?"hour":"hours",
		g_msg_varcol,
		minutes,
		g_msg_textcol,
		(minutes==1)?"minute":"minutes",
		g_msg_varcol,
		seconds,
		g_msg_textcol,
		(seconds==1)?"second":"seconds");
}

// Open sound control menu
public Action:SM_Sound(client, args)
{
	new Handle:menu = CreateMenu(Menu_StopSound);
	SetMenuTitle(menu, "Control Sounds");

	decl String:sInfo[16];
	IntToString(STOP_DOORS, sInfo, sizeof(sInfo));
	AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_DOORS)?"Door sounds: Off":"Door sounds: On");

	IntToString(STOP_GUNS, sInfo, sizeof(sInfo));
	AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_GUNS)?"Gun sounds: Off":"Gun sounds: On");

	IntToString(STOP_MUSIC, sInfo, sizeof(sInfo));
	AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_MUSIC)?"Music: Off":"Music: On");

	IntToString(STOP_RECSND, sInfo, sizeof(sInfo));
	AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_RECSND)?"WR sound: Off":"WR sound: On");

	IntToString(STOP_RECSND, sInfo, sizeof(sInfo));
	AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_PBSND)?"Personal best sound: Off":"Personal best sound: On");

	IntToString(STOP_RECSND, sInfo, sizeof(sInfo));
	AddMenuItem(menu, sInfo, (g_Settings[client] & STOP_FAILSND)?"No new time sound: Off":"No new time sound: On");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Menu_StopSound(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));

		new setting = StringToInt(info);
		SetClientSettings(param1, GetClientSettings(param1) ^ setting);

		if(setting == STOP_GUNS)
			CheckHooks();

		if(setting == STOP_MUSIC && (g_Settings[param1] & STOP_MUSIC))
		{
			new ientity, String:sSound[128];
			for (new i = 0; i < g_iNumSounds; i++)
			{
				ientity = EntRefToEntIndex(g_iSoundEnts[i]);

				if (ientity != INVALID_ENT_REFERENCE)
				{
					GetEntPropString(ientity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
					EmitSoundToClient(param1, sSound, ientity, SNDCHAN_STATIC, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
				}
			}
		}

		FakeClientCommand(param1, "sm_sound");
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:SM_Speed(client, args)
{
	if(args == 1)
	{
		// Get the specified speed
		decl String:sArg[250];
		GetCmdArgString(sArg, sizeof(sArg));

		new Float:fSpeed = StringToFloat(sArg);

		// Check if the speed value is in a valid range
		if(!(0 <= fSpeed <= 100))
		{
			PrintColorText(client, "%s%sYour speed must be between 0 and 100",
				g_msg_start,
				g_msg_textcol);
			return Plugin_Handled;
		}

		StopTimer(client);

		// Set the speed
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);

		// Notify them
		PrintColorText(client, "%s%sSpeed changed to %s%f%s%s",
			g_msg_start,
			g_msg_textcol,
			g_msg_varcol,
			fSpeed,
			g_msg_textcol,
			(fSpeed != 1.0)?" (Default is 1)":" (Default)");
	}
	else
	{
		// Show how to use the command
		PrintColorText(client, "%s%sExample: sm_speed 2.0",
			g_msg_start,
			g_msg_textcol);
	}

	return Plugin_Handled;
}

public Action:SM_Fast(client, args)
{
	StopTimer(client);

	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 2.0);

	return Plugin_Handled;
}

public Action:SM_Slow(client, args)
{
	StopTimer(client);

	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.5);

	return Plugin_Handled;
}

public Action:SM_Normalspeed(client, args)
{
	StopTimer(client);

	// Set the speed
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

	return Plugin_Handled;
}

public Action:SM_Lowgrav(client, args)
{
	StopTimer(client);

	SetEntityGravity(client, 0.6);

	PrintColorText(client, "%s%sUsing low gravity. Use !normalgrav to switch back to normal gravity.",
		g_msg_start,
		g_msg_textcol);
}

public Action:SM_Normalgrav(client, args)
{
	SetEntityGravity(client, 0.0);

	PrintColorText(client, "%s%sUsing normal gravity.",
		g_msg_start,
		g_msg_textcol);
}

public Action:Hook_SetTransmit(entity, client)
{
	if(client != entity && (0 < entity <= MaxClients) && IsPlayerAlive(client)){
		if(g_Settings[client] & HIDE_PLAYERS)
			return Plugin_Handled;
		if(GetEntityMoveType(entity) == MOVETYPE_NOCLIP && !IsFakeClient(entity))
			return Plugin_Handled;

		if(!IsPlayerAlive(entity))
			return Plugin_Handled;
	}
	if(client != entity && (IsFakeClient(entity) || IsFakeClient(client)) && IsPlayerAlive(client))
		return Plugin_Handled;

	return Plugin_Continue;
}

// get a player's settings
public Native_GetClientSettings(Handle:plugin, numParams)
{
	return g_Settings[GetNativeCell(1)];
}

// set a player's settings
public Native_SetClientSettings(Handle:plugin, numParams)
{
	new client         = GetNativeCell(1);
	g_Settings[client] = GetNativeCell(2);

	if(AreClientCookiesCached(client))
	{
		decl String:sSettings[16];
		IntToString(g_Settings[client], sSettings, sizeof(sSettings));
		SetClientCookie(client, g_hSettingsCookie, sSettings);
	}
}


// fix damage
public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{

	damage = 0.0;

	return Plugin_Changed;
}

public Action:SM_FlashLight(client, args){
	if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client) && !IsSpamming(client)){
		SetIsSpamming(client, 0.5);
		SetEntProp(client, Prop_Send, "m_fEffects", GetEntProp(client, Prop_Send, "m_fEffects") ^ 4);
	}

	return Plugin_Handled;
}

public Action:SM_SelectRandom(client, args){
	new target = SelectRandomPlayer();

	PrintColorTextAll("%sSelecting random player...", g_msg_textcol);
	PrintColorTextAll("%s-> %s%N%s is the recipient.", g_msg_textcol, g_msg_varcol, target, g_msg_textcol);

	return Plugin_Handled;
}

stock int SelectRandomPlayer(int Team = -2001){
	int[] Players = new int[MaxClients + 1];
	int PlayersNum = 0;

	for (int i = 1; i <= MaxClients; i++){
		if (IsClientInGame(i) && !IsClientSourceTV(i) && !IsFakeClient(i)){
			if(Team == -2001 || (Team != -2001 && GetClientTeam(i) == Team)){
				Players[PlayersNum] = i;
				PlayersNum++;
			}
		}
	}


	return (PlayersNum != 0) ? Players[GetRandomInt(0, PlayersNum - 1)] : -1;
}
