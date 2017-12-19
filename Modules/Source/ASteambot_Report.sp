#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <adminmenu>
#include <morecolors>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"2.0"
#define MODULE_NAME 	"[ASteambot - Report]"

Handle CVAR_Delay;
Handle ARRAY_DisconnectedPlayers;

int Target[MAXPLAYERS + 1];

float LastUsedReport[MAXPLAYERS + 1];

char configLines[256][192];
char TargetOffline[MAXPLAYERS + 1][50];

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Report", 
	author = PLUGIN_AUTHOR, 
	description = "Report players on server by sending steam messages to admins.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_Report");
	
	RegConsoleCmd("sm_report", CMD_Report, "Report a player by sending a message to admins through steam chat.");
	
	CVAR_Delay = CreateConVar("sm_asteambot_report_delay", "30.0", "Time, in seconds, to delay the target of sm_rocket's death.", FCVAR_NONE, true, 0.0);
	
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	
	ARRAY_DisconnectedPlayers = CreateArray();
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public void OnClientPutInServer(int client)
{
	Target[client] = 0;
	LastUsedReport[client] = GetGameTime();
	for (new z = 1; z <= GetMaxClients(); z++)
	{
		if (Target[z] == client) Target[z] = 0;
	}
}

public void OnClientDisconnect(int client)
{
	char pName[65];
	char steamID[45];
	GetClientName(client, pName, sizeof(pName));
	GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
	
	Format(pName, sizeof(pName), "%s [DISCONNECTED]", pName);
	
	Handle TRIE_Player = CreateTrie();
	SetTrieString(TRIE_Player, "name", pName);
	SetTrieString(TRIE_Player, "steamid", steamID);
	
	PushArrayCell(ARRAY_DisconnectedPlayers, TRIE_Player);
}

public Action CMD_Report(int client, int args)
{
	if (LastUsedReport[client] + GetConVarFloat(CVAR_Delay) > GetGameTime())
	{
		ReplyToCommand(client, "%s You must wait %i seconds before submitting another report.", MODULE_NAME, RoundFloat((LastUsedReport[client] + RoundFloat(GetConVarFloat(CVAR_Delay))) - RoundFloat(GetGameTime())));
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		ChooseTargetMenu(client);
		return Plugin_Handled;
	}
	
	char arg1[128];
	char arg2[256];
	
	if (args == 1)
	{
		GetCmdArg(1, arg1, sizeof(arg1));
	
	    Target[client] = FindTarget(client, arg1, true, false);
		
		if (!IsValidClient(Target[client]))
		{
			ReplyToCommand(client, "%s %t", MODULE_NAME, "No matching client");
			return Plugin_Handled;
		}
		
		ReasonMenu(client);
	}
	else if (args > 1)
	{
		GetCmdArg(1, arg1, 128);
		GetCmdArgString(arg2, 256);
		ReplaceStringEx(arg2, 256, arg1, "");
		int target = FindTarget(client, arg1, true, false);
		if (!IsValidClient(target))
		{
			ReplyToCommand(client, "[PR] %t", "No matching client");
			return Plugin_Handled;
		}
		
		ReportPlayer(client, target, arg2);
	}
	return Plugin_Handled;
}

stock ReportPlayer(client, target, char[] reason)
{
	if (!IsValidClient(target) && strlen(TargetOffline[client]) < 2)
	{
		PrintToChat(client, "[PR] The player you were going to report is no longer in-game.");
		return;
	}
	
	char offlineName[45];
	if(strlen(TargetOffline[client]) > 2)
	{
		char value[45];
		for (int i = 0; i < GetArraySize(ARRAY_DisconnectedPlayers); i++)
		{
			Handle trie = GetArrayCell(ARRAY_DisconnectedPlayers, i);
			GetTrieString(trie, "steamid", value, sizeof(value));
			if(StrEqual(value, TargetOffline[client]))
			{
				GetTrieString(trie, "name", offlineName, sizeof(offlineName));
				break;
			}
		}
	}
	
	char configFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/playerreport_logs.txt");
	Handle file = OpenFile(configFile, "at+");
	
	char ID1[50];
	char ID2[50];
	char date[50];
	char time[50];
	
	GetClientAuthId(client, AuthId_Steam2, ID1, sizeof(ID1));
	if(strlen(TargetOffline[client]) < 2)
		GetClientAuthId(target, AuthId_Steam2, ID2, sizeof(ID2));
	else
		Format(ID2, sizeof(ID2), TargetOffline[client]);
		
	FormatTime(date, 50, "%m/%d/%Y");
	FormatTime(time, 50, "%H:%M:%S");
	WriteFileLine(file, "User: %N [%s]\nReported: %N [%s]\nDate: %s\nTime: %s\nReason: \"%s\"\n-------\n\n", client, ID1, target, ID2, date, time, reason);
	CloseHandle(file);
	
	PrintToChat(client, "%s Report submitted.", MODULE_NAME);
	for (new z = 1; z <= GetMaxClients(); z++)
	{
		if (!IsValidClient(z)) continue;
		if (CheckCommandAccess(z, "sm_admin", ADMFLAG_GENERIC))
		{
			if(strlen(TargetOffline[client]) < 2)
				PrintToChat(z, "%s %N reported %N (Reason: \"%s\")", MODULE_NAME, client, target, reason);
			else
				PrintToChat(z, "%s %N reported %s (Reason: \"%s\")", MODULE_NAME, client, offlineName, reason);
		}
	}
	
	if(strlen(TargetOffline[client]) < 2)
		PrintToServer("%s %N reported %N (Reason: \"%s\")", MODULE_NAME, client, target, reason);
	else
		PrintToServer("%s %N reported %s (Reason: \"%s\")", MODULE_NAME, client, offlineName, reason);
		
	
	char message[100];
	Format(message, sizeof(message), "%s/%s/%s", ID1, ID2, reason);
	ASteambot_SendMesssage(AS_REPORT_PLAYER, message);
	
	LastUsedReport[client] = GetGameTime();
}

