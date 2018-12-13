#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"2.0"
#define MODULE_NAME 	"[ANY] ASteambot Invite To Group"
#define UPDATE_URL    	"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Modules/Binaries/addons/sourcemod/ASteambot_InviteToGroup.txt"

Handle CVAR_SteamGroupID;


//Release note
/*
*Fixed late load problems, added more iunfos
*/

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_InviteToGroup");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
		
}

public Plugin myinfo = 
{
	name = MODULE_NAME, 
	author = PLUGIN_AUTHOR, 
	description = "ASteambot will invite players to steam group !", 
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
	RegConsoleCmd("sm_steamgroup", CMD_JoinSteamGroup, "Join the steam group.");
	
	CVAR_SteamGroupID = CreateConVar("sm_asteambot_steamgroupid", "", "The steam group id, THE BOT'S ACCOUNT HAVE TO BE IN THE GROUP AND THE RIGHT TO INVITE POEPLE !");
	
	AutoExecConfig(true, "asteambot_invitetogroup", "asteambot");

	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action CMD_JoinSteamGroup(int client, int args)
{	
	if(client == 0 || client == -1)
	{
		PrintToServer("[SM] This command is in-game only.");
		return Plugin_Handled;
	}
	
	char steamID[45];
	char groupID[45];
	char msg[100];
	GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
	GetConVarString(CVAR_SteamGroupID, groupID, sizeof(groupID));
	
	Format(msg, sizeof(msg),  "%s/%s", steamID, groupID);
	ASteambot_SendMesssage(AS_INVITE_GROUP, msg);
	
	return Plugin_Handled;
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
{	
	if(MessageType == AS_NOT_FRIENDS)
	{
		int client = ASteambot_FindClientBySteam64(message);
		
		if(client != -1)
		{
			CPrintToChat(client, "%s {green}I can't invite you in my steamgroup, because we are not friend. Please accept my friend request and try again.", MODULE_NAME);
			ASteambot_SendMesssage(AS_FRIEND_INVITE, message);
		}
		else
		{
			PrintToServer("%s Couldn't find client with steamID %s", MODULE_NAME, message);
		}
	}
	else if(MessageType == AS_INVITE_GROUP)
	{
		int client = ASteambot_FindClientBySteam64(message);
		
		if(client != -1)
			CPrintToChat(client, "%s {green}Steam group invite sent !", MODULE_NAME);
		else
			PrintToServer("%s Couldn't find client with steamID %s", MODULE_NAME, message);
	}
}

stock bool IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}