/**
 * =============================================================================
 * Custom Weapon Models
 *
 * Copyright (C) 2014 Andersso
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// TODO:
// Test L4D1/L4D2
// Toggle animation seems to bug on some rare occasions
// Proxy over m_nSkin to view model 2? (sleeve skin)
// Add support for non-custom weapon models
/*
	if (g_iOffset_ItemDefinitionIndex == -1)
	{
		LogError("Game does not support item definition index! (Weapon index %i)", i + 1);

		continue;
	}
	
	this should be tested when parsing config!
	
	sm_weaponmodels_reloadconfig needs fixing!
	
	
	Fix dropped weapon models!
	
	Add activity translate feature thingy!
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// This should be on top, sm includes still not updated as of today
#pragma newdecls required

// Change this if you need more custom weapon models
#define MAX_CUSTOM_WEAPONS 50

#define MAX_SWAP_SEQEUENCES 100

#define CLASS_NAME_MAX_LENGTH 48

#define EF_NODRAW 0x20

#define PARTICLE_DISPATCH_FROM_ENTITY (1 << 0)

#define PATTACH_WORLDORIGIN 5

#define SWAP_SEQ_PAIRED (1 << 31)

#define PLUGIN_NAME "Custom Weapon Models"
#define PLUGIN_VERSION "1.1"

Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Andersso",
	description = "Change any weapon model",
	version     = PLUGIN_VERSION,
	url         = "http://www.sourcemod.net/"
};

// This value should be true on the later versions of Source which uses client-predicted weapon switching
bool g_bPredictedWeaponSwitch;

EngineVersion g_iEngineVersion;

char g_szViewModelClassName[CLASS_NAME_MAX_LENGTH] = "predicted_viewmodel";
char g_szWeaponPrefix[CLASS_NAME_MAX_LENGTH] = "weapon_";

Handle g_hSDKCall_UpdateTransmitState; // UpdateTransmitState will stop the view model from transmitting if EF_NODRAW flag is present
Handle g_hSDKCall_GetSequenceActivity;

int g_iOffset_StudioHdr;
int g_iOffset_SequenceCount;

int g_iOffset_Effects;
int g_iOffset_ModelIndex;

int g_iOffset_WorldModelIndex;

int g_iOffset_ViewModel;
int g_iOffset_ActiveWeapon;

int g_iOffset_Owner;
int g_iOffset_Weapon;
int g_iOffset_Sequence;
int g_iOffset_PlaybackRate;
int g_iOffset_ViewModelIndex;

int g_iOffset_ItemDefinitionIndex;

enum ClientInfo
{
	ClientInfo_ViewModels[2],
	ClientInfo_LastSequence,
	ClientInfo_CustomWeapon,
	ClientInfo_DrawSequence,
	ClientInfo_WeaponIndex,
	bool:ClientInfo_ToggleSequence,
	ClientInfo_LastSequenceParity,
	Float:ClientInfo_UpdateTransmitStateTime
};

int g_ClientInfo[MAXPLAYERS + 1][ClientInfo];

enum WeaponModelInfoStatus
{
	WeaponModelInfoStatus_Free,
	WeaponModelInfoStatus_Config,
	WeaponModelInfoStatus_API
};

enum WeaponModelInfo
{
	WeaponModelInfo_DefIndex,
//	WeaponModelInfo_SwapWeapon,
	WeaponModelInfo_SwapSequences[MAX_SWAP_SEQEUENCES],
	WeaponModelInfo_NumAnims,
	Handle:WeaponModelInfo_Forward,
	String:WeaponModelInfo_ClassName[CLASS_NAME_MAX_LENGTH + 1],
	String:WeaponModelInfo_ViewModel[PLATFORM_MAX_PATH + 1],
	String:WeaponModelInfo_WorldModel[PLATFORM_MAX_PATH + 1],
	WeaponModelInfo_ViewModelIndex,
	WeaponModelInfo_WorldModelIndex,
	WeaponModelInfo_TeamNum,
	bool:WeaponModelInfo_BlockLAW,
	WeaponModelInfoStatus:WeaponModelInfo_Status
};

int g_WeaponModelInfo[MAX_CUSTOM_WEAPONS][WeaponModelInfo];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("weaponmodels");

	// This should only be called in AskPluginLoad()
	CreateNative("WeaponModels_AddWeaponByClassName", Native_AddWeaponByClassName);
	CreateNative("WeaponModels_AddWeaponByItemDefIndex", Native_AddWeaponByItemDefIndex);
	CreateNative("WeaponModels_RemoveWeaponModel", Native_RemoveWeaponModel);

	if (late)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPostAdminCheck(i);
			}
		}
	}
	
	return APLRes_Success;
}

public int Native_AddWeaponByClassName(Handle plugin, int numParams)
{
	char className[CLASS_NAME_MAX_LENGTH];
	GetNativeString(1, className, sizeof(className));

	int weaponIndex = -1;

	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		// Check if class-name is already used
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] != WeaponModelInfoStatus_Free && StrEqual(g_WeaponModelInfo[i][WeaponModelInfo_ClassName], className, false))
		{
			if (CheckForwardCleanup(i))
			{
				// If the forward handle is cleaned up, it also means that the index is no longer used
				weaponIndex = i;

				break;
			}

			return -1;
		}
	}

	if (weaponIndex == -1 && (weaponIndex = GetFreeWeaponInfoIndex()) == -1)
	{
		return -1;
	}

	char viewModel[PLATFORM_MAX_PATH + 1];
	char worldModel[PLATFORM_MAX_PATH + 1];
	GetNativeString(2, viewModel, sizeof(viewModel));
	GetNativeString(3, worldModel, sizeof(worldModel));

	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_DefIndex] = -1;

	strcopy(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ClassName], CLASS_NAME_MAX_LENGTH, className);

	AddWeapon(weaponIndex, viewModel, worldModel, plugin, GetNativeCell(4));

	return weaponIndex;
}

public int Native_AddWeaponByItemDefIndex(Handle plugin, int numParams)
{
	int itemDefIndex = GetNativeCell(1);

	if (itemDefIndex < 0)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Item definition index was invalid");
	}

	int weaponIndex = -1;

	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		// Check if definition index is already used
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] != WeaponModelInfoStatus_Free && g_WeaponModelInfo[i][WeaponModelInfo_DefIndex] == itemDefIndex)
		{
			if (CheckForwardCleanup(i))
			{
				// If the forward handle is cleaned up, it also means that the index is no longer used
				weaponIndex = i;

				break;
			}

			// FIXME: What is this?
			return -1;
		}
	}

	if (weaponIndex == -1 && (weaponIndex = GetFreeWeaponInfoIndex()) == -1)
	{
		return -1;
	}

	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_DefIndex] = itemDefIndex;

	char viewModel[PLATFORM_MAX_PATH + 1];
	char worldModel[PLATFORM_MAX_PATH + 1];
	GetNativeString(2, viewModel, sizeof(viewModel));
	GetNativeString(3, worldModel, sizeof(worldModel));

	AddWeapon(weaponIndex, viewModel, worldModel, plugin, GetNativeCell(4));

	return weaponIndex;
}

bool CheckForwardCleanup(int weaponIndex)
{
	Handle forwardHandle = g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Forward];

	if (forwardHandle != INVALID_HANDLE)
	{
		forwardHandle.Close();

		return true;
	}

	return false;
}

int GetFreeWeaponInfoIndex()
{
	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] == WeaponModelInfoStatus_Free)
		{
			return i;
		}
	}

	return -1;
}

void AddWeapon(int weaponIndex, const char[] viewModel, const char[] worldModel, Handle plugin, Function _function) // <- SP-Compiler error
{
	Handle forwardHandle = CreateForward(ET_Single, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell);

	AddToForward(forwardHandle, plugin, _function);

	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_NumAnims] = -1;
	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Forward] = forwardHandle;

	strcopy(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel], PLATFORM_MAX_PATH + 1, viewModel);
	strcopy(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModel], PLATFORM_MAX_PATH + 1, worldModel);

	PrecacheWeaponInfo(weaponIndex);

	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Status] = WeaponModelInfoStatus_API;
}

void PrecacheWeaponInfo(int weaponIndex)
{
	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex] = PrecacheWeaponInfo_PrecahceModel(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel]);
	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModelIndex] = PrecacheWeaponInfo_PrecahceModel(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModel]);
}

int PrecacheWeaponInfo_PrecahceModel(const char[] model)
{
	return model[0] != '\0' ? PrecacheModel(model, true) : 0;
}

public int Native_RemoveWeaponModel(Handle plugin, int numParams)
{
	int weaponIndex = GetNativeCell(1);

	if (weaponIndex < 0 || weaponIndex >= MAX_CUSTOM_WEAPONS)
	{
		ThrowNativeError(SP_ERROR_INDEX, "Weapon index was invalid");
	}

	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Forward].Close();

//	CleanUpSwapWeapon(weaponIndex);

	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Status] = WeaponModelInfoStatus_Free;
}

/*
void CleanUpSwapWeapon(int weaponIndex)
{
	int swapWeapon = EntRefToEntIndex(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapWeapon]);

	if (swapWeapon > 0)
	{
		AcceptEntityInput(swapWeapon, "Kill");
	}
}*/

