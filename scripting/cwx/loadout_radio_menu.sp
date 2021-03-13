/**
 * This file deals with the radio menu-based interface for equipping weapons.
 */

static Menu s_LoadoutSlotMenu;

// Menu containing our list of items.  This is initalized once, then items are modified
// depending on which ones the player is browsing at the time.
static Menu s_EquipMenu;

static int g_iPlayerClassInMenu[MAXPLAYERS + 1];
static int g_iPlayerSlotInMenu[MAXPLAYERS + 1];

/**
 * Localized player class names, in TFClassType order.  Used in CWX's translation file.
 */
char g_LocalizedPlayerClass[][] = {
	"TF_Class_Name_Undefined",
	"TF_Class_Name_Scout",
	"TF_Class_Name_Sniper",
	"TF_Class_Name_Soldier",
	"TF_Class_Name_Demoman",
	"TF_Class_Name_Medic",
	"TF_Class_Name_HWGuy",
	"TF_Class_Name_Pyro",
	"TF_Class_Name_Spy",
	"TF_Class_Name_Engineer",
};

/**
 * Localized loadout slot names, in loadout slot order.
 */
char g_LocalizedLoadoutSlots[][] = {
	"LoadoutSlot_Primary",
	"LoadoutSlot_Secondary",
	"LoadoutSlot_Melee",
	"LoadoutSlot_Utility",
	"LoadoutSlot_Building",
	"LoadoutSlot_pda",
	"LoadoutSlot_pda2",
	"LoadoutSlot_PrimaryMod",
	"LoadoutSlot_Head",
	"LoadoutSlot_Misc",
	"LoadoutSlot_Action",
	"LoadoutSlot_Taunt",
	"LoadoutSlot_Taunt2",
	"LoadoutSlot_Taunt3",
	"LoadoutSlot_Taunt4",
	"LoadoutSlot_Taunt5",
	"LoadoutSlot_Taunt6",
	"LoadoutSlot_Taunt7",
	"LoadoutSlot_Taunt8",
	"LoadoutSlot_TauntSlot",
};

/**
 * Command callback to display items to a player.
 */
Action DisplayItems(int client, int argc) {
	g_iPlayerClassInMenu[client] = view_as<int>(TF2_GetPlayerClass(client));
	s_LoadoutSlotMenu.Display(client, 30);
	return Plugin_Handled;
}

/**
 * Initializes our loadout slot selection menu.
 * 
 * This must be called after all plugins are loaded, since we depend on Econ Data.
 */
void BuildLoadoutSlotMenu() {
	delete s_LoadoutSlotMenu;
	s_LoadoutSlotMenu = new Menu(OnLoadoutSlotMenuEvent,
			MENU_ACTIONS_DEFAULT | MenuAction_Display | MenuAction_DisplayItem);
	
	for (int i; i < 3; i++) {
		char name[32];
		TF2Econ_TranslateLoadoutSlotIndexToName(i, name, sizeof(name));
		s_LoadoutSlotMenu.AddItem(name, name);
	}
}

/**
 * Initializes the weapon list menu used for players to equip weapons.
 * Should be called when the custom item schema is reset.
 * 
 * Visibility of an item is determined based on currently browsed class / weapon slot
 * (see `ItemVisibleInEquipMenu` and `OnEquipMenuEvent->MenuAction_DrawItem`).
 */
void BuildEquipMenu() {
	delete s_EquipMenu;
	
	if (!g_CustomItemConfig.GotoFirstSubKey()) {
		return;
	}
	
	s_EquipMenu = new Menu(OnEquipMenuEvent, MENU_ACTIONS_ALL);
	s_EquipMenu.ExitBackButton = true;
	
	s_EquipMenu.AddItem("", "[Unequip custom weapon]");
	
	do {
		// iterate over subsections and add name / uid pair to menu
		char uid[MAX_ITEM_IDENTIFIER_LENGTH];
		char name[128];
		
		g_CustomItemConfig.GetSectionName(uid, sizeof(uid));
		g_CustomItemConfig.GetString("name", name, sizeof(name));
		
		s_EquipMenu.AddItem(uid, name);
	} while (g_CustomItemConfig.GotoNextKey());
	g_CustomItemConfig.Rewind();
}

/**
 * Determines visibility of items in the loadout menu.
 */
