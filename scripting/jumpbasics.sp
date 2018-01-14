/*

	TODO:
		* File saving system for user saves
		* Support for messages as to why regen/tele is blocked
		* Test all natives and forwards
*/


#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

#if !defined REQUIRE_PLUGIN
#define REQUIRE_PLUGIN
#endif

#if !defined AUTOLOAD_EXTENSIONS
#define AUTOLOAD_EXTENSIONS
#endif

#include <steamtools>

#define PLUGIN_VERSION "0.0.1"
#define PLUGIN_NAME "Jump Basics"
#define PLUGIN_AUTHOR "talkingmelon"

new Handle:g_hPluginEnabled;
new Handle:g_hWelcomeMsg;
new Handle:g_hCriticals;
new Handle:g_hSuperman;
new Handle:g_hSentryLevel;
new Handle:g_hCheapObjects;
new Handle:g_hAmmoCheat;
new Handle:g_hFastBuild;
new Handle:hArray_NoFuncRegen;

new Handle:g_hHealthRegenOnForward;
new Handle:g_hHealthRegenOffForward;
new Handle:g_hAmmoRegenOnForward;
new Handle:g_hAmmoRegenOffForward;
new Handle:g_hTeleportForward;
new Handle:g_hResetForward;

new bool:g_bHPRegenEnabled[MAXPLAYERS+1];
new bool:g_bAmmoRegenEnabled[MAXPLAYERS+1];
new bool:g_bTeleportsEnabled[MAXPLAYERS+1];

new bool:g_bHPRegen[MAXPLAYERS+1];
new bool:g_bAmmoRegen[MAXPLAYERS+1];

new Float:g_fOrigin[MAXPLAYERS+1][3];
new Float:g_fAngles[MAXPLAYERS+1][3];

new Float:g_ResetLoc[MAXPLAYERS+1][3];
new Float:g_ResetAng[MAXPLAYERS+1][3];


new g_iMapClass = -1;
new g_iLockCPs = 1;
new g_iCPs;

new String:g_MessagePrefix[32] = "";

#include "jumpbasics/skeys.sp"
#include "jumpbasics/sound.sp"

new Handle:waitingForPlayers;


