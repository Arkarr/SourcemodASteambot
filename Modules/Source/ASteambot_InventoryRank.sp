#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#include <chat-processor>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.4"
#define MODULE_NAME 			"[ASteambot - Inventory Rank]"

#define ITEM_ID					"itemID"
#define ITEM_NAME				"itemName"
#define ITEM_VALUE				"itemValue"
#define ITEM_DONATED			"itemDonated"
#define TRIE_RNAME				"rank_name"
#define TRIE_RVALUE				"rank_value"
#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Modules/Binaries/addons/sourcemod/ASteambot_InventoryRank.txt"

EngineVersion Game;

char rankTag[MAXPLAYERS + 1][150];

Handle ARRAY_Ranks;
Handle ARRAY_Items[MAXPLAYERS + 1];


//Release note
/*
*Fixed late load problems, added more infos
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Inventory Rank", 
	author = PLUGIN_AUTHOR, 
	description = "Assign a tag to players indicating their game's backpack value", 
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
		ASteambot_RegisterModule("ASteambot_InventoryRank");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public void OnPluginStart()
{	
	RegConsoleCmd("sm_inventoryrank", CMD_InventoryRank, "Force the refresh of the tag");
	RegConsoleCmd("sm_invrank", CMD_InventoryRank, "Force the refresh of the tag");
	RegConsoleCmd("sm_ir", CMD_InventoryRank, "Force the refresh of the tag");
	
	RegAdminCmd("sm_inventoryrank_reload", CMD_ReloadConfig, ADMFLAG_CONFIG, "Reload the configuration file");
	
	LoadTranslations("ASteambot.invrank.phrases");
	
	Game = GetEngineVersion();
	
	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public void OnConfigsExecuted()
{
	Reload();
}

public void OnClientConnected(int client)
{
	GetSteamInventoryValue(client);
}

public Action CMD_ReloadConfig(int client, int args)
{
	if(client != 0)
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "Config_reloaded");
	else
		PrintToServer("%s %t", MODULE_NAME, "Config_reloaded");
		
	Reload();
		
	return Plugin_Handled;
}

public Action CMD_InventoryRank(int client, int args)
{
	if(client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Handled;
	}
	
	if(!ASteambot_IsConnected())
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_NotConnected");
		return Plugin_Handled;
	}	
	
	GetSteamInventoryValue(client);
	
	return Plugin_Handled;
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{
	char[][] parts = new char[4][messageSize];	
	char steamID[40];
	
	ExplodeString(message, "/", parts, 4, messageSize);
	Format(steamID, sizeof(steamID), parts[0]);
	
	int client = ASteambot_FindClientBySteam64(steamID);
	
	if(MessageType == AS_SCAN_INVENTORY && client != -1)
	{		
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_InventoryScanned");
		
		switch(Game)
		{
			case Engine_TF2:  PrepareInventories(client, parts[1], messageSize);
			case Engine_CSGO: PrepareInventories(client, parts[2], messageSize);
			case Engine_DOTA: PrepareInventories(client, parts[3], messageSize);
		}
		
		CalculateRank(client, rankTag[client], sizeof(rankTag[]));
	}	
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	Format(name, MAXLENGTH_NAME, "%s %s", rankTag[author], name);
	
	return Plugin_Changed;
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

//Helper functions

public void LoadRanks()
{
	ARRAY_Ranks = CreateArray();
	
	char path[PLATFORM_MAX_PATH];
	char line[300];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/inventoryranks.cfg");
	Handle file = OpenFile(path,"r");
	
	if(file == INVALID_HANDLE)
		SetFailState("%s NO RANKS FOUND ! CONFIG EXIST ?", MODULE_NAME);
		
	while(!IsEndOfFile(file) && ReadFileLine(file, line, sizeof(line)))
	{
		if(StrContains(line, "=") != -1)
		{
			char tag_value[2][150];
			ExplodeString(line, "=", tag_value, sizeof tag_value, sizeof tag_value[]);
			Handle rank = CreateTrie();
			SetTrieString(rank, TRIE_RNAME, tag_value[0]);
			SetTrieValue(rank, TRIE_RVALUE, StringToFloat(tag_value[1]));
			PushArrayCell(ARRAY_Ranks, rank);
		}
	}
	
	if(GetArraySize(ARRAY_Ranks) == 0)
		SetFailState("%s NO RANKS FOUND ! CONFIG EXIST ?", MODULE_NAME);
	
	CloseHandle(file);
}

stock void Reload()
{
	LoadRanks();
	
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			GetSteamInventoryValue(i);
		}
	}
}

stock void CalculateRank(int client, char[] rT, int rankTagSize)
{
	int nbrItems = GetArraySize(ARRAY_Items[client]);
	
	if(nbrItems == 0)
	{
		Handle rank = GetArrayCell(ARRAY_Ranks, 0);
		GetTrieString(rank, TRIE_RNAME, rT, rankTagSize);
		return;
	}
		
	float totalValue = 0.0;
	float value = 0.0;
	
	for (int i = 0; i < nbrItems; i++)
	{
		Handle item = GetArrayCell(ARRAY_Items[client], i);
		GetTrieValue(item, ITEM_VALUE, value);
		totalValue += value;
	}
	
	for (int rankID = 0; rankID < GetArraySize(ARRAY_Ranks); rankID++)
	{
		Handle rank = GetArrayCell(ARRAY_Ranks, rankID);
		GetTrieValue(rank, TRIE_RVALUE, value);
		if(value > totalValue)
		{
			if(rankID > 0)
				rankID--;
				
			rank = GetArrayCell(ARRAY_Ranks, rankID);
			GetTrieString(rank, TRIE_RNAME, rT, rankTagSize);
			return;
		}
	}
	
	Handle rank = GetArrayCell(ARRAY_Ranks, 0);
	GetTrieString(rank, TRIE_RNAME, rT, rankTagSize);
}

stock void GetSteamInventoryValue(int client)
{
	if(!IsValidClient(client))
		return;
		
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	ASteambot_SendMesssage(AS_SCAN_INVENTORY, clientSteamID);
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
} 