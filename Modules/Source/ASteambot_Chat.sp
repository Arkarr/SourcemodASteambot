#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"1.3"
#define MODULE_NAME 	"[ASteambot - Chat]"


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
	ASteambot_RemoveModule();
}

public int ASteambot_Message(int MessageType, char[] message, const int messageSize)
{
	if(MessageType == AS_HOOK_CHAT)
		transferMessages = true;
	else if(MessageType == AS_UNHOOK_CHAT)
		transferMessages = false;
		
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