public Plugin:myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "Basic Jump Plugin Settings.",
	version = PLUGIN_VERSION,
	url = "http://teammethane.com/"
}
public OnPluginStart()
{

	g_hPluginEnabled = CreateConVar("jb_enable", "1", "Turns JumpAssist on/off.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hFastBuild = CreateConVar("jb_fastbuild", "1", "Allows engineers near instant buildings.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hAmmoCheat = CreateConVar("jb_ammocheat", "1", "Allows engineers infinite sentrygun ammo.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hCheapObjects = CreateConVar("jb_cheapobjects", "0", "No metal cost on buildings.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hCriticals = CreateConVar("jb_crits", "0", "Allow critical hits.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hSoundBlock = CreateConVar("jb_sounds", "0", "Block pain, regenerate, and ammo pickup sounds?", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hSentryLevel = CreateConVar("jb_sglevel", "3", "Sets the default sentry level (1-3)", FCVAR_PLUGIN|FCVAR_NOTIFY);

	g_hHealthRegenOnForward = CreateGlobalForward("OnHealthRegenOn", ET_Event, Param_Cell);
	g_hHealthRegenOffForward = CreateGlobalForward("OnHealthRegenOff", ET_Event, Param_Cell);
	g_hAmmoRegenOnForward = CreateGlobalForward("OnAmmoRegenOn", ET_Event, Param_Cell);
	g_hAmmoRegenOffForward = CreateGlobalForward("OnAmmoRegenOff", ET_Event, Param_Cell);
	g_hResetForward = CreateGlobalForward("OnReset", ET_Event, Param_Cell);
	g_hTeleportForward = CreateGlobalForward("OnTeleport", ET_Event, Param_Cell, Param_Float, Param_Float, Param_Float, Param_Float, Param_Float, Param_Float);


	// Jump Assist console commands
	RegConsoleCmd("sm_r", cmdReset, "Sends you back to the beginning without deleting your save..");
	RegConsoleCmd("sm_reset", cmdReset, "Sends you back to the beginning without deleting your save..");
	RegConsoleCmd("sm_restart", cmdRestart, "Deletes your save, and sends you back to the beginning.");
	RegConsoleCmd("sm_s", cmdSave, "Saves your current position.");
	RegConsoleCmd("sm_save", cmdSave, "Saves your current position.");
	RegConsoleCmd("sm_regen", cmdToggleRegen, "Changes regeneration settings.");
	RegConsoleCmd("sm_t", cmdTele, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_ammo", cmdToggleAmmo, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_health", cmdToggleHealth, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_tele", cmdTele, "Teleports you to your current saved location.");
	RegConsoleCmd("sm_skeys", cmdGetClientKeys, "Toggle showing a clients key's.");
	RegConsoleCmd("sm_skeys_color", cmdChangeSkeysColor, "Changes the color of the text for skeys."); //cannot whether the database is configured or not
	RegConsoleCmd("sm_skeys_loc", cmdChangeSkeysLoc, "Changes the color of the text for skeys.");

	// Hooks
	HookEvent("player_team", eventPlayerChangeTeam);
	HookEvent("player_changeclass", eventPlayerChangeClass);
	HookEvent("player_spawn", eventPlayerSpawn);
	HookEvent("player_death", eventPlayerDeath);
	HookEvent("player_hurt", eventPlayerHurt);
	HookEvent("player_builtobject", eventPlayerBuiltObj);
	HookEvent("player_upgradedobject", eventPlayerUpgradedObj);
	HookEvent("teamplay_round_start", eventRoundStart);
	HookEvent("post_inventory_application", eventInventoryUpdate);


	// ConVar Hooks
	HookConVarChange(g_hFastBuild, cvarFastBuildChanged);
	HookConVarChange(g_hCheapObjects, cvarCheapObjectsChanged);
	HookConVarChange(g_hAmmoCheat, cvarAmmoCheatChanged);
	HookConVarChange(g_hSoundBlock, cvarSoundsChanged);
	HookConVarChange(g_hSentryLevel, cvarSentryLevelChanged);

	HookUserMessage(GetUserMessageId("VoiceSubtitle"), HookVoice, true);
	AddNormalSoundHook(NormalSHook:sound_hook);

	LoadTranslations("common.phrases");

	HudDisplayForward = CreateHudSynchronizer();
	HudDisplayASD = CreateHudSynchronizer();
	HudDisplayDuck = CreateHudSynchronizer();
	HudDisplayJump = CreateHudSynchronizer();

	waitingForPlayers = FindConVar("mp_waitingforplayers_time");

	hArray_NoFuncRegen = CreateArray();

	for(new i = 0; i < MAXPLAYERS+1; i++){
		if (IsValidClient(i))
		{
			g_iClientWeapons[i][0] = GetPlayerWeaponSlot(i, TFWeaponSlot_Primary);
			g_iClientWeapons[i][1] = GetPlayerWeaponSlot(i, TFWeaponSlot_Secondary);
			g_iClientWeapons[i][2] = GetPlayerWeaponSlot(i, TFWeaponSlot_Melee);
		}
		g_bHPRegenEnabled[i] = true;
		g_bAmmoRegenEnabled[i] = true;
		g_bTeleportsEnabled[i] = true;
	}


	SetAllSkeysDefaults();
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Regen_On", Native_RegenOn);
	CreateNative("AmmoRegen_On", Native_AmmoRegenOn);
	CreateNative("HealthRegen_On", Native_HealthRegenOn);
	CreateNative("Regen_Off", Native_RegenOff);
	CreateNative("AmmoRegen_Off", Native_AmmoRegenOff);
	CreateNative("HealthRegen_Off", Native_HealthRegenOff);
	CreateNative("Teleports_On", Native_TeleportsOn);
	CreateNative("Teleports_Off", Native_TeleportsOff);
	CreateNative("SetStringPrefix", Native_SetStringPrefix);
	CreateNative("SetResetLoc", Native_SetResetLoc);

	return APLRes_Success;
}


public Native_RegenOn(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bHPRegenEnabled[client] = true;
	g_bAmmoRegenEnabled[client] = true;
	return true;
}
public Native_AmmoRegenOn(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bAmmoRegenEnabled[client] = true;
	return true;
}
public Native_HealthRegenOn(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bHPRegenEnabled[client] = true;
	return true;
}
public Native_RegenOff(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bHPRegenEnabled[client] = false;
	g_bAmmoRegenEnabled[client] = false;
	return true;
}
public Native_AmmoRegenOff(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bAmmoRegenEnabled[client] = false;
	return true;
}
public Native_HealthRegenOff(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bHPRegenEnabled[client] = false;
	return true;
}
public Native_TeleportsOn(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bTeleportsEnabled[client] = true;
	return true;
}
public Native_TeleportsOff(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	if (!IsValidClient(client)) { return false; }
	g_bTeleportsEnabled[client] = false;
	return true;
}

public Native_SetStringPrefix(Handle:plugin, numparams){
	new String:prefix[256];
	GetNativeString(1, prefix, sizeof(prefix));
	Format(g_MessagePrefix, sizeof(g_MessagePrefix), "%s ", prefix);
	return true;
}

public Native_SetResetLoc(Handle:plugin, numparams){
	new client = GetNativeCell(1);
	g_ResetLoc[client][0] = GetNativeCell(2);
	g_ResetLoc[client][1] = GetNativeCell(3);
	g_ResetLoc[client][2] = GetNativeCell(4);
	g_ResetAng[client][0] = GetNativeCell(5);
	g_ResetAng[client][1] = GetNativeCell(6);
	g_ResetAng[client][2] = GetNativeCell(7);
	return true;
}






enum TFGameType {
	TFGame_Unknown,
	TFGame_CaptureTheFlag,
	TFGame_CapturePoint,
	TFGame_Payload,
	TFGame_Arena,
};

TF2_SetGameType()
{
	GameRules_SetProp("m_nGameType", 2);
}


public OnGameFrame(){
	SkeysOnGameFrame();
}

// Support for beggers bazooka
Hook_Func_regenerate()
{
	new entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_regenerate")) != INVALID_ENT_REFERENCE) {
		// Support for concmap*, and quad* maps that are imported from TFC.
		HookFunc(entity);
	}
}

HookFunc(entity)
{

	SDKUnhook(entity,SDKHook_StartTouch,OnPlayerStartTouchFuncRegenerate);
	SDKUnhook(entity,SDKHook_Touch,OnPlayerStartTouchFuncRegenerate);
	SDKUnhook(entity,SDKHook_EndTouch,OnPlayerStartTouchFuncRegenerate);


	SDKHook(entity,SDKHook_StartTouch,OnPlayerStartTouchFuncRegenerate);
	SDKHook(entity,SDKHook_Touch,OnPlayerStartTouchFuncRegenerate);
	SDKHook(entity,SDKHook_EndTouch,OnPlayerStartTouchFuncRegenerate);
}


public OnMapStart()
{
	if (GetConVarBool(g_hPluginEnabled))
	{

		SetConVarInt(waitingForPlayers, 0);

		for(new i = 0; i < MAXPLAYERS+1; i++){
			g_bHPRegenEnabled[i] = true;
			g_bAmmoRegenEnabled[i] = true;
			g_bTeleportsEnabled[i] = true;
			g_ResetLoc[i][0] = 0.0;
			g_ResetLoc[i][1] = 0.0;
			g_ResetLoc[i][2] = 0.0;
			g_ResetAng[i][0] = 0.0;
			g_ResetAng[i][1] = 0.0;
			g_ResetAng[i][2] = 0.0;
		}

		// Change game rules to CP.
		TF2_SetGameType();

		Hook_Func_regenerate();



	}
}

public OnClientDisconnect(client)
{
	if (GetConVarBool(g_hPluginEnabled))
	{
		g_bHPRegen[client] = false;
		g_bAmmoRegen[client] = false;
		g_bGetClientKeys[client] = false;

		EraseLocs(client);
	}

	SetSkeysDefaults(client);

	new idx;
	if((idx = FindValueInArray(hArray_NoFuncRegen,client)) != -1)
	{
		RemoveFromArray(hArray_NoFuncRegen,idx);
	}

}
public OnClientPutInServer(client)
{
	if (GetConVarBool(g_hPluginEnabled))
	{

		// Hook the client
		if(IsValidClient(client))
		{
			SDKHook(client, SDKHook_WeaponEquipPost, SDKHook_OnWeaponEquipPost);
		}

		g_bHPRegen[client] = false;
		g_bGetClientKeys[client] = false;
	}
}
/*****************************************************************************************************************
												Functions
*****************************************************************************************************************/



public bool:EnableAmmoRegen(client){
	if (!IsValidClient(client)) { return false; }
	if(!g_bAmmoRegenEnabled[client]) {
		PrintToChat(client, "%sAmmo regen is currently blocked", g_MessagePrefix);
		return false;
	}
	g_bAmmoRegen[client] = true;

	PrintToChat(client, "%sAmmo regen turned on", g_MessagePrefix);

	Call_StartForward(g_hAmmoRegenOnForward);
	Call_PushCell(client);
	Call_Finish();


	return true;
}
public bool:EnableHealthRegen(client){
	if (!IsValidClient(client)) { return false; }
	if(!g_bHPRegenEnabled[client]) {
		PrintToChat(client, "%sHealth regen is currently blocked", g_MessagePrefix);
		return false;
	}
	g_bHPRegen[client] = true;

	PrintToChat(client, "%sHealth regen turned on", g_MessagePrefix);

	Call_StartForward(g_hHealthRegenOnForward);
	Call_PushCell(client);
	Call_Finish();

	return true;
}
public bool:DisableAmmoRegen(client){
	if (!IsValidClient(client)) { return false; }
	g_bAmmoRegen[client] = false;

	PrintToChat(client, "%sAmmo regen turned off", g_MessagePrefix);

	Call_StartForward(g_hAmmoRegenOffForward);
	Call_PushCell(client);
	Call_Finish();

	return true;
}
public bool:DisableHealthRegen(client){
	if (!IsValidClient(client)) { return false; }
	g_bHPRegen[client] = false;

	PrintToChat(client, "%sHealth regen turned off", g_MessagePrefix);

	Call_StartForward(g_hHealthRegenOffForward);
	Call_PushCell(client);
	Call_Finish();

	return true;
}

public Action:cmdToggleRegen(client, args)
{
	if (!IsValidClient(client)) { return; }
	if(g_bHPRegen[client]){
		DisableHealthRegen(client);
		DisableAmmoRegen(client);
	}else{
		EnableHealthRegen(client);
		EnableAmmoRegen(client);
	}

}

public Action:cmdToggleAmmo(client, args)
{
	if (!IsValidClient(client)) { return; }
	if(g_bAmmoRegen[client]){
		DisableAmmoRegen(client);
	}else{
		EnableAmmoRegen(client);
	}

}

public Action:cmdToggleHealth(client, args)
{
	if (!IsValidClient(client)) { return; }
	if(g_bHPRegen[client]){
		DisableHealthRegen(client);
	}else{
		EnableHealthRegen(client);
	}

}

stock bool:IsUsingJumper(client)
{
	if (!IsValidClient(client)) { return false; }

	if (TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		if (!IsValidWeapon(g_iClientWeapons[client][0])) { return false; }
		new sol_weap = GetEntProp(g_iClientWeapons[client][0], Prop_Send, "m_iItemDefinitionIndex");
		switch (sol_weap)
		{
			case 237:
				return true;
		}
		return false;
	}

	if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
	{
		if (!IsValidWeapon(g_iClientWeapons[client][1])) { return false; }
		new dem_weap = GetEntProp(g_iClientWeapons[client][1], Prop_Send, "m_iItemDefinitionIndex");
		switch (dem_weap)
		{
			case 265:
				return true;
		}
		return false;
	}
	return false;
}

stock CheckBeggers(iClient)
{
	new iWeapon = GetPlayerWeaponSlot(iClient, 0);

	new index = FindValueInArray(hArray_NoFuncRegen,iClient);

        if (IsValidEntity(iWeapon) &&
		GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") == 730)
	{
		if(index == -1)
		{
			PushArrayCell(hArray_NoFuncRegen,iClient);
		}
	} else if(index != -1) {
		RemoveFromArray(hArray_NoFuncRegen,index);
	}
}

stock IsStringNumeric(const String:MyString[])
{
	new n=0;
	while (MyString[n] != '\0')
	{
		if (!IsCharNumeric(MyString[n]))
		{
			return false;
		}
		n++;
	}
	return true;
}


public Action:cmdReset(client, args)
{
	if (GetConVarBool(g_hPluginEnabled))
	{

		if (IsClientObserver(client))
		{
			return Plugin_Handled;
		}

		SendToStart(client);
	}
	PrintToChat(client, "%sLocation reset", g_MessagePrefix);

	Call_StartForward(g_hResetForward);
	Call_PushCell(client);
	Call_Finish();

	return Plugin_Handled;
}


public Action:cmdTele(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	if (!g_bTeleportsEnabled[client]) {
		PrintToChat(client, "%sTeleports are currently blocked", g_MessagePrefix);
		return Plugin_Handled;
	}
	Teleport(client);

	return Plugin_Handled;
}

public Action:cmdSave(client, args)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	SaveLoc(client);

	return Plugin_Handled;
}

public Action:cmdRestart(client, args)
{
	if (!IsValidClient(client) || IsClientObserver(client) || !GetConVarBool(g_hPluginEnabled))
	{
		return Plugin_Handled;
	}

	EraseLocs(client);
	SendToStart(client);

	Call_StartForward(g_hResetForward);
	Call_PushCell(client);
	Call_Finish();

	PrintToChat(client, "%sLocation reset and save wiped", g_MessagePrefix);

	return Plugin_Handled;
}

Teleport(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (!IsValidClient(client)) { return; }


	new g_iClass = int:TF2_GetPlayerClass(client);
	new g_iTeam = GetClientTeam(client);
	decl String:g_sClass[32], String:g_sTeam[32];
	new Float:g_vVelocity[3];
	g_vVelocity[0] = 0.0; g_vVelocity[1] = 0.0; g_vVelocity[2] = 0.0;

	Format(g_sClass, sizeof(g_sClass), "%s", GetClassname(g_iClass));

	if (g_iTeam == 2)
	{
		Format(g_sTeam, sizeof(g_sTeam), "Red Team");
	} else if (g_iTeam == 3)
	{
		Format(g_sTeam, sizeof(g_sTeam), "Blue Team");
	}

	if(!IsPlayerAlive(client))
		PrintToChat(client, "%sYou cannot teleport while dead", g_MessagePrefix);
	else if(g_fOrigin[client][0] == 0.0)
		PrintToChat(client, "%sYou do not have a save", g_MessagePrefix);
	else
	{
		TeleportEntity(client, g_fOrigin[client], g_fAngles[client], g_vVelocity);

		Call_StartForward(g_hTeleportForward);
		Call_PushCell(client);
		Call_PushFloat(g_fOrigin[client][0]);
		Call_PushFloat(g_fOrigin[client][1]);
		Call_PushFloat(g_fOrigin[client][2]);
		Call_PushFloat(g_fAngles[client][0]);
		Call_PushFloat(g_fAngles[client][1]);
		Call_PushFloat(g_fAngles[client][2]);
		Call_Finish();

		PrintToChat(client, "%sTeleported to save", g_MessagePrefix);

	}
}

SaveLoc(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	if(!IsPlayerAlive(client))
		PrintToChat(client, "%sYou cannot save while dead", g_MessagePrefix);
	else if(!(GetEntityFlags(client) & FL_ONGROUND))
		PrintToChat(client, "%sYou cannot save in the air", g_MessagePrefix);
	else if(GetEntProp(client, Prop_Send, "m_bDucked") == 1)
		PrintToChat(client, "%sYou cannot save while crouched", g_MessagePrefix);
	else
	{

		GetClientAbsOrigin(client, g_fOrigin[client]);
		GetClientAbsAngles(client, g_fAngles[client]);

		PrintToChat(client, "%sLocation saved", g_MessagePrefix);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){

	g_iButtons[client] = buttons; //FOR SKEYS AS WELL AS REGEN
	if ((g_iButtons[client] & IN_ATTACK) == IN_ATTACK)
	{
		if (g_bAmmoRegen[client])
		{
			ReSupply(client, g_iClientWeapons[client][0]);
			ReSupply(client, g_iClientWeapons[client][1]);
			ReSupply(client, g_iClientWeapons[client][2]);
			
			if (TF2_GetPlayerClass(client) == TFClass_Engineer){
				SetEntProp(client, Prop_Data, "m_iAmmo", 200, 4, 3);
			}
		}
		if (g_bHPRegen[client]){
			new iMaxHealth = TF2_GetPlayerResourceData(client, TFResource_MaxHealth);
			SetEntityHealth(client, iMaxHealth);
		}
	}

	return Plugin_Continue;
}



public SDKHook_OnWeaponEquipPost(client, weapon)
{
	if (IsValidClient(client))
	{
		g_iClientWeapons[client][0] = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		g_iClientWeapons[client][1] = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		g_iClientWeapons[client][2] = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	}
}

stock bool:IsValidWeapon(iEntity)
{
	decl String:strClassname[128];
	if (IsValidEntity(iEntity) && GetEntityClassname(iEntity, strClassname, sizeof(strClassname)) && StrContains(strClassname, "tf_weapon", false) != -1) return true;
	return false;
}

stock ReSupply(iClient, iWeapon)
{
	if (!GetConVarBool(g_hPluginEnabled)) return;
	if (!IsValidWeapon(iWeapon)) return;
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient)) return;	//Check if the client is valid and alive
	
	int iWepIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");	//Grab the weapon index
	char szClassname[128];
	GetEntityClassname(iWeapon, szClassname, sizeof(szClassname));				//Grab the weapon's classname
	
	//Rocket Launchers
	if (!StrContains(szClassname, "tf_weapon_rocketlauncher") || !StrContains(szClassname, "tf_weapon_particle_cannon")) //Check for Rocket Launchers
	{
		switch (iWepIndex)
		{
			case 441: //The Cow Mangler 5000
			{
				SetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy", 100.0);	//Cow Mangler uses Energy instead of ammo.
			}
			case 228, 1085: //Black Box
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 3);
			}
			case 414: //Liberty Launcher
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 5);
			}
			case 730: {} //Beggar's Bazooka - This is here so we don't keep refilling its clip infinitely.
			default: //The default action for Rocket Launchers. This basically future proofs it for any new Rocket Launchers unless they have a totally different classname like the CM5K.
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 4); //Technically we don't need to make extra cases for different clip sizes, since players are constantly ReSupply()'d, but whatever.
			}
		}
		GivePlayerAmmo(iClient, 100, view_as<int>(TFWeaponSlot_Primary)+1, false); //Refill the player's ammo supply to whatever the weapon's max is.
	}
	//Grenade Launchers
	if (!StrContains(szClassname, "tf_weapon_grenadelauncher") || !StrContains(szClassname, "tf_weapon_cannon")) //Check for Stickybomb Launchers
	{
		switch (iWepIndex)
		{
			case 308: // Loch-n-Load
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 3);
			}
			default: //The default action for Grenade Launchers
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 4);
			}
		}
		GivePlayerAmmo(iClient, 100, view_as<int>(TFWeaponSlot_Primary)+1, false); //Refill the player's ammo supply to whatever the weapon's max is.
	}
	//Stickybomb Launchers
	if (!StrContains(szClassname, "tf_weapon_pipebomblauncher")) //Check for Stickybomb Launchers
	{
		switch (iWepIndex)
		{
			case 1150: //Quickiebomb Launcher
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 4);
			}
			default: //The default action for Stickybomb Launchers
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 8);
			}
		}
		GivePlayerAmmo(iClient, 100, view_as<int>(TFWeaponSlot_Secondary)+1, false); //Refill the player's ammo supply to whatever the weapon's max is.
	}
	//Shotguns
	if (!StrContains(szClassname, "tf_weapon_shotgun") || !StrContains(szClassname, "tf_weapon_sentry_revenge")) //Check for Shotguns
	{
		switch (iWepIndex)
		{
			case 425: //Family Business
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 8);
			}
			case 997, 415: //Rescue Ranger, Reserve Shooter
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 4);
			}
			case 141, 1004: //Frontier Justice
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 3);
			}
			case 527: //Widowmaker
			{
				SetEntProp(iClient, Prop_Data, "m_iAmmo", 200, _, 3); //Sets Metal count to 200
			}
			default: //The default action for Shotguns
			{
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 6);
			}
		}
		if (TF2_GetPlayerClass(iClient) == TFClass_Engineer)
			GivePlayerAmmo(iClient, 100, view_as<int>(TFWeaponSlot_Primary)+1, false); //Refill the player's ammo supply to whatever the weapon's max is.
		else
			GivePlayerAmmo(iClient, 100, view_as<int>(TFWeaponSlot_Secondary)+1, false); //Refill the player's ammo supply to whatever the weapon's max is.
	}
	// Ullapool caber
	if (!StrContains(szClassname, "tf_weapon_stickbomb"))
	{
		SetEntProp(iWeapon, Prop_Send, "m_bBroken", 0);
		SetEntProp(iWeapon, Prop_Send, "m_iDetonated", 0);
	}
}
stock SetAmmo(client, iWeapon, iAmmo)
{
	new iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if(iAmmoType != -1) SetEntProp(client, Prop_Data, "m_iAmmo", iAmmo, _, iAmmoType);
}

