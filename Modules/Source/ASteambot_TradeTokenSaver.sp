#include <sourcemod>
#include <sdktools>
#include <ASteambot>
#include <morecolors>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"1.7"
#define MODULE_NAME 	"[ANY] ASteambot Trade Token Saver"
#define UPDATE_URL    	"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_TradeTokenSaver.txt"


//Release note
/*
*Updater update file location
*/

public Plugin myinfo = 
{
	name = MODULE_NAME, 
	author = PLUGIN_AUTHOR, 
	description = "Save player trade token into ASteambot database. User don't need to add the bot as friend to trade.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnAllPluginsLoaded()
{
	//Ensure that there is not late-load problems.
    if (LibraryExists("ASteambot"))
		ASteambot_RegisterModule("ASteambot_TradeTokenSaver");
	else
		SetFailState("ASteambot_Core is not present/not running. Plugin can't continue !");
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_savetradetoken", CMD_SaveTradeToken, "Save trade token into ASteambot's database.");
	
	LoadTranslations("ASteambot.tradetokensaver.phrases");
	
	if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public OnPluginEnd()
{
	ASteambot_RemoveModule();
}

public Action CMD_SaveTradeToken(int client, int args)
{		
	if(args < 1)
	{
		if(client != 0)
		{
			char steamid64[64];
			if(GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64)))
			{
				CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "cmd_wrong_1");
				CPrintToChat(client, "{red}%t", "cmd_wrong_2");
				CPrintToChat(client, "{green}http://steamcommunity.com/profiles/%s/tradeoffers/privacy", steamid64);
				CPrintToChat(client, "{red}%t", "cmd_wrong_3");
			}
		}
		else
		{
			PrintToServer("%s Command is usuable in-game only.", MODULE_NAME);
		}
		
		return Plugin_Handled;
	}
	
	char token[100];
	char steamid32[32];
	char tradeURL[100];
	GetCmdArg(1, tradeURL, sizeof(tradeURL));
	GetClientAuthId(client, AuthId_Steam2, steamid32, sizeof(steamid32))
	
	if(StrContains(tradeURL, "=") != -1)	
	{
		char tokenURL[2][20];
		ExplodeString(tradeURL, "&token=", tokenURL, sizeof(tokenURL), sizeof(tokenURL[]));
		Format(tradeURL, sizeof(tradeURL), "%s/%s", steamid32, tokenURL[1]);
		Format(token, sizeof(token), tokenURL[1]);
	}
	else
	{
		Format(token, sizeof(token), tradeURL);
		Format(tradeURL, sizeof(tradeURL), "%s/%s", steamid32, tradeURL);
	}
	
	ASteambot_SendMesssage(AS_TRADE_TOKEN, tradeURL);
	
	CPrintToChat(client, "%s {fullred}%t", MODULE_NAME, "token_saved", token);
	
	return Plugin_Handled;
}

public int ASteambot_Message(AS_MessageType MessageType, char[] message, const int messageSize)
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