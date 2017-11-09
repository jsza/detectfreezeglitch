#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#define REFIRE_DELAY 56

Handle g_freezeFoward;
ConVar g_Cvar_Debug;
bool   g_Debug = false;

float TICK_INTERVAL;
int clientLastActive[MAXPLAYERS+1];
float clientPos[MAXPLAYERS+1][20];
int lastReportTick[MAXPLAYERS+1];
int lastFiredRocket[MAXPLAYERS+1];
bool clientFrozen[MAXPLAYERS+1];
int clientRefireDelay[MAXPLAYERS+1];
int index = 0;

public Plugin myinfo =
{
	name = "detectfreezeglitch",
	author = "Larry",
	description = "",
	version = "1.0.2",
	url = "http://steamcommunity.com/id/pancakelarry"
};

public OnPluginStart()
{
	TICK_INTERVAL = GetTickInterval();
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
	}
	lastReportTick[client] = 0;
	clientFrozen[client] = false;
	clientRefireDelay[client] = 0;
	clientLastActive[client] = 0;
	lastFiredRocket[client] = 0;
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "tf_projectile_rocket"))
	{
		SDKHook(entity, SDKHook_Spawn, OnRocketFired);
	}
}

// this fires twice for each rocket spawned, but it seems to cause no problems
public OnRocketFired(entity)
{
	new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(owner < 1 || owner > MaxClients)
		return;
	lastFiredRocket[owner] = GetGameTickCount();
	// reset this here so we're not blocking clients that haven't frozen
	// recently
	clientRefireDelay[owner] = 0;
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

		// get index 5 frames ago
		int oldIndex = index - 5;
		if (oldIndex < 0)
			oldIndex += 19;

		int frameLastActive = GetGameTickCount() - clientLastActive[i];

		float vecPos[3], vecVel[3];
		GetEntPropVector(i, Prop_Data, "m_vecAbsOrigin", vecPos);
		GetEntPropVector(i, Prop_Data, "m_vecVelocity", vecVel);
		clientPos[i][index] = vecPos[2];

		if(frameLastActive >= 5
			&& clientPos[i][index] == clientPos[i][oldIndex])
		{
			if (!clientFrozen[i]) {
				int lastFired = GetGameTickCount() - lastFiredRocket[i];

				if (g_Debug) {
					char name[32];
					GetClientName(i, name, sizeof(name));
					PrintToServer("Freezeglitch started by %s at tick %d", name, GetGameTickCount());
				}

				if (lastFired <= REFIRE_DELAY)
					clientRefireDelay[i] = REFIRE_DELAY - lastFired;

				FireFreezeGlitch(i, GetGameTickCount());
			}
			clientFrozen[i] = true;
			clientRefireDelay[i] += 1;
		}
		else if (clientFrozen[i])
		{
			int delayAdded = lastFiredRocket[i] + clientRefireDelay[i] - GetGameTickCount();
			if (delayAdded >= 0) {
				if (g_Debug) {
					char name[32];
					GetClientName(i, name, sizeof(name));
					PrintToServer("Freezeglitch ended by %s at tick %d", name, GetGameTickCount());
				}
				PrintToChat(
					i, "Detected a freezeglitch and added %.3f sec to refire delay.",
					float(delayAdded) * TICK_INTERVAL);
			}
			clientFrozen[i] = false;
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
	int tick = GetGameTickCount();
	clientLastActive[client] = tick;

	int tickCanFire = lastFiredRocket[client] + clientRefireDelay[client];

	if (tick >= tickCanFire) {
		return Plugin_Continue;
	}

	if (buttons & IN_ATTACK) {
		buttons &= ~IN_ATTACK;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}
