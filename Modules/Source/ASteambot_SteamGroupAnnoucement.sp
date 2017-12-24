#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"1.0"
#define MODULE_NAME 	"[ANY] ASteambot Steam Group Annoucement"

Handle CVAR_SteamGroupID;

char groupID[50];

public Plugin myinfo = 
{
	name = MODULE_NAME, 
	author = PLUGIN_AUTHOR, 
	description = "Allow to post annoucement directly through ASteambot", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public OnPluginStart()
{
	ASteambot_RegisterModule("ASteambot_SGAnnoucement");
	
	RegAdminCmd("sm_annoucement", CMD_PostAnnoucement, ADMFLAG_CHAT, "Post a new annoucement in the steam group.");
	
	CVAR_SteamGroupID = CreateConVar("sm_asteambot_steamgroupid", "", "The steam group id, THE BOT'S ACCOUNT HAVE TO BE IN THE GROUP AND HAVE THE RIGHT TO POST ANNOUCEMNTS !");
	
	AutoExecConfig(true, "asteambot_sgannoucement", "asteambot");
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public void OnConfigsExecuted()
{
	GetConVarString(CVAR_SteamGroupID, groupID, sizeof(groupID));
}

public Action CMD_PostAnnoucement(int client, int args)
{		
	if(args < 2)
	{
		if(client != 0)
			CPrintToChat(client, "%s {fullred}Usage : sm_annoucement [TITLE] [CONTENT]", MODULE_NAME);
		else
			PrintToServer("%s Usage : sm_annoucement [TITLE] [CONTENT]", MODULE_NAME);
		
		return Plugin_Handled;
	}
	
	char headLine[50];
	char content[100];
	char msg[200];
	
	GetCmdArg(1, headLine, sizeof(headLine));
	GetCmdArg(2, content, sizeof(content));
	
	Format(msg, sizeof(msg),  "%s/%s/%s", groupID, headLine, content);
	ASteambot_SendMesssage(AS_SG_ANNOUCEMENT, msg);
	
	if(client != 0)
			CPrintToChat(client, "%s {fullred} Annoucement sent !", MODULE_NAME);
		else
			PrintToServer("%s Annoucement sent !", MODULE_NAME);
	
	return Plugin_Handled;
}

public int ASteambot_Message(int MessageType, char[] message, const int messageSize)
{	
	if(MessageType == AS_SG_ANNOUCEMENT)
		PrintToServer("%s Annoucement %s has been posted !", MODULE_NAME, message);
}

stock bool IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}