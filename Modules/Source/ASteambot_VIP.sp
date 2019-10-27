#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 		 	"Arkarr"
#define PLUGIN_VERSION 			"2.2"
#define MODULE_NAME 			"[ASteambot - VIP]"

#define ITEM_ID					"itemID"
#define ITEM_NAME				"itemName"
#define ITEM_VALUE				"itemValue"
#define ITEM_DONATED			"itemDonated"
#define VIPP_ITEMS				"items"
#define VIPP_TIME				"vip_time"
#define VIPP_FLAGS				"vip_flags"
#define VIPP_NAME				"package_name"
#define VIPP_ID					"id"

#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_VIP.txt"

#define QUERY_UPDATE_DATABASE	"INSERT INTO t_vip_members_v2 (vip_steamid, vip_flag, vip_time, vip_immunity) SELECT * FROM t_vip_members;"
#define QUERY_RECOVER_OLD_DATA	"UPDATE t_vip_members_v2 SET vip_active='1';"
#define QUERY_DELETE_OLD_DATA	"DROP TABLE  t_vip_members;"
#define QUERY_CREATE_T_VIP		"CREATE TABLE `t_vip_members_v2` (`vip_steamid` VARCHAR(30) NOT NULL, `vip_flag` VARCHAR(200) NOT NULL, `vip_time` INT(30) NOT NULL, `vip_immunity` INT(30) NOT NULL, `vip_active` INT(5) NOT NULL, PRIMARY KEY (`vip_steamid`)) ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;"
#define QUERY_CREATE_T_TRADE	"CREATE TABLE IF NOT EXISTS `t_vip_trade_logs` (`vip_steamid` VARCHAR(30) NOT NULL, `trade_id` VARCHAR(30) NOT NULL, `trade_status` VARCHAR(30) NOT NULL, PRIMARY KEY (`trade_id`))ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;"
#define QUERY_CREATE_T_VIPBAN	"CREATE TABLE IF NOT EXISTS `t_vip_ban` (`steamid` VARCHAR(30) NOT NULL, `vip_ban_time` VARCHAR(30) NOT NULL, PRIMARY KEY (`steamid`))ENGINE = InnoDB DEFAULT CHARACTER SET = latin1;"
#define QUERY_ADD_VIPBAN		"INSERT INTO `t_vip_ban` (`steamid`, `vip_ban_time`) VALUES ('%s', '%i');"
#define QUERY_SELECT_VIPBAN		"SELECT * FROM `t_vip_ban` WHERE steamid='%s';"
#define QUERY_ADD_VIP			"INSERT INTO `t_vip_members_v2` (`vip_steamid`, `vip_flag`, `vip_time`, `vip_active`) VALUES ('%s', '%s', '%i', '0');"
#define QUERY_ADD_TRADE			"INSERT INTO `t_vip_trade_logs` (`vip_steamid`, `trade_id`, `trade_status`) VALUES ('%s', '%s', '%s');"
#define QUERY_UPD_TRADE			"UPDATE `t_vip_trade_logs` SET `trade_status` = '%s' WHERE `trade_id` = '%s'; "
#define QUERY_SELECT_VIP		"SELECT * FROM `t_vip_members_v2` WHERE vip_steamid='%s' AND `vip_active` = 1;"
#define QUERY_ACTIVATE_VIP		"UPDATE t_vip_members_v2 SET vip_active=1 WHERE vip_steamid='%s';"
#define QUERY_DELETE_VIP		"DELETE FROM `t_vip_members_v2` WHERE `vip_steamid`='%s' AND `vip_time` <= '%i';"
#define QUERY_DELETE_VIP_FORCE	"DELETE FROM `t_vip_members_v2` WHERE `vip_steamid`='%s';"
#define QUERY_SELECT_TRADE_LOG	"SELECT trade_id FROM `t_vip_trade_logs` WHERE vip_steamid='%s' AND trade_status='%s';"

#define TRADEOFFER_ACCEPTED 	"TradeOfferStateAccepted"
#define TRADEOFFER_UNCONFIRMED 	"TradeOfferStateActive"
#define TRADEOFFER_DECLINED 	"TradeOfferStateDeclined"

