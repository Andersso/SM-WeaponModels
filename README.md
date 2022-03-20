Weapon Models plugin for SourceMod
===============

This is a SourceMod plugin which allows you to change both world and view model of any weapon server-side. The plugin provides both a config file and a simple but powerful [API](#how-to-use-the-api) for adding custom weapon models.

Changing the view model is not intended to be possible server-side, and therefore a bunch of dirty hacks need to be done in order for this to be achieved. See [Requirements](#requirements)

## List of compatible games
 * **Counter-Strike: Source**
 * **Counter-Strike: Global Offensive** - *Arm model also needs to be included in custom view model*
 * **Day of Defeat: Source**
 * **Half-Life 2: Deathmatch** - *Untested, but is expected to work*
 * **Team-Fortress 2** - *Not recommended, see [Custom Weapons](https://forums.alliedmods.net/showthread.php?p=2105924) plugin instead.*
 * **No More Room in Hell** - Thanks zeThijs!

## Requirements
 * SourceMod 1.10 or higher
 * A view model should work optimally if these requirements are met:
   * Matching activities used by the original model
   * More than one fire animation
   * Contains an arm model (CS:GO)

## Adding a custom model in config
The config file is located in the SourceMod config directory and is named weaponmodels_config.cfg

Inside the config you should find a key named "ViewModelConfig". Inside this key, add the following:
```
"<classname or item definition index>"
{
	"ViewModel" "<path to view model>"
	"WorldModel" "<path to world model>"

	"TeamNum" "<Team index>" // This will only allow the specified team to use the custom weapon. Teams index is usually 2 or 3
	"BlockLAW" "<1/0>" // This will block the look at weapon key in CS:GO, which may otherwise bug the view model
}
```
*Note that you can just leave out any of the keys you wish not to use*

Here is an example
```
"weapon_knife"
{
	"ViewModel" "models/weapons/v_my_custom_knife.mdl"
	"WorldModel" "models/weapons/w_my_custom_knife.mdl"

	"BlockLAW" "1" 
}
```
### List of weapons, Classnames and item definition indexes
 * [Counter-Strike: Source](#list-of-weapons---css)
 * [Counter-Strike: Global Offensive](#list-of-weapons---csgo)
 * [Day of Defeat: Source](#list-of-weapons---dods)
 * [Half-Life 2: Deathmatch](#list-of-weapons---hl2dm)
 * [Team-Fortress 2](#list-of-weapons---tf2)
 * [No More Room in Hell](#list-of-weapons---nmrih)

## How to use the API

The API consists of these natives:
```PAWN
native WeaponModels_AddWeaponByClassName(const String:className[], const String:viewModel[], const String:worldModel[], WeaponModelsFunc:function);
native WeaponModels_AddWeaponByItemDefIndex(itemDefIndex, const String:viewModel[], const String:worldModel[], WeaponModelsFunc:function);
native WeaponModels_RemoveWeaponModel(weaponIndex);
```
*Full documentation of the natives can be found [here](scripting/include/weaponmodels.inc#L51)*

Here is an example
```PAWN
#pragma semicolon 1
#include <sourcemod>

// Don't forget the weaponmodels include!
#include <weaponmodels>

public void OnMapStart()
{
	WeaponModels_AddWeaponByClassName("weapon_knife", "models/weapons/v_my_custom_knife.mdl", NULL_STRING, WeaponModels_OnWeapon);
	
	// The item def index of the M4A1-S in CS:GO is 60
	WeaponModels_AddWeaponByItemDefIndex(60, "models/weapons/v_my_custom_m4a1s.mdl", "models/weapons/w_my_custom_m4a1s.mdl", WeaponModels_OnWeapon);
}

// Don't forget you can both share or have individual callbacks for weapons. In this case we share the callback
public bool WeaponModels_OnWeapon(int weaponIndex, int client, int weapon, const char[] className, int itemDefIndex)
{
	AdminId adminId = GetUserAdmin(client);

	// Player has an invalid admin id, don't show weapon
	if (adminId == INVALID_ADMIN_ID)
	{
		return false;
	}

	// Player is missing the specified admin flags, don't show weapon
	if (!(GetAdminFlags(adminId) & ADMFLAG_KICK|ADMFLAG_SLAY))
	{
		return false;
	}

	// All conditions have passed, show the weapon!
	return true;
}
```

## List of weapons - CS:S
*Some weapons may be missing or invalid*

Name | Classname
--- | ---
Glock 18 | weapon_glock
USP | weapon_usp
P228 | weapon_p228
Desert Eagle | weapon_deagle 
Dual Elites | weapon_elite 
Five-seveN | weapon_fiveseven 
M3 | weapon_m3 
XM1014 | weapon_xm1014 
Galil | weapon_galil 
AK47 | weapon_ak47 
Scout | weapon_scout 
SG552 | weapon_sg552 
AWP | weapon_awp 
G3SG1 | weapon_gs3g1 
FAMAS | weapon_famas 
M4A1 | weapon_m4a1 
AUG | weapon_aug 
SG550 | weapon_sg550 
MAC-10 | weapon_mac10 
TMP | weapon_tmp 
MP5 Navy | weapon_mp5navy 
UMP-45 | weapon_ump45 
P90 | weapon_p90 
M249 | weapon_m249
Flashbang | weapon_flashbang 
High Explosive Grenade | weapon_hegrenade 
Smoke Grenade | weapon_smokegrenade 
C4 Explosive | weapon_c4

## List of weapons - CS:GO
*Some weapons may be missing or invalid*

Name | Classname | Item definition index 
--- | --- | ---
Desert Eagle | weapon_deagle | 1
Dual Berettas | weapon_elite | 2
Five-SeveN | weapon_fiveseven | 3
Glock-18 | weapon_glock | 4
AK-47 | weapon_ak47 | 7
AUG | weapon_aug | 8
AWP | weapon_awp | 9
FAMAS | weapon_famas | 10
G3SG1 | weapon_g3sg1 | 11
Galil AR | weapon_galilar | 13
M249 | weapon_m249 | 14
M4A4 | weapon_m4a1 | 16
MAC-10 | weapon_mac10 | 17
P90 | weapon_p90 | 19
UMP-45 | weapon_ump45 | 24
XM1014 | weapon_xm1014 | 25
PP-Bizon | weapon_bizon | 26
MAG-7 | weapon_mag7 | 27
Negev | weapon_negev | 28
Sawed-Off | weapon_sawedoff | 29
Tec-9 | weapon_tec9 | 30
Zeus x27 | weapon_taser | 31
P2000 | weapon_hkp2000 | 32
MP7 | weapon_mp7 | 33
MP9 | weapon_mp9 | 34
Nova | weapon_nova | 35
P250 | weapon_p250 | 36
SCAR-20 | weapon_scar20 | 38
SG 553 | weapon_sg556 | 39
SSG 08 | weapon_ssg08 | 40
Knife | weapon_knife | 42
Flashbang | weapon_flashbang | 43
High Explosive Grenade | weapon_hegrenade | 44
Smoke Grenade | weapon_smokegrenade | 45
Molotov | weapon_molotov | 46
Decoy Grenade | weapon_decoy | 47
Incendiary Grenade | weapon_incgrenade | 48
C4 Explosive | weapon_c4 | 49
Knife | weapon_knife | 59
M4A1-S | weapon_m4a1 | 60
USP-S | weapon_hkp2000 | 61
CZ75-Auto | weapon_p250 | 63
Bayonet | weapon_knife | 500
Flip Knife | weapon_knife | 505
Gut Knife | weapon_knife | 506
Karambit | weapon_knife | 507
M9 Bayonet | weapon_knife | 508
Huntsman Knife | weapon_knife | 509

## List of weapons - DoD:S
*Some weapons may be missing or invalid*

Name | Classname
--- | ---
Spade | weapon_spade
Knife | weapon_amerknife
C96 | weapon_c96
P38 | weapon_p38
Colt | weapon_colt
BAR | weapon_bar
Thompson | weapon_thompson
M1 Carbine | weapon_m1carbine
MP40 | weapon_mp40
STG 44 | weapon_mp44
Bazooka | weapon_bazooka
Panzerschreck | weapon_pschreck
M1 Garand | weapon_garand
K98 | weapon_k98
K98 Scoped | weapon_k98_scoped
Springfield | weapon_spring
MG42 | weapon_mg42
30 Cal | weapon_30cal
Frag Grenade GER | weapon_frag_ger
Frag Grenade US | weapon_frag_us
Smoke grenade GER | weapon_smoke_ger
Smoke grenade US | weapon_smoke_us
Riflegren US | weapon_riflegren_us
Riflegren GER | weapon_riflegren_ger

## List of weapons - HL2:DM
*Some weapons may be missing or invalid*

Name | Classname
--- | ---
Crowbar | weapon_crowbar
Pistol | weapon_pistol
SMG1 | weapon_smg1
.357 Magnum | weapon_357
Gravity gun | weapon_physcannon
Shotgun | weapon_shotgun
AR2 | weapon_ar2
RPG | weapon_rpg
Frag grenade | weapon_frag
Crossbow | weapon_crossbow
Bugbait | weapon_bugbait 

## List of weapons - TF2
*Some weapons may be missing or invalid*

Name | Classname | Item definition index 
--- | --- | ---
Bat | tf_weapon_bat | 0
Bottle | tf_weapon_bottle | 1
Fire Axe | tf_weapon_fireaxe | 2
Kukri | tf_weapon_club | 3
Knife | tf_weapon_knife | 4
Fists | tf_weapon_fists | 5
Shovel | tf_weapon_shovel | 6
Wrench | tf_weapon_wrench | 7
Bonesaw | tf_weapon_bonesaw | 8
Shotgun | tf_weapon_shotgun | 9
Shotgun | tf_weapon_shotgun | 10
Shotgun | tf_weapon_shotgun | 11
Shotgun | tf_weapon_shotgun | 12
Scattergun | tf_weapon_scattergun | 13
Sniper Rifle | tf_weapon_sniperrifle | 14
Minigun | tf_weapon_minigun | 15
SMG | tf_weapon_smg | 16
Syringe Gun | tf_weapon_syringegun_medic | 17
Rocket Launcher | tf_weapon_rocketlauncher | 18
Grenade Launcher | tf_weapon_grenadelauncher | 19
Stickybomb Launcher | tf_weapon_pipebomblauncher | 20
Flame Thrower | tf_weapon_flamethrower | 21
Pistol | tf_weapon_pistol | 22
Pistol | tf_weapon_pistol | 23
Revolver | tf_weapon_revolver | 24
Construction PDA | tf_weapon_pda_engineer_build | 25
Destruction PDA | tf_weapon_pda_engineer_destroy | 26
Disguise Kit | tf_weapon_pda_spy | 27
PDA | tf_weapon_builder | 28
Medi Gun | tf_weapon_medigun | 29
Invis Watch | tf_weapon_invis | 30
Kritzkrieg | tf_weapon_medigun | 35
Blutsauger | tf_weapon_syringegun_medic | 36
Ubersaw | tf_weapon_bonesaw | 37
Axtinguisher | tf_weapon_fireaxe | 38
Flare Gun | tf_weapon_flaregun | 39
Backburner | tf_weapon_flamethrower | 40
Natascha | tf_weapon_minigun | 41
Sandvich | tf_weapon_lunchbox | 42
Killing Gloves of Boxing | tf_weapon_fists | 43
Sandman | tf_weapon_bat_wood | 44
Force-A-Nature | tf_weapon_scattergun | 45
Bonk! Atomic Punch | tf_weapon_lunchbox_drink | 46
Huntsman | tf_weapon_compound_bow | 56
Jarate | tf_weapon_jar | 58
Dead Ringer | tf_weapon_invis | 59
Cloak and Dagger | tf_weapon_invis | 60
Ambassador | tf_weapon_revolver | 61
Direct Hit | tf_weapon_rocketlauncher_directhit | 127
Equalizer | tf_weapon_shovel | 128
Buff Banner | tf_weapon_buff_item | 129
Scottish Resistance | tf_weapon_pipebomblauncher | 130
Eyelander | tf_weapon_sword | 132
Wrangler | tf_weapon_laser_pointer | 140
Frontier Justice | tf_weapon_sentry_revenge | 141
Gunslinger | tf_weapon_robot_arm | 142
Homewrecker | tf_weapon_fireaxe | 153
Pain Train | tf_weapon_shovel | 154
Southern Hospitality | tf_weapon_wrench | 155
Dalokohs Bar | tf_weapon_lunchbox | 159
Lugermorph | tf_weapon_pistol | 160
Big Kill | tf_weapon_revolver | 161
Crit-a-Cola | tf_weapon_lunchbox_drink | 163
Golden Wrench | tf_weapon_wrench | 169
Tribalman's Shiv | tf_weapon_club | 171
Scotsman's Skullcutter | tf_weapon_sword | 172
Vita-Saw | tf_weapon_bonesaw | 173
Bat | tf_weapon_bat | 190
Bottle | tf_weapon_bottle | 191
Fire Axe | tf_weapon_fireaxe | 192
Kukri | tf_weapon_club | 193
Knife | tf_weapon_knife | 194
Fists | tf_weapon_fists | 195
Shovel | tf_weapon_shovel | 196
Wrench | tf_weapon_wrench | 197
Bonesaw | tf_weapon_bonesaw | 198
Shotgun | tf_weapon_shotgun | 199
Scattergun | tf_weapon_scattergun | 200
Sniper Rifle | tf_weapon_sniperrifle | 201
Minigun | tf_weapon_minigun | 202
SMG | tf_weapon_smg | 203
Syringe Gun | tf_weapon_syringegun_medic | 204
Rocket Launcher | tf_weapon_rocketlauncher | 205
Grenade Launcher | tf_weapon_grenadelauncher | 206
Stickybomb Launcher | tf_weapon_pipebomblauncher | 207
Flame Thrower | tf_weapon_flamethrower | 208
Pistol | tf_weapon_pistol | 209
Revolver | tf_weapon_revolver | 210
Medi Gun | tf_weapon_medigun | 211
Invis Watch | tf_weapon_invis | 212
Powerjack | tf_weapon_fireaxe | 214
Degreaser | tf_weapon_flamethrower | 215
Shortstop | tf_weapon_handgun_scout_primary | 220
Holy Mackerel | tf_weapon_bat_fish | 221
Mad Milk | tf_weapon_jar_milk | 222
L'Etranger | tf_weapon_revolver | 224
Your Eternal Reward | tf_weapon_knife | 225
Battalion's Backup | tf_weapon_buff_item | 226
Black Box | tf_weapon_rocketlauncher | 228
Sydney Sleeper | tf_weapon_sniperrifle | 230
Bushwacka | tf_weapon_club | 232
Rocket Jumper | tf_weapon_rocketlauncher | 237
Gloves of Running Urgently | tf_weapon_fists | 239
Sticky Jumper | tf_weapon_pipebomblauncher | 265
Horseless Headless Horsemann's Headtaker | tf_weapon_sword | 266
Lugermorph | tf_weapon_pistol | 294
Enthusiast's Timepiece | tf_weapon_invis | 297
Iron Curtain | tf_weapon_minigun | 298
Amputator | tf_weapon_bonesaw | 304
Crusader's Crossbow | tf_weapon_crossbow | 305
Ullapool Caber | tf_weapon_stickbomb | 307
Loch-n-Load | tf_weapon_grenadelauncher | 308
Warrior's Spirit | tf_weapon_fists | 310
Buffalo Steak Sandvich | tf_weapon_lunchbox | 311
Brass Beast | tf_weapon_minigun | 312
Candy Cane | tf_weapon_bat | 317
Boston Basher | tf_weapon_bat | 325
Back Scratcher | tf_weapon_fireaxe | 326
Claidheamh Mòr | tf_weapon_sword | 327
Jag | tf_weapon_wrench | 329
Fists of Steel | tf_weapon_fists | 331
Sharpened Volcano Fragment | tf_weapon_fireaxe | 348
Sun-on-a-Stick | tf_weapon_bat | 349
Detonator | tf_weapon_flaregun | 351
Concheror | tf_weapon_buff_item | 354
Fan O'War | tf_weapon_bat | 355
Conniver's Kunai | tf_weapon_knife | 356
Half-Zatoichi | tf_weapon_katana | 357
Shahanshah | tf_weapon_club | 401
Bazaar Bargain | tf_weapon_sniperrifle_decap | 402
Persian Persuader | tf_weapon_sword | 404
Quick-Fix | tf_weapon_medigun | 411
Overdose | tf_weapon_syringegun_medic | 412
Solemn Vow | tf_weapon_bonesaw | 413
Liberty Launcher | tf_weapon_rocketlauncher | 414
Reserve Shooter | tf_weapon_shotgun | 415
Market Gardener | tf_weapon_shovel | 416
Tomislav | tf_weapon_minigun | 424
Family Business | tf_weapon_shotgun | 425
Eviction Notice | tf_weapon_fists | 426
Fishcake | tf_weapon_lunchbox | 433
Cow Mangler 5000 | tf_weapon_particle_cannon | 441
Righteous Bison | tf_weapon_raygun | 442
Disciplinary Action | tf_weapon_shovel | 447
Soda Popper | tf_weapon_soda_popper | 448
Winger | tf_weapon_handgun_scout_secondary | 449
Atomizer | tf_weapon_bat | 450
Three-Rune Blade | tf_weapon_bat | 452
Postal Pummeler | tf_weapon_fireaxe | 457
Enforcer | tf_weapon_revolver | 460
Big Earner | tf_weapon_knife | 461
Maul | tf_weapon_fireaxe | 466
Nessie's Nine Iron | tf_weapon_sword | 482
Original | tf_weapon_rocketlauncher | 513
Diamondback | tf_weapon_revolver | 525
Machina | tf_weapon_sniperrifle | 526
Widowmaker | tf_weapon_shotgun_primary | 527
Short Circuit | tf_weapon_mechanical_arm | 528
Unarmed Combat | tf_weapon_bat_fish | 572
Wanga Prick | tf_weapon_knife | 574
Apoco-Fists | tf_weapon_fists | 587
Pomson 6000 | tf_weapon_drg_pomson | 588
Eureka Effect | tf_weapon_wrench | 589
Third Degree | tf_weapon_fireaxe | 593
Phlogistinator | tf_weapon_flamethrower | 594
Manmelter | tf_weapon_flaregun_revenge | 595
Scottish Handshake | tf_weapon_bottle | 609
Sharp Dresser | tf_weapon_knife | 638
Wrap Assassin | tf_weapon_bat_giftwrap | 648
Spy-cicle | tf_weapon_knife | 649
Festive Minigun | tf_weapon_minigun | 654
Holiday Punch | tf_weapon_fists | 656
Festive Rocket Launcher | tf_weapon_rocketlauncher | 658
Festive Flame Thrower | tf_weapon_flamethrower | 659
Festive Bat | tf_weapon_bat | 660
Festive Stickybomb Launcher | tf_weapon_pipebomblauncher | 661
Festive Wrench | tf_weapon_wrench | 662
Festive Medi Gun | tf_weapon_medigun | 663
Festive Sniper Rifle | tf_weapon_sniperrifle | 664
Festive Knife | tf_weapon_knife | 665
Festive Scattergun | tf_weapon_scattergun | 669
Black Rose | tf_weapon_knife | 727
Beggar's Bazooka | tf_weapon_rocketlauncher | 730
Sapper | tf_weapon_builder | 735
Sapper | tf_weapon_builder | 736
Construction PDA | tf_weapon_pda_engineer_build | 737
Lollichop | tf_weapon_fireaxe | 739
Scorch Shot | tf_weapon_flaregun | 740
Rainblower | tf_weapon_flamethrower | 741
Cleaner's Carbine | tf_weapon_smg | 751
Hitman's Heatmaker | tf_weapon_sniperrifle | 752
Baby Face's Blaster | tf_weapon_pep_brawler_blaster | 772
Pretty Boy's Pocket Pistol | tf_weapon_handgun_scout_secondary | 773
Escape Plan | tf_weapon_shovel | 775
Silver Botkiller Sniper Rifle Mk.I | tf_weapon_sniperrifle | 792
Silver Botkiller Minigun Mk.I | tf_weapon_minigun | 793
Silver Botkiller Knife Mk.I | tf_weapon_knife | 794
Silver Botkiller Wrench Mk.I | tf_weapon_wrench | 795
Silver Botkiller Medi Gun Mk.I | tf_weapon_medigun | 796
Silver Botkiller Stickybomb Launcher Mk.I | tf_weapon_pipebomblauncher | 797
Silver Botkiller Flame Thrower Mk.I | tf_weapon_flamethrower | 798
Silver Botkiller Scattergun Mk.I | tf_weapon_scattergun | 799
Silver Botkiller Rocket Launcher Mk.I | tf_weapon_rocketlauncher | 800
Gold Botkiller Sniper Rifle Mk.I | tf_weapon_sniperrifle | 801
Gold Botkiller Minigun Mk.I | tf_weapon_minigun | 802
Gold Botkiller Knife Mk.I | tf_weapon_knife | 803
Gold Botkiller Wrench Mk.I | tf_weapon_wrench | 804
Gold Botkiller Medi Gun Mk.I | tf_weapon_medigun | 805
Gold Botkiller Stickybomb Launcher Mk.I | tf_weapon_pipebomblauncher | 806
Gold Botkiller Flame Thrower Mk.I | tf_weapon_flamethrower | 807
Gold Botkiller Scattergun Mk.I | tf_weapon_scattergun | 808
Gold Botkiller Rocket Launcher Mk.I | tf_weapon_rocketlauncher | 809
Red-Tape Recorder | tf_weapon_sapper | 810
Huo-Long Heater | tf_weapon_minigun | 811
Flying Guillotine | tf_weapon_cleaver | 812
Neon Annihilator | tf_weapon_fireaxe | 813
Red-Tape Recorder | tf_weapon_sapper | 831
Huo-Long Heater | tf_weapon_minigun | 832
Flying Guillotine | tf_weapon_cleaver | 833
Neon Annihilator | tf_weapon_fireaxe | 834
Deflector | tf_weapon_minigun | 850
AWPer Hand | tf_weapon_sniperrifle | 851
Robo-Sandvich | tf_weapon_lunchbox | 863
Rust Botkiller Sniper Rifle Mk.I | tf_weapon_sniperrifle | 881
Rust Botkiller Minigun Mk.I | tf_weapon_minigun | 882
Rust Botkiller Knife Mk.I | tf_weapon_knife | 883
Rust Botkiller Wrench Mk.I | tf_weapon_wrench | 884
Rust Botkiller Medi Gun Mk.I | tf_weapon_medigun | 885
Rust Botkiller Stickybomb Launcher Mk.I | tf_weapon_pipebomblauncher | 886
Rust Botkiller Flame Thrower Mk.I | tf_weapon_flamethrower | 887
Rust Botkiller Scattergun Mk.I | tf_weapon_scattergun | 888
Rust Botkiller Rocket Launcher Mk.I | tf_weapon_rocketlauncher | 889
Blood Botkiller Sniper Rifle Mk.I | tf_weapon_sniperrifle | 890
Blood Botkiller Minigun Mk.I | tf_weapon_minigun | 891
Blood Botkiller Knife Mk.I | tf_weapon_knife | 892
Blood Botkiller Wrench Mk.I | tf_weapon_wrench | 893
Blood Botkiller Medi Gun Mk.I | tf_weapon_medigun | 894
Blood Botkiller Stickybomb Launcher Mk.I | tf_weapon_pipebomblauncher | 895
Blood Botkiller Flame Thrower Mk.I | tf_weapon_flamethrower | 896
Blood Botkiller Scattergun Mk.I | tf_weapon_scattergun | 897
Blood Botkiller Rocket Launcher Mk.I | tf_weapon_rocketlauncher | 898
Carbonado Botkiller Sniper Rifle Mk.I | tf_weapon_sniperrifle | 899
Carbonado Botkiller Minigun Mk.I | tf_weapon_minigun | 900
Carbonado Botkiller Knife Mk.I | tf_weapon_knife | 901
Carbonado Botkiller Wrench Mk.I | tf_weapon_wrench | 902
Carbonado Botkiller Medi Gun Mk.I | tf_weapon_medigun | 903
Carbonado Botkiller Stickybomb Launcher Mk.I | tf_weapon_pipebomblauncher | 904
Carbonado Botkiller Flame Thrower Mk.I | tf_weapon_flamethrower | 905
Carbonado Botkiller Scattergun Mk.I | tf_weapon_scattergun | 906
Carbonado Botkiller Rocket Launcher Mk.I | tf_weapon_rocketlauncher | 907
Diamond Botkiller Sniper Rifle Mk.I | tf_weapon_sniperrifle | 908
Diamond Botkiller Minigun Mk.I | tf_weapon_minigun | 909
Diamond Botkiller Knife Mk.I | tf_weapon_knife | 910
Diamond Botkiller Wrench Mk.I | tf_weapon_wrench | 911
Diamond Botkiller Medi Gun Mk.I | tf_weapon_medigun | 912
Diamond Botkiller Stickybomb Launcher Mk.I | tf_weapon_pipebomblauncher | 913
Diamond Botkiller Flame Thrower Mk.I | tf_weapon_flamethrower | 914
Diamond Botkiller Scattergun Mk.I | tf_weapon_scattergun | 915
Diamond Botkiller Rocket Launcher Mk.I | tf_weapon_rocketlauncher | 916
Ap-Sap | tf_weapon_sapper | 933
Quäckenbirdt | tf_weapon_invis | 947
Silver Botkiller Sniper Rifle Mk.II | tf_weapon_sniperrifle | 957
Silver Botkiller Minigun Mk.II | tf_weapon_minigun | 958
Silver Botkiller Knife Mk.II | tf_weapon_knife | 959
Silver Botkiller Wrench Mk.II | tf_weapon_wrench | 960
Silver Botkiller Medi Gun Mk.II | tf_weapon_medigun | 961
Silver Botkiller Stickybomb Launcher Mk.II | tf_weapon_pipebomblauncher | 962
Silver Botkiller Flame Thrower Mk.II | tf_weapon_flamethrower | 963
Silver Botkiller Scattergun Mk.II | tf_weapon_scattergun | 964
Silver Botkiller Rocket Launcher Mk.II | tf_weapon_rocketlauncher | 965
Gold Botkiller Sniper Rifle Mk.II | tf_weapon_sniperrifle | 966
Gold Botkiller Minigun Mk.II | tf_weapon_minigun | 967
Gold Botkiller Knife Mk.II | tf_weapon_knife | 968
Gold Botkiller Wrench Mk.II | tf_weapon_wrench | 969
Gold Botkiller Medi Gun Mk.II | tf_weapon_medigun | 970
Gold Botkiller Stickybomb Launcher Mk.II | tf_weapon_pipebomblauncher | 971
Gold Botkiller Flame Thrower Mk.II | tf_weapon_flamethrower | 972
Gold Botkiller Scattergun Mk.II | tf_weapon_scattergun | 973
Gold Botkiller Rocket Launcher Mk.II | tf_weapon_rocketlauncher | 974
Loose Cannon | tf_weapon_cannon | 996
Rescue Ranger | tf_weapon_shotgun_building_rescue | 997
Vaccinator | tf_weapon_medigun | 998
Festive Holy Mackerel | tf_weapon_bat_fish | 999
Festive Axtinguisher | tf_weapon_fireaxe | 1000
Festive Buff Banner | tf_weapon_buff_item | 1001
Festive Sandvich | tf_weapon_lunchbox | 1002
Festive Ubersaw | tf_weapon_bonesaw | 1003
Festive Frontier Justice | tf_weapon_sentry_revenge | 1004
Festive Huntsman | tf_weapon_compound_bow | 1005
Festive Ambassador | tf_weapon_revolver | 1006
Festive Grenade Launcher | tf_weapon_grenadelauncher | 1007
Fancy Spellbook | tf_weapon_spellbook | 1069
Spellbook Magazine | tf_weapon_spellbook | 1070
Festive Force-A-Nature | tf_weapon_scattergun | 1078
Festive Crusader's Crossbow | tf_weapon_crossbow | 1079
Festive Sapper | tf_weapon_sapper | 1080
Festive Flare Gun | tf_weapon_flaregun | 1081
Festive Eyelander | tf_weapon_sword | 1082
Festive Jarate | tf_weapon_jar | 1083
Festive Gloves of Running Urgently | tf_weapon_fists | 1084
Festive Black Box | tf_weapon_rocketlauncher | 1085
Festive Wrangler | tf_weapon_laser_pointer | 1086
Fortified Compound | tf_weapon_compound_bow | 1092
Classic | tf_weapon_sniperrifle_classic | 1098
Bread Bite | tf_weapon_fists | 1100
B.A.S.E. Jumper | tf_weapon_parachute | 1101
Snack Attack | tf_weapon_sapper | 1102
Back Scatter | tf_weapon_scattergun | 1103
Air Strike | tf_weapon_rocketlauncher_airstrike | 1104
Self-Aware Beauty Mark | tf_weapon_jar | 1105
Mutated Milk | tf_weapon_jar_milk | 1121
Fireproof Secret Diary | tf_weapon_spellbook | 5605

## List of weapons - NMRIH
*Some weapons may be missing or invalid*

#### Handguns:

Name | Classname
--- | ---
Colt 1911 | fa_1911
Glock 17 | fa_glock17
Strum Ruger MK III | fa_mkiii
S&W 686-6 | fa_sw686
Beretta M92FS | fa_m92fs

#### Rifles:

Name | Classname
--- | ---
Ruger 10/22 | fa_1022
Ruger 10/22 ( 25 Bullets ) | fa_1022_25mag
CZ858 | fa_cz858
Sako 85 | fa_sako85
Sako 85 ( No Ironsight ) | fa_sako85_ironsights
Simonov SKS | fa_sks
Simonov SKS (No Bayonet) | fa_sks_nobayo
Remington JAE-700 | fa_jae700

#### Shotguns:

Name | Classname
--- | ---
Mossberg 500A | fa_500a
Remington 870 Police Magnum | fa_870
Winchester Super X3 | fa_superx3
SV-10 | fa_sv10
Winchester 1892 | fa_winchester1892

#### Machineguns:

Name | Classname
--- | ---
Mac-10 | fa_mac10

#### Military:

Name | Classname
--- | ---
MP5A4 | fa_mp5a3
M16A4 (ACOG + Handle) | fa_m16a4
FN-FAL | fa_fnfal
M16A4 (Pure) | fa_m16a4_carryhandle 

#### Archery:

Name | Classname
--- | ---
PSE Deer Hunter | bow_deerhunter

#### Melees:

Name | Classname
--- | ---
Abrasive Saw | me_abrasivesaw
Fire Axe | me_axe_fire
Baseball Bat | me_bat_metal
Chainsaw | me_chainsaw
Cleaver | me_cleaver
Crowbar | me_crowbar
E-Tool | me_etool
FUBAR | me_fubar
Hatchet | me_hatchet
Kitchen Knife | me_kitknife
Machete | me_machete
Pickaxe | me_pickaxe
Pipe | me_pipe_lead
Shovel | me_shovel
Sledgehammer | me_sledge
Wrench | me_wrench

#### Explosives:

Name | Classname
--- | ---
Grenade | exp_grenade
Molotov | exp_molotov
TNT | exp_tnt

#### Items:

Name | Classname
--- | ---
Barricade Hammer | tool_barricade
Fire Extinguisher | tool_extinguisher
Flare Gun | tool_flare_gun
Welder | tool_welder
Bandages | item_bandages
First Aid | item_first_aid
Maglite (Flashlight) | item_maglite
Pills | item_pills
Walkie Talkie | item_walkietalkie
Zippo Lighter | item_zippo
Gene Therapy | item_gene_therapy
