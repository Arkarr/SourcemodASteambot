
#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <adminmenu>
#include <morecolors>
#include <redirect/version.sp>

public Plugin myinfo =
{
    name = "Server Redirect: Ask connect with ASteambot",
    author = "Arkarr",
    description = "Server redirection/follow: Ask connect with ASteambot",
    version = VERSION,
    url = "http://www.sourcemod.net"
};

public OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_Redirect");
	
	LoadTranslations("redirect.phrases");
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

public ASteambot_Message(int MessageType, char[] msg, const int msgSize)
{
	if(MessageType == AS_SIMPLE)
	{
		SetFailState(msg);
	}
	else if(MessageType == AS_NOT_FRIENDS)
	{
		int clientID = FindClientBySteamID(msg);
		if(clientID != -1)
		{
			ASteambot_SendMesssage(AS_FRIEND_INVITE, msg);
			PrintToServer("You are not friend with me and I can't send you steam messages. I sent you a friend invite.");
		}
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