EraseLocs(client)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	g_fOrigin[client][0] = 0.0; g_fOrigin[client][1] = 0.0; g_fOrigin[client][2] = 0.0;
	g_fAngles[client][0] = 0.0; g_fAngles[client][1] = 0.0; g_fAngles[client][2] = 0.0;

}


LockCPs()
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new iCP = -1;
	g_iCPs = 0;
	while ((iCP = FindEntityByClassname(iCP, "trigger_capture_area")) != -1)
	{
		SetVariantString("2 0");
		AcceptEntityInput(iCP, "SetTeamCanCap");
		SetVariantString("3 0");
		AcceptEntityInput(iCP, "SetTeamCanCap");
		g_iCPs++;
	}
}


SendToStart(client)
{
	if (!IsValidClient(client) || IsClientObserver(client) || !GetConVarBool(g_hPluginEnabled))
	{
		return;
	}

	if(g_ResetLoc[client][0] == 0.0){
		TF2_RespawnPlayer(client);
	} else {
		new Float:g_vVelocity[3];
		TeleportEntity(client, g_ResetLoc[client], g_ResetAng[client], g_vVelocity);
	}

}

stock String:GetClassname(class)
{
	new String:buffer[128];
	switch(class)
	{
		case 1:	{ Format(buffer, sizeof(buffer), "Scout"); }
		case 2: { Format(buffer, sizeof(buffer), "Sniper"); }
		case 3: { Format(buffer, sizeof(buffer), "Soldier"); }
		case 4: { Format(buffer, sizeof(buffer), "Demoman"); }
		case 5: { Format(buffer, sizeof(buffer), "Medic"); }
		case 6: { Format(buffer, sizeof(buffer), "Heavy"); }
		case 7: { Format(buffer, sizeof(buffer), "Pyro"); }
		case 8: { Format(buffer, sizeof(buffer), "Spy"); }
		case 9: { Format(buffer, sizeof(buffer), "Engineer"); }
	}
	return buffer;
}

