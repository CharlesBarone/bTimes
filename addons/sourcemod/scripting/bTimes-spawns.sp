#include <sourcemod>
#include <sdktools>

new Handle:g_hTSpawns = INVALID_HANDLE;
new Handle:g_hCTSpawns = INVALID_HANDLE;

new g_icvarTSpawns;
new g_icvarCTSpawns;

new bool:g_bMapStart;

public Plugin myinfo = 
{
	name = "[bTimes] Spawns",
	description = "Auto add spawn points",
    author = "Charles_(hypnos), (original by gamemann modified for bTimes)",
	version = "1.9.0",
	url = ""
}

public OnPluginStart()
{
	g_hTSpawns = CreateConVar("sm_ESP_spawns_t", "32", "Amount of spawn points to enforce on the T team.");
	g_hCTSpawns = CreateConVar("sm_ESP_spawns_ct", "32", "Amount of spawn points to enforce on the CT team.");
	
	HookConVarChange(g_hTSpawns, CVarChanged);
	HookConVarChange(g_hCTSpawns, CVarChanged);

	GetValues();
	g_bMapStart = false;

	AutoExecConfig(true, "spawns", "timer");
}

public CVarChanged(Handle:hCVar, const String:sOldV[], const String:sNewV[])
{
	OnConfigsExecuted();
}

public Action:timer_DelayAddSpawnPoints(Handle:hTimer) 
{
	AddMapSpawns();
}

public OnConfigsExecuted() 
{
	GetValues();
	
	if (!g_bMapStart) 
	{
		CreateTimer(1.0, timer_DelayAddSpawnPoints);
		g_bMapStart = true;
	}
	
	if (g_bMapStart) 
	{
		AddMapSpawns();
	}
}

stock GetValues() 
{
	g_icvarTSpawns = GetConVarInt(g_hTSpawns);
	g_icvarCTSpawns = GetConVarInt(g_hCTSpawns);
}

stock AddMapSpawns() 
{
	new iTSpawns = 0;
	new iCTSpawns = 0;
	
	new Float:fVecCt[3];
	new Float:fVecT[3];
	new Float:angVec[3];
	decl String:sClassName[64];
	
	for (new i = MaxClients; i < GetMaxEntities(); i++)
	{
		if (IsValidEdict(i) && IsValidEntity(i) && GetEdictClassname(i, sClassName, sizeof(sClassName)))
		{
			if (StrEqual(sClassName, "info_player_terrorist"))
			{
				iTSpawns++;
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVecT);
			}
			else if (StrEqual(sClassName, "info_player_counterterrorist"))
			{
				iCTSpawns++;
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVecCt);
			}
		}
	}
	
	if(iCTSpawns < g_icvarCTSpawns)
	{
		for(new i = iCTSpawns; i < g_icvarCTSpawns; i++)
		{
			new iEnt = CreateEntityByName("info_player_counterterrorist");
			DispatchSpawn(iEnt);
			TeleportEntity(iEnt, fVecCt, angVec, NULL_VECTOR);
		}
	}
	
	if(iTSpawns < g_icvarTSpawns)
	{
		for(new i = iTSpawns; i < g_icvarTSpawns; i++)
		{
			new iEnt = CreateEntityByName("info_player_terrorist");
			DispatchSpawn(iEnt);
			TeleportEntity(iEnt, fVecT, angVec, NULL_VECTOR);
		}
	}
	
}