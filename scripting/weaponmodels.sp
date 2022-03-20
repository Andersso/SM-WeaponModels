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

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_NAME "Custom Weapon Models"
#define PLUGIN_VERSION "1.3"

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

enum Games
{
	Game_Unknown,
	Game_DODS,
	Game_TF2,
	Game_L4D,
	Game_L4D2,
	Game_Portal2,
	Game_CSGO,
	Game_NMRIH
};

Games g_Game;

char g_szViewModelClassName[CLASS_NAME_MAX_LENGTH] = "predicted_viewmodel";

enum struct ClientInfo
{
	int ViewModels[2];
	int LastSequence;
	int CustomWeapon;
	int DrawSequence;
	int WeaponIndex;
	bool ToggleSequence;
	int LastSequenceParity;
	int SwapWeapon; // This property is used when g_bEconomyWeapons is true
	bool ViewModelSwapped;
	int HolsteredViewModelIndex;
}

ClientInfo g_ClientInfo[MAXPLAYERS + 1];

enum WeaponModelInfoStatus
{
	WeaponModelInfoStatus_Free,
	WeaponModelInfoStatus_Config,
	WeaponModelInfoStatus_API
};

enum struct WeaponModelInfo
{
	int DefIndex;
	int SwapWeapon; // This property is used when g_bEconomyWeapons is false
	int SwapSequences[MAX_SEQEUENCES];
	int SequenceCount;
	Handle Forward;
	char ClassName[CLASS_NAME_MAX_LENGTH + 1];
	char ViewModel[PLATFORM_MAX_PATH + 1];
	char WorldModel[PLATFORM_MAX_PATH + 1];
	int ViewModelIndex;
	int WorldModelIndex;
	int TeamNum;
	bool BlockLAW;
	WeaponModelInfoStatus Status;
}

WeaponModelInfo g_WeaponModelInfo[MAX_CUSTOM_WEAPONS];

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

void PrecacheWeaponInfo(int weaponIndex)
{
	g_WeaponModelInfo[weaponIndex].ViewModelIndex = PrecacheWeaponInfo_PrecahceModel(g_WeaponModelInfo[weaponIndex].ViewModel);
	g_WeaponModelInfo[weaponIndex].WorldModelIndex = PrecacheWeaponInfo_PrecahceModel(g_WeaponModelInfo[weaponIndex].WorldModel);
}

int PrecacheWeaponInfo_PrecahceModel(const char[] model)
{
	return model[0] != '\0' ? PrecacheModel(model, true) : 0;
}

void CleanUpSwapWeapon(int weaponIndex)
{
	int swapWeapon = EntRefToEntIndex(g_WeaponModelInfo[weaponIndex].SwapWeapon);

	if (swapWeapon > 0)
	{
		AcceptEntityInput(swapWeapon, "Kill");
	}
}

public void OnPluginStart()
{
	CreateConVar("sm_weaponmodels_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);

	WeaponModels_ConfigInit();

	switch (GetEngineVersion())
	{
		case Engine_DODS:
		{
			g_szViewModelClassName = "dod_viewmodel";

			g_Game = Game_DODS;
		}
		case Engine_TF2:
		{
			g_szViewModelClassName = "tf_viewmodel";

			g_Game = Game_TF2;
		}
		case Engine_Left4Dead:
		{
			g_bPredictedWeaponSwitch = true;

			g_Game = Game_L4D;
		}
		case Engine_Left4Dead2:
		{
			g_bPredictedWeaponSwitch = true;

			g_Game = Game_L4D2;
		}
		case Engine_Portal2:
		{
			g_bPredictedWeaponSwitch = true;

			g_Game = Game_Portal2;
		}
		case Engine_CSGO:
		{
			g_bPredictedWeaponSwitch = true;
			g_bViewModelOffsetIndependent = true;
			
			g_Game = Game_CSGO;

			WeaponModels_CSGOInit();
		}
		case Engine_SDK2013:
		{
			char gameFolder[PLATFORM_MAX_PATH + 1];
			GetGameFolderName(gameFolder, sizeof(gameFolder));

			if (StrEqual(gameFolder, "nmrih"))
			{
				g_Game = Game_NMRIH;
			}
		}
		default:
		{
			g_Game = Game_Unknown;
		}
	}

	WeaponModels_EntityDataInit();
	
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

	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[1]);

	if (viewModel2 != -1)
	{
		// Hide the custom view model if the player dies
		SetEntityVisibility(viewModel2, false);
	}

	g_ClientInfo[client].ViewModels = { -1, -1 };
	g_ClientInfo[client].CustomWeapon = 0;
}