bool:IsValidClient( client )
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) || IsFakeClient(client))
        return false;

    return true;
}

stock FindTarget2(client, const String:target[], bool:nobots = false, bool:immunity = true)
{
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[1], target_count, bool:tn_is_ml;

	new flags = COMMAND_FILTER_NO_MULTI;
	if (nobots)
	{
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if (!immunity)
	{
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}

	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			1,
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		return target_list[0];
	}
	else
	{
		if (target_count == 0) { return -1; }
		ReplyToCommand(client, "afasdf");
		return -1;
	}
}
// Ugly wtf was I thinking?
stock GetValidClassNum(String:class[])
{
	new iClass = -1;
	if(StrEqual(class,"scout", false))
	{
		iClass = 1;
		return iClass;
	}
	if(StrEqual(class,"sniper", false))
	{
		iClass = 2;
		return iClass;
	}
	if(StrEqual(class,"soldier", false))
	{
		iClass = 3;
		return iClass;
	}
	if(StrEqual(class,"demoman", false))
	{
		iClass = 4;
		return iClass;
	}
	if(StrEqual(class,"medic", false))
	{
		iClass = 5;
		return iClass;
	}
	if(StrEqual(class,"heavy", false))
	{
		iClass = 6;
		return iClass;
	}
	if(StrEqual(class,"pyro", false))
	{
		iClass = 7;
		return iClass;
	}
	if(StrEqual(class,"spy", false))
	{
		iClass = 8;
		return iClass;
	}
	if(StrEqual(class,"engineer", false))
	{
		iClass = 9;
		return iClass;
	}
	return iClass;
}