public void OnPluginStart()
{
	CreateConVar("sm_weaponmodels_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegAdminCmd("sm_weaponmodels_reloadconfig", Command_ReloadConfig, ADMFLAG_CONFIG);

	switch (g_iEngineVersion = GetEngineVersion())
	{
		case Engine_DODS:
		{
			g_szViewModelClassName = "dod_viewmodel";
		}
		case Engine_TF2:
		{
			g_szViewModelClassName = "tf_viewmodel";
			g_szWeaponPrefix = "tf_weapon_";
		}
		case Engine_Left4Dead, Engine_Left4Dead2, Engine_Portal2:
		{
			g_bPredictedWeaponSwitch = true;
		}
		case Engine_CSGO:
		{
			g_bPredictedWeaponSwitch = true;

			AddCommandListener(Command_LookAtWeapon, "+lookatweapon");

			HookEvent("hostage_follows", Event_HostageFollows);
			HookEvent("weapon_fire", Event_WeaponFire);
		}
	}

	HookEvent("player_death", Event_PlayerDeath);

	Handle gameConf = LoadGameConfigFile("plugin.weaponmodels");

	if (gameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(gameConf, SDKConf_Virtual, "UpdateTransmitState");

		if (!(g_hSDKCall_UpdateTransmitState = EndPrepSDKCall()))
		{
			SetFailState("Failed to load SDK call \"UpdateTransmitState\"!");
		}

		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "GetSequenceActivity");

		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

		if (!(g_hSDKCall_GetSequenceActivity = EndPrepSDKCall()))
		{
			SetFailState("Failed to load SDK call \"GetSequenceActivity\"!");
		}

		InitGameConfOffset(gameConf, g_iOffset_StudioHdr, "StudioHdr");
		InitGameConfOffset(gameConf, g_iOffset_SequenceCount, "SequenceCount");

		CloseHandle(gameConf);
	}
	else
	{
		SetFailState("Failed to load game conf");
	}

	InitSendPropOffset(g_iOffset_Effects, "CBaseEntity", "m_fEffects");
	InitSendPropOffset(g_iOffset_ModelIndex, "CBaseEntity", "m_nModelIndex");

	InitSendPropOffset(g_iOffset_WorldModelIndex, "CBaseCombatWeapon", "m_iWorldModelIndex");

	InitSendPropOffset(g_iOffset_ViewModel, "CBasePlayer", "m_hViewModel");
	InitSendPropOffset(g_iOffset_ActiveWeapon, "CBasePlayer", "m_hActiveWeapon");

	InitSendPropOffset(g_iOffset_Owner, "CBaseViewModel", "m_hOwner");
	InitSendPropOffset(g_iOffset_Weapon, "CBaseViewModel", "m_hWeapon");
	InitSendPropOffset(g_iOffset_Sequence, "CBaseViewModel", "m_nSequence");
	InitSendPropOffset(g_iOffset_PlaybackRate, "CBaseViewModel", "m_flPlaybackRate");
	InitSendPropOffset(g_iOffset_ViewModelIndex, "CBaseViewModel", "m_nViewModelIndex");

	InitSendPropOffset(g_iOffset_ItemDefinitionIndex, "CEconEntity", "m_iItemDefinitionIndex", false);

	int lightingOriginOffset;
	InitSendPropOffset(lightingOriginOffset, "CBaseAnimating", "m_hLightingOrigin");

	// StudioHdr offset in gameconf is only relative to the offset of m_hLightingOrigin, in order to make the offset more resilient to game updates
	g_iOffset_StudioHdr += lightingOriginOffset;
}

