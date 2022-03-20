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

void WeaponModels_ConfigInit()
{
	RegAdminCmd("sm_weaponmodels_reloadconfig", Command_ReloadConfig, ADMFLAG_CONFIG);
}

public Action Command_ReloadConfig(int client, int numArgs)
{
	LoadConfig();

	return Plugin_Handled;
}

void LoadConfig()
{
	char path[PLATFORM_MAX_PATH + 1];
	char buffer[PLATFORM_MAX_PATH + 1];

	BuildPath(Path_SM, path, sizeof(path), "configs/weaponmodels_config.cfg");

	if (FileExists(path))
	{
		KeyValues keyValues = new KeyValues("ViewModelConfig");

		keyValues.ImportFromFile(path);

		if (keyValues.GotoFirstSubKey())
		{
			int nextIndex = 0;

			do
			{
				int weaponIndex = -1;

				for (int i = nextIndex; i < MAX_CUSTOM_WEAPONS; i++)
				{
					// Select indexes of status free or config
					if (g_WeaponModelInfo[i].Status < WeaponModelInfoStatus_API)
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

				keyValues.GetSectionName(buffer, sizeof(buffer));

				int defIndex;

				// Check if string is numeric
				if (StringToIntEx(buffer, defIndex) != strlen(buffer))
				{
					defIndex = -1;

					strcopy(g_WeaponModelInfo[weaponIndex].ClassName, CLASS_NAME_MAX_LENGTH, buffer);
				}
				else if (defIndex < 0)
				{
					LogError("Item definition index %i is invalid (Weapon index %i)", defIndex, weaponIndex + 1);

					continue;
				}

				g_WeaponModelInfo[weaponIndex].DefIndex = defIndex;
				
				keyValues.GetString("ViewModel", g_WeaponModelInfo[weaponIndex].ViewModel, PLATFORM_MAX_PATH + 1);
				keyValues.GetString("WorldModel", g_WeaponModelInfo[weaponIndex].WorldModel, PLATFORM_MAX_PATH + 1);

				PrecacheWeaponInfo(weaponIndex);

				g_WeaponModelInfo[weaponIndex].TeamNum = KvGetNum(keyValues, "TeamNum");
				g_WeaponModelInfo[weaponIndex].BlockLAW = KvGetNum(keyValues, "BlockLAW") > 0;

				g_WeaponModelInfo[weaponIndex].SequenceCount = -1;

				g_WeaponModelInfo[weaponIndex].Status = WeaponModelInfoStatus_Config;

				nextIndex = weaponIndex + 1;
			}
			while (keyValues.GotoNextKey());
		}

		keyValues.Close();
	}
	else
	{
		SetFailState("Failed to open config file: \"%s\"!", path);
	}

	BuildPath(Path_SM, path, sizeof(path), "configs/weaponmodels_downloadlist.cfg");

	File file = OpenFile(path, "r");

	if (file != INVALID_HANDLE)
	{
		while (!file.EndOfFile() && file.ReadLine(buffer, sizeof(buffer)))
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

		file.Close();
	}
	else
	{
		LogError("Failed to open config file: \"%s\" !", path);
	}
}