stock bool:IsUserAdmin(client)
{
	new bool:IsAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic);

	if (IsAdmin)
		return true;
	else
		return false;
}
stock SetCvarValues()
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	if (!GetConVarBool(g_hCriticals))
		SetConVarInt(FindConVar("tf_weapon_criticals"), 0, true, false);
	if (GetConVarBool(g_hFastBuild))
		SetConVarInt(FindConVar("tf_fastbuild"), 1, false, false);
	if (GetConVarBool(g_hCheapObjects))
		SetConVarInt(FindConVar("tf_cheapobjects"), 1, false, false);
	if (GetConVarBool(g_hAmmoCheat))
		SetConVarInt(FindConVar("tf_sentrygun_ammocheat"), 1, false, false);
}

/*****************************************************************************************************************
												Player Events
*****************************************************************************************************************/
public Action:OnPlayerStartTouchFuncRegenerate(entity, other)
{
	if(other <= MaxClients && GetArraySize(hArray_NoFuncRegen) > 0 && FindValueInArray(hArray_NoFuncRegen,other) != -1)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}




public Action:eventPlayerBuiltObj(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new obj = GetEventInt(event, "object"), index = GetEventInt(event, "index");

	if (obj == 2)
	{
		if (GetConVarInt(g_hSentryLevel) == 3)
		{
			SetEntData(index, FindSendPropOffs("CObjectSentrygun", "m_iUpgradeLevel"), 3, 4);
			SetEntData(index, FindSendPropOffs("CObjectSentrygun", "m_iUpgradeMetal"), 200);
		}
	}

}
public Action:eventPlayerUpgradedObj(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

}
public Action:eventRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:currentMap[32]; GetCurrentMap(currentMap, sizeof(currentMap));
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	if (g_iLockCPs == 1) { LockCPs(); }
	Hook_Func_regenerate();

	SetCvarValues();
}

