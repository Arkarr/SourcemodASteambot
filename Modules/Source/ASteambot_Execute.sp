#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_AUTHOR 			"Arkarr"
#define PLUGIN_VERSION 			"1.1"
#define MODULE_NAME 			"[ASteambot - Execute]"
#define UPDATE_URL    			"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Modules/Binaries/addons/sourcemod/ASteambot_Redirect.txt"


//Release note
/*
*Fixed late load problems
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Execute", 
	author = PLUGIN_AUTHOR, 
	description = "Allow admins to execute commands directly from the steam chat !", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public void OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_Execute");
	
	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_TradeTrigger");
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{
	if (MessageType == AS_EXECUTE_CMD)
		ServerCommand(message);
}