//TODO: restore weapon model name
public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_ClientInfo[i].CustomWeapon)
		{
			int viewModel1 = EntRefToEntIndex(g_ClientInfo[i].ViewModels[0]);
			int viewModel2 = EntRefToEntIndex(g_ClientInfo[i].ViewModels[1]);

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
			if (g_WeaponModelInfo[i].Status != WeaponModelInfoStatus_Free)
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
		if (g_WeaponModelInfo[i].Status == WeaponModelInfoStatus_API)
		{
			PrecacheWeaponInfo(i);
		}
	}

	LoadConfig();
}

public void OnClientPostAdminCheck(int client)
{
	g_ClientInfo[client].ViewModels = { -1, -1 };
	g_ClientInfo[client].CustomWeapon = 0;

	SDKHook(client, SDKHook_SpawnPost, OnClientSpawnPost);
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
	SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

public void OnClientSpawnPost(int client)
{
	bool isSpectator =  GetClientTeam(client) < 2;
	
	// NMRIH:
	// Spectators have the same team id as non spectators: 0
	// without this engine check the code will always end here
	// TODO: Find way to verify nmrih spectator status
	if (g_Game == Game_NMRIH)
	{
		isSpectator = false;
	}

	// No spectators
	if (isSpectator)
	{
		return;
	}

	g_ClientInfo[client].CustomWeapon = 0;

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

	g_ClientInfo[client].ViewModels[0] = EntIndexToEntRef(viewModel1);
	g_ClientInfo[client].ViewModels[1] = EntIndexToEntRef(viewModel2);

	// Hide the secondary view model, in case the player has respawned
	SetEntityVisibility(viewModel2, false);

	int activeWeapon = GetEntDataEnt2(client, g_iOffset_PlayerActiveWeapon);

	OnWeaponSwitch(client, activeWeapon);
	OnWeaponSwitchPost(client, activeWeapon);
}

public Action OnWeaponSwitch(int client, int weapon)
{
	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[1]);

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
		if (g_WeaponModelInfo[i].Status == WeaponModelInfoStatus_Free)
		{
			continue;
		}

		if (g_WeaponModelInfo[i].DefIndex != -1)
		{
			if (!g_bEconomyWeapons)
			{
				LogError("Game does not support item definition index! (Weapon index %i)", i + 1);

				continue;
			}

			int itemDefIndex = GetEntData(weapon, g_iOffset_EconItemDefinitionIndex);

			if (g_WeaponModelInfo[i].DefIndex != itemDefIndex)
			{
				continue;
			}

			if (g_WeaponModelInfo[i].Forward && !ExecuteForward(i, client, weapon, className, itemDefIndex))
			{
				continue;
			}
		}
		else if (!StrEqual(className, g_WeaponModelInfo[i].ClassName, false))
		{
			continue;
		}
		else if (g_WeaponModelInfo[i].Forward)
		{
			if (!ExecuteForward(i, client, weapon, className))
			{
				continue;
			}
		}
		else if (g_WeaponModelInfo[i].TeamNum && g_WeaponModelInfo[i].TeamNum != GetClientTeam(client))
		{
			continue;
		}

		g_ClientInfo[client].SwapWeapon = -1;
		g_ClientInfo[client].CustomWeapon = weapon;
		g_ClientInfo[client].WeaponIndex = i;

		// Get the class-name if the custom weapon is set by definition index
		if (g_WeaponModelInfo[i].ClassName[0] == '\0')
		{
			GetEdictClassname(weapon, g_WeaponModelInfo[i].ClassName, CLASS_NAME_MAX_LENGTH);
		}

		if (!g_bEconomyWeapons && EntRefToEntIndex(g_WeaponModelInfo[i].SwapWeapon) <= 0)
		{
			g_WeaponModelInfo[i].SwapWeapon = EntIndexToEntRef(CreateSwapWeapon(i, client));
		}

		// In case there is a holster animation, we will have to wait for the swapped weapon to be holstered.
		g_ClientInfo[client].ViewModelSwapped = false;
		g_ClientInfo[client].HolsteredViewModelIndex = GetEntData(viewModel1, g_iOffset_EntityModelIndex);

		return Plugin_Continue;
	}

	// Client has swapped to a regular weapon
	if (g_ClientInfo[client].CustomWeapon != 0)
	{
		g_ClientInfo[client].CustomWeapon = 0;
		g_ClientInfo[client].WeaponIndex = -1;
	}

	return Plugin_Continue;
}

