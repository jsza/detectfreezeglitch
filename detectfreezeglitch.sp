#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

Handle g_freezeFoward;
ConVar g_Cvar_Debug;
bool   g_Debug = false;

int clientLastActive[MAXPLAYERS+1];
float clientPos[MAXPLAYERS+1][20];
int lastReportTick[MAXPLAYERS+1];
int index = 0;

public Plugin myinfo =
{
	name = "detectfreezeglitch",
	author = "Larry",
	description = "",
	version = "1.0.0",
	url = "http://steamcommunity.com/id/pancakelarry"
};

public OnPluginStart()
{
	g_freezeFoward = CreateGlobalForward("OnClientFreezeGlitch", ET_Event, Param_Cell, Param_Cell);
	g_Cvar_Debug = CreateConVar("sm_detectfreezeglitch_debug", "0", "Print debug message upon detection");
	g_Cvar_Debug.AddChangeHook(OnDebugChanged);
}

void OnDebugChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_Debug = convar.BoolValue;
}

public OnClientDisconnect(int client)
{
	for(int i = 0; i < 19; i++)
	{
		clientPos[client][i] = 0.0;
		clientLastActive[client] = 0;
	}
	lastReportTick[client] = 0;
}

public OnGameFrame()
{
	for(int i = 1; i <= MaxClients; i++)
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

		int frameLastActive = GetGameTickCount() - clientLastActive[i];

		float vecPos[3], vecVel[3];
		GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", vecPos);
		GetEntPropVector(i, Prop_Data, "m_vecVelocity", vecVel);
		clientPos[i][index] = vecPos[2];

		int waterLevel = GetEntProp(i, Prop_Data, "m_nWaterLevel");

		if(waterLevel < 2
			&& !(GetEntityFlags(i) & FL_ONGROUND)
			&& !(GetEntityMoveType(i) & MOVETYPE_LADDER)
			&& clientPos[i][index] == clientPos[i][oldIndex]
			&& frameLastActive >= 18
			&& vecVel[2] != 0 && GetGameTickCount() - lastReportTick[i] > 66)
		{
			lastReportTick[i] = GetGameTickCount();
			FireFreezeGlitch(i, GetGameTickCount());

			if (g_Debug) {
				char name[32];
				GetClientName(i, name, sizeof(name));
				PrintToServer("Detected possible freezeglitch by %s at tick %d", name, GetGameTickCount());
			}
		}
	}
}


FireFreezeGlitch(client, tick)
{
	Action result;
	Call_StartForward(g_freezeFoward);
	Call_PushCell(client);
	Call_PushCell(tick);
	Call_Finish(result);
}


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	clientLastActive[client] = GetGameTickCount();
}
