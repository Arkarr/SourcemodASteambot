#include <sourcemod>
#include <sdktools>
#include <socket>
#include <ASteambot>
#undef REQUIRE_PLUGIN
#include <updater>
#include <morecolors>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 				"Arkarr"
#define PLUGIN_VERSION 				"1.0"
#define MODULE_NAME 				"[ASteambot - Roll The Items]"
#define UPDATE_URL    				"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_RollTheItems.txt"

#define ITEM_ID						"itemID"
#define ITEM_NAME					"itemName"
#define ITEM_VALUE					"itemValue"
#define ITEM_DONATED				"itemDonated"

#define DB_INIT_TABLE_ROULETTE 			"CREATE TABLE IF NOT EXISTS `rolltheitems`.`t_roulette_v2` ( `ID` INT(11) NOT NULL AUTO_INCREMENT, `roulette_status` INT(11) NOT NULL, `roulette_winner` BIGINT(20) NULL DEFAULT NULL, `winner_trade_offer` VARCHAR(45) NOT NULL, PRIMARY KEY (`ID`)) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;"
#define DB_INIT_TABLE_TRADES 			"CREATE TABLE IF NOT EXISTS `rolltheitems`.`t_trades` ( `ID` INT(11) NOT NULL AUTO_INCREMENT, `trade_id` BIGINT(20) NOT NULL, `trade_steamid` BIGINT(20) NOT NULL, `trade_value` DOUBLE NOT NULL, `t_roulette_ID` INT(11) NOT NULL, PRIMARY KEY (`ID`), INDEX `fk_t_trades_t_roulette_idx` (`t_roulette_ID` ASC), CONSTRAINT `fk_t_trades_t_roulette` FOREIGN KEY (`t_roulette_ID`) REFERENCES `rolltheitems`.`t_roulette_v2` (`ID`) ON DELETE NO ACTION ON UPDATE NO ACTION) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;"
#define DB_SELECT_CURRENT_ROULETTE_ID	"SELECT ID FROM t_roulette_v2 WHERE roulette_status=1"
#define DB_SELECT_LAST_ROULETTE_ID		"SELECT ID FROM t_roulette_v2 ORDER BY ID DESC LIMIT 1"
#define DB_SELECT_ROLL_DETAILS			"SELECT trade_steamid, trade_value FROM t_trades WHERE t_roulette_ID=%i ORDER BY trade_value ASC"
#define DB_INSERT_SUCCESSFUL_TRADE		"INSERT INTO `t_trades` (`trade_id`, `trade_steamid`, `trade_value`, `t_roulette_ID`) VALUES ('%s', '%s', '%.2f', '%i')"
#define DB_UPDATE_ROULETTE_GAME			"UPDATE `t_roulette_v2` SET `roulette_status` = %i, `roulette_winner` = '%s', `winner_trade_offer` = '%s' WHERE `t_roulette_v2`.`ID` = %i;"
#define DB_UPDATE_ROULETTE_WINNER_OFFER "UPDATE `t_roulette_v2` SET `winner_trade_offer` = '%s' WHERE `t_roulette_v2`.`ID` = %i;"
#define DB_INSERT_ROULETTE_GAME			"INSERT INTO `t_roulette_v2` (`ID`, `roulette_status`, `roulette_winner`, `winner_trade_offer`) VALUES ('%i', '1', NULL, 'NOT_CREATED');"

#define GAMEID_TF2			440
#define GAMEID_CSGO			730
#define GAMEID_DOTA2		570

#define ROLL_STATUS_NONE	0
#define ROLL_STATUS_STARTED	1
#define ROLL_STATUS_ENDED	2

int displayWinnerID;
int currentRollRoundID;
int currentRollStatus;
int lastSelectedGame[MAXPLAYERS + 1];

float timerWinner;
float rouletteSum;
float tradeValue[MAXPLAYERS + 1];

char BotSteamID[100];

Handle DATABASE;
Handle HUDManager;
Handle RouletteTrie;
Handle TMR_Winner;
Handle TMR_PrintRouletteDetails;
Handle STACK_Prizes;
Handle ItemsToGive;
Handle ARRAY_ItemsTF2[MAXPLAYERS + 1];
Handle ARRAY_ItemsCSGO[MAXPLAYERS + 1];
Handle ARRAY_ItemsDOTA2[MAXPLAYERS + 1];
Handle ARRAY_BotItemsTF2;
Handle ARRAY_BotItemsCSGO;
Handle ARRAY_BotItemsDOTA2;
Handle CVAR_MinimumPlayer;
Handle CVAR_WinnerAnnouncement;
Handle CVAR_TradeOfferType;

