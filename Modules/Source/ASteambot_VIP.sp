#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#include <VIP-Manager>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.0"
#define MODULE_NAME 			"[ASteambot - VIP]"

#define ITEM_ID					"itemID"
#define ITEM_NAME				"itemName"
#define ITEM_VALUE				"itemValue"
#define ITEM_DONATED			"itemDonated"
#define VIPP_ITEMS				"items"
#define VIPP_TIME				"vip_time"
#define VIPP_NAME				"package_name"
#define VIPP_ID					"id"

#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Modules/Binaries/addons/sourcemod/ASteambot_VIP.txt"

float tradeValue[MAXPLAYERS + 1];

int VIPDuration[MAXPLAYERS + 1];

Handle ARRAY_Packages;
Handle ARRAY_ItemsTF2[MAXPLAYERS + 1];
Handle ARRAY_ItemsCSGO[MAXPLAYERS + 1];
Handle ARRAY_ItemsDOTA2[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[ANY] ASteambot VIP", 
	author = PLUGIN_AUTHOR, 
	description = "Players can donate a certain ammount of $ through steam items to get a VIP status.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max)
{	
	MarkNativeAsOptional("ModVIP");

	return APLRes_Success;
}

public void OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_VIP");
	
	RegConsoleCmd("sm_donatevip", CMD_GetVP, "Create a trade offer and send it to the player.");
	
	LoadTranslations("ASteambot.vip.phrases");

	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public void OnConfigsExecuted()
{
	LoadVIPPackages();
}

public void LoadVIPPackages()
{
	ARRAY_Packages = CreateArray();
	
	Handle kv = CreateKeyValues("VIP_Packages");
	FileToKeyValues(kv, "addons/sourcemod/configs/vippackages.cfg");
	
	if (!KvGotoFirstSubKey(kv))
	{
		SetFailState("%s CONFIG FILE NOT FOUND !!", MODULE_NAME);
		return;
	}
	
	char vippackage[255];
	char items[255];
	char time[255];
	
	int id = 0;
	do
	{
		KvGetSectionName(kv, vippackage, sizeof(vippackage));
		KvGetString(kv, VIPP_ITEMS, items, sizeof(items));
		KvGetString(kv, VIPP_TIME, time, sizeof(time));
		
		Handle trie = CreateTrie();
		SetTrieString(trie, VIPP_NAME, vippackage, false);
		SetTrieValue(trie, VIPP_TIME, StringToInt(time), false);
		
		char[][] iItems = new char[100][100];
		int nbrItems = ExplodeString(items, ",", iItems, 40, 45);
		
		Handle tmpArray = CreateArray(45);
		for (int i = 0; i < nbrItems; i++)
			PushArrayString(tmpArray, iItems[i]);
		
		SetTrieValue(trie, VIPP_ITEMS, tmpArray, false);
		
		SetTrieValue(trie, VIPP_ID, id, false);
		
		PushArrayCell(ARRAY_Packages, trie);
		id++;
	}
	while (KvGotoNextKey(kv));
}

public Action CMD_GetVP(int client, int args)
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
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_WaitItems");
	
	tradeValue[client] = 0.0;
	
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	
	ASteambot_SendMesssage(AS_SCAN_INVENTORY, clientSteamID);
	
	return Plugin_Handled;
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{
	char[][] parts = new char[4][messageSize];
	char steamID[40];
	
	ExplodeString(message, "/", parts, 4, messageSize);
	Format(steamID, sizeof(steamID), parts[0]);
	
	int client = FindClientBySteamID(steamID);
	
	if (MessageType == AS_NOT_FRIENDS && client != -1)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Steam_NotFriends");
		char clientSteamID[30];
		
		GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
		ASteambot_SendMesssage(AS_FRIEND_INVITE, clientSteamID);
		
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Steam_FriendInvitSend");
	}
	else if (MessageType == AS_SCAN_INVENTORY && client != -1)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_InventoryScanned");
		PrepareInventories(client, parts[1], parts[2], parts[3], messageSize)
	}
	else if (MessageType == AS_TRADEOFFER_DECLINED && client != -1)
	{
		CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Declined");
	}
	else if (MessageType == AS_TRADEOFFER_SUCCESS && client != -1)
	{
		/*char[] offerID = new char[messageSize];
		char[] value = new char[messageSize];
		
		Format(offerID, messageSize, parts[1]);
		Format(value, messageSize, parts[2]);*/
		
		char pName[45];
		GetClientName(client, pName, sizeof(pName));
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Success", pName);
		
		
		ModVIP(client, "add", 0, VIPDuration[client] );
	}
}

public void PrepareInventories(int client, const char[] tf2, const char[] csgo, const char[] dota2, int charSize)
{
	int tf2_icount = CountCharInString(tf2, ',') + 1;
	int csgo_icount = CountCharInString(csgo, ',') + 1;
	int dota2_icount = CountCharInString(dota2, ',') + 1;
	
	ARRAY_ItemsTF2[client] = CreateArray(tf2_icount);
	ARRAY_ItemsCSGO[client] = CreateArray(csgo_icount);
	ARRAY_ItemsDOTA2[client] = CreateArray(dota2_icount);
	
	CreateInventory(client, tf2, tf2_icount, ARRAY_ItemsTF2[client]);
	CreateInventory(client, csgo, csgo_icount, ARRAY_ItemsCSGO[client]);
	CreateInventory(client, dota2, dota2_icount, ARRAY_ItemsDOTA2[client]);
	
	DisplayVIPPackageSelection(client);
}

