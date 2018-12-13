
#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <adminmenu>
#include <morecolors>
#include <redirect/version.sp>
#undef REQUIRE_PLUGIN
#include <updater>

#define MODULE_NAME		"[ASteambot - Redirect]"
#define PLUGIN_VERSION 	"1.5"
#define UPDATE_URL    	"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Modules/Binaries/addons/sourcemod/ASteambot_Redirect.txt"



//Release note
/*
*Fixed late load problems add more infos
*/

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_Report");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public Plugin myinfo =
{
    name = "Server Redirect: Ask connect with ASteambot",
    author = "Arkarr",
    description = "Server redirection/follow: Ask connect with ASteambot",
    version = PLUGIN_VERSION,
    url = "http://www.sourcemod.net"
};

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginStart()
{	
	LoadTranslations("redirect.phrases");
	
	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public OnAskClientConnect(int client, char[] ip, char[] password)
{
    char steamId[30];
    
    if(GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
    {
	    char buffer[4096];
	    char TranslatedStr[500];
	    
	    Format(TranslatedStr, sizeof(TranslatedStr), "%T", "Connect by Clicking Link", client);
	
	    Format(buffer, sizeof(buffer), "%s/steam://connect/%s/%s", steamId, ip, password);
	    
	    PrintToServer(buffer);
	    ASteambot_SendMesssage(AS_SIMPLE, buffer);
	}
}

public ASteambot_Message(AS_MessageType MessageType, char[] msg, const int msgSize)
{
	if(MessageType == AS_NOT_FRIENDS)
	{
		int client = FindClientBySteamID(msg);
		if(client != -1)
		{
			ASteambot_SendMesssage(AS_FRIEND_INVITE, msg);
			CPrintToChat(client, "{green}%s{default} You are not friend with me and I can't send you steam messages. I sent you a friend invite.", MODULE_NAME);
		}
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

