#pragma semicolon 1 

#include <sourcemod> 
#include <sdktools>
#include <tf2_stocks>

float clientPos[MAXPLAYERS][20];
float lastReportTime[MAXPLAYERS];
int index = 0;

public Plugin myinfo = 
{ 
    name = "detectfreezeglitch", 
    author = "Larry", 
    description = "", 
    version = "1.0.0", 
    url = "http://steamcommunity.com/id/pancakelarry" 
}; 

public OnClientDisconnect(int client)
{
	for(int i = 0; i < 19; i++)
	{
		clientPos[client][i] = 0.0;
	}
	lastReportTime[client] = 0.0;
}

public OnGameFrame()
{
	for(int i = 1; i < MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		if(TF2_GetClientTeam(i) == TFTeam_Spectator || TF2_GetClientTeam(i) == TFTeam_Unassigned || !(TF2_GetPlayerClass(i) == TFClass_Soldier || TF2_GetPlayerClass(i) == TFClass_DemoMan) || GetEntityMoveType(i) == MOVETYPE_NOCLIP || !IsPlayerAlive(i))
			continue;

		if(index < 19)
			index++;
		else
			index = 0;

		// get index 18 frames ago
		int oldIndex = index - 18;
		if (oldIndex < 0)
			oldIndex += 19;

		float vecPos[3], vecVel[3];
		GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", vecPos);
		GetEntPropVector(i, Prop_Data, "m_vecVelocity", vecVel);
		clientPos[i][index] = vecPos[2];

		int waterLevel = GetEntProp(i, Prop_Data, "m_nWaterLevel");

		if(waterLevel < 2 && !(GetEntityFlags(i) & FL_ONGROUND) && !(GetEntityMoveType(i) & MOVETYPE_LADDER) && clientPos[i][index] == clientPos[i][oldIndex] && vecVel[2] != 0 && GetGameTime() - lastReportTime[i] > 1)
		{
			lastReportTime[i] = GetGameTime();
			char name[32];
			GetClientName(i, name, sizeof(name));
			PrintToServer("Detected possible freezeglitch by %s at tick %d", name, RoundToFloor(GetGameTime()*66.7));
		}
	}
}



