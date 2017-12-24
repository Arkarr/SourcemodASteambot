/*
*
*	Contains things for ASteambot plugin developpement <--- Best description ever, isn't it ?
*
*/
#if defined _INCLUDE_ASteambot
 #endinput
#endif
#define _INCLUDE_ASteambot

#define AS_REGISTER_SERVER		0
#define AS_HOOK_CHAT			1
#define AS_UNHOOK_CHAT			2
#define AS_SIMPLE				3
#define AS_TRADEOFFER_SUCCESS	4
#define AS_TRADEOFFER_DECLINED	5
#define AS_SCAN_INVENTORY		6
#define AS_CREATE_TRADEOFFER	7
#define AS_NOT_FRIENDS			8
#define AS_TRADE_TOKEN			9
#define AS_FRIEND_INVITE		10
#define AS_REPORT_PLAYER		11
#define AS_INVITE_GROUP			12
#define AS_SCAN_INVENTORY_IMG   13
#define AS_EXECUTE_CMD		    14
#define AS_DISCONNECT			15
#define AS_SG_ANNOUCEMENT	    16

/** 
 * Register the plugin, required to receive and send messages.
 * 
 * @return          Nothing.
 */ 
native void ASteambot_RegisterModule(const char[] moduleName)

/** 
 * Remove the module from ASteambot_Core, the plugin won't be able to receive and send messages anymore.
 * 
 * @return          Nothing.
 */ 
native void ASteambot_RemoveModule()

/** 
 * Get the connection state to ASteambot
 * 
 * @return          true if connected and can receive/send messages, false otherwise. 
 */ 
native bool ASteambot_IsConnected() 

/** 
 * Send a message to ASteambot (Maximum char 900). 
 * 
 * @return          Nothing.
 */ 
native void ASteambot_SendMesssage(int MessageType, const char[] message) 

/** 
 * Send a message to ASteambot (Maximum char 900). 
 * 
 * @return          Nothing.
 */ 
native void ASteambot_CreateTradeOffer(int client, Handle ArrayAssetID) 

/** 
 * Fire when ever you get a message from ASteambot.
 * 
 * @return          Nothing.
 */ 
forward int ASteambot_Message(int MessageType, char[] message, const int messageSize);

/**
Shared plugin information
**/
public SharedPlugin _pl_ASteambot = 
{
	name = "[ANY] ASteambot Core",
	file = "ASteambot_Core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};