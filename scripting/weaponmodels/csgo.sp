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
 */

void WeaponModels_CSGOInit()
{
	AddCommandListener(Command_LookAtWeapon, "+lookatweapon");

	HookEvent("hostage_follows", Event_HostageFollows);
	HookEvent("weapon_fire", Event_WeaponFire);
}

public Action Command_LookAtWeapon(int client, const char[] command, int numArgs)
{
	if (g_ClientInfo[client].ClientInfo_CustomWeapon)
	{
		int weaponIndex = g_ClientInfo[client].ClientInfo_WeaponIndex;

		if (g_WeaponModelInfo[weaponIndex][WeaponModelInfo_BlockLAW])
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public void Event_HostageFollows(Event event, const char[] eventName, bool dontBrodcast)
{
	int userID = event.GetInt("userid");
	int client = GetClientOfUserId(userID);

	// Prevent the view model from being removed
	SetPlayerViewModel(client, 1, -1);

	RequestFrame(RefreshViewModel, userID);
}

public void RefreshViewModel(any client)
{
	if ((client = GetClientOfUserId(client)) == 0)
	{
		return;
	}

	if (g_ClientInfo[client].ClientInfo_CustomWeapon)
	{
		int viewModel2 = GetPlayerViewModel(client, 1);

		// Remove the view model created by the game
		if (viewModel2 != -1)
		{
			AcceptEntityInput(viewModel2, "Kill");
		}

		SetPlayerViewModel(client, 1, EntRefToEntIndex(g_ClientInfo[client].ClientInfo_ViewModels[1]));
	}
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBrodcast)
{
	static float heatValue[MAXPLAYERS + 1];
	
	float lastSmoke[MAXPLAYERS + 1];

	int client = GetClientOfUserId(event.GetInt("userid"));
	float gameTime = GetGameTime();

	if (g_ClientInfo[client].ClientInfo_CustomWeapon)
	{
		int viewModel2 = EntRefToEntIndex(g_ClientInfo[client].ClientInfo_ViewModels[1]);

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

		int activeWeapon = GetEntDataEnt2(client, g_iOffset_PlayerActiveWeapon);

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