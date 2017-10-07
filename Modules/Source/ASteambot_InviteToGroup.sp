#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"1.2"
#define MODULE_NAME 	"[ANY] ASteambot Invite To Group"

Handle CVAR_SteamGroupID;

public Plugin myinfo = 
{
	name = MODULE_NAME, 
	author = PLUGIN_AUTHOR, 
	description = "ASteambot will invite players to steam group !", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_InviteToGroup");
	
	RegConsoleCmd("sm_steamgroup", CMD_JoinSteamGroup, "Join the steam group.");
	
	CVAR_SteamGroupID = CreateConVar("sm_asteambot_steamgroupid", "", "The steam group id, THE BOT'S ACCOUNT HAVE TO BE IN THE GROUP AND THE RIGHT TO INVITE POEPLE !");
	
	AutoExecConfig(true, "asteambot_invitetogroup", "asteambot");
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action CMD_JoinSteamGroup(int client, int args)
{	
	if(client == 0)
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

public int ASteambot_Message(int MessageType, char[] message, const int messageSize)
{	
	if(MessageType == AS_NOT_FRIENDS)
	{
		int client = FindClientBySteamID(message)
		CPrintToChat(client, "%s {green}I can't invite you in my steamgroup, because we are not friend. Please accept my friend request and try again.", MODULE_NAME);
		ASteambot_SendMesssage(AS_FRIEND_INVITE, message);
	}
	else if(MessageType == AS_INVITE_GROUP)
	{
		int client = FindClientBySteamID(message)
		CPrintToChat(client, "%s {green}Steam group invite sent !", MODULE_NAME);
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

stock bool IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}