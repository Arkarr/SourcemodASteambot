#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <adminmenu>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#define MODULE_NAME		"[ASteambot - Trade Token Updater]"
#define PLUGIN_VERSION 	"1.0"
#define UPDATE_URL    	"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_TradeTokenUpdater.txt"


//Release note
/*
*Initial release
*/

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_tt_updater");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public Plugin myinfo =
{
    name = "[ASteambot] Trade token saver",
    author = "Arkarr",
    description = "Save trade tokens for futur usage with ASteambot",
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
	RegConsoleCmd("sm_asteambot_trade_token", CMD_ASTradeToken, "Save/Update trade token.");
	
	LoadTranslations("ASteambot.tradetokenupdater.phrases.txt");
	
	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action CMD_ASTradeToken(int client, int args)
{
	if (args < 1)
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_invalid_trade_token");
		CPrintToChat(client, "{fullred}%t", "ASteambot_invalid_trade_token_url");
		CPrintToChat(client, "{lime}https://steamcommunity.com/id/me/tradeoffers/privacy");
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_invalid_trade_token_url_2");
		return Plugin_Handled;
	}
	
	if (!ASteambot_IsConnected())
	{
		CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_NotConnected");
		return Plugin_Handled;
	}
	
	char steamID[40];
	char msg[200];
	char token[100];
	
	GetCmdArg(1, token, sizeof(token));
	
	if(StrEqual(token, "https"))
	{
		CPrintToChat(client, "%s %t", MODULE_NAME, "ASteambot_invalid_trade_token");
	}
	else
	{
		GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));
		
		Format(msg, sizeof(msg), "%s/%s", steamID, token);
		ASteambot_SendMessage(AS_TRADE_TOKEN, msg);
	}
	
	return Plugin_Handled;
}

public ASteambot_Message(AS_MessageType MessageType, char[] msg, const int msgSize)
{
	if(MessageType == AS_TRADE_TOKEN)
	{
		char bit[3][64];
		ExplodeString(msg, "/", bit, sizeof bit, sizeof bit[]);

		int client = ASteambot_FindClientBySteam64(bit[0]);
			
		if(client != -1)
		{
			if(StrEqual(bit[1], "ok"))
				CPrintToChat(client, "%s {lime}%t", MODULE_NAME, "ASteambot_valid_trade_token_saved", bit[2]);
			else
				CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "ASteambot_error_while_saving_token", bit[2]);
				
		}
	}
}

