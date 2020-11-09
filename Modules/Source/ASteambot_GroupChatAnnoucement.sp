#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.0"
#define MODULE_NAME 			"[ASteambot - Group Chat Annoucement]"

#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_GroupChatAnnoucement.txt"


Handle CVAR_Cooldown;
Handle CVAR_GroupChatName;
Handle CVAR_GroupChannelName;

char server_ip[16];
char server_port[10];
char strGroupChatName[100];
char strGroupChannelName[100];

float timeout;
float playerTimeout[MAXPLAYERS + 1];

//Release note
/*
*Initial release
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Group Chat Annoucement", 
	author = PLUGIN_AUTHOR, 
	description = "Allow players to make annoucement directly in steam groups.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_GroupChatAnnoucement");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public void OnPluginStart()
{	
	CVAR_Cooldown = CreateConVar("sm_asteambot_gca", "60", "Time in seconds before another annoucement can be made for each players", _, true, 1.0);
	CVAR_GroupChatName = CreateConVar("sm_asteambot_gca_group_name", "Arkarr's bot", "Group chat name to make the annoucement on");
	CVAR_GroupChannelName = CreateConVar("sm_asteambot_gca_channel_name", "ASTEAMBOT-TEST-ONLY", "Group channel name to make the annoucement on");

	RegConsoleCmd("sm_group_chat_annoucement", CMD_MakeGroupChatAnnoucement, "Make a group chat annoucement.");
	RegConsoleCmd("sm_gca", CMD_MakeGroupChatAnnoucement, "Make a group chat annoucement.");
	
	AutoExecConfig(true, "asteambot_group_chat_annoucement", "asteambot");
	
	LoadTranslations("ASteambot.groupchatannoucement.phrases");
	
	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public void OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public void OnConfigsExecuted()
{
	timeout = GetConVarFloat(CVAR_Cooldown);
	GetConVarString(CVAR_GroupChatName, strGroupChatName, sizeof(strGroupChatName));
	GetConVarString(CVAR_GroupChannelName, strGroupChannelName, sizeof(strGroupChannelName));
 
	Handle cvar_port = FindConVar("hostport");
	GetConVarString(cvar_port, server_port, sizeof(server_port));
	CloseHandle(cvar_port);
	
	int ip = GetConVarInt(FindConVar("hostip"));
	Format(server_ip, sizeof(server_ip), "%i.%i.%i.%i", (ip >> 24) & 0x000000FF,
                                                        (ip >> 16) & 0x000000FF,
                                                        (ip >>  8) & 0x000000FF,
                                                        (ip      ) & 0x000000FF);
}

public void OnClientConnected(int client)
{
	playerTimeout[client] = -1.0;
}

public Action CMD_MakeGroupChatAnnoucement(int client, int args)
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
	
	if(args == 0)
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_GroupChatAnnoucement_Usage");
		return Plugin_Handled;
	}
	
	if(GetGameTime() < playerTimeout[client])
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_Timeout", playerTimeout[client]-GetGameTime());
		return Plugin_Handled;
	}
	
	playerTimeout[client] = GetGameTime() + timeout;
	
	char msg[400];
	char hostname[25];
	GetHostName(hostname, sizeof(hostname));
	
	GetCmdArgString(msg, sizeof(msg));
	
	Format(msg, sizeof(msg), "%s/%s/%s (%s:%s) - %s", strGroupChatName, strGroupChannelName, hostname, server_ip, server_port, msg)
	
	ASteambot_SendMessage(AS_SEND_CHAT_GROUP_MSG, msg);
	
	CPrintToChat(client, "%s {green}%t", MODULE_NAME, "Done");
	
	return Plugin_Handled;
}

public GetHostName(char[] str, size)
{
    Handle hHostName;
    
    if(hHostName == INVALID_HANDLE)
    {
        if((hHostName = FindConVar("hostname")) == INVALID_HANDLE)
            return;
    }
    
    GetConVarString(hHostName, str, size);
}