public void ChooseTargetMenu(int client)
{
	Handle smMenu = CreateMenu(ChooseTargetMenuHandler);
	SetGlobalTransTarget(client);
	char text[128];
	char info[20];
	Format(text, 128, "Report player:", client);
	SetMenuTitle(smMenu, text);
	SetMenuExitBackButton(smMenu, true);
	
	char playerName[100];
	char steamID[100];
			
	for(new z = 0; z < GetArraySize(ARRAY_DisconnectedPlayers); z++)
	{
		Handle trie = GetArrayCell(ARRAY_DisconnectedPlayers, z);
		GetTrieString(trie, "name", playerName, sizeof(playerName));
		GetTrieString(trie, "steamid", steamID, sizeof(steamID));
		AddMenuItem(smMenu, steamID, playerName);
	}
		
	for (new z = 1; z <= GetMaxClients(); z++)
	{
		if (!IsValidClient(z))
			continue;
		
		Format(info, sizeof(info), "%i", GetClientUserId(z));
		GetClientName(z, playerName, sizeof(playerName));
		AddMenuItem(smMenu, info, playerName);
	}
	
	if(GetMenuItemCount(smMenu) == 0)
		PrintToChat(client, "%s Found nobody to report.", MODULE_NAME);
	else
		DisplayMenu(smMenu, client, MENU_TIME_FOREVER);
}

public int ChooseTargetMenuHandler(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		int userid;
		int target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if(StrContains(info, "STEAM_ID:") != -1 || StrContains(info, "BOT") != -1)
		{
			ReasonMenu(client);
			Format(TargetOffline[client], sizeof(TargetOffline[]), info);
		}
		else
		{
			userid = StringToInt(info);
			Format(TargetOffline[client], sizeof(TargetOffline[]), "");
	
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(client, "%s %t", MODULE_NAME, "Player no longer available");
			}	
			else
			{
				if (client == target)
				{
					ReplyToCommand(client, "%s Why would you report yourself?", MODULE_NAME);
				}	
				else
				{
					Target[client] = target;
					ReasonMenu(client);
				}
			}
		}
	}
}

public void ReasonMenu(int client)
{
	Handle smMenu = CreateMenu(ReasonMenuHandler);
	
	SetGlobalTransTarget(client);
	
	char text[128];
	Format(text, 128, "Select reason:");
	
	SetMenuTitle(smMenu, text);
	
	int lines;
	lines = ReadConfig("playerreport_reasons");
	
	for (new z = 0; z <= lines - 1; z++)
		AddMenuItem(smMenu, configLines[z], configLines[z]);
		
	DisplayMenu(smMenu, client, MENU_TIME_FOREVER);
}

public int ReasonMenuHandler(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		CloseHandle(menu);
		
	if (action == MenuAction_Select)
	{
		char selection[128];
		GetMenuItem(menu, item, selection, 128);
		ReportPlayer(client, Target[client], selection);
	}
}

stock bool IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock ReadConfig(char[] configName)
{
	char configFile[PLATFORM_MAX_PATH];
	char line[192];
	int i = 0;
	int totalLines = 0;
	
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/%s.txt", configName);
	
	Handle file = OpenFile(configFile, "rt");
	
	if(file != INVALID_HANDLE)
	{
		while (!IsEndOfFile(file))
		{
			if (!ReadFileLine(file, line, sizeof(line)))
				break;
			
			TrimString(line);
			if(strlen(line) > 0)
			{
				FormatEx(configLines[i], 192, "%s", line);
				totalLines++;
			}
			
			i++;
			
			if(i >= sizeof(configLines))
			{
				LogError("%s config contains too many entries!", configName);
				break;
			}
		}
				
		CloseHandle(file);
	}
	else LogError("[SM] ERROR: Config sourcemod/configs/%s.txt does not exist.", configName);
	
	return totalLines;
}