void InitGameConfOffset(Handle gameConf, int &offsetDest, const char[] keyName)
{
	if ((offsetDest = GameConfGetOffset(gameConf, keyName)) == -1)
	{
		SetFailState("Failed to get offset: \"%s\"!", keyName);
	}
}

void InitSendPropOffset(int &offsetDest, const char[] serverClass, const char[] propName, bool failOnError = true)
{
	if ((offsetDest = FindSendPropInfo(serverClass, propName)) < 1 && failOnError)
	{
		SetFailState("Failed to find offset: \"%s\"!", propName);
	}
}

public Action Command_ReloadConfig(int client, int numArgs)
{
	LoadConfig();
}

public Action Command_LookAtWeapon(int client, const char[] command, int numArgs)
{
	if (g_ClientInfo[client][ClientInfo_CustomWeapon])
	{
		int weaponIndex = g_ClientInfo[client][ClientInfo_WeaponIndex];

		if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_BlockLAW])
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public void Event_HostageFollows(Handle event, const char[] eventName, bool dontBrodcast)
{
	int userID = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userID);

	// Prevent the view model from being removed
	SetViewModel(client, 1, -1);

	RequestFrame(RefreshViewModel, userID);
}

public void RefreshViewModel(any client)
{
	if (!(client = GetClientOfUserId(client)))
	{
		return;
	}

	if (g_ClientInfo[client][ClientInfo_CustomWeapon])
	{
		int viewModel2 = GetViewModel(client, 1);

		// Remove the view model created by the game
		if (viewModel2 != -1)
		{
			AcceptEntityInput(viewModel2, "Kill");
		}

		SetViewModel(client, 1, EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]));
	}
}