public void CreateInventory(int client, const char[] strinventory, int itemCount, Handle inventory)
{
	if (!StrEqual(strinventory, "EMPTY"))
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
	else if (StrEqual(strinventory, "ERROR"))
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

public bool GetItemID(int client, const char[] mainItemName, char[] itemID, int itemIDsize)
{
	if(GetItemIDFromInventory(ARRAY_ItemsTF2[client], mainItemName, itemID, itemIDsize))
		return true;
	else if(GetItemIDFromInventory(ARRAY_ItemsCSGO[client], mainItemName, itemID, itemIDsize))
		return true;
	else if(GetItemIDFromInventory(ARRAY_ItemsDOTA2[client], mainItemName, itemID, itemIDsize))
		return true;
		
	return false;
}

public bool GetItemIDFromInventory(Handle inventory, const char[] mainItemName, char[] itemID, int itemIDsize)
{
	char itemName[100];
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle t = GetArrayCell(inventory, i);
		GetTrieString(t, ITEM_NAME, itemName, sizeof(itemName));

		if (StrEqual(itemName, mainItemName))
		{
			int donated = -1;
			GetTrieValue(t, ITEM_DONATED, donated)
			if(donated == 0)
			{ 
				SetTrieValue(t, ITEM_DONATED, 1);
				GetTrieString(t, ITEM_ID, itemID, itemIDsize);
				return true;
			}
		}
	}
	
	return false;
}

public void ResetInventory(Handle inventory)
{
	for (int i = 0; i < GetArraySize(inventory); i++)
	{
		Handle t = GetArrayCell(inventory, i);
		SetTrieValue(t, ITEM_DONATED, 0);
	}
}

public void ResetInventories(int client)
{
	ResetInventory(ARRAY_ItemsTF2[client]);
	ResetInventory(ARRAY_ItemsCSGO[client]);
	ResetInventory(ARRAY_ItemsDOTA2[client]);
}

public Handle AvailabeVIPPackage(int client)
{
	Handle ARRAY_ClientPackages = CreateArray();
	
	for (int i = 0; i < GetArraySize(ARRAY_Packages); i++)
	{
		Handle trie = GetArrayCell(ARRAY_Packages, i);
		Handle items;
		int itemFound = 0;
		char mainItemName[100];
		char packageName[100];
		
		GetTrieValue(trie, VIPP_ITEMS, items);
		GetTrieString(trie, VIPP_NAME, packageName, sizeof(packageName));
		
		for (int j = 0; j < GetArraySize(items); j++)
		{
			GetArrayString(items, j, mainItemName, sizeof(mainItemName));
			
			char itemID[30];
			
			bool result = GetItemID(client, mainItemName, itemID, sizeof(itemID));

			if(result && StrEqual(itemID, "NOT_FOUND") == false)
			{
				itemFound++;
			}
			else
			{
				//CPrintToChat(client, "%s {fullred}Item %s not found for package %s !", MODULE_NAME, mainItemName, packageName);
			}
		}
		
		if (itemFound == GetArraySize(items))
			PushArrayCell(ARRAY_ClientPackages, trie);
			
	
		ResetInventories(client);
	}
	
	return ARRAY_ClientPackages;
}

public void DisplayVIPPackageSelection(int client)
{
	Handle VIPpackage = AvailabeVIPPackage(client);
	
	if(GetArraySize(VIPpackage) == 0)
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "VIP_NoPackageAvailable");
		return;
	}
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_SelectTradeOffer");
	
	Handle menu = CreateMenu(MenuHandle_MainMenu);
	SetMenuTitle(menu, "Select a VIP package :");
	
	for (int i = 0; i < GetArraySize(VIPpackage); i++)
	{
		Handle trie = GetArrayCell(VIPpackage, i);
		char pname[40];
		char num[10];
		int id;
		GetTrieValue(trie, VIPP_ID, id);
		GetTrieString(trie, VIPP_NAME, pname, sizeof(pname));
		IntToString(id, num, sizeof(num));
		AddMenuItem(menu, num, pname);
	}
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_MainMenu(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char description[32];
		GetMenuItem(menu, itemIndex, description, sizeof(description));
		
		ShowPackageMenu(client, StringToInt(description));
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public void ShowPackageMenu(int client, int packageID)
{	
	Handle items;
	char iname[50];
	char itemID[30];
	char packageName[55];
	Handle VIPpackage = GetArrayCell(ARRAY_Packages, packageID);
	
	GetTrieString(VIPpackage, VIPP_NAME, packageName, sizeof(packageName));
	GetTrieValue(VIPpackage, VIPP_ITEMS, items);
	GetTrieValue(VIPpackage, VIPP_TIME, VIPDuration[client]);
	
	Handle menu = CreateMenu(MenuHandle_PackageSelect);
	SetMenuTitle(menu, packageName);

	for (int i = 0; i < GetArraySize(items); i++)
	{
		GetArrayString(items, i, iname, sizeof(iname));
		if(GetItemID(client, iname, itemID, sizeof(itemID)))
		{
			AddMenuItem(menu, itemID, iname, ITEMDRAW_DEFAULT);
		}
		else
		{
			PrintToServer("");
		}
	}
	
	AddMenuItem(menu, "OK", "OK!");
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandle_PackageSelect(Handle menu, MenuAction action, int client, int itemIndex)
{
	if (action == MenuAction_Select)
	{
		char itemID[32];
		GetMenuItem(menu, itemIndex, itemID, sizeof(itemID));
		if(StrEqual(itemID, "OK"))
		{
			Handle items = CreateArray(100);
			
			for (int i = 0; i < itemIndex; i++)
			{
				GetMenuItem(menu, i, itemID, sizeof(itemID));
				PushArrayString(items, itemID);
			}
			
			ASteambot_CreateTradeOffer(client, items);
			
			CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Created");
		}
		else
		{
			CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "VIP_Denied");
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
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

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
} 