//Release note
/*
* Initial release
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Roll The Items", 
	author = PLUGIN_AUTHOR, 
	description = "Allow you to particiapte to a roulette with steam items.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
	if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_RollTheItems");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_asteambot_rolltheitems", CMD_RollTheItems, "Enter the roulette round.");
	RegConsoleCmd("sm_asteambot_rti", CMD_RollTheItems, "Enter the roulette round.");
	
	RegConsoleCmd("sm_as_test", CMD_test);
	
	CreateConVar("sm_asteambot_roll_the_items_version", PLUGIN_VERSION, "Standard plugin version ConVar. Please don't change me!", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	CVAR_MinimumPlayer = CreateConVar("sm_asteambot_roll_the_items_minimum_players", "5", "Minimum number of players required to start the roulette (minimum 2)", _, true, 2.0);
	CVAR_WinnerAnnouncement = CreateConVar("sm_asteambot_roll_the_items_winner_annoucement", "5", "Seconds before annoucing the winner (minimum 3.0)", _, true, 3.0);
	CVAR_TradeOfferType = CreateConVar("sm_asteambot_roll_the_items_trade_offer_type", "1", "Trade offer type to use : tradeoffer = 1 OR ingame = 2", _, true, 1.0, true, 2.0);
	
	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);
	
	LoadTranslations("ASteambot.rolltheitems.phrases");
	
	AutoExecConfig(true, "asteambot_rolltheitems", "asteambot")
}

public Action CMD_test(int client, int args)
{
	
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{
	STACK_Prizes = CreateStack(200);
	RouletteTrie = CreateArray(100);
	ItemsToGive = CreateArray(100);
	HUDManager = CreateHudSynchronizer();
	currentRollStatus = ROLL_STATUS_NONE;
	SQL_TConnect(ConnectToDatabaseResult, "ASteambot-RollTheItems");
	
	ASteambot_SendMessage(AS_STEAM_ID, "");
}

public void OnMapStart()
{
	if (TMR_PrintRouletteDetails == INVALID_HANDLE)
		TMR_PrintRouletteDetails = CreateTimer(3.0, PrintRouletteDetails, _, TIMER_REPEAT);
		
	if (TMR_Winner == INVALID_HANDLE && timerWinner > 0.0)
		TMR_Winner = CreateTimer(0.25, PrintWinner, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	if (TMR_PrintRouletteDetails != INVALID_HANDLE)
	{
		KillTimer(TMR_PrintRouletteDetails);
		TMR_PrintRouletteDetails = INVALID_HANDLE;
	}
	
	if (TMR_Winner != INVALID_HANDLE)
	{
		KillTimer(TMR_Winner);
		TMR_Winner = INVALID_HANDLE;
	}
}

public void OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action CMD_RollTheItems(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Continue;
	}
	
	if (!ASteambot_IsConnected())
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_NotConnected");
		return Plugin_Handled;
	}
	
	switch (currentRollStatus)
	{
		case ROLL_STATUS_NONE: { AskPlayerToCreate(client); }
		case ROLL_STATUS_STARTED: { AskPlayerToEnter(client); }
		case ROLL_STATUS_ENDED: { AskPlayerToWait(client); }
	}
	
	return Plugin_Handled;
}

public void AskPlayerToCreate(int client)
{
	char buffer[255];
	Menu menu = new Menu(MenuHandler_CreateOrJoinRoulette);
	menu.SetTitle("%t", "Roulette_Menu_Title");
	
	menu.AddItem("-", "!!!!!!!!!!!", ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "Roulette_Policy");
	menu.AddItem("-", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "Roulette_Policy_2");
	menu.AddItem("-", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "Roulette_Policy_3");
	menu.AddItem("-", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "menu_accept");
	menu.AddItem("-", buffer, ITEMDRAW_RAWLINE);
	
	Format(buffer, sizeof(buffer), "%t", "menu_yes");
	menu.AddItem("y", buffer);
	
	Format(buffer, sizeof(buffer), "%t", "menu_no");
	menu.AddItem("n", buffer);
	
	menu.AddItem("-", "!!!!!!!!!!!", ITEMDRAW_DISABLED);
	
	menu.Display(client, 30);
}

public void AskPlayerToEnter(int client)
{
	char buffer[255];
	Menu menu = new Menu(MenuHandler_CreateOrJoinRoulette);
	menu.SetTitle("%t", "Roulette_Menu_Title");
	
	menu.AddItem("-", "!!!!!!!!!!!", ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "Roulette_Policy_Enter");
	menu.AddItem("-", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "Roulette_Policy_2");
	menu.AddItem("-", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "Roulette_Policy_3");
	menu.AddItem("-", buffer, ITEMDRAW_DISABLED);
	
	Format(buffer, sizeof(buffer), "%t", "menu_accept");
	menu.AddItem("-", buffer, ITEMDRAW_RAWLINE);
	
	Format(buffer, sizeof(buffer), "%t", "menu_yes");
	menu.AddItem("y", buffer);
	
	Format(buffer, sizeof(buffer), "%t", "menu_no");
	menu.AddItem("n", buffer);
	
	menu.AddItem("-", "!!!!!!!!!!!", ITEMDRAW_DISABLED);
	
	menu.Display(client, 30);
}

public int MenuHandler_CreateOrJoinRoulette(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char info[10];
		GetMenuItem(menu, itemIndex, info, sizeof(info));
		
		if (StrEqual(info, "y"))
		{
			if (TMR_PrintRouletteDetails == INVALID_HANDLE)
				TMR_PrintRouletteDetails = CreateTimer(3.0, PrintRouletteDetails, _, TIMER_REPEAT);
		
			LoadInventory(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public void AskPlayerToWait(int client)
{
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Roulette_WinnerBeingSelected");
}

public void LoadInventory(int client)
{
	if(GetConVarInt(CVAR_TradeOfferType) == 1)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_WaitItems");
		
		char clientSteamID[40];
		GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
		
		ASteambot_SendMessage(AS_SCAN_INVENTORY, clientSteamID);
	}
	else
	{
		char clientSteamIDGame[120];
		GetClientAuthId(client, AuthId_Steam2, clientSteamIDGame, sizeof(clientSteamIDGame));
		
		switch(GetEngineVersion())
		{
			case Engine_CSGO: { Format(clientSteamIDGame, sizeof(clientSteamIDGame), "%s/%i/", clientSteamIDGame, GAMEID_CSGO); }
			case Engine_DOTA: { Format(clientSteamIDGame, sizeof(clientSteamIDGame), "%s/%i/", clientSteamIDGame, GAMEID_DOTA2); }
			case Engine_TF2: { Format(clientSteamIDGame, sizeof(clientSteamIDGame), "%s/%i/", clientSteamIDGame, GAMEID_TF2); }
		}
		
		ASteambot_SendMessage(AS_CREATE_QUICK_TRADE, clientSteamIDGame);
	}
	
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{
	char[][] parts = new char[4][messageSize];
	char steamID[40];
	
	ExplodeString(message, "/", parts, 4, messageSize);
	Format(steamID, sizeof(steamID), parts[0]);
	
	int client = ASteambot_FindClientBySteam64(steamID);
	
	if (MessageType == AS_NOT_FRIENDS && client != -1)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Steam_NotFriends");
	}
	else if (MessageType == AS_TRADE_TOKEN && client != -1)
	{
		if (StrEqual(parts[1], "trade_token_not_found"))
			CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_TokenMissing");
		else if (StrEqual(parts[1], "trade_token_invalid"))
			CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_TokenInvalid");
	}
	else if (MessageType == AS_SCAN_INVENTORY)
	{
		if(StrEqual(steamID, BotSteamID))
		{
			char winner[200];
			PopStackString(STACK_Prizes, winner, sizeof(winner));
			
			char bit[4][200];
			ExplodeString(winner, "|", bit, sizeof bit, sizeof bit[]);
			
			PrepareInventories(-1, parts[1], parts[2], parts[3], messageSize);
			
			FindAndGiveItem(bit[0], StringToFloat(bit[1]), StringToFloat(bit[2]), StringToInt(bit[3]));
		}
		else
		{
			CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_InventoryScanned");
			PrepareInventories(client, parts[1], parts[2], parts[3], messageSize);
		}
	}
	else if (MessageType == AS_CREATE_TRADEOFFER && client != -1)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Created");
	}
	else if (MessageType == AS_TRADEOFFER_DECLINED && client != -1)
	{
		char[] value = new char[100];
		
		Format(value, messageSize, parts[2]);
		ReplaceString(value, messageSize, ",", ".");
		
		float credits = StringToFloat(value);
		
		//Is trade a withdraw ?
		
		//No
		if(credits != -1)
		{
			CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Declined");
		}
		//Yes
		else
		{
			ReplaceString(parts[3], 40, "roulette_id_", "", false);
			
			char dbquery[200];
			Format(dbquery, sizeof(dbquery), DB_UPDATE_ROULETTE_WINNER_OFFER, "OFFER_REJECTED", StringToInt(parts[3]));
			DBFastQuery(dbquery, true);
			
			CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Declined_Donation");
		}	
	}
	else if (MessageType == AS_STEAM_ID)
	{
		Format(BotSteamID, sizeof(BotSteamID), steamID);
	}
	else if (MessageType == AS_TRADEOFFER_SUCCESS)
	{
		char[] offerID = new char[messageSize];
		char[] value = new char[messageSize];
		
		Format(offerID, messageSize, parts[1]);
		Format(value, messageSize, parts[2]);
		ReplaceString(value, messageSize, ",", ".");
		
		float credits = StringToFloat(value);
		
		//Is trade a withdraw ?
		
		//No
		if(credits != -1)
		{
			if(client != -1)
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Success", credits);
		
			char dbquery[200];
			Format(dbquery, sizeof(dbquery), DB_INSERT_SUCCESSFUL_TRADE, offerID, steamID, credits, currentRollRoundID);
			SQL_TQuery(DATABASE, TQuery_InsertNewTradeSuccess, dbquery, RouletteTrie);
		}
		//Yes
		else
		{
			ReplaceString(parts[3], 40, "roulette_id_", "", false);
			
			char dbquery[200];
			Format(dbquery, sizeof(dbquery), DB_UPDATE_ROULETTE_WINNER_OFFER, "OFFER_ACCEPTED", StringToInt(parts[3]));
			DBFastQuery(dbquery, true);
		}
	}
}

public void PrepareInventories(int client, const char[] tf2, const char[] csgo, const char[] dota2, int charSize)
{
	int tf2_icount = CountCharInString(tf2, ',') + 1;
	int csgo_icount = CountCharInString(csgo, ',') + 1;
	int dota2_icount = CountCharInString(dota2, ',') + 1;
	
	bool inv_tf2 = false;
	bool inv_csgo = false;
	bool inv_dota2 = false;
	
	if(client != -1)
	{
		ARRAY_ItemsTF2[client] = CreateArray(tf2_icount);
		ARRAY_ItemsCSGO[client] = CreateArray(csgo_icount);
		ARRAY_ItemsDOTA2[client] = CreateArray(dota2_icount);
	
		inv_tf2 = CreateInventory(client, tf2, tf2_icount, ARRAY_ItemsTF2[client]);
		inv_csgo = CreateInventory(client, csgo, csgo_icount, ARRAY_ItemsCSGO[client]);
		inv_dota2 = CreateInventory(client, dota2, dota2_icount, ARRAY_ItemsDOTA2[client]);
	}
	else
	{
		ARRAY_BotItemsTF2 = CreateArray(tf2_icount);
		ARRAY_BotItemsCSGO = CreateArray(csgo_icount);
		ARRAY_BotItemsDOTA2 = CreateArray(dota2_icount);
	
		inv_tf2 = CreateInventory(client, tf2, tf2_icount, ARRAY_BotItemsTF2);
		inv_csgo = CreateInventory(client, csgo, csgo_icount, ARRAY_BotItemsCSGO);
		inv_dota2 = CreateInventory(client, dota2, dota2_icount, ARRAY_BotItemsDOTA2);
	}
	
	char timeOut[100];
	if (StrEqual(tf2, "TIME_OUT"))
		Format(timeOut, sizeof(timeOut), "TF2");
	
	if (StrEqual(csgo, "TIME_OUT"))
		Format(timeOut, sizeof(timeOut), "%s,CS:GO", timeOut);
	
	if (StrEqual(dota2, "TIME_OUT"))
		Format(timeOut, sizeof(timeOut), "%s,Dota 2", timeOut);
	
	if (StrContains(timeOut, ",") == 0)
		strcopy(timeOut, sizeof(timeOut), timeOut[1]);
	
	if (!inv_tf2 && !inv_csgo && !inv_dota2 && client != -1)
	{
		lastSelectedGame[client] = -1;
		
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_InventoryError");
	}
	else if(client != -1)
	{
		lastSelectedGame[client] = -1;
		
		DisplayInventorySelectMenu(client);
		
		if (strlen(timeOut) > 0)
			CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_BotInventoryScanTimeOut", timeOut);
	}
}

public bool CreateInventory(int client, const char[] strinventory, int itemCount, Handle inventory)
{
	if (StrEqual(strinventory, "EMPTY"))
		return true;
	
	if (StrEqual(strinventory, "TIME_OUT"))
		return true;
	
	if (StrEqual(strinventory, "ERROR") && client != -1)
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_ItemsError", strinventory);
		return false;
	}
	
	char[][] items = new char[itemCount][60];
	
	ExplodeString(strinventory, ",", items, itemCount, 60);
	
	for (int i = 0; i < itemCount; i++)
	{
		char itemInfos[3][100];
		ExplodeString(items[i], "=", itemInfos, sizeof itemInfos, sizeof itemInfos[]);
		
		Handle TRIE_Item = CreateTrie();
		SetTrieString(TRIE_Item, ITEM_ID, itemInfos[0]);
		SetTrieString(TRIE_Item, ITEM_NAME, itemInfos[1]);
		SetTrieValue(TRIE_Item, ITEM_VALUE, StringToFloat(itemInfos[2]));
		SetTrieValue(TRIE_Item, ITEM_DONATED, 0);
		
		if (StringToFloat(itemInfos[2]) <= 0)
			continue;
		
		PushArrayCell(inventory, TRIE_Item);
	}
	
	return true;
}

public int MenuHandle_MainMenu(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		if (itemIndex == 0) //TF2
			DisplayInventory(client, 0);
		else if (itemIndex == 1) //CSGO
			DisplayInventory(client, 1);
		else if (itemIndex == 2) //DOTA2 ---> DEFINE !!!
			DisplayInventory(client, 2);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public void DisplayInventorySelectMenu(int client)
{
	Handle menu = CreateMenu(MenuHandle_MainMenu);
	SetMenuTitle(menu, "Select an inventory :");
	
	if (GetArraySize(ARRAY_ItemsTF2[client]) > 0)
		AddMenuItem(menu, "tf2", "Team Fortress 2");
	else
		AddMenuItem(menu, "tf2", "Team Fortress 2", ITEMDRAW_DISABLED);
	
	if (GetArraySize(ARRAY_ItemsCSGO[client]) > 0)
		AddMenuItem(menu, "csgo", "Counter-Strike: Global Offensive");
	else
		AddMenuItem(menu, "csgo", "Counter-Strike: Global Offensive", ITEMDRAW_DISABLED);
	
	if (GetArraySize(ARRAY_ItemsDOTA2[client]) > 0)
		AddMenuItem(menu, "dota2", "Dota 2");
	else
		AddMenuItem(menu, "dota2", "Dota 2", ITEMDRAW_DISABLED);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_SelectItems");
}

public int MenuHandle_ItemSelect(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char description[32];
		char itemID[32];
		float itemValue;
		GetMenuItem(menu, itemIndex, description, sizeof(description));
		
		if (StrEqual(description, "OK"))
		{
			int selected = 0;
			Handle inventory = GetLastInventory(client);
			for (int i = 0; i < GetArraySize(inventory); i++)
			{
				Handle trie = GetArrayCell(inventory, i);
				GetTrieValue(trie, ITEM_DONATED, selected);
				
				if (selected == 1)
					break;
			}
			
			if (selected == 0)
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_NoItems");
			else
				CreateTradeOffer(client, tradeValue[client]);
		}
		else
		{
			Handle inventory = GetLastInventory(client);
			for (int i = 0; i < GetArraySize(inventory); i++)
			{
				Handle trie = GetArrayCell(inventory, i);
				GetTrieString(trie, ITEM_ID, itemID, sizeof(itemID));
				GetTrieValue(trie, ITEM_VALUE, itemValue);
				
				if (StrEqual(itemID, description))
				{
					SetTrieValue(trie, ITEM_DONATED, 1);
					tradeValue[client] += itemValue;
					DisplayInventory(client, -1);
					return;
				}
			}
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Handle GetLastInventory(int client)
{
	switch (lastSelectedGame[client])
	{
		case GAMEID_TF2:return ARRAY_ItemsTF2[client];
		case GAMEID_CSGO:return ARRAY_ItemsCSGO[client];
		case GAMEID_DOTA2:return ARRAY_ItemsDOTA2[client];
	}
	
	return INVALID_HANDLE;
}

public void DisplayInventory(int client, int inventoryID)
{
	Handle inventory;
	if (lastSelectedGame[client] == -1)
	{
		if (inventoryID == 0)
		{
			inventory = ARRAY_ItemsTF2[client];
			lastSelectedGame[client] = GAMEID_TF2;
		}
		else if (inventoryID == 1)
		{
			inventory = ARRAY_ItemsCSGO[client];
			lastSelectedGame[client] = GAMEID_CSGO;
		}
		else if (inventoryID == 2)
		{
			inventory = ARRAY_ItemsDOTA2[client];
			lastSelectedGame[client] = GAMEID_DOTA2;
		}
	}
	else
	{
		inventory = GetLastInventory(client);
	}
	
	Handle menu = CreateMenu(MenuHandle_ItemSelect);
	SetMenuTitle(menu, "Select items to donate (%.2f$) :", tradeValue[client]);
	
	char itemName[30];
	char itemID[30];
	float itemValue;
	int itemDonated;
	
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle trie = GetArrayCell(inventory, i);
		GetTrieString(trie, ITEM_NAME, itemName, sizeof(itemName));
		GetTrieString(trie, ITEM_ID, itemID, sizeof(itemID));
		GetTrieValue(trie, ITEM_VALUE, itemValue);
		GetTrieValue(trie, ITEM_DONATED, itemDonated);
		
		char menuItem[35];
		
		Format(menuItem, sizeof(menuItem), "%.2f$ - %s", itemValue, itemName);
		
		if (itemDonated == 0)
			AddMenuItem(menu, itemID, menuItem);
		else
			AddMenuItem(menu, itemID, menuItem, ITEMDRAW_DISABLED);
	}
	
	AddMenuItem(menu, "OK", "OK!");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void CreateTradeOffer(int client, float tv)
{
	char itemID[32];
	int selected = 0;
	Handle items = CreateArray(30);
	
	Handle inventory = GetLastInventory(client);
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle trie = GetArrayCell(inventory, i);
		GetTrieValue(trie, ITEM_DONATED, selected);
		
		if (selected == 1)
		{
			GetTrieString(trie, ITEM_ID, itemID, sizeof(itemID));
			PushArrayString(items, itemID);
		}
	}
	
	ASteambot_CreateTradeOffer(client, items, INVALID_HANDLE, tv, "");
}

public void GiveoutPrice(const char[] steamID, float value, float valueMax)
{
	char winner[200];
	Format(winner, sizeof(winner), "%s|%.2f|%.2f|%i", steamID, value, valueMax, currentRollRoundID);
	PushStackString(STACK_Prizes, winner);
	
	ASteambot_SendMessage(AS_SCAN_INVENTORY, BotSteamID);
}

public void FindAndGiveItem(const char[] steamID, float maxvalue, float minvalue, int rollID)
{
	Handle inventory = null;
	
	if(GetEngineVersion() == Engine_TF2)
		inventory = ARRAY_BotItemsTF2;
	else
		inventory = ARRAY_BotItemsCSGO;
	
	char itemName[30];
	char itemID[30];
	float stash = maxvalue;
	float itemValue;
	bool minValueFound = false;
	Handle botItems = CreateArray(100);
	
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle trie = GetArrayCell(inventory, i);
		GetTrieString(trie, ITEM_NAME, itemName, sizeof(itemName));
		GetTrieString(trie, ITEM_ID, itemID, sizeof(itemID));
		GetTrieValue(trie, ITEM_VALUE, itemValue);
		
		if(FindStringInArray(ItemsToGive, itemID) != -1)
			continue;
		
		if(minValueFound == false && minvalue + 0.6 <= itemValue && itemValue >= minvalue)
		{
			stash -= itemValue;
			minValueFound = true;
		}
		else
		{
			stash -= itemValue;
		}
		
		PushArrayString(botItems, itemID);
		PushArrayString(ItemsToGive, itemID);
		
		if(stash <= 0.0)
			break;
	}
	
	char args[200];
	Format(args, sizeof(args), "roulette_id_%i", rollID);
	ASteambot_CreateTradeOfferBySteamID(steamID, INVALID_HANDLE, botItems, _, args);
}

public int CalculateWinner(float &percent, char[] steamID, int steamIDsize)
{
	char info[100];
	char bit[2][50];
		
	Handle arrayPercent = CreateArray();
	for(int i = 0; i < GetArraySize(RouletteTrie); i++)
	{
		GetArrayString(RouletteTrie, i, info, sizeof(info));
		ExplodeString(info, "|", bit, sizeof bit, sizeof bit[]);
		float pValue = StringToFloat(bit[1]);
		percent = (pValue / rouletteSum) * 100;
		PushArrayCell(arrayPercent, percent);
	}
	
	float total = 0.0;
	float winningNumber = GetRandomFloat(0.0, 100.0);

	for(int i = 0; i < GetArraySize(arrayPercent); i++)
	{
		GetArrayString(RouletteTrie, i, info, sizeof(info));
		ExplodeString(info, "|", bit, sizeof bit, sizeof bit[]);
		percent = GetArrayCell(arrayPercent, i);
		
		total += percent;
		
		if(total > winningNumber)
		{
			GetArrayString(RouletteTrie, i, info, sizeof(info));
			ExplodeString(info, "|", bit, sizeof bit, sizeof bit[]);
		
			float winnerValue = (rouletteSum * 0.85);
			float winnerBet = StringToFloat(bit[1]);
			
			if(winnerValue < winnerBet)
				winnerValue = rouletteSum;
				
			GiveoutPrice(bit[0], winnerValue, winnerBet);
			
			strcopy(steamID, steamIDsize, bit[0]);
			
			return ASteambot_FindClientBySteam64(bit[0]);
		}
	}
	
	return -1;
}

public Action PrintWinner(Handle tmr)
{
	if(timerWinner <= 0.0)
	{
		if (TMR_Winner != INVALID_HANDLE)
		{
			KillTimer(TMR_Winner);
			TMR_Winner = INVALID_HANDLE;
		}
		
		float percent;
		char steamID[45];
		int client = CalculateWinner(percent, steamID, sizeof(steamID));
		
		char hudmsg[100];
		if(client != -1)
			Format(hudmsg, sizeof(hudmsg), "Winner is \n%N\nWon with a probability of %.2f%% !", client, percent);
		else
			Format(hudmsg, sizeof(hudmsg), "Winner is \n%s\nWon with a probability of %.2f%% !", steamID, percent);
		
		SetHudTextParams(-1.0, 0.25, 8.0, 25, 255, 25, 150);
		
		for (int j = 1; j <= MaxClients; j++)
		{
			if (!IsClientInGame(j) || IsFakeClient(j))
				continue;
			
			ShowSyncHudText(j, HUDManager, "%s", hudmsg);
		}		
		
		char query[200];
		Format(query, sizeof(query), DB_UPDATE_ROULETTE_GAME, ROLL_STATUS_ENDED, steamID, "OFFER_CREATED", currentRollRoundID);
		DBFastQuery(query, false);
		
		EmitGameSoundToAll("Achievement.Earned");
		
		PrepareRoulette();
	}
	else
	{
		EmitGameSoundToAll("Vote.Created");
		
		if(displayWinnerID == GetArraySize(RouletteTrie))
			displayWinnerID = 0;
			
		timerWinner -= 0.25;
			
		if(GetConVarFloat(CVAR_WinnerAnnouncement) > timerWinner)
		{
			char info[100];
			char bit[2][50];
			GetArrayString(RouletteTrie, displayWinnerID, info, sizeof(info));
			ExplodeString(info, "|", bit, sizeof bit, sizeof bit[]);
			
			float pValue = StringToFloat(bit[1]);
			float percent = (pValue / rouletteSum)*100;
			
			int client = ASteambot_FindClientBySteam64(bit[0]);
			
			char hudmsg[100];
			if(client != -1)
				Format(hudmsg, sizeof(hudmsg), "/!\\ Selecting winner /!\\\n%N (%.2f%%)", client, percent);
			else
				Format(hudmsg, sizeof(hudmsg), "/!\\ Selecting winner /!\\\n%s (%.2f%%)", bit[0], percent);
			
			
			SetHudTextParams(-1.0,  0.25, 0.25, 25, 255, 25, 150);
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i))
					continue;
				
				ShowSyncHudText(i, HUDManager, "%s", hudmsg);
			}
			
			displayWinnerID++;
		}
	}
}

public Action PrintRouletteDetails(Handle tmr)
{
	SetHudTextParams(0.05, 0.05, 3.1, 150, 255, 0, 150);
	
	char status[40];
	char hudmsg[400];
	if (currentRollStatus != ROLL_STATUS_STARTED)
		Format(status, sizeof(status), "ENDED!");
	else
		Format(status, sizeof(status), "STARTED!");
		
	Format(hudmsg, sizeof(hudmsg), "Roulette status : %s\n", status);
		
	int max = GetArraySize(RouletteTrie)-1;
	
	if(max >= 0)
	{
		for(int i = max; i >= 0; i--)
		{
			char value[200];
			char bit[2][100];
			GetArrayString(RouletteTrie, i, value, sizeof(value));
			ExplodeString(value, "|", bit, sizeof bit, sizeof bit[]);
			
			int client = ASteambot_FindClientBySteam64(bit[0]);
			
			float pValue = StringToFloat(bit[1]);
			float percent = (pValue / rouletteSum)*100;
				
			if(client != -1)
				Format(hudmsg, sizeof(hudmsg), "%s%N has a chance of winning of %.2f%%\n", hudmsg, client, percent);
			else
				Format(hudmsg, sizeof(hudmsg), "%s<disconnected> have a chance of winning of %.2f%%\n", hudmsg, percent);
		}
	
		Format(hudmsg, sizeof(hudmsg), "%sTotal roulette value : %.2f$\n\n", hudmsg, rouletteSum);
			
		Format(hudmsg, sizeof(hudmsg), "%sType !asteambot_rti to join the roulette\nand get a chance to win !\n", hudmsg);
	}
	else
	{
		Format(hudmsg, sizeof(hudmsg), "%sNo roulette opened yet. Use !asteambot_rti\n", hudmsg);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		ShowSyncHudText(i, HUDManager, "%s", hudmsg);
	}
	
	return Plugin_Continue;
}

public void PrepareRoulette()
{
	currentRollRoundID = DBGetRouletteNextID();
	LoadCurrentRoll(currentRollRoundID);
}

/* Boring DB stuff */
public void ConnectToDatabaseResult(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	else
	{
		DATABASE = hndl;
		
		if (DBFastQuery(DB_INIT_TABLE_ROULETTE, true) && DBFastQuery(DB_INIT_TABLE_TRADES, true))
		{
			PrintToServer("%s %t", MODULE_NAME, "Database_Success");
			
			PrepareRoulette();
		}
	}
}