public void Event_WeaponFire(Handle event, const char[] name, bool dontBrodcast)
{
	static float heatValue[MAXPLAYERS + 1];
	
	float lastSmoke[MAXPLAYERS + 1];

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	float gameTime = GetGameTime();

	if (g_ClientInfo[client][ClientInfo_CustomWeapon])
	{
		int viewModel2 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]);

		if (viewModel2 == -1)
		{
			return;
		}

		static int primaryAmmoTypeOffset;
		static int lastShotTimeOffset;

		if (!primaryAmmoTypeOffset)
		{
			InitSendPropOffset(primaryAmmoTypeOffset, "CBaseCombatWeapon", "m_iPrimaryAmmoType");
		}

		int activeWeapon = GetEntDataEnt2(client, g_iOffset_ActiveWeapon);

		// Weapons without any type of ammo will not use smoke effects
		if (GetEntData(activeWeapon, primaryAmmoTypeOffset) == -1)
		{
			return;
		}

		if (!lastShotTimeOffset)
		{
			InitSendPropOffset(lastShotTimeOffset, "CWeaponCSBase", "m_fLastShotTime");
		}

		float newHeat = ((gameTime - GetEntDataFloat(activeWeapon, lastShotTimeOffset)) * -0.5) + heatValue[client];

		if (newHeat <= 0.0)
		{
			newHeat = 0.0;
		}

		// This value would normally be set specifically for each weapon, but who really cares?
		newHeat += 0.3;

		if (newHeat > 1.0)
		{
			if (gameTime - lastSmoke[client] > 4.0)
			{
				ShowMuzzleSmoke(client, viewModel2);

				lastSmoke[client] = gameTime;
			}

			newHeat = 0.0;
		}

		heatValue[client] = newHeat;
	}
}

void ShowMuzzleSmoke(int client, int entity)
{
	static int muzzleSmokeIndex = INVALID_STRING_INDEX;
	static int effectIndex = INVALID_STRING_INDEX;

	if (muzzleSmokeIndex == INVALID_STRING_INDEX && (muzzleSmokeIndex = GetStringTableItemIndex("ParticleEffectNames", "weapon_muzzle_smoke")) == INVALID_STRING_INDEX)
	{
		return;
	}

	if (effectIndex == INVALID_STRING_INDEX && (effectIndex = GetStringTableItemIndex("EffectDispatch", "ParticleEffect")) == INVALID_STRING_INDEX)
	{
		return;
	}

	TE_Start("EffectDispatch");

	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_fFlags", PARTICLE_DISPATCH_FROM_ENTITY);
	TE_WriteNum("m_nHitBox", muzzleSmokeIndex);
	TE_WriteNum("m_iEffectName", effectIndex);
	TE_WriteNum("m_nAttachmentIndex", 1);
	TE_WriteNum("m_nDamageType", PATTACH_WORLDORIGIN);

	TE_SendToClient(client);
}

void StopParticleEffects(int client, int entity)
{
	static int effectIndex = INVALID_STRING_INDEX;

	if (effectIndex == INVALID_STRING_INDEX && (effectIndex = GetStringTableItemIndex("EffectDispatch", "ParticleEffectStop")) == INVALID_STRING_INDEX)
	{
		return;
	}

	TE_Start("EffectDispatch");

	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iEffectName", effectIndex);

	TE_SendToClient(client);
}

int GetStringTableItemIndex(const char[] stringTable, const char[] string)
{
	int tableIndex = FindStringTable(stringTable);

	if (tableIndex == INVALID_STRING_TABLE)
	{
		LogError("Failed to receive string table \"%s\"!", stringTable);

		return INVALID_STRING_INDEX;
	}

	int index = FindStringIndex(tableIndex, string);

	if (index == INVALID_STRING_TABLE)
	{
		LogError("Failed to receive item \"%s\" in string table \"%s\"!", string, stringTable);
	}

	return index;
}

public void Event_PlayerDeath(Handle event, const char[] eventName, bool dontBrodcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// Event is sometimes called with client index 0 in Left 4 Dead
	if (!client)
	{
		return;
	}

	// Add compatibility with Zombie:Reloaded
	if (IsPlayerAlive(client))
	{
		return;
	}

	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]);

	if (viewModel2 != -1)
	{
		// Hide the custom view model if the player dies
		ShowViewModel(viewModel2, false);
	}

	g_ClientInfo[client][ClientInfo_ViewModels] = { -1, -1 };
	g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;
}

//TODO: restore weapon model name
public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_ClientInfo[i][ClientInfo_CustomWeapon])
		{
			int viewModel1 = EntRefToEntIndex(g_ClientInfo[i][ClientInfo_ViewModels][0]);
			int viewModel2 = EntRefToEntIndex(g_ClientInfo[i][ClientInfo_ViewModels][1]);

			if (viewModel1 != -1)
			{
				ShowViewModel(viewModel1, true);
				SDKCall(g_hSDKCall_UpdateTransmitState, viewModel1);
			}

			if (viewModel2 != -1)
			{
				ShowViewModel(viewModel2, false);
				SDKCall(g_hSDKCall_UpdateTransmitState, viewModel2);
			}
		}
	}

	/*
	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] != WeaponModelInfoStatus_Free)
		{
			CleanUpSwapWeapon(i);
		}
	}*/

	LoadConfig();
}

