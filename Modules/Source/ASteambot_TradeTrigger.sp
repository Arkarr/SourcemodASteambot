#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.5"
#define MODULE_NAME 			"[ASteambot - Trade Trigger]"

#define ITEM_ID					"itemID"
#define ITEM_NAME				"itemName"
#define ITEM_VALUE				"itemValue"
#define ITEM_DONATED			"itemDonated"

#define GAMEID_TF2				440
#define GAMEID_CSGO				730
#define GAMEID_DOTA2			570

#define QUERY_CREATE_T_CLIENTS	"CREATE TABLE IF NOT EXISTS `t_client` (`client_steamid` VARCHAR(30) NOT NULL, `client_token` VARCHAR(30) NOT NULL, `client_balance` DOUBLE NOT NULL, PRIMARY KEY (`client_steamid`))ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;"
#define QUERY_SELECT_MONEY		"SELECT `client_balance` FROM `t_client` WHERE `client_steamid`=\"%s\""
#define QUERY_SELECT_TOKEN		"SELECT `client_token` FROM `t_client` WHERE `client_steamid`=\"%s\""
#define QUERY_INSERT_MONEY		"INSERT INTO `t_client` (`client_steamid`,`client_balance`) VALUES (\"%s\", %.2f);"
#define QUERY_UPDATE_MONEY		"UPDATE `t_client` SET `client_balance`=%.2f WHERE `client_steamid`=\"%s\""

#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_TradeTrigger.txt"

int lastSelectedGame[MAXPLAYERS + 1];

float minValue;
float tradeValue[MAXPLAYERS + 1];

Handle DATABASE;
Handle CVAR_DBConfigurationName;
Handle ARRAY_ItemsTF2[MAXPLAYERS + 1];
Handle ARRAY_ItemsCSGO[MAXPLAYERS + 1];
Handle ARRAY_ItemsDOTA2[MAXPLAYERS + 1];

