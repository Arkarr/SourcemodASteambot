#include <sourcemod>
#include <sdktools>
#include <ASteambot>

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.0"
#define MODULE_NAME 			"[ASteambot - Execute]"

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Execute", 
	author = PLUGIN_AUTHOR, 
	description = "Allow admins to execute commands directly from the steam chat !", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_Execute");
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public int ASteambot_Message(int MessageType, char[] message, const int messageSize)
{
	if (MessageType == AS_EXECUTE_CMD)
		ServerCommand(message);
}