public void OnConfigsExecuted()
{
	// In case of map-change
	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] == WeaponModelInfoStatus_API)
		{
			PrecacheWeaponInfo(i);
		}
	}

	LoadConfig();
}

void LoadConfig()
{
	char path[PLATFORM_MAX_PATH + 1];
	char buffer[PLATFORM_MAX_PATH + 1];

	BuildPath(Path_SM, path, sizeof(path), "configs/weaponmodels_config.cfg");

	if (FileExists(path))
	{
		Handle kv = CreateKeyValues("ViewModelConfig");

		FileToKeyValues(kv, path);

		if (KvGotoFirstSubKey(kv))
		{
			int nextIndex = 0;

			do
			{
				int weaponIndex = -1;

				for (int i = nextIndex; i < MAX_CUSTOM_WEAPONS; i++)
				{
					// Select indexes of status free or config
					if (g_WeaponModelInfo[i][WeaponModelInfo_Status] < WeaponModelInfoStatus_API)
					{
						weaponIndex = i;

						break;
					}
				}

				if (weaponIndex == -1)
				{
					LogError("Out of weapon indexes! Change MAX_CUSTOM_WEAPONS in source code to increase limit");

					break;
				}

				KvGetSectionName(kv, buffer, sizeof(buffer));

				int defIndex;

				// Check if string is numeral
				if (StringToIntEx(buffer, defIndex) != strlen(buffer))
				{
					defIndex = -1;

					strcopy(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ClassName], CLASS_NAME_MAX_LENGTH, buffer);
				}
				else if (defIndex < 0)
				{
					LogError("Item definition index %i is invalid (Weapon index %i)", defIndex, weaponIndex + 1);

					continue;
				}

				g_WeaponModelInfo[weaponIndex][WeaponModelInfo_DefIndex] = defIndex;

				//CleanUpSwapWeapon(weaponIndex);

				KvGetString(kv, "ViewModel", g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel], PLATFORM_MAX_PATH + 1);
				KvGetString(kv, "WorldModel", g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModel], PLATFORM_MAX_PATH + 1);

				PrecacheWeaponInfo(weaponIndex);

				g_WeaponModelInfo[weaponIndex][WeaponModelInfo_TeamNum] = KvGetNum(kv, "TeamNum");
				g_WeaponModelInfo[weaponIndex][WeaponModelInfo_BlockLAW] = KvGetNum(kv, "BlockLAW") > 0;

				g_WeaponModelInfo[weaponIndex][WeaponModelInfo_NumAnims] = -1;

				g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Status] = WeaponModelInfoStatus_Config;

				nextIndex = weaponIndex + 1;
			}
			while (KvGotoNextKey(kv));
		}

		CloseHandle(kv);
	}
	else
	{
		SetFailState("Failed to open config file: \"%s\"!", path);
	}

	BuildPath(Path_SM, path, sizeof(path), "configs/weaponmodels_downloadlist.cfg");

	Handle file = OpenFile(path, "r");

	if (file)
	{
		while (!IsEndOfFile(file) && ReadFileLine(file, buffer, sizeof(buffer)))
		{
			if (SplitString(buffer, "//", buffer, sizeof(buffer)) == 0)
			{
				continue;
			}

			if (TrimString(buffer))
			{
				if (FileExists(buffer))
				{
					AddFileToDownloadsTable(buffer);
				}
				else
				{
					LogError("File \"%s\" was not found!", buffer);
				}
			}
		}

		CloseHandle(file);
	}
	else
	{
		LogError("Failed to open config file: \"%s\" !", path);
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_ClientInfo[client][ClientInfo_ViewModels] = { -1, -1 };
	g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;

	SDKHook(client, SDKHook_SpawnPost, OnClientSpawnPost);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

public void OnClientSpawnPost(int client)
{
	// No spectators
	if (GetClientTeam(client) < 2)
	{
		return;
	}

	g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;

	int viewModel1 = GetViewModel(client, 0);
	int viewModel2 = GetViewModel(client, 1);

	// If a secondary view model doesn't exist, create one
	if (viewModel2 == -1)
	{
		if ((viewModel2 = CreateEntityByName(g_szViewModelClassName)) == -1)
		{
			LogError("Failed to create secondary view model!");

			return;
		}

		SetEntDataEnt2(viewModel2, g_iOffset_Owner, client, true);
		SetEntData(viewModel2, g_iOffset_ViewModelIndex, 1, _, true);

		DispatchSpawn(viewModel2);

		SetViewModel(client, 1, viewModel2);
	}

	g_ClientInfo[client][ClientInfo_ViewModels][0] = EntIndexToEntRef(viewModel1);
	g_ClientInfo[client][ClientInfo_ViewModels][1] = EntIndexToEntRef(viewModel2);

	// Hide the secondary view model, in case the player has respawned
	ShowViewModel(viewModel2, false);

	int activeWeapon = GetEntDataEnt2(client, g_iOffset_ActiveWeapon);

	OnWeaponSwitch(client, activeWeapon);
	OnWeaponSwitchPost(client, activeWeapon);
}

int GetViewModel(int client, int index)
{
	return GetEntDataEnt2(client, g_iOffset_ViewModel + index * 4);
}

void SetViewModel(int client, int index, int viewModel)
{
	SetEntDataEnt2(client, g_iOffset_ViewModel + index * 4, viewModel);
}

void ShowViewModel(int viewModel, bool show)
{
	int flags = GetEntData(viewModel, g_iOffset_Effects);

	SetEntData(viewModel, g_iOffset_Effects, show ? flags & ~EF_NODRAW : flags | EF_NODRAW, _, true);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]);

	if (viewModel1 == -1 || viewModel2 == -1)
	{
		return Plugin_Continue;
	}

	char className[CLASS_NAME_MAX_LENGTH];
	if (!GetEdictClassname(weapon, className, sizeof(className)))
	{
		return Plugin_Continue;
	}

	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		// Skip unused indexes
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] == WeaponModelInfoStatus_Free)
		{
			continue;
		}

		if (g_WeaponModelInfo[i][WeaponModelInfo_DefIndex] != -1)
		{
			if (g_iOffset_ItemDefinitionIndex == -1)
			{
				LogError("Game does not support item definition index! (Weapon index %i)", i + 1);

				continue;
			}

			int itemDefIndex = GetEntData(weapon, g_iOffset_ItemDefinitionIndex);

			if (g_WeaponModelInfo[i][WeaponModelInfo_DefIndex] != itemDefIndex)
			{
				continue;
			}

			if (g_WeaponModelInfo[i][WeaponModelInfo_Forward] && !ExecuteForward(i, client, weapon, className, itemDefIndex))
			{
				continue;
			}
		}
		else if (!StrEqual(className, g_WeaponModelInfo[i][WeaponModelInfo_ClassName], false))
		{
			continue;
		}
		else if (g_WeaponModelInfo[i][WeaponModelInfo_Forward])
		{
			if (!ExecuteForward(i, client, weapon, className))
			{
				continue;
			}
		}
		else if (g_WeaponModelInfo[i][WeaponModelInfo_TeamNum] && g_WeaponModelInfo[i][WeaponModelInfo_TeamNum] != GetClientTeam(client))
		{
			continue;
		}

		g_ClientInfo[client][ClientInfo_CustomWeapon] = weapon;
		g_ClientInfo[client][ClientInfo_WeaponIndex] = i;

		/*
		if (EntRefToEntIndex(g_WeaponModelInfo[i][WeaponModelInfo_SwapWeapon]) <= 0)
		{
			if (g_WeaponModelInfo[i][WeaponModelInfo_ClassName][0] == '\0')
			{
				// Get the class-name if the custom weapon is set by definition index
				GetEdictClassname(weapon, g_WeaponModelInfo[i][WeaponModelInfo_ClassName], CLASS_NAME_MAX_LENGTH);
			}

			g_WeaponModelInfo[i][WeaponModelInfo_SwapWeapon] = EntIndexToEntRef(CreateSwapWeapon(className, client));
		}*/

		return Plugin_Continue;
	}

	// Hide secondary view model if player has switched from a custom to a regular weapon
	if (g_ClientInfo[client][ClientInfo_CustomWeapon])
	{
		g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;
		g_ClientInfo[client][ClientInfo_WeaponIndex] = -1;
	}

	return Plugin_Continue;
}