public Action:eventPlayerChangeClass(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	decl String:g_sClass[MAX_NAME_LENGTH], String:steamid[32];

	EraseLocs(client);
	TF2_RespawnPlayer(client);

	GetClientAuthId(client,AuthId_Steam2, steamid, sizeof(steamid));

	new class = int:TF2_GetPlayerClass(client);
	Format(g_sClass, sizeof(g_sClass), "%s", GetClassname(g_iMapClass));

	g_iClientWeapons[client][0] = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
	g_iClientWeapons[client][1] = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	g_iClientWeapons[client][2] = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);

}

public Action:eventPlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return Plugin_Handled; }
	new client = GetClientOfUserId(GetEventInt(event, "userid")), team = GetEventInt(event, "team");


	if (team == 1)
	{

	} else {
		CreateTimer(0.1, timerTeam, client);
	}

	return Plugin_Handled;
}

public eventInventoryUpdate(Handle:hEvent, String:strName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(iClient)) return;
	CheckBeggers(iClient);
}

public Action:eventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, timerRespawn, client);
}

public Action:eventPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_bHPRegen[client])
	{
		CreateTimer(0.1, timerRegen, client);
	}
	if (g_bAmmoRegen[client])
	{
		ReSupply(client, g_iClientWeapons[client][0]);
		ReSupply(client, g_iClientWeapons[client][1]);
		ReSupply(client, g_iClientWeapons[client][2]);
	}
}