int VIPDuration[MAXPLAYERS + 1];
char VIPFlags[MAXPLAYERS + 1][200];

Handle DATABASE;
Handle ARRAY_Packages;
Handle ARRAY_ItemsTF2[MAXPLAYERS + 1];
Handle ARRAY_ItemsCSGO[MAXPLAYERS + 1];
Handle ARRAY_ItemsDOTA2[MAXPLAYERS + 1];

Handle CVAR_MessageOnTradeSucess;

//Release note
/*
* Added a command where you can check your trade offer status in case of bug
*/

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

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_VIP");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public void OnPluginStart()
{	
	RegConsoleCmd("sm_donatevip", CMD_GetVIP, "Create a trade offer and send it to the player.");
	RegConsoleCmd("sm_vipstatus", CMD_GetVIPStatus, "Give current VIP information about the player executing the command.");
	
	RegAdminCmd("sm_ban_vip", CMD_BanVIP, ADMFLAG_BAN, "Ban a user from buying VIP access.");
	
	CVAR_MessageOnTradeSucess = CreateConVar("sm_asteambot_vip_message_on_trade_success", "", "Send this message on trade sucessful through steam chat.");
	
	LoadTranslations("ASteambot.vip.phrases");
	LoadTranslations("common.phrases");

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
	
	SQL_TConnect(ConnectToDatabaseResult, "ASteambot-VIP");
}

public void OnClientPostAdminFilter(int client)
{
	VIPDuration[client] = 0;
	VIPFlags[client] = "";
	CheckVIPAccess(client);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if(part == AdminCache_Overrides)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
	    	if (IsClientInGame(i))
	        	CheckVIPAccess(i);
	    }
	}
}

void CheckVIPAccess(int client)
{
	char query[100];
	char steamID[40];
	
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Format(query, sizeof(query), QUERY_SELECT_VIP, steamID);
	DBResultSet q = SQL_Query(DATABASE, query);
	
	if (q == null)
	{
		char error[255];
		SQL_GetError(DATABASE, error, sizeof(error));
		SetFailState("%s %t", MODULE_NAME, "Database_Failure", error);
	} 
	else 
	{
		int day;
		char flag[200];
	
		PrintToServer(query);
		while (SQL_FetchRow(q))
		{
			SQL_FetchString(q, 0, steamID, sizeof(steamID));
			SQL_FetchString(q, 1, flag, sizeof(flag));
			day = SQL_FetchInt(q, 2);
			
			int currentDaytime = GetTime();

			if(currentDaytime > day)
			{
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_Ended");
				
				Format(query, sizeof(query), QUERY_DELETE_VIP, steamID, currentDaytime);
				DBFastQuery(query);
			}
			else
			{
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_Continue");
				
				SetUserFlagBits(client, ParseFlagString(flag));
			}
		}
		
		delete q;
	}
}

void ConnectToDatabaseResult(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	else
	{
		DATABASE = hndl;
		
		
		if(DBFastQuery(QUERY_CREATE_T_VIP, false))
		{
			if(!DBFastQuery(QUERY_UPDATE_DATABASE) || !DBFastQuery(QUERY_RECOVER_OLD_DATA))
				SetFailState("%s %t", MODULE_NAME, "Database_Failure", "Could not remove old tables.");
			else
				DBFastQuery(QUERY_DELETE_OLD_DATA);
		}
		
		if (DBFastQuery(QUERY_CREATE_T_TRADE) && DBFastQuery(QUERY_CREATE_T_VIPBAN))
		{
			PrintToServer("%s %t", MODULE_NAME, "Database_Success");
			
			for (new i = 1; i <= MaxClients; i++)
			{
		    	if (IsClientInGame(i))
		        	CheckVIPAccess(i);
		    }
		}
		else
		{
			SetFailState("%s %t", MODULE_NAME, "Database_Failure", error);
		}
	}
}

