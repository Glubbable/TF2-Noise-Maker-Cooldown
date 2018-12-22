#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#define PLUGIN_VERSION	"1.0"
#define PLUGIN_DESC	"Prevents players from spamming noise makers."
#define PLUGIN_NAME	"[TF2] Noise Maker Cooldown"
#define PLUGIN_AUTH	"Glubbable"
#define PLUGIN_URL	"https://steamcommunity.com/groups/GlubsServers"

#define TFAttribute_NoiseMaker 196

public const Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTH,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL,
};

ConVar g_cvNMEnable;
ConVar g_cvNMCooldown;
ConVar g_cvNMTeam;

bool g_bClientHasNoiseMaker[MAXPLAYERS + 1];
float g_flNoiseMakerCooldown[MAXPLAYERS + 1];
Handle g_hActionSlotCheckTimer[MAXPLAYERS + 1];

bool g_bEnable;
float g_flCoolDown;
TFTeam g_tfTeam;

public void OnPluginStart()
{
	g_cvNMEnable = CreateConVar("sm_noisemaker_cooldown_enable", "1", "Enables/Disables Noise Maker Cooldown", _, true, _, true, 1.0);
	g_cvNMCooldown = CreateConVar("sm_noisemaker_cooldown", "5.0", "How long a cooldown on a noise maker should last for.", _, true);
	g_cvNMTeam = CreateConVar("sm_noisemaker_cooldown_team", "0","Determins if the cooldown applies to all or just one team.", _, true, _, true, 2.0);
	
	g_cvNMEnable.AddChangeHook(Hook_OnCvarChange);
	g_cvNMCooldown.AddChangeHook(Hook_OnCvarChange);
	g_cvNMTeam.AddChangeHook(Hook_OnCvarChange);
	
	g_bEnable = g_cvNMEnable.BoolValue;
	g_flCoolDown = g_cvNMCooldown.FloatValue;
	g_tfTeam = view_as<TFTeam>(g_cvNMTeam.IntValue + 1);
	
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	
	ProcessLateLoad();
}

void ProcessLateLoad()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient)) continue;
		
		CheckClientActionSlot(iClient);
	}
}

public void OnClientPutInServer(int iClient)
{
	ClearClientData(iClient);
}

public void OnClientDisconnect(int iClient)
{
	ClearClientData(iClient);
}

void ClearClientData(int iClient)
{
	g_bClientHasNoiseMaker[iClient] = false;
	g_flNoiseMakerCooldown[iClient] = 0.0;
}

public void Hook_OnCvarChange(ConVar cvConVar, const char[] sOldValue, const char[] sNewValue)
{
	if (strcmp(sOldValue, sNewValue) == 0) return;
	
	if (cvConVar == g_cvNMEnable)
	{
		g_bEnable = cvConVar.BoolValue;		
	}
	else if (cvConVar == g_cvNMCooldown)
	{
		g_flCoolDown = cvConVar.FloatValue;
	}
	else if (cvConVar == g_cvNMTeam)
	{
		g_tfTeam = view_as<TFTeam>(cvConVar.IntValue + 1);
	}
}

public Action OnClientCommandKeyValues(int iClient, KeyValues hKeyValue)
{
	if (!g_bEnable || g_flCoolDown <= 0.0) return Plugin_Continue;
	
	char sName[64];
	hKeyValue.GetSectionName(sName, sizeof(sName));
	if (strcmp(sName, "use_action_slot_item_server") == 0)
	{
		if (g_bClientHasNoiseMaker[iClient])
		{
			float flGameTime = GetGameTime();
			if (g_flNoiseMakerCooldown[iClient] > flGameTime)
			{
				if (g_tfTeam != TFTeam_Spectator)
				{
					if (TF2_GetClientTeam(iClient) == g_tfTeam)
						return Plugin_Handled;
					
					return Plugin_Continue;
				}

				return Plugin_Handled;
			}
			else
			{
				g_flNoiseMakerCooldown[iClient] = flGameTime + g_flCoolDown;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Event_PostInventoryApplication(Event eEvent, const char[] sName, bool bDB)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (iClient)
	{
		CheckClientActionSlot(iClient);
	}
}

void CheckClientActionSlot(int iClient, float flTime = 0.5)
{
	g_hActionSlotCheckTimer[iClient] = CreateTimer(flTime, Timer_CheckActionSlot, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckActionSlot(Handle hTimer, int iUserid)
{
	int iClient = GetClientOfUserId(iUserid);
	if (!iClient || iClient > MaxClients) return Plugin_Stop;
	if (g_hActionSlotCheckTimer[iClient] != hTimer) return Plugin_Stop;
	
	int iItem = TF2_FindNoiseMaker(iClient);
	g_bClientHasNoiseMaker[iClient] = (iItem > MaxClients) ? true : false;
	
	return Plugin_Stop;
}

stock int TF2_FindNoiseMaker(int iClient)
{
	int iEntity = MaxClients + 1;
	while ((iEntity = FindEntityByClassname(iEntity, "tf_wearable")) > MaxClients)
	{
		if (GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			if (TF2_WeaponFindAttribute(iEntity, TFAttribute_NoiseMaker) > 0.0)
			{
				return iEntity;
			}
		}
	}
	
	return -1;
}

stock float TF2_WeaponFindAttribute(int iWeapon, int iAttrib)
{
	Address addAttrib = TF2Attrib_GetByDefIndex(iWeapon, iAttrib);
	if (addAttrib == Address_Null)
	{
		int iItemDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		int iAttributes[16];
		float flAttribValues[16];
		
		int iMaxAttrib = TF2Attrib_GetStaticAttribs(iItemDefIndex, iAttributes, flAttribValues);
		for (int i = 0; i < iMaxAttrib; i++)
		{
			if (iAttributes[i] == iAttrib)
			{
				return flAttribValues[i];
			}
		}
		
		return 0.0;
	}
	
	return TF2Attrib_GetValue(addAttrib);
}