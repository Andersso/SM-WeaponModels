/**
 * =============================================================================
 * Custom Weapon Models
 *
 * Copyright (C) 2015 Andersso
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
 *
 */
/* TODO nmrih:

 * Find what's causing nodraw flag overwrite in SetEntityVisibility, find a better fix than to delay frames
	HINT: 	This is likely caused by a holster animation, and subsequent unholster of new weapon
			This follows up nicely in the following issue:
 * Switching a weapon doesn't immediately play the weapon selection animation; delay and singly janky movement at switch
					m_nSequence recording:
					4 (hands idle01)
	switch superx3:	4->1 (superx idle01dry)
					1->6 (superx unholster)
					6->0 (superx idle01)
	switch back to hands:
				0	 to 7	
				0	 to 7	
				7	 to 4	
				7	 to 4	
				4	 to 0	
				4	 to 0	
				0	 to 4	
				0	 to 4	
	As you can see, this looks it would be janky, and indeed, that is the case in game

 * Transition code to new sourcemod syntax
 * Find way to verify nmrih spectator status in OnClientSpawnPost
 
 * Feature: more viewmodel support ( such as for melees, items, tools )
 
 * Optional: (gun)sound overrides
			gun feel is heavily influenced by its sounds. Custom sounds may elevate immersion drastically
			alas, this may be impossible
 * Optional: per-client toggle and/or permissions. Could be fun for some kind of ingame shop.
 
 * current:  check if can do 10 frames, repeating if fail, for viewmodel1
 *			 weapon switch fade in/out
 			 and/or hide viewmodel2 after time | weapon holster sequence complete
 *			 I need a global variable storing weapon visibility status

 * Changes:
 * 
 * plugin is reloaded while players are ingame.

*/
// TODO:
// Test L4D1/L4D2
// Toggle animation seems to bug on some rare occasions
// Proxy over m_nSkin to view model 2? (sleeve skin)
// Add support for non-custom weapon models
/*
	this should be tested when parsing config!
	
	sm_weaponmodels_reloadconfig needs fixing!
	
	
	Fix dropped weapon models!
	
	Add activity translate feature thingy!
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_NAME "Custom Weapon Models"
#define PLUGIN_VERSION "1.3"

// #define DEBUG true

#include "weaponmodels/consts.sp"
#include "weaponmodels/entitydata.sp"

// This should be on top, sm includes still not updated as of today
#pragma newdecls required

public Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = "Andersso, Thijs",
	description = "Change any weapon model",
	version     = PLUGIN_VERSION,
	url         = "http://www.sourcemod.net/"
};


// This value should be true on the later versions of Source which uses client-predicted weapon switching
bool g_bPredictedWeaponSwitch = false;

// This value should be true on games where CBaseCombatWeapon derives from CEconEntity
bool g_bEconomyWeapons = false;

// This value should be true if view model offsets doesn't differ between different weapons (In this case only CS:GO)
bool g_bViewModelOffsetIndependent = false;

EngineVersion g_iEngineVersion;

char g_szViewModelClassName[CLASS_NAME_MAX_LENGTH] = "predicted_viewmodel";
//char g_szWeaponPrefix[CLASS_NAME_MAX_LENGTH] = "weapon_"; // never used? removing..

// char g_szMeleePrefix[CLASS_NAME_MAX_LENGTH] = "me_";

ConVar g_iFrameSkipCount;



enum ClientInfo
{
	ClientInfo_ViewModels[2],
	ClientInfo_LastSequence,
	ClientInfo_CustomWeapon,
	ClientInfo_DrawSequence,
	ClientInfo_WeaponIndex,
	bool:ClientInfo_ToggleSequence,
	ClientInfo_LastSequenceParity,
	ClientInfo_SwapWeapon // This property is used when g_bEconomyWeapons is true
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
	WeaponModelInfo_SwapWeapon, // This property is used when g_bEconomyWeapons is false
	WeaponModelInfo_SwapSequences[MAX_SEQEUENCES],
	WeaponModelInfo_SequenceCount,
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

#include "weaponmodels/config.sp"
#include "weaponmodels/csgo.sp"
#include "weaponmodels/api.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	WeaponModels_ApiInit();

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

public void PrecacheWeaponInfo(int weaponIndex)
{
	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex] = PrecacheWeaponInfo_PrecahceModel(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel]);
	g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModelIndex] = PrecacheWeaponInfo_PrecahceModel(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModel]);
}

public int PrecacheWeaponInfo_PrecahceModel(const char[] model)
{
	return model[0] != '\0' ? PrecacheModel(model, true) : 0;
}

public void CleanUpSwapWeapon(int weaponIndex)
{
	int swapWeapon = EntRefToEntIndex(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapWeapon]);

	if (swapWeapon > 0)
	{
		AcceptEntityInput(swapWeapon, "Kill");
	}
}

public void OnPluginStart()
{
	CreateConVar("sm_weaponmodels_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	WeaponModels_ConfigInit();
	switch (g_iEngineVersion = GetEngineVersion())
	{

		case Engine_SDK2013:
		{
			//g_szWeaponPrefix = "fa_";
			// g_szMeleePrefix = "me_";
			#if defined DEBUG
			PrintToServer("%s: initializing for No More Room in Hell", PLUGIN_NAME);
			#endif
		}
		case Engine_DODS:
		{
			g_szViewModelClassName = "dod_viewmodel";
			#if defined DEBUG
			PrintToServer("%s: initializing for Day Of Defeat", PLUGIN_NAME);
			#endif
		}
		case Engine_TF2:
		{
			g_szViewModelClassName = "tf_viewmodel";
			//g_szWeaponPrefix = "tf_weapon_";
			#if defined DEBUG
			PrintToServer("%s: initializing for Team Fortress 2", PLUGIN_NAME);
			#endif
		}
		case Engine_Left4Dead, Engine_Left4Dead2, Engine_Portal2:
		{
			g_bPredictedWeaponSwitch = true;
			#if defined DEBUG
			PrintToServer("%s: initializing for L4D/L4D2/Portal2", PLUGIN_NAME);
			#endif
		}
		case Engine_CSGO:
		{
			g_bPredictedWeaponSwitch = true;
			g_bViewModelOffsetIndependent = true;
			
			WeaponModels_CSGOInit();
			#if defined DEBUG
			PrintToServer("%s: initializing for Counter Strike;Global Offensive", PLUGIN_NAME);
			#endif
		}
	}

	WeaponModels_EntityDataInit();

	g_iFrameSkipCount = CreateConVar("sm_frameskip", "60", "frame skip count for weapon switch");

	g_bEconomyWeapons = g_iOffset_EconItemDefinitionIndex != -1;
	
	HookEvent("player_death", Event_PlayerDeath);
}


public void Event_PlayerDeath(Event event, const char[] eventName, bool dontBrodcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	// Event is sometimes called with client index 0 in Left 4 Dead
	if (client == 0)
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
		SetEntityVisibility(viewModel2, false);
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
				SetEntityVisibility(viewModel1, true);

				SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel1);
			}

			if (viewModel2 != -1)
			{
				SetEntityVisibility(viewModel2, false);
				SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel2);
			}
		}
	}

	if (!g_bEconomyWeapons)
	{
		for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
		{
			if (g_WeaponModelInfo[i][WeaponModelInfo_Status] != WeaponModelInfoStatus_Free)
			{
				CleanUpSwapWeapon(i);
			}
		}
	}
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
	//nmrih spectators have the same team id as non spectators: 0
	//without this engine check the code will always end here in nmrih
	//TODO: Find way to verify nmrih spectator status 
	if ( g_iEngineVersion != Engine_SDK2013 )
	{
		// No spectators
		int clientTeam = GetClientTeam(client);
		if (clientTeam < 2)
		{
			return;
		}
	}	

	g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;

	int viewModel1 = GetPlayerViewModel(client, 0);
	int viewModel2 = GetPlayerViewModel(client, 1);

	// If a secondary view model doesn't exist, create one
	if (viewModel2 == -1)
	{
		if ((viewModel2 = CreateEntityByName(g_szViewModelClassName)) == -1)
		{
			LogError("Failed to create secondary view model!");
			return;
		}

		SetEntDataEnt2(viewModel2, g_iOffset_ViewModelOwner, client, true);
		SetEntData(viewModel2, g_iOffset_ViewModelIndex, 1, _, true);
		
		if (g_iOffset_ViewModelIgnoreOffsAcc != -1)
		{
			SetEntData(viewModel2, g_iOffset_ViewModelIgnoreOffsAcc, true, 1, true);
		}
		
		DispatchSpawn(viewModel2);

		SetPlayerViewModel(client, 1, viewModel2);
	}

	g_ClientInfo[client][ClientInfo_ViewModels][0] = EntIndexToEntRef(viewModel1);
	g_ClientInfo[client][ClientInfo_ViewModels][1] = EntIndexToEntRef(viewModel2);

	// Hide the secondary view model, in case the player has respawned
	SetEntityVisibility(viewModel2, false);

	int activeWeapon = GetEntDataEnt2(client, g_iOffset_PlayerActiveWeapon);
	OnWeaponSwitch(client, activeWeapon);
	OnWeaponSwitchPost(client, activeWeapon);
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

	PrintToServer("viewmodel1:%d viewmodel2%d:", viewModel1, viewModel2);

	for (int i = 0; i < MAX_CUSTOM_WEAPONS; i++)
	{
		// Skip unused indexes
		if (g_WeaponModelInfo[i][WeaponModelInfo_Status] == WeaponModelInfoStatus_Free)
			continue;

		if (g_WeaponModelInfo[i][WeaponModelInfo_DefIndex] != -1)
		{
			if (!g_bEconomyWeapons)
			{
				LogError("Game does not support item definition index! (Weapon index %i)", i + 1);

				continue;
			}

			int itemDefIndex = GetEntData(weapon, g_iOffset_EconItemDefinitionIndex);

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
			if (!ExecuteForward(i, client, weapon, className, -1))
			{
				continue;
			}
		}
		else if (g_WeaponModelInfo[i][WeaponModelInfo_TeamNum] && g_WeaponModelInfo[i][WeaponModelInfo_TeamNum] != GetClientTeam(client))
		{
			continue;
		}

		g_ClientInfo[client][ClientInfo_SwapWeapon] = -1;
		g_ClientInfo[client][ClientInfo_CustomWeapon] = weapon;
		g_ClientInfo[client][ClientInfo_WeaponIndex] = i;

		// Get the class-name if the custom weapon is set by definition index
		if (g_WeaponModelInfo[i][WeaponModelInfo_ClassName][0] == '\0')
		{
			GetEdictClassname(weapon, g_WeaponModelInfo[i][WeaponModelInfo_ClassName], CLASS_NAME_MAX_LENGTH);
		}

		if (!g_bEconomyWeapons && EntRefToEntIndex(g_WeaponModelInfo[i][WeaponModelInfo_SwapWeapon]) <= 0)
		{
			g_WeaponModelInfo[i][WeaponModelInfo_SwapWeapon] = EntIndexToEntRef(CreateSwapWeapon(i, client));
		}

		return Plugin_Continue;
	}

	// Client has swapped to a regular weapon
	if (g_ClientInfo[client][ClientInfo_CustomWeapon] != 0)
	{
		g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;
		g_ClientInfo[client][ClientInfo_WeaponIndex] = -1;
	}

	return Plugin_Continue;
}

public int CreateSwapWeapon(int weaponIndex, int client)
{
	int customWeapon = g_ClientInfo[client][ClientInfo_CustomWeapon];
	
	if (g_bViewModelOffsetIndependent)
	{	
		for (int i = 0; i < MAX_WEAPONS; i++)
		{
			int weapon = GetEntDataEnt2(client, g_iOffset_CharacterWeapons + (i * 4));
			if (weapon != -1 && weapon != customWeapon)
			{
				return weapon;
			}
		}
	}
	
	int swapWeapon = CreateEntityByName(g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ClassName]);

	if (swapWeapon == -1)
	{
		return LogError("Failed to create swap weapon entity!");
	}
	
	DispatchSpawn(swapWeapon);

	SetEntDataEnt2(swapWeapon, g_iOffset_WeaponOwner, client, true);
	SetEntDataEnt2(swapWeapon, g_iOffset_EntityOwnerEntity, client, true);

	SetEntityMoveType(swapWeapon, MOVETYPE_NONE);

	// CEconEntity: The parent of the swap weapon must the client using it
	SetVariantString("!activator");
	AcceptEntityInput(swapWeapon, "SetParent", client);

	return swapWeapon;
}

// This algorithm gives me an headache, even though I made it myself. But it's as fast as it can be I hope 
public int BuildSwapSequenceArray(int swapSequences[MAX_SEQEUENCES], int sequenceCount, int weapon, int index)
{
	int value = swapSequences[index], swapIndex = -1;

	if (!value)
	{
		// Continue to next if sequence wasn't an activity
		if ((value = swapSequences[index] = Animating_GetSequenceActivity(weapon, index)) == -1)
		{
			if (++index < sequenceCount)
			{
				BuildSwapSequenceArray(swapSequences, sequenceCount, weapon, index);

				return -1;
			}

			return 0;
		}
	}
	else if (value == -1)
	{
		if (++index < sequenceCount)
		{
			BuildSwapSequenceArray(swapSequences, sequenceCount, weapon, index);

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

	for (int i = index + 1; i < sequenceCount; i++)
	{
		int nextValue = BuildSwapSequenceArray(swapSequences, sequenceCount, weapon, i);

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

			if (g_iEngineVersion == Engine_SDK2013)	{
				//idk how to hide/show at the end of the holster sequence..
				//for now just keep viewmodels invisible/visible until end of holster sequence.
				//the viewmodel should eventually change lol
				SetEntityVisibility(viewModel2, false);
				SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel2);
				}
			else {
				SetEntityVisibility(viewModel1, true);
				SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel1);
				SetEntityVisibility(viewModel2, false);
				SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel2);
			}
			
			g_ClientInfo[client][ClientInfo_WeaponIndex] = 0;
		}

		return;
	}

	if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex])
	{

		if (g_iEngineVersion == Engine_SDK2013)	{ 
			SetEntityVisibility_FrameDelay(viewModel1, false, g_iFrameSkipCount.IntValue, weapon);
		}
		else { 
			SetEntityVisibility(viewModel1, false); 			
		}
		
		SetEntityVisibility(viewModel2, true);

		if (g_iEngineVersion == Engine_CSGO)
			StopParticleEffects(client, viewModel2);
		

		if (g_bPredictedWeaponSwitch)
		{
			g_ClientInfo[client][ClientInfo_DrawSequence] = GetEntData(viewModel1, g_iOffset_ViewModelSequence);

			// Switch to an invalid sequence to prevent it from playing sounds before UpdateTransmitStateTime() is called
			SetEntData(viewModel1, g_iOffset_ViewModelSequence, -1, _, true);
		}
		else
		{
			SetEntData(viewModel2, g_iOffset_ViewModelSequence, GetEntData(viewModel1, g_iOffset_ViewModelSequence), _, true);
			SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel1);
		}

		SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel2);

		SetEntityModel(weapon, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel]);


		if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SequenceCount] == -1)
		{
			int sequenceCount = Animating_GetSequenceCount(weapon);

			if (sequenceCount > 0)
			{
				int swapSequences[MAX_SEQEUENCES];

				if (sequenceCount < MAX_SEQEUENCES)
				{

					BuildSwapSequenceArray(swapSequences, sequenceCount, weapon, 0);

					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SequenceCount] = sequenceCount;
					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapSequences] = swapSequences;
				}
				else
				{
					LogError("View model \"%s\" is having too many sequences! (Max %i, is %i) - Increase value of MAX_SEQEUENCES in plugin",
						g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel],
						MAX_SEQEUENCES,
						sequenceCount);
				}
			}
			else
			{
				for (int i = 0; i < MAX_SEQEUENCES; i++)
				{
					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapSequences][i] = -1;
				}

				LogError("Failed to get sequence count for weapon using model \"%s\" - Animations may not work as expected",
					g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModel]);
			}
		}

		SetEntData(viewModel1, g_iOffset_EntityModelIndex, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex], _, true);
		SetEntData(viewModel2, g_iOffset_EntityModelIndex, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_ViewModelIndex], _, true);
		
		SetEntDataFloat(viewModel2, g_iOffset_ViewModelPlaybackRate, GetEntDataFloat(viewModel1, g_iOffset_ViewModelPlaybackRate), true);

		// FIXME: Why am I calling this? - good question lol
		ToggleViewModelWeapon(client, viewModel2, weaponIndex);
		
		g_ClientInfo[client][ClientInfo_LastSequenceParity] = -1;
	}
	else
	{
		g_ClientInfo[client][ClientInfo_CustomWeapon] = 0;
	}

	if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModelIndex])
	{
		SetEntData(weapon, g_iOffset_WeaponWorldModelIndex, g_WeaponModelInfo[weaponIndex][WeaponModelInfo_WorldModelIndex], _, true);
	}
}

public void ToggleViewModelWeapon(int client, int viewModel, int weaponIndex)
{
	int swapWeapon;

	if ((g_ClientInfo[client][ClientInfo_ToggleSequence] = !g_ClientInfo[client][ClientInfo_ToggleSequence]))
	{
		swapWeapon = EntRefToEntIndex(g_bEconomyWeapons ? g_ClientInfo[client][ClientInfo_SwapWeapon] : g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapWeapon]);

		if (swapWeapon == -1)
		{
			swapWeapon = CreateSwapWeapon(weaponIndex, client);

			if (g_bEconomyWeapons)
			{
				g_ClientInfo[client][ClientInfo_SwapWeapon] = EntIndexToEntRef(swapWeapon);
			}
			else
			{
				g_WeaponModelInfo[weaponIndex][WeaponModelInfo_SwapWeapon] = EntIndexToEntRef(swapWeapon);
			}
		}
	}
	else
	{
		swapWeapon = g_ClientInfo[client][ClientInfo_CustomWeapon];
	}

	SetEntDataEnt2(viewModel, g_iOffset_ViewModelWeapon, swapWeapon, true);
}

public void OnClientPostThinkPost(int client)
{
	// Callback is sometimes called on disconnected clients
	if (!IsClientConnected(client))
	{
		return;
	}

	if (g_ClientInfo[client][ClientInfo_CustomWeapon] == 0)
	{
		return;
	}

	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client][ClientInfo_ViewModels][1]);

	if (viewModel1 == -1 || viewModel2 == -1)
	{
		return;
	}

	int sequence = GetEntData(viewModel1, g_iOffset_ViewModelSequence);

	int drawSequence = -1;
	
	if (g_bPredictedWeaponSwitch)
	{
		drawSequence = g_ClientInfo[client][ClientInfo_DrawSequence];
		
		if (sequence == -1)
		{
			sequence = drawSequence;
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
			
			// Change to swap sequence, if present
			if (swapSequence != -1)
			{
				SetEntData(viewModel1, g_iOffset_ViewModelSequence, swapSequence, _, true);
				SetEntData(viewModel2, g_iOffset_ViewModelSequence, swapSequence, _, true);

				g_ClientInfo[client][ClientInfo_LastSequence] = swapSequence;
			}
			else
			{
				ToggleViewModelWeapon(client, viewModel2, weaponIndex);
			}
		}
	}
	else
	{
		if (g_bPredictedWeaponSwitch && drawSequence != -1 && sequence != drawSequence)
		{
			SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel1);
			g_ClientInfo[client][ClientInfo_DrawSequence] = -1;
		}
		
		SetEntData(viewModel2, g_iOffset_ViewModelSequence, sequence, _, true);

		g_ClientInfo[client][ClientInfo_LastSequence] = sequence;
	}
	
	g_ClientInfo[client][ClientInfo_LastSequenceParity] = sequenceParity;
}

void InitDataMapOffset(int &offset, int entity, const char[] propName)
{
	if ((offset = FindDataMapInfo(entity, propName)) == -1)
	{
		SetFailState("Fatal Error: Failed to find offset: \"%s\"!", propName);
	}
}