int CreateSwapWeapon(int weaponIndex, int client)
{
	int customWeapon = g_ClientInfo[client].CustomWeapon;
	
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
	
	int swapWeapon = CreateEntityByName(g_WeaponModelInfo[weaponIndex].ClassName);

	if (swapWeapon == -1)
	{
		LogError("Failed to create swap weapon entity!");
		return 0;
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
int BuildSwapSequenceArray(int swapSequences[MAX_SEQEUENCES], int sequenceCount, int weapon, int index = 0)
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

	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[1]);

	if (viewModel1 == -1 || viewModel2 == -1)
	{
		return;
	}

	int weaponIndex = g_ClientInfo[client].WeaponIndex;

	if (weapon != g_ClientInfo[client].CustomWeapon)
	{
		// Hide the secondary view model. This needs to be done on post because the weapon needs to be switched first
		if (weaponIndex == -1)
		{
			SetEntityVisibility(viewModel1, true);
			SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel1);

			SetEntityVisibility(viewModel2, false);
			SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel2);

			g_ClientInfo[client].WeaponIndex = 0;
		}

		return;
	}

	if (g_WeaponModelInfo[weaponIndex].ViewModelIndex)
	{
		int currentViewModelIndex = GetEntData(viewModel1, g_iOffset_EntityModelIndex);

		// The view model index has changed, which means the old weapon is holstered, do the view model swap.
		if (currentViewModelIndex != g_ClientInfo[client].HolsteredViewModelIndex)
		{
			g_ClientInfo[client].ViewModelSwapped = true;
			SwapViewModel(client, weapon, viewModel1, viewModel2);
		}
	}
	else
	{
		g_ClientInfo[client].CustomWeapon = 0;
	}

	if (g_WeaponModelInfo[weaponIndex].WorldModelIndex)
	{
		SetEntData(weapon, g_iOffset_WeaponWorldModelIndex, g_WeaponModelInfo[weaponIndex].WorldModelIndex, _, true);
	}
}

void SwapViewModel(int client, int weapon, int viewModel1, int viewModel2)
{
	SetEntityVisibility(viewModel1, false);
	SetEntityVisibility(viewModel2, true);
	
	if (g_Game == Game_CSGO)
	{
		StopParticleEffects(client, viewModel2);
	}

	if (g_bPredictedWeaponSwitch)
	{
		g_ClientInfo[client].DrawSequence = GetEntData(viewModel1, g_iOffset_ViewModelSequence);

		// Switch to an invalid sequence to prevent it from playing sounds before UpdateTransmitStateTime() is called
		SetEntData(viewModel1, g_iOffset_ViewModelSequence, -1, _, true);
	}
	else
	{
		SetEntData(viewModel2, g_iOffset_ViewModelSequence, GetEntData(viewModel1, g_iOffset_ViewModelSequence), _, true);

		SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel1);
	}

	SDKCall(g_hSDKCall_Entity_UpdateTransmitState, viewModel2);

	int weaponIndex = g_ClientInfo[client].WeaponIndex;

	SetEntityModel(weapon, g_WeaponModelInfo[weaponIndex].ViewModel);

	if (g_WeaponModelInfo[weaponIndex].SequenceCount == -1)
	{
		int sequenceCount = Animating_GetSequenceCount(weapon);

		if (sequenceCount > 0)
		{
			int swapSequences[MAX_SEQEUENCES];

			if (sequenceCount < MAX_SEQEUENCES)
			{

				BuildSwapSequenceArray(swapSequences, sequenceCount, weapon);

				g_WeaponModelInfo[weaponIndex].SequenceCount = sequenceCount;
				g_WeaponModelInfo[weaponIndex].SwapSequences = swapSequences;
			}
			else
			{
				LogError("View model \"%s\" is having too many sequences! (Max %i, is %i) - Increase value of MAX_SEQEUENCES in plugin",
					g_WeaponModelInfo[weaponIndex].ViewModel,
					MAX_SEQEUENCES,
					sequenceCount);
			}
		}
		else
		{
			for (int i = 0; i < MAX_SEQEUENCES; i++)
			{
				g_WeaponModelInfo[weaponIndex].SwapSequences[i] = -1;
			}

			LogError("Failed to get sequence count for weapon using model \"%s\" - Animations may not work as expected",
				g_WeaponModelInfo[weaponIndex].ViewModel);
		}
	}

	SetEntData(viewModel1, g_iOffset_EntityModelIndex, g_WeaponModelInfo[weaponIndex].ViewModelIndex, _, true);
	SetEntData(viewModel2, g_iOffset_EntityModelIndex, g_WeaponModelInfo[weaponIndex].ViewModelIndex, _, true);
	
	SetEntDataFloat(viewModel2, g_iOffset_ViewModelPlaybackRate, GetEntDataFloat(viewModel1, g_iOffset_ViewModelPlaybackRate), true);

	// FIXME: Why am I calling this?
	ToggleViewModelWeapon(client, viewModel2, weaponIndex);
	
	g_ClientInfo[client].LastSequenceParity = -1;
}

