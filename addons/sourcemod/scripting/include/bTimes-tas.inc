#if defined _btimes_tas_included
#endinput
#endif
#define _btimes_tas_included

native bool:Timer_DrawTASMenu(client);

native Timer_GetSpeedTAS(client, bool:threeAxis, &Float:speed);

native Timer_GetTASTime(client, &Float:time);

native Timer_GetFrames(client, &Handle:frames);

public SharedPlugin __pl_btimes_tas = 
{
	name = "bTimes-tas",
	file = "bTimes-tas.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

public __pl_btimes_tas_SetNTVOptional()
{
	MarkNativeAsOptional("Timer_DrawTASMenu");
	MarkNativeAsOptional("Timer_GetSpeedTAS");
	MarkNativeAsOptional("Timer_GetTASTime");
	MarkNativeAsOptional("Timer_GetFrames");
}