#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <multicolors>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"1.3.1"
#define MODULE_NAME 	"[ASteambot - Chat]"

int connectionCount;

bool transferMessages;

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Chat", 
	author = PLUGIN_AUTHOR, 
	description = "Handle anything that is related to chat.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_Chat");
}

public OnPluginEnd()
{
	connectionCount = 0;
	ASteambot_SendMesssage(AS_UNHOOK_CHAT, "");
	
	ASteambot_RemoveModule();
}

public void OnMapEnd()
{
	connectionCount = 0;
	transferMessages = false;
	ASteambot_SendMesssage(AS_UNHOOK_CHAT, "");
}

public int ASteambot_Message(int MessageType, char[] message, const int messageSize)
{
	if(MessageType == AS_HOOK_CHAT)
	{
		transferMessages = true;
		connectionCount++;
	}
	else if(MessageType == AS_UNHOOK_CHAT)
	{
		connectionCount--;
		transferMessages = (connectionCount <= 0 ? false : true);
	}
		
	if(transferMessages && MessageType == AS_SIMPLE)
		CPrintToChatAll("{green}%s", message);
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(!transferMessages)
		return;
		
	char text[200];
	Format(text, sizeof(text), "%N : %s", client, sArgs)
	ASteambot_SendMesssage(AS_HOOK_CHAT, text);
}