//Release note
/*
*Updater update file location
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Trade Trigger", 
	author = PLUGIN_AUTHOR, 
	description = "Whenever a trade end, the server will be notified and do some actions related to the ammount of the trade offer in USD ($)", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_TradeTrigger");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public void OnPluginStart()
{
	
	CVAR_DBConfigurationName = CreateConVar("sm_asteambot_donation_database", "ASteambot", "SET THIS PARAMETER IF YOU DON'T HAVE ANY STORE (sm_asteambot_donation_store_select=NONE) ! The database configuration in database.cfg");

	RegConsoleCmd("sm_tradeoffer", CMD_TradeTrigger, "Create a trade offer with ASteambot as a trade trigger.");
	
	AutoExecConfig(true, "asteambot_tradetrigger", "asteambot");
	
	LoadTranslations("ASteambot.tradetrigger.phrases");

	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public void OnConfigsExecuted()
{
	char dbconfig[45];
	GetConVarString(CVAR_DBConfigurationName, dbconfig, sizeof(dbconfig));
	
	SQL_TConnect(GotDatabase, dbconfig);
}

public void OnClientConnected(int client)
{
	lastSelectedGame[client] = -1;
}

public Action CMD_TradeTrigger(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Continue;
	}
	
	if(!ASteambot_IsConnected())
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_NotConnected");
		return Plugin_Handled;
	}	
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_WaitItems");
	
	tradeValue[client] = 0.0;
	
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	
	ASteambot_SendMesssage(AS_SCAN_INVENTORY, clientSteamID);
	
	return Plugin_Handled;
}

public Action CMD_AsFriends(int client, int args)
{
	char clientSteamID[30];
	
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	ASteambot_SendMesssage(AS_FRIEND_INVITE, clientSteamID);
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Steam_FriendInvitSend");

	return Plugin_Handled;
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{
	char query[300];
	
	char[][] parts = new char[4][messageSize];	
	char steamID[40];
	
	ExplodeString(message, "/", parts, 4, messageSize);
	Format(steamID, sizeof(steamID), parts[0]);
	
	int client = FindClientBySteamID(steamID);
	
	if(MessageType == AS_NOT_FRIENDS && client != -1)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Steam_NotFriends");
	}
	else if(MessageType == AS_SCAN_INVENTORY && client != -1)
	{		
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_InventoryScanned");
		PrepareInventories(client, parts[1], parts[2], parts[3], messageSize)
	}	
	else if (MessageType == AS_TRADEOFFER_DECLINED && client != -1)
	{
		CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Declined");
	}
	else if(MessageType == AS_TRADEOFFER_SUCCESS)
	{
		char[] offerID = new char[messageSize];
		char[] value = new char[messageSize];
		
		Format(offerID, messageSize, parts[1]);
		Format(value, messageSize, parts[2]);
		
		float credits = StringToFloat(value);

		if (client == -1)
		{
			Handle pack = CreateDataPack();
			WritePackString(pack, steamID);
			WritePackString(pack, offerID);
			WritePackFloat(pack, credits);
			
			Format(query, sizeof(query), QUERY_SELECT_MONEY, steamID);
			SQL_TQuery(DATABASE, GetPlayerCredits, query, pack);
		}
		else
		{
			//ProcessTradeOffer(client, credits);
		}
	}
}

public void PrepareInventories(int client, const char[] tf2, const char[] csgo, const char[] dota2, int charSize)
{
	int tf2_icount = CountCharInString(tf2, ',')+1;
	int csgo_icount = CountCharInString(csgo, ',')+1;
	int dota2_icount = CountCharInString(dota2, ',')+1;
	
	ARRAY_ItemsTF2[client] = CreateArray(tf2_icount);
	ARRAY_ItemsCSGO[client] = CreateArray(csgo_icount);
	ARRAY_ItemsDOTA2[client] = CreateArray(dota2_icount);
	
	CreateInventory(client, tf2, tf2_icount, ARRAY_ItemsTF2[client]);
	CreateInventory(client, csgo, csgo_icount, ARRAY_ItemsCSGO[client]);
	CreateInventory(client, dota2, dota2_icount, ARRAY_ItemsDOTA2[client]);
	
	lastSelectedGame[client] = -1;
	
	DisplayInventorySelectMenu(client);
}

public void CreateInventory(int client, const char[] strinventory, int itemCount, Handle inventory)
{
	if(!StrEqual(strinventory, "EMPTY"))
	{
		char[][] items = new char[itemCount][60];
		
		ExplodeString(strinventory, ",", items, itemCount, 60);
		
		for (int i = 0; i < itemCount; i++)
		{
			char itemInfos[3][30];
			ExplodeString(items[i], "=", itemInfos, sizeof itemInfos, sizeof itemInfos[]);
			
			Handle TRIE_Item = CreateTrie();
			SetTrieString(TRIE_Item, ITEM_ID, itemInfos[0]);
			SetTrieString(TRIE_Item, ITEM_NAME, itemInfos[1]);
			SetTrieValue(TRIE_Item, ITEM_VALUE, StringToFloat(itemInfos[2]));
			SetTrieValue(TRIE_Item, ITEM_DONATED, 0);
			PushArrayCell(inventory, TRIE_Item);
		}
	}
	else if(StrEqual(strinventory, "ERROR"))
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_ItemsError", strinventory);
	}
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

public void DisplayInventorySelectMenu(int client)
{
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_SelectItems");
	
	Handle menu = CreateMenu(MenuHandle_MainMenu);
	SetMenuTitle(menu, "Select an inventory :");
	
	if(GetArraySize(ARRAY_ItemsTF2[client]) > 0)
		AddMenuItem(menu, "tf2", "Team Fortress 2");
	else
		AddMenuItem(menu, "tf2", "Team Fortress 2", ITEMDRAW_DISABLED);
	
	if(GetArraySize(ARRAY_ItemsCSGO[client]) > 0)
		AddMenuItem(menu, "csgo", "Counter-Strike: Global Offensive");
	else
		AddMenuItem(menu, "csgo", "Counter-Strike: Global Offensive", ITEMDRAW_DISABLED);
		
	if(GetArraySize(ARRAY_ItemsDOTA2[client]) > 0)
		AddMenuItem(menu, "dota2", "Dota 2");
	else
		AddMenuItem(menu, "dota2", "Dota 2", ITEMDRAW_DISABLED);
	
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void DisplayInventory(int client, int inventoryID)
{
	Handle inventory;
	if(lastSelectedGame[client] == -1)
	{
		if(inventoryID == 0)
		{
			inventory = ARRAY_ItemsTF2[client];
			lastSelectedGame[client] = GAMEID_TF2;
		}
		else if(inventoryID == 1)
		{
			inventory = ARRAY_ItemsCSGO[client];
			lastSelectedGame[client] = GAMEID_CSGO;
		}
		else if(inventoryID == 2)
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
	SetMenuTitle(menu, "Select items to donate (%.2f$ / %.2f$) :", tradeValue[client], minValue);
	
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
		
		if(itemDonated == 0)
			AddMenuItem(menu, itemID, menuItem);
		else
			AddMenuItem(menu, itemID, menuItem, ITEMDRAW_DISABLED);
	}
			
	AddMenuItem(menu, "OK", "OK!");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
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

public int MenuHandle_ItemSelect(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char description[32];
		char itemID[32];
		float itemValue;
		GetMenuItem(menu, itemIndex, description, sizeof(description));
				
		if(StrEqual(description, "OK"))
		{
			int selected = 0;
			Handle inventory = GetLastInventory(client);
			for (int i = 0; i < GetArraySize(inventory); i++)
			{
				Handle trie = GetArrayCell(inventory, i);
				GetTrieValue(trie, ITEM_DONATED, selected);
				
				if(selected == 1)
					break;
			}
			
			if(selected == 0)
			{
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_NoItems");
			}
			else if(minValue <= tradeValue[client])
			{
				CreateTradeOffer(client);
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Created");
			}
			else
			{
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_ValueTooLow", minValue);	
			}
		}
		else
		{
			Handle inventory = GetLastInventory(client);
			for (int i = 0; i < GetArraySize(inventory); i++)
			{
				Handle trie = GetArrayCell(inventory, i);
				GetTrieString(trie, ITEM_ID, itemID, sizeof(itemID));
				GetTrieValue(trie, ITEM_VALUE, itemValue);
				
				if(StrEqual(itemID, description))
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
	switch(lastSelectedGame[client])
	{
		case GAMEID_TF2: return ARRAY_ItemsTF2[client];
		case GAMEID_CSGO: return ARRAY_ItemsCSGO[client];
		case GAMEID_DOTA2: return ARRAY_ItemsDOTA2[client];
	}
	
	return INVALID_HANDLE;
}

public void CreateTradeOffer(int client)
{
	char itemID[32];
	int selected = 0;
	Handle items = CreateArray(30);
	
	Handle inventory = GetLastInventory(client);
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle trie = GetArrayCell(inventory, i);
		GetTrieValue(trie, ITEM_DONATED, selected);
		
		if(selected == 1)
		{
			GetTrieString(trie, ITEM_ID, itemID, sizeof(itemID));
			PushArrayString(items, itemID);
		}
	}
	
	ASteambot_CreateTradeOffer(client, items)
}

public void GetPlayerCredits(Handle db, Handle results, const char[] error, any data)
{
	float value;
	char steamID[30], offerID[30];
	
	ResetPack(data);
	ReadPackString(data, steamID, sizeof(steamID));
	ReadPackString(data, offerID, sizeof(offerID));
	value = ReadPackFloat(data);
	
	int client = FindClientBySteamID(steamID);
	
	if (results == INVALID_HANDLE)
	{
		SetFailState(error);
		return;
	}
	
	char query[300];
	if (!SQL_FetchRow(results))
	{
		Format(query, sizeof(query), QUERY_INSERT_MONEY, steamID, value);
		DBFastQuery(query);
	}
	else
	{
		value += SQL_FetchFloat(results, 0);
		
		Format(query, sizeof(query), QUERY_UPDATE_MONEY, value, steamID);
		DBFastQuery(query);
	}
	
	if (client != -1)
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Success", value);
}

public void GotDatabase(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	else
	{
		DATABASE = hndl;
		
		if (DBFastQuery(QUERY_CREATE_T_CLIENTS))
			PrintToServer("%s %t", MODULE_NAME, "Database_Success");
	}
}

public int FindClientBySteamID(char[] steamID)
{
	char clientSteamID[30];
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClientASteambot(i))
		{
			GetClientAuthId(i, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
			if (StrEqual(clientSteamID, steamID))
			{
				return i;
			}
		}
	}
	
	return -1;
}

public bool DBFastQuery(const char[] sql)
{
	char error[400];
	SQL_FastQuery(DATABASE, sql);
	if (SQL_GetError(DATABASE, error, sizeof(error)))
	{
		PrintToServer("%s %t", MODULE_NAME, "Database_Failure", error);
		return false;
	}
	
	return true;
}

stock bool IsValidClientASteambot(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
} 