public Action:eventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetConVarBool(g_hPluginEnabled)) { return; }
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	CheckBeggers(client);

}
/*****************************************************************************************************************
												Timers
*****************************************************************************************************************/

public Action:timerTeam(Handle:timer, any:client)
{
	if (client == 0)
	{
		return;
	}
	EraseLocs(client);
	if(IsClientInGame(client)){
		//Previously forced client team change
	}
}
public Action:timerRegen(Handle:timer, any:client)
{
	if (client == 0 || !IsValidEntity(client))
	{
		return;
	}
	new iMaxHealth = TF2_GetPlayerResourceData(client, TFResource_MaxHealth);
	SetEntityHealth(client, iMaxHealth);
}
public Action:timerRespawn(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		TF2_RespawnPlayer(client);
	}
}

/*****************************************************************************************************************
											ConVars Hooks
*****************************************************************************************************************/
public cvarFastBuildChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarInt(FindConVar("tf_fastbuild"), 0);
	}
	else
	{
		SetConVarInt(FindConVar("tf_fastbuild"), 1);
	}
}
public cvarCheapObjectsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarInt(FindConVar("tf_cheapobjects"), 0);
	}
	else
	{
		SetConVarInt(FindConVar("tf_cheapobjects"), 1);
	}
}
public cvarAmmoCheatChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
	{
		SetConVarInt(FindConVar("tf_sentrygun_ammocheat"), 0);
	}
	else
	{
		SetConVarInt(FindConVar("tf_sentrygun_ammocheat"), 1);
	}
}
public cvarWelcomeMsgChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hWelcomeMsg, false);
	else
		SetConVarBool(g_hWelcomeMsg, true);
}
public cvarSentryLevelChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSentryLevel, false);
	else
		SetConVarBool(g_hSentryLevel, true);
}
public cvarSupermanChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSuperman, false);
	else
		SetConVarBool(g_hSuperman, true);
}
public cvarSoundsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) == 0)
		SetConVarBool(g_hSoundBlock, false);
	else
		SetConVarBool(g_hSoundBlock, true);
}