bool DBFastQuery(const char[] sql, bool errorReport = true)
{
	char error[400];
	SQL_FastQuery(DATABASE, sql);
	if (SQL_GetError(DATABASE, error, sizeof(error)))
	{
		if(errorReport)
			PrintToServer("%s %t", MODULE_NAME, "Database_Failure", error);
			
		return false;
	}
	
	return true;
}

public int ParseFlagString(const char[] flags)
{
	char flagNames[32][16];
	int flagCount = ExplodeString(flags, ",", flagNames, sizeof(flagNames), sizeof(flagNames[]));
	int flag;
	for (int i = 0; i < flagCount; i++) 
		flag |= ReadFlagString(flagNames[i]);
	
	return flag;
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
	char items[10000];
	char time[255];
	char flags[255];
	
	int id = 0;
	do
	{
		KvGetSectionName(kv, vippackage, sizeof(vippackage));
		KvGetString(kv, VIPP_ITEMS, items, sizeof(items));
		KvGetString(kv, VIPP_TIME, time, sizeof(time));
		KvGetString(kv, VIPP_FLAGS, flags, sizeof(flags));
		
		Handle trie = CreateTrie();
		SetTrieString(trie, VIPP_NAME, vippackage, false);
		SetTrieValue(trie, VIPP_TIME, StringToInt(time), false);
		SetTrieString(trie, VIPP_FLAGS, flags, false);
		
		char[][] iItems = new char[100][100];
		int nbrItems = ExplodeString(items, ",", iItems, 100, 100);
		
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

public Action CMD_BanVIP(int client, int args)
{
	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, true);
	
	if(target == -1)
		return Plugin_Handled;
	
	char query[300];
	char steamID[40];
	
	GetClientAuthId(target, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Format(query, sizeof(query), QUERY_ADD_VIPBAN, steamID, GetTime());
	DBFastQuery(query);

	GetClientName(target, arg1, sizeof(arg1));

	if(client != 0)
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_BanSuccess", arg1);
	else
		PrintToServer("%s %t", MODULE_NAME, "VIP_BanSuccess", arg1);
	
	Format(query, sizeof(query), QUERY_DELETE_VIP_FORCE, steamID);
	DBFastQuery(query);
	
	return Plugin_Handled;
}

public Action CMD_GetVIP(int client, int args)
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
	
	char query[100];
	char steamID[40];
	
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Format(query, sizeof(query), QUERY_SELECT_VIP, steamID);
	DBResultSet q = SQL_Query(DATABASE, query);
	
	if (q == null)
	{
		char error[255];
		SQL_GetError(DATABASE, error, sizeof(error));
		
		SetFailState("%s %t", MODULE_NAME, "Database_Failure", error);
	} 
	else if(SQL_GetRowCount(q) > 0)
	{
		int endTime;
		char time[50];
	
		while (SQL_FetchRow(q))
		{
			SQL_FetchString(q, 0, steamID, sizeof(steamID));
			endTime = SQL_FetchInt(q, 2);

			if(endTime > GetTime())
			{
				FormatTime(time, sizeof(time), "%d/%m/%Y @ %H:%M:%S", endTime);
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_EndTime", time);
		
				return Plugin_Handled;
			}
		}
	}

	Format(query, sizeof(query), QUERY_SELECT_VIPBAN, steamID);
	q = SQL_Query(DATABASE, query);
	if(SQL_GetRowCount(q) > 0)
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "VIP_BanAbuse");
		
		return Plugin_Handled;
	}
	
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_WaitItems");
	
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	
	ASteambot_SendMesssage(AS_SCAN_INVENTORY, clientSteamID);
	
	return Plugin_Handled;
}