public void LoadCurrentRoll(int rollID)
{
	rouletteSum = 0.0;
	ClearArray(RouletteTrie);
	currentRollStatus = ROLL_STATUS_NONE;
	
	char dbquery[200];
	Format(dbquery, sizeof(dbquery), DB_SELECT_ROLL_DETAILS, rollID);
	
	SQL_TQuery(DATABASE, TQuery_LoadCurrentRoll, dbquery, RouletteTrie);
}

public int DBGetRouletteNextID()
{
	char query[400];
	Format(query, sizeof(query), DB_SELECT_CURRENT_ROULETTE_ID);
	
	DBResultSet hQuery = SQL_Query(DATABASE, query);
	if (hQuery == null)
		return -1;
	
	int result = -1;
	while (SQL_FetchRow(hQuery))
		result = SQL_FetchInt(hQuery, 0);
	
	if (result == -1)
	{
		Format(query, sizeof(query), DB_SELECT_LAST_ROULETTE_ID);
		
		hQuery = SQL_Query(DATABASE, query);
		if (hQuery == null)
			return -1;
		
		result = 0;
		while (SQL_FetchRow(hQuery))
			result = SQL_FetchInt(hQuery, 0) + 1;
		
		currentRollStatus = ROLL_STATUS_STARTED;
		Format(query, sizeof(query), DB_INSERT_ROULETTE_GAME, result);
		DBFastQuery(query, true);
	}
	else
	{
		currentRollStatus = ROLL_STATUS_STARTED;
	}
	
	delete hQuery;
	
	return result;
}