static bool ItemVisibleInEquipMenu(int client, const char[] uid) {
	TFClassType playerClass = TF2_GetPlayerClass(client);
	int position[NUM_PLAYER_CLASSES];
	
	// not visible for current submenu
	s_EquipLoadoutPosition.GetArray(uid, position, sizeof(position));
	if (position[playerClass] != g_iPlayerSlotInMenu[client]) {
		return false;
	}
	
	// visible for submenu, but player can't equip it
	return CanPlayerEquipItem(client, uid);
}

/**
 * Handles the loadout slot menu.
 */
int OnLoadoutSlotMenuEvent(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		/**
		 * Sets the menu header for the current section.
		 */
		case MenuAction_Display: {
			int client = param1;
			Panel panel = view_as<any>(param2);
			
			SetGlobalTransTarget(client);
			
			char buffer[64];
			FormatEx(buffer, sizeof(buffer), "Custom Weapons X");
			
			panel.SetTitle(buffer);
			
			SetGlobalTransTarget(LANG_SERVER);
		}
		
		/**
		 * Reads the selected loadout slot and displays the weapon selection menu.
		 */
		case MenuAction_Select: {
			int client = param1;
			int position = param2;
			
			char loadoutSlot[32];
			menu.GetItem(position, loadoutSlot, sizeof(loadoutSlot));
			
			g_iPlayerSlotInMenu[client] = TF2Econ_TranslateLoadoutSlotNameToIndex(loadoutSlot);
			s_EquipMenu.Display(client, 30);
		}
		
		/**
		 * Renders the native loadout slot name for the client.
		 */
		case MenuAction_DisplayItem: {
			int client = param1;
			int position = param2;
			
			char loadoutSlotName[64];
			menu.GetItem(position, loadoutSlotName, sizeof(loadoutSlotName));
			
			SetGlobalTransTarget(client);
			int loadoutSlot = TF2Econ_TranslateLoadoutSlotNameToIndex(loadoutSlotName);
			FormatEx(loadoutSlotName, sizeof(loadoutSlotName), "%t ›",
					g_LocalizedLoadoutSlots[loadoutSlot]);
			SetGlobalTransTarget(LANG_SERVER);
			
			return RedrawMenuItem(loadoutSlotName);
		}
	}
	return 0;
}

/**
 * Handles the weapon list selection menu.
 */
int OnEquipMenuEvent(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		/**
		 * Sets the menu title for the current section (as the player class / loadout slot).
		 */
		case MenuAction_Display: {
			int client = param1;
			Panel panel = view_as<any>(param2);
			
			SetGlobalTransTarget(client);
			
			char buffer[64];
			FormatEx(buffer, sizeof(buffer), "%t » %t",
					g_LocalizedPlayerClass[g_iPlayerClassInMenu[client]],
					g_LocalizedLoadoutSlots[g_iPlayerSlotInMenu[client]]);
			
			panel.SetTitle(buffer);
			
			SetGlobalTransTarget(LANG_SERVER);
		}
		
		/**
		 * Reads the custom item UID from the menu selection and sets the corresponding item
		 * on the player.
		 */
		case MenuAction_Select: {
			int client = param1;
			int position = param2;
			
			char uid[MAX_ITEM_IDENTIFIER_LENGTH];
			menu.GetItem(position, uid, sizeof(uid));
			
			// TODO: we should be making this a submenu with item description?
			SetClientCustomLoadoutItem(client, uid);
		}
		
		/**
		 * Hides items that are not meant for the currently browsed loadout slot and items that
		 * the player cannot equip.
		 */
		case MenuAction_DrawItem: {
			int client = param1;
			int position = param2;
			
			char uid[MAX_ITEM_IDENTIFIER_LENGTH];
			menu.GetItem(position, uid, sizeof(uid));
			
			if (uid[0] && !ItemVisibleInEquipMenu(client, uid)) {
				// remove visibility of item
				return ITEMDRAW_IGNORE;
			}
		}
		
		/**
		 * Renders the custom item name.
		 */
		case MenuAction_DisplayItem: {
			// TODO: use QuickSwitchEquipped for active item
			// TODO: support localization of item names
		}
		
		/**
		 * Return back to the loadout selection menu.
		 */
		case MenuAction_Cancel: {
			int client = param1;
			int reason = param2;
			
			if (reason == MenuCancel_ExitBack) {
				s_LoadoutSlotMenu.Display(client, 30);
			}
		}
	}
	return 0;
}