/*
int CreateSwapWeapon(const char[] className, int client)
{
	int swapWeapon = CreateEntityByName(className);

	if (swapWeapon == -1)
	{
		SetFailState("Failed to create swap weapon entity \"%s\"!", className);
	}

	DispatchSpawn(swapWeapon);

	SetEntPropEnt(swapWeapon, Prop_Send, "m_hOwner", client);
	SetEntPropEnt(swapWeapon, Prop_Send, "m_hOwnerEntity", client);

	SetEntityMoveType(swapWeapon, MOVETYPE_NONE);

	SetVariantString("!activator");
	AcceptEntityInput(swapWeapon, "SetParent", g_iEngineVersion == Engine_CSGO ? client : 0);

	return swapWeapon;
}*/

bool ExecuteForward(int weaponIndex, int client, int weapon, const char[] className, int itemDefIndex = -1)
{
	Handle forwardHandle = g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Forward];

	// Clean-up, if required
	if (!GetForwardFunctionCount(forwardHandle))
	{
		CloseHandle(forwardHandle);

		g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Status] = WeaponModelInfoStatus_Free;

		return false;
	}

	Call_StartForward(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_Forward]);

	Call_PushCell(weaponIndex);
	Call_PushCell(client);
	Call_PushCell(weapon);
	Call_PushString(className);
	Call_PushCell(itemDefIndex);

	bool result;
	Call_Finish(result);

	return result;
}