public Action CMD_GetVIPStatus(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("%s %t", MODULE_NAME, "ingame");
		return Plugin_Continue;
	}
	
	char query[400];
	char steamID[40];
	
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
	
	Format(query, sizeof(query), QUERY_SELECT_VIP, steamID);
	DBResultSet q = SQL_Query(DATABASE, query);
	
	if (q == null)
	{
		char error[255];
		SQL_GetError(DATABASE, error, sizeof(error));
		
		SetFailState("%s %t", MODULE_NAME, "Database_Failure", error);
	} 
	else if(SQL_GetRowCount(q) > 0)
	{
		int endTime;
		char time[50];
	
		while (SQL_FetchRow(q))
		{
			SQL_FetchString(q, 0, steamID, sizeof(steamID));
			endTime = SQL_FetchInt(q, 2);

			if(endTime > GetTime())
			{
				FormatTime(time, sizeof(time), "%d/%m/%Y @ %H:%M:%S", endTime);
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_EndTime", time);
				
				return Plugin_Handled;
			}
		}
	}
	
	//check trade offer logs		
	Format(query, sizeof(query), QUERY_SELECT_TRADE_LOG, steamID, TRADEOFFER_UNCONFIRMED);
	q = SQL_Query(DATABASE, query);
	
	if (q == null)
	{
		char error[255];
		SQL_GetError(DATABASE, error, sizeof(error));
		
		SetFailState("%s %t", MODULE_NAME, "Database_Failure", error);
	} 
	else if(SQL_GetRowCount(q) > 0)
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_CheckingTradeOfferStatus", SQL_GetRowCount(q));
		
		char tradeOfferID[20];
		while (SQL_FetchRow(q))
		{
			SQL_FetchString(q, 0, tradeOfferID, sizeof(tradeOfferID));

			ASteambot_SendMesssage(AS_TRADEOFFER_INFORMATION, tradeOfferID);
		}
	}
	else
	{
		CPrintToChat(client, "%s {green}%t", MODULE_NAME, "VIP_NoTradeOffers");
	}

	return Plugin_Handled;
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
	else if (MessageType == AS_CREATE_TRADEOFFER)
	{
		if(!StrEqual(parts[1], "-1"))
		{			
			if(client != -1)
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Created");
		
			char query[300];
			Format(query, sizeof(query), QUERY_ADD_TRADE, steamID, parts[1], TRADEOFFER_UNCONFIRMED);
			PrintToServer(query);
			SQL_FastQuery(DATABASE, query);
		
			Format(query, sizeof(query), QUERY_DELETE_VIP, steamID, GetTime());
			DBFastQuery(query);
			
			Format(query, sizeof(query), QUERY_ADD_VIP, steamID, VIPFlags[client], GetTime() + (VIPDuration[client] * 60 * 60 * 24));
			DBFastQuery(query);
		}
		else if (client != -1)
		{
			CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_TimeOut");
		}
	}
	else if (MessageType == AS_TRADEOFFER_DECLINED)
	{
		if(client != -1)
			CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Declined");
			
		char query[300];
		
		Format(query, sizeof(query), QUERY_UPD_TRADE, TRADEOFFER_DECLINED, parts[2]);
		PrintToServer(query);
		SQL_FastQuery(DATABASE, query);
	}
	else if (MessageType == AS_TRADEOFFER_SUCCESS)
	{
		if(client != -1)
		{
			char pName[45];
			GetClientName(client, pName, sizeof(pName));
			CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Success", pName);
			SetUserFlagBits(client, ParseFlagString(VIPFlags[client]));
		}
		
		char query[300];
		
		Format(query, sizeof(query), QUERY_UPD_TRADE, TRADEOFFER_ACCEPTED, parts[2]);
		SQL_FastQuery(DATABASE, query);
		
		Format(query, sizeof(query), QUERY_ACTIVATE_VIP, steamID);
		DBFastQuery(query);
			
		char msg[400];
		GetConVarString(CVAR_MessageOnTradeSucess, msg, sizeof(msg));
		
		if(strlen(msg) > 0)
		{
			Format(msg, sizeof(msg), "%s/%s", steamID, msg);
			ASteambot_SendMesssage(AS_SIMPLE, msg);
		}
	}
	else if (MessageType == AS_TRADEOFFER_INFORMATION)
	{
		if(StrEqual(parts[1], TRADEOFFER_ACCEPTED))
		{
			char query[300];
			
			Format(query, sizeof(query), QUERY_DELETE_VIP, steamID, GetTime());
			DBFastQuery(query);
		
			Format(query, sizeof(query), QUERY_ACTIVATE_VIP, steamID);
			DBFastQuery(query);
				
			Format(query, sizeof(query), QUERY_UPD_TRADE, TRADEOFFER_ACCEPTED, parts[2]);
			SQL_FastQuery(DATABASE, query);
				
			if(client != -1)
			{
				char pName[45];
				GetClientName(client, pName, sizeof(pName));
				CPrintToChat(client, "%s {green}%t", MODULE_NAME, "TradeOffer_Success", pName);
				SetUserFlagBits(client, ParseFlagString(VIPFlags[client]));
			}
			
			CheckVIPAccess(client);
			
			char msg[400];
			GetConVarString(CVAR_MessageOnTradeSucess, msg, sizeof(msg));
			
			if(strlen(msg) > 0)
			{
				Format(msg, sizeof(msg), "%s/%s", steamID, msg);
				ASteambot_SendMesssage(AS_SIMPLE, msg);
			}
		}
		else if(StrEqual(parts[1], TRADEOFFER_UNCONFIRMED))
		{
			if(client != -1)
				CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Unconfirmed");
		}
		else if(StrEqual(parts[1], TRADEOFFER_DECLINED))
		{
			if(client != -1)
				CPrintToChat(client, "%s {red}%t", MODULE_NAME, "TradeOffer_Declined");
		}
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
	
	bool inv_tf2 = CreateInventory(client, tf2, tf2_icount, ARRAY_ItemsTF2[client]);
	bool inv_csgo = CreateInventory(client, csgo, csgo_icount, ARRAY_ItemsCSGO[client]);
	bool inv_dota2 = CreateInventory(client, dota2, dota2_icount, ARRAY_ItemsDOTA2[client]);
	
	CreateInventory(client, tf2, tf2_icount, ARRAY_ItemsTF2[client]);
	CreateInventory(client, csgo, csgo_icount, ARRAY_ItemsCSGO[client]);
	CreateInventory(client, dota2, dota2_icount, ARRAY_ItemsDOTA2[client]);
	

	char timeOut[100];
	if(StrEqual(tf2, "TIME_OUT"))
	{
		Format(timeOut, sizeof(timeOut), "TF2");
	}
	
	if(StrEqual(csgo, "TIME_OUT"))
	{
		Format(timeOut, sizeof(timeOut), "%s,CS:GO", timeOut);
	}
	
	if(StrEqual(dota2, "TIME_OUT"))
	{
		Format(timeOut, sizeof(timeOut), "%s,Dota 2", timeOut);
	}
	
	if(StrContains(timeOut, ",") == 0)
		strcopy(timeOut, sizeof(timeOut), timeOut[1]);
	
	if(!inv_tf2 && !inv_csgo && !inv_dota2)
    {
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_InventoryError");
	}
	else
	{
		DisplayVIPPackageSelection(client);
		
		if(strlen(timeOut) > 0)
			CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_ItemsError", timeOut);
	}
}

public bool CreateInventory(int client, const char[] strinventory, int itemCount, Handle inventory)
{
	if(StrEqual(strinventory, "EMPTY"))
		return true;
		
	if(StrEqual(strinventory, "TIME_OUT"))
		return true;
	
	if(StrEqual(strinventory, "ERROR"))
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "TradeOffer_ItemsError", strinventory);
		return false;
	}
	
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
	GetTrieString(VIPpackage, VIPP_FLAGS, VIPFlags[client], sizeof(VIPFlags[]));
	
	
	Handle menu = CreateMenu(MenuHandle_PackageSelect);
	SetMenuTitle(menu, packageName);

	for (int i = 0; i < GetArraySize(items); i++)
	{
		GetArrayString(items, i, iname, sizeof(iname));
		if(GetItemID(client, iname, itemID, sizeof(itemID)))
		{
			AddMenuItem(menu, itemID, iname, ITEMDRAW_DEFAULT);
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

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}