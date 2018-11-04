#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.2"
#define MODULE_NAME 			"[ASteambot - Server Offer]"

#define ITEM_ID					"itemID"
#define ITEM_NAME				"itemName"
#define ITEM_VALUE				"itemValue"
#define ITEM_DISPLAY			"itemDisplay"
#define ITEM_MESSAGE			"itemMsg"
#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Modules/Binaries/addons/sourcemod/ASteambot_ServerOffer.txt"

EngineVersion Game;

int offerIndex[MAXPLAYERS + 1];

char itemID[MAXPLAYERS + 1][30];

Handle ARRAY_Items[MAXPLAYERS + 1];

//Release note
/*
*Fixed late load problems
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Server Offer", 
	author = PLUGIN_AUTHOR, 
	description = "Allow user to create and display offers and also read the current offers in the server.", 
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
		ASteambot_RegisterModule("ASteambot_ServerItem");
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_editoffer", CMD_EditOffers, "Edit your current offers");
	RegConsoleCmd("sm_showitems", CMD_ShowItems, "Show your current items");
	RegConsoleCmd("sm_reloaditems", CMD_ReloadItems, "Reload your inventory offer");
	RegConsoleCmd("sm_myoffers", CMD_Ad, "Print one of your offers");
	RegConsoleCmd("sm_offers", CMD_ShowOffers, "Display all offers");

	LoadTranslations("ASteambot.serveroffer.phrases");
	
	Game = GetEngineVersion();

	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action CMD_ShowOffers(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Handled;
	}
	
	ShowAllOffersMenu(client);
	
	return Plugin_Handled;
}

public Action CMD_ReloadItems(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "{green}%s {default}%t", MODULE_NAME, "ItemsReload");
	
	GetSteamInventory(client);
		
	return Plugin_Handled;
}

public Action CMD_ShowItems(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Handled;
	}
	
	DisplayEditOfferMenu(client);
		
	return Plugin_Handled;
}

public Action CMD_EditOffers(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Handled;
	}
	
	if(StrEqual(itemID[client], "NONE") || StrEqual(itemID[client], ""))
	{
		CPrintToChat(client, "{green}%s {default}%t", MODULE_NAME, "ItemSelectFirstly");
		DisplayEditOfferMenu(client);
	}
	else
	{	    
		Handle item = GetItemByID(itemID[client]);
		
		if(item == INVALID_HANDLE)
		{
			CPrintToChat(client, "{green}%s {fullred}Unknow error while setting your item message !", MODULE_NAME);
		}
		else
		{
			char itemName[50];
			char message[500];
			GetCmdArgString(message, sizeof(message));
			GetTrieString(item, ITEM_NAME, itemName, sizeof(itemName));
			SetTrieValue(item, ITEM_DISPLAY, 1);
			Format(message, sizeof(message), "[%N] {yellow}%s{green} |{default} %s", client, itemName, message);
			SetTrieString(item, ITEM_MESSAGE, message);
			
			CPrintToChat(client, "{green}%s {default}Message set to '%s{default}' for item '%s' !", MODULE_NAME, message, itemName);
			
			DisplayEditOfferMenu(client);
			
			Format(itemID[client], sizeof(itemID[]), "NONE");
		}
	}
		
	return Plugin_Handled;
}

public Action CMD_Ad(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Handled;
	}
	
	PrintNextOffer(client);
	
	return Plugin_Handled;
}

public void PrintNextOffer(int client)
{
	int startID = offerIndex[client];
	int isOffer = 0;
	for (int i = startID; i < GetArraySize(ARRAY_Items[client]); i++)
	{
		Handle item = GetArrayCell(ARRAY_Items[client], i);
		GetTrieValue(item, ITEM_DISPLAY, isOffer);
		if(isOffer == 1)
		{
			char msg[300];
			GetTrieString(item, ITEM_MESSAGE, msg, sizeof(msg));
			offerIndex[client] = i+1;
			
			CPrintToChatAll(msg);
			
			return;
		}
	}
	
	//Ugly
	if(startID != 0)
	{
	 	offerIndex[client] = 0;
		PrintNextOffer(client);
	}
	else
	{
		CPrintToChat(client, "{green}%s {default}%t", MODULE_NAME, "NoOfferFound");
	}
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{
	char[][] parts = new char[4][messageSize];	
	char steamID[40];
	
	ExplodeString(message, "/", parts, 4, messageSize);
	Format(steamID, sizeof(steamID), parts[0]);
	
	int client = FindClientBySteamID(steamID);
	
	if(MessageType == AS_SCAN_INVENTORY && client != -1)
	{		
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "InventoryScanned");
		
		switch(Game)
		{
			case Engine_TF2:  PrepareInventories(client, parts[1], messageSize);
			case Engine_CSGO: PrepareInventories(client, parts[2], messageSize);
			case Engine_DOTA: PrepareInventories(client, parts[3], messageSize);
		}
	}	
}

public void PrepareInventories(int client, const char[] inventory, int charSize)
{
	int icount = CountCharInString(inventory, ',')+1;
	
	ARRAY_Items[client] = CreateArray(icount);
	
	CreateInventory(client, inventory, icount, ARRAY_Items[client]);
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
			SetTrieValue(TRIE_Item, ITEM_DISPLAY, 0);
			PushArrayCell(inventory, TRIE_Item);
		}
	}
	else if(StrEqual(strinventory, "ERROR"))
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ItemsError", strinventory);
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

public int FindClientBySteamID(char[] steamID)
{
	char clientSteamID[30];
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
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

public int MenuHandle_ItemSelect(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, itemIndex, itemID[client], sizeof(itemID[]));

		CPrintToChat(client, "{green}%s {default}%t", MODULE_NAME, "OfferEdit");
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public int MenuHandle_OfferSelect(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, itemIndex, itemID[client], sizeof(itemID[]));
		
		char message[500];
		Handle item = GetItemByID(itemID[client]);
		GetTrieString(item, ITEM_MESSAGE, message, sizeof(message));

		CPrintToChat(client, message);
		
		ShowAllOffersMenu(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public void DisplayEditOfferMenu(int client)
{
	Handle inventory = ARRAY_Items[client];
	Handle menu = CreateMenu(MenuHandle_ItemSelect);
	
	SetMenuTitle(menu, "%t", "MenuOfferEdit");
	
	char itemName[30];
	float itemValue;
	int itemDisplay;
	
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle trie = GetArrayCell(inventory, i);
		GetTrieString(trie, ITEM_NAME, itemName, sizeof(itemName));
		GetTrieString(trie, ITEM_ID, itemID[client], sizeof(itemID[]));
		GetTrieValue(trie, ITEM_VALUE, itemValue);
		GetTrieValue(trie, ITEM_DISPLAY, itemDisplay);
		
		char menuItem[35];
		
		if(itemDisplay == 0)
			Format(menuItem, sizeof(menuItem), "[N] %s", itemName);
		else
			Format(menuItem, sizeof(menuItem), "[Y] %s", itemName);
			
		AddMenuItem(menu, itemID[client], menuItem);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	Format(itemID[client], sizeof(itemID[]), "NONE");
}

public void ShowAllOffersMenu(int client)
{
	Handle menu = CreateMenu(MenuHandle_OfferSelect);
	
	SetMenuTitle(menu, "All offers :");
	
	char itemName[30];
	int itemDisplay;
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			Handle inventory = ARRAY_Items[i];
			for (int y = 0; y < GetArraySize(inventory); y++)
			{
				Handle trie = GetArrayCell(inventory, y);
				GetTrieString(trie, ITEM_NAME, itemName, sizeof(itemName));
				GetTrieString(trie, ITEM_ID, itemID[client], sizeof(itemID[]));
				GetTrieValue(trie, ITEM_DISPLAY, itemDisplay);
				
				if(itemDisplay == 1)
					AddMenuItem(menu, itemID[client], itemName);
			}
		}
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
	Format(itemID[client], sizeof(itemID[]), "NONE");
}

stock void GetSteamInventory(int client)
{
	if(!IsValidClient(client))
		return;
		
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	ASteambot_SendMesssage(AS_SCAN_INVENTORY, clientSteamID);
}

stock Handle GetItemByID(const char[] id)
{
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			char iID[30];
			for (int y = 0; y < GetArraySize(ARRAY_Items[i]); y++)
			{
				Handle item = GetArrayCell(ARRAY_Items[i], y);
				GetTrieString(item, ITEM_ID, iID, sizeof(iID));
				
				if(StrEqual(iID, id))
					return item;
			}
		}
	}
	
	return INVALID_HANDLE;
}

//Helper functions
stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
} 