int InitSwapSequenceArray(int swapSequences[MAX_SWAP_SEQEUENCES], int numAnims, int weapon, int index = 0)
{
	int value = swapSequences[index], swapIndex = -1;

	if (!value)
	{
		//PrintToServer("%i - test", SDKCall(g_hSDKCall_GetSequenceActivity, weapon, index));
		
		// Continue to next if sequence wasn't an activity
		if ((value = swapSequences[index] = SDKCall(g_hSDKCall_GetSequenceActivity, weapon, index)) == -1)
		{
			if (++index < numAnims)
			{
				InitSwapSequenceArray(swapSequences, numAnims, weapon, index);

				return -1;
			}

			return 0;
		}
	}
	else if (value == -1)
	{
		if (++index < numAnims)
		{
			InitSwapSequenceArray(swapSequences, numAnims, weapon, index);

			return -1;
		}
		
		return 0;
	}
	else if (value & SWAP_SEQ_PAIRED)
	{
		// Get the index
		swapIndex = (value & ~SWAP_SEQ_PAIRED) >> 16;

		// Get activity value
		value &= 0x0000FFFF;
	}
	else
	{
		return 0;
	}

	for (int i = index + 1; i < numAnims; i++)
	{
		int nextValue = InitSwapSequenceArray(swapSequences, numAnims, weapon, i);

		if (value == nextValue)
		{
			swapIndex = i;

			// Let the index be be stored after the 16th bit, and add a bit-flag to indicate this being done
			swapSequences[i] = nextValue | (index << 16) | SWAP_SEQ_PAIRED;

			break;
		}
	}

	swapSequences[index] = swapIndex;

	return value;
}

public void OnWeaponSwitchPost(int client, int weapon)
{
	// Callback is sometimes called on disconnected clients
	if (!IsClientConnected(client))
	{
		return;
	}

	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]);

	if (viewModel1 == -1 || viewModel2 == -1)
	{
		return;
	}

	int weaponIndex = g_ClientInfo[client][ClientInfo_WeaponIndex];

	if (weapon != g_ClientInfo[client][ClientInfo_CustomWeapon])
	{
		// Hide the secondary view model. This needs to be done on post because the weapon needs to be switched first
		if (weaponIndex == -1)
		{
			ShowViewModel(viewModel1, true);
			SDKCall(g_hSDKCall_UpdateTransmitState, viewModel1);

			ShowViewModel(viewModel2, false);
			SDKCall(g_hSDKCall_UpdateTransmitState, viewModel2);

			g_ClientInfo[client][ClientInfo_WeaponIndex] = 0;
		}

		return;
	}

	if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex])
	{
		ShowViewModel(viewModel1, false);
		ShowViewModel(viewModel2, true);

		if (g_iEngineVersion == Engine_CSGO)
		{
			StopParticleEffects(client, viewModel2);
		}

		if (g_bPredictedWeaponSwitch)
		{
			int sequence = GetEntData(viewModel1, g_iOffset_Sequence);

			g_ClientInfo[client][ClientInfo_DrawSequence] = sequence;

			// UpdateTransmitStateTime needs to be delayed a bit to prevent the drawing sequence from locking up and being repeatedly played client-side
			g_ClientInfo[client][ClientInfo_UpdateTransmitStateTime] = GetGameTime() + 0.5;

			// Switch to an invalid sequence to prevent it from playing sounds before UpdateTransmitStateTime() is called
			SetEntData(viewModel1, g_iOffset_Sequence, -2, _, true);
		}
		else
		{
			SetEntData(viewModel2, g_iOffset_Sequence, GetEntData(viewModel1, g_iOffset_Sequence));

			SDKCall(g_hSDKCall_UpdateTransmitState, viewModel1);
		}

		SDKCall(g_hSDKCall_UpdateTransmitState, viewModel2);

		SetEntityModel(weapon, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel]);

		if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_NumAnims] == -1)
		{
			Address pStudioHdr = view_as<Address>(GetEntData(weapon, g_iOffset_StudioHdr));

			// Check if StudioHdr is valid
			if (pStudioHdr >= Address_MinimumValid && (pStudioHdr = view_as<Address>(LoadFromAddress(pStudioHdr, NumberType_Int32))) >= Address_MinimumValid)
			{
				int numAnims = LoadFromAddress(pStudioHdr + view_as<Address>(g_iOffset_SequenceCount), NumberType_Int32);
				int swapSequences[MAX_SWAP_SEQEUENCES];

				if (numAnims < MAX_SWAP_SEQEUENCES)
				{
					InitSwapSequenceArray(swapSequences, numAnims, weapon);

					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_NumAnims] = numAnims;
					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapSequences] = swapSequences;
				}
				else
				{
					LogError("View model \"%s\" is having too many sequences! (Max %i) - Increase value of MAX_SWAP_SEQEUENCES in plugin");
				}
			}
			else
			{
				for (int i = 0; i < MAX_SWAP_SEQEUENCES; i++)
				{
					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapSequences][i] = -1;
				}

				LogError("Failed to get StudioHdr for weapon using model \"%s\" - Animations may not work as expected", g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel]);
			}
		}

		SetEntData(viewModel1, g_iOffset_ModelIndex, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex], _, true);
		SetEntData(viewModel2, g_iOffset_ModelIndex, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex], _, true);
		SetEntDataFloat(viewModel2, g_iOffset_PlaybackRate, GetEntDataFloat(viewModel1, g_iOffset_PlaybackRate), true);

		//ToggleViewModelWeapon(client, viewModel2, weaponIndex);
		
		g_ClientInfo[client][ClientInfo_LastSequenceParity] = -1;
	}
	else
	{
		g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;
	}

	if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModelIndex])
	{
		SetEntData(weapon, g_iOffset_WorldModelIndex, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModelIndex], _, true);
	}
}