void ToggleViewModelWeapon(int client, int viewModel, int weaponIndex)
{
	int swapWeapon;

	bool toggle = g_ClientInfo[client].ToggleSequence = !g_ClientInfo[client].ToggleSequence;

	if (toggle)
	{
		swapWeapon = EntRefToEntIndex(g_bEconomyWeapons ? g_ClientInfo[client].SwapWeapon : g_WeaponModelInfo[weaponIndex].SwapWeapon);

		if (swapWeapon == -1)
		{
			swapWeapon = CreateSwapWeapon(weaponIndex, client);

			if (g_bEconomyWeapons)
			{
				g_ClientInfo[client].SwapWeapon = EntIndexToEntRef(swapWeapon);
			}
			else
			{
				g_WeaponModelInfo[weaponIndex].SwapWeapon = EntIndexToEntRef(swapWeapon);
			}
		}
	}
	else
	{
		swapWeapon = g_ClientInfo[client].CustomWeapon;
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

	int weapon = g_ClientInfo[client].CustomWeapon;
	if (weapon == 0)
	{
		return;
	}

	int viewModel1 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[0]);
	int viewModel2 = EntRefToEntIndex(g_ClientInfo[client].ViewModels[1]);

	if (viewModel1 == -1 || viewModel2 == -1)
	{
		return;
	}

	if (!g_ClientInfo[client].ViewModelSwapped)
	{
		int currentViewModelIndex = GetEntData(viewModel1, g_iOffset_EntityModelIndex);

		// The view model index has changed, which means the old weapon is holstered, do the view model swap.
		if (currentViewModelIndex != g_ClientInfo[client].HolsteredViewModelIndex)
		{
			g_ClientInfo[client].ViewModelSwapped = true;
			SwapViewModel(client, weapon, viewModel1, viewModel2);
		}
	}
	else
	{
		bool weaponVisible = GetEntityVisibility(weapon);

		// Copy the weapon visiblility state to the secondary view model.
		SetEntityVisibility(viewModel2, weaponVisible);
	}

	int sequence = GetEntData(viewModel1, g_iOffset_ViewModelSequence);

	int drawSequence = -1;
	
	if (g_bPredictedWeaponSwitch)
	{
		drawSequence = g_ClientInfo[client].DrawSequence;
		
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
	if (sequence == g_ClientInfo[client].LastSequence)
	{
		// Skip on weapon switch
		if (g_ClientInfo[client].LastSequenceParity != -1)
		{
			// Skip if sequence hasn't finished
			if (sequenceParity == g_ClientInfo[client].LastSequenceParity)
			{
				return;
			}

			int weaponIndex = g_ClientInfo[client].WeaponIndex;
			int swapSequence = g_WeaponModelInfo[weaponIndex].SwapSequences[sequence];
			
			// Change to swap sequence, if present
			if (swapSequence != -1)
			{
				SetEntData(viewModel1, g_iOffset_ViewModelSequence, swapSequence, _, true);
				SetEntData(viewModel2, g_iOffset_ViewModelSequence, swapSequence, _, true);

				g_ClientInfo[client].LastSequence = swapSequence;
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

			g_ClientInfo[client].DrawSequence = -1;
		}
		
		SetEntData(viewModel2, g_iOffset_ViewModelSequence, sequence, _, true);

		g_ClientInfo[client].LastSequence = sequence;
	}
	
	g_ClientInfo[client].LastSequenceParity = sequenceParity;
}

void InitDataMapOffset(int &offset, int entity, const char[] propName)
{
	if ((offset = FindDataMapInfo(entity, propName)) == -1)
	{
		SetFailState("Fatal Error: Failed to find offset: \"%s\"!", propName);
	}
}