public void TQuery_InsertNewTradeSuccess(Handle owner, Handle db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		char err[255];
		SQL_GetError(DATABASE, err, sizeof(err));
		PrintToServer("%s %t", MODULE_NAME, "Database_Failure", err);
		SetFailState("%s An error occured.", MODULE_NAME);
		
		return;
	}
	
	LoadCurrentRoll(currentRollRoundID);
}

public void TQuery_LoadCurrentRoll(Handle owner, Handle db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		char err[255];
		SQL_GetError(DATABASE, err, sizeof(err));
		PrintToServer("%s %t", MODULE_NAME, "Database_Failure", err);
		SetFailState("%s An error occured.", MODULE_NAME);
		
		return;
	}
	
	char strdata[200];
	char steamID[128];
	float value;
	
	currentRollStatus = ROLL_STATUS_STARTED;
		
	while (SQL_FetchRow(db))
	{
		SQL_FetchString(db, 0, steamID, sizeof(steamID));
		value = SQL_FetchFloat(db, 1);
		Format(strdata, sizeof(strdata), "%s|%f", steamID, value);
		rouletteSum += value;
		
		bool found = false;
		char entry[200];
		for(int i = 0; i < GetArraySize(RouletteTrie); i++)
		{
			GetArrayString(RouletteTrie, i, entry, sizeof(entry));
			if(StrContains(entry, steamID) != -1)
			{
				char bit[2][100];
				ExplodeString(entry, "|", bit, sizeof bit, sizeof bit[]);
				Format(strdata, sizeof(strdata), "%s|%f", steamID, (StringToFloat(bit[1]) + value));
				SetArrayString(RouletteTrie, i, strdata);
				found = true;
				break;
			}
		}
		
		if(!found)
			PushArrayString(RouletteTrie, strdata);
	}
	
	if(GetArraySize(RouletteTrie) >= GetConVarInt(CVAR_MinimumPlayer))
	{
		displayWinnerID = 0;
		currentRollStatus = ROLL_STATUS_ENDED;
		timerWinner = GetConVarFloat(CVAR_WinnerAnnouncement)+3;
		
		if (TMR_PrintRouletteDetails != INVALID_HANDLE)
		{
			KillTimer(TMR_PrintRouletteDetails);
			TMR_PrintRouletteDetails = INVALID_HANDLE;
		}
		
		TMR_Winner = CreateTimer(0.25, PrintWinner, _, TIMER_REPEAT);
	}
	else
	{	
		if (TMR_PrintRouletteDetails == INVALID_HANDLE)
			TMR_PrintRouletteDetails = CreateTimer(3.0, PrintRouletteDetails, _, TIMER_REPEAT);
	
	}
}

public bool DBFastQuery(const char[] sql, bool errorReport)
{
	char error[400];
	SQL_FastQuery(DATABASE, sql);
	if (SQL_GetError(DATABASE, error, sizeof(error)))
	{
		if (errorReport)
			SetFailState("%s %t", MODULE_NAME, "Database_Failure", error);
		
		return false;
	}
	
	return true;
}

public int CountCharInString(const char[] str, int c)
{
	int i = 0, count = 0;
	
	while (str[i] != '\0')
	{
		if (str[i++] == c)
			count++;
	}
	
	return count;
} 