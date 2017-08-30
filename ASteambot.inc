/*
*
*	Contains things for ASteambot plugin developpement <--- Best description ever, isn't it ?
*
*/
#if defined _INCLUDE_ASteambot
 #endinput
#endif
#define _INCLUDE_ASteambot

#define AS_REGISTER_SERVER	0
#define AS_HOOK_CHAT		1
#define AS_UNHOOK_CHAT		2
#define AS_SIMPLE			3

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
 * Fire when ever you get a message from ASteambot.
 * 
 * @return          Nothing.
 */ 
forward int ASteambot_Message(int MessageType, char[] message);

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