/*
void ToggleViewModelWeapon(int client, int viewModel, int weaponIndex)
{
	int swapWeapon;

	if ((g_ClientInfo[client][ClientInfo_ToggleSequence] = !g_ClientInfo[client][ClientInfo_ToggleSequence]))
	{
		swapWeapon = EntRefToEntIndex(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapWeapon]);

		if (swapWeapon == -1)
		{
			swapWeapon = CreateSwapWeapon(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ClassName], client);

			g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapWeapon] = EntIndexToEntRef(swapWeapon);
		}
	}
	else
	{
		swapWeapon = g_ClientInfo[client][ClientInfo_CustomWeapon];
	}

	SetEntDataEnt2(viewModel, g_iOffset_Weapon, swapWeapon, true);
}*/

public void OnClientPostThinkPost(int client)
{
	// Callback is sometimes called on disconnected clients
	if (!IsClientConnected(client))
	{
		return;
	}

	if (!g_ClientInfo[client][ClientInfo_CustomWeapon])
	{
		return;
	}

	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]);

	if (viewModel1 == -1 || viewModel2 == -1)
	{
		return;
	}

	int sequence = GetEntData(viewModel1, g_iOffset_Sequence);

	//bool predictedDraw = false;

	if (g_bPredictedWeaponSwitch)
	{
		float updateTransmitStateTime = g_ClientInfo[client][ClientInfo_UpdateTransmitStateTime];

		if (updateTransmitStateTime && GetGameTime() > updateTransmitStateTime)
		{
			//PrintToServer("update transmit state");
			SDKCall(g_hSDKCall_UpdateTransmitState, viewModel1);

			g_ClientInfo[client][ClientInfo_UpdateTransmitStateTime] = 0.0;
		}

		if (sequence == -2)
		{
			sequence = g_ClientInfo[client][ClientInfo_DrawSequence];
			//predictedDraw = true;
		}
	}

	static int newSequenceParityOffset = 0;

	if (!newSequenceParityOffset)
	{
		InitDataMapOffset(newSequenceParityOffset, viewModel1, "m_nNewSequenceParity");
	}

	int sequenceParity = GetEntData(viewModel1, newSequenceParityOffset);

	// Sequence has not changed since last think
	if (sequence == g_ClientInfo[client][ClientInfo_LastSequence])
	{
		// Skip on weapon switch
		if (g_ClientInfo[client][ClientInfo_LastSequenceParity] != -1)
		{
			// Skip if sequence hasn't finished
			if (sequenceParity == g_ClientInfo[client][ClientInfo_LastSequenceParity])
			{
				return;
			}

			int weaponIndex = g_ClientInfo[client][ClientInfo_WeaponIndex];

			int swapSequence = g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapSequences][sequence];

			// Change to swap sequence, if exist
			if (swapSequence != -1)
			{
				//if (predictedDraw) PrintToServer("ah fuck");

				SetEntData(viewModel1, g_iOffset_Sequence, swapSequence, _, true);
				SetEntData(viewModel2, g_iOffset_Sequence, swapSequence, _, true);

				g_ClientInfo[client][ClientInfo_LastSequence] = swapSequence;
			}
			else
			{
				//if (predictedDraw) PrintToServer("ah fuck 2");
				//ToggleViewModelWeapon(client, viewModel2, weaponIndex);
			}
		}
	}
	else
	{
		//PrintToServer("seq %i", sequence);
		SetEntData(viewModel2, g_iOffset_Sequence, sequence, _, true);

		g_ClientInfo[client][ClientInfo_LastSequence] = sequence;
	}
	
	g_ClientInfo[client][ClientInfo_LastSequenceParity] = sequenceParity;
}

void InitDataMapOffset(int &offset, int entity, const char[] propName)
{
	if ((offset = FindDataMapOffs(entity, propName)) == -1)
	{
		SetFailState("Fatal Error: Failed to find offset: \"%s\"!", propName);
	}
}
