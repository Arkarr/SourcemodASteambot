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

/** 
 * Connect to ASteambot and get your server ID. Will work only after OnConfigsExecuted().
 * Will automatically try to keep the connection alive, even after disconnection.
 * 
 * @return          Nothing. 
 */ 
//native void ASteambot_Connect() 

/** 
 * Disconnect from ASteambot. On reconnection, you will get a new server ID.
 * 
 * @return          Nothing. 
 */ 
//native void ASteambot_Disconnect() 

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
native void ASteambot_CreateTradeOffer(int client, int gameID, Handle ArrayAssetID) 

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