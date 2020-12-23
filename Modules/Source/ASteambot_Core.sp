#include <sourcemod>
#include <sdktools>
#include <socket>
#include <ASteambot>
#undef REQUIRE_PLUGIN
#include <updater>
#include <morecolors>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"6.1"
#define MODULE_NAME 	"[ASteambot - Core]"
#define M_PLUGIN		"plugin"
#define M_ID			"mID"
#define M_NAME			"mName"
#define MAX_DATA_SIZE   1000
#define UPDATE_URL    	"https://raw.githubusercontent.com/Arkarr/SourcemodASteambot/master/Updater/ASteambot_Core.txt"

Handle modules;
Handle clientSocket;
Handle ARRAY_Data;
Handle CVAR_Debug;
Handle CVAR_SteambotServerIP;
Handle CVAR_SteambotServerPort;
Handle CVAR_SteambotTCPPassword;
Handle TimerReconnect;
Handle g_fwdASteambotMessage;

char steambotIP[100];
char steambotPort[10];
char steambotPassword[25];
char bigestDataModuleS[50];
char smallestDataModuleS[50];
char bigestDataModuleR[50];
char smallestDataModuleR[50];

int moduleID;
int serverID;
int maxDataSizeS;
int minDataSizeS;
int maxDataSizeR;
int minDataSizeR;
int totalDataSend;
int totalDataReceived;

bool DEBUG;
bool connected;

//Release note
/*
*Fix creating trade offer when no player items are requested.
*Thank you, dvarnai
*/

public Plugin myinfo = 
{
	name = "[ANY] ASteambot Core", 
	author = PLUGIN_AUTHOR, 
	description = "The core module for ASteambot.", 
	version = PLUGIN_VERSION, 
	url = "http://www.sourcemod.net"
};

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL)
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	ARRAY_Data = CreateArray(MAX_DATA_SIZE);
	modules = CreateArray();
	
	CreateNative("ASteambot_RegisterModule", Native_RegisterModule);
	CreateNative("ASteambot_RemoveModule", Native_RemoveModule);
	CreateNative("ASteambot_IsConnected", Native_IsConnected);
	CreateNative("ASteambot_SendMessage", Native_SendMessage);
	CreateNative("ASteambot_CreateTradeOffer", Native_CreateTradeOffer);
	CreateNative("ASteambot_CreateTradeOfferBySteamID", Native_CreateTradeOfferBySteamID);
	CreateNative("ASteambot_FindClientBySteam64", Native_FindClientBySteam64);
	
	RegPluginLibrary("ASteambot");
	
	return APLRes_Success;
}

public Action CMD_ASStats(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("------ ASteambot network usage ------");
		PrintToServer("");
		PrintToServer("Module that have send the most data :");
		PrintToServer("%s - %i bytes", bigestDataModuleS, maxDataSizeS);
		PrintToServer("Module that have send the less data :");
		PrintToServer("%s - %i bytes", smallestDataModuleS, minDataSizeS);
		PrintToServer("Module that have received the most data :");
		PrintToServer("%s - %i bytes", bigestDataModuleR, maxDataSizeR);
		PrintToServer("Module that have received the less data :");
		PrintToServer("%s - %i bytes", smallestDataModuleR, minDataSizeR);
		PrintToServer("Total data stats :");
		PrintToServer("Sent : %i bytes\tReceived : %i bytes", totalDataSend, totalDataReceived);
		PrintToServer("Sent : %i mb\t\tReceived : %i mb", totalDataSend / 1000000, totalDataReceived / 1000000);
	}
	else
	{
		PrintToConsole(client, "------ ASteambot network usage ------");
		PrintToConsole(client, "");
		PrintToConsole(client, "Module that have send the most data :");
		PrintToConsole(client, "%s - %i bytes", bigestDataModuleS, maxDataSizeS);
		PrintToConsole(client, "Module that have send the less data :");
		PrintToConsole(client, "%s - %i bytes", smallestDataModuleS, minDataSizeS);
		PrintToConsole(client, "Module that have received the most data :");
		PrintToConsole(client, "%s - %i bytes", bigestDataModuleR, maxDataSizeR);
		PrintToConsole(client, "Module that have received the less data :");
		PrintToConsole(client, "%s - %i bytes", smallestDataModuleR, minDataSizeR);
		PrintToConsole(client, "Total data stats :");
		PrintToConsole(client, "Sent : %i bytes\tReceived : %i bytes", totalDataSend, totalDataReceived);
		PrintToConsole(client, "Sent : %i mb\t\tReceived : %i mb", totalDataSend / 1000000, totalDataReceived / 1000000);
	}
	
	return Plugin_Handled;
}

//////////////
//  NATIVE  //
//////////////
public Native_RegisterModule(Handle plugin, int numParams)
{
	Handle module;
	char mName[50];
	char mOldName[50];
	moduleID++;
	
	if (DEBUG)
	{
		PrintToServer("------------");
		for (int i = 0; i < GetArraySize(modules); i++)
		{
			int mID;
			Handle test = GetArrayCell(modules, i);
			GetTrieString(test, M_NAME, mName, sizeof(mName));
			GetTrieValue(test, M_ID, mID);
			PrintToServer("%i -> Module ID: %i - %s", i, mID, mName);
		}
		PrintToServer("Number of modules : %i", GetArraySize(modules));
		PrintToServer("------------");
	}
	
	GetNativeString(1, mName, sizeof(mName));
	
	for (int i = 0; i < GetArraySize(modules); i++)
	{
		Handle test = GetArrayCell(modules, i);
		GetTrieString(test, M_NAME, mOldName, sizeof(mOldName));
		
		if(StrEqual(mName, mOldName))
		{
			PrintToServer("*********************** ASTEAMBOT CORE ***********************");
			PrintToServer("* Warning: a module with the same registring name is already *");
			PrintToServer("* loaded ! Ignoring...									*");
			PrintToServer("* Module name : %s										*", mName);
			PrintToServer("* Total module registred : %i					     	*", GetArraySize(modules));
			PrintToServer("**************************************************************");
			return 1;
		}
	}
	
	module = CreateTrie();
	SetTrieValue(module, M_PLUGIN, plugin);
	SetTrieValue(module, M_ID, moduleID);
	SetTrieString(module, M_NAME, mName);
	
	PushArrayCell(modules, module);
	
	if (DEBUG)
	{
		PrintToServer("------------");
		for (int i = 0; i < GetArraySize(modules); i++)
		{
			int mID;
			module = GetArrayCell(modules, i);
			GetTrieString(module, M_NAME, mName, sizeof(mName));
			GetTrieValue(module, M_ID, mID);
			PrintToServer("%i -> Module ID: %i - %s", i, mID, mName);
		}
		PrintToServer("Number of modules : %i", GetArraySize(modules));
		PrintToServer("------------");
	}
	
	return 1;
}

public Native_RemoveModule(Handle plugin, int numParams)
{
	for (int i = 0; i < GetArraySize(modules); i++)
	{
		Handle module = GetArrayCell(modules, i);
		
		Handle p;
		GetTrieValue(module, M_PLUGIN, p);
		if (p == plugin)
		{
			RemoveFromArray(modules, i);
			
			return 1;
		}
	}
	
	return 0;
}

public int Native_IsConnected(Handle plugin, int numParams)
{
	return connected;
}

public int Native_SendMessage(Handle plugin, int numParams)
{
	if (!ASteambot_IsConnected())
		return false;
	
	char message[950];
	AS_MessageType messageType = GetNativeCell(1);
	GetNativeString(2, message, sizeof(message));
	/*Handle module = GetModuleByPlugin(plugin);
	
	if(module != INVALID_HANDLE)
	{
		int id;
		GetTrieValue(module, M_ID, id);
		SendMessage(id, messageType, message, sizeof(message));
	}
	else
	{
		PrintToServer("%s ERROR: Module not found ! Is it registred ?", MODULE_NAME);
		PrintToChatAll("%s ERROR: Module not found !", MODULE_NAME);
	}*/
	SendMessage(plugin, messageType, message, sizeof(message));
	
	return true;
}

public int Native_CreateTradeOfferBySteamID(Handle plugin, int numParams)
{
	char message[MAX_DATA_SIZE]; //bad
	char item[30];
	char clientSteamID[40];
	
	GetNativeString(1, clientSteamID, sizeof(clientSteamID));
	Handle ItemList = GetNativeCell(2);
	Handle MyItemList = GetNativeCell(3);
	float fakeValue = GetNativeCell(4);
	
	int commentLength;
	GetNativeStringLength(5, commentLength);
	
	char[] comment = new char[commentLength + 1];
	GetNativeString(5, comment, commentLength + 1);
	
	Format(message, sizeof(message), "%s/", clientSteamID)
	
	if(ItemList != null)
	{
		for (int i = 0; i < GetArraySize(ItemList); i++)
		{
			GetArrayString(ItemList, i, item, sizeof(item));
			
			if (i + 1 != GetArraySize(ItemList))
				Format(item, sizeof(item), "%s,", item);
			else
				Format(item, sizeof(item), "%s", item);
			
			StrCat(message, sizeof(message), item);
		}
	}
	else
	{
		StrCat(message, sizeof(message), "NULL");
	}
	
	StrCat(message, sizeof(message), "/");
	
	if (MyItemList != INVALID_HANDLE && GetArraySize(MyItemList) > 0)
	{
		for (int i = 0; i < GetArraySize(MyItemList); i++)
		{
			GetArrayString(MyItemList, i, item, sizeof(item));
			
			if (i + 1 != GetArraySize(MyItemList))
				Format(item, sizeof(item), "%s,", item);
			else
				Format(item, sizeof(item), "%s", item);
			
			StrCat(message, sizeof(message), item);
		}
	}
	else
	{
		StrCat(message, sizeof(message), "NULL");
	}
	
	
	if (fakeValue != 1.0)
	{
		char fakeVal[100];
		Format(fakeVal, sizeof(fakeVal), "/%.2f", fakeValue);
		StrCat(message, sizeof(message), fakeVal);
	}
	else
	{
		StrCat(message, sizeof(message), "/-1");
	}
	
	Format(comment, commentLength+5, "/%s", comment);
	StrCat(message, sizeof(message), comment);
	
	SendMessage(plugin, AS_CREATE_TRADEOFFER, message, sizeof(message));
}

public int Native_CreateTradeOffer(Handle plugin, int numParams)
{
	char message[MAX_DATA_SIZE]; //bad
	
	int client = GetNativeCell(1);
	Handle ItemList = GetNativeCell(2);
	Handle MyItemList = GetNativeCell(3);
	float fakeValue = GetNativeCell(4);
	
	//Handle module = GetModuleByPlugin(plugin);
	
	char item[30];
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	
	Format(message, sizeof(message), "%s/", clientSteamID)
	
	if(ItemList != null)
	{
		for (int i = 0; i < GetArraySize(ItemList); i++)
		{
			GetArrayString(ItemList, i, item, sizeof(item));
			
			if (i + 1 != GetArraySize(ItemList))
				Format(item, sizeof(item), "%s,", item);
			else
				Format(item, sizeof(item), "%s", item);
			
			StrCat(message, sizeof(message), item);
		}
	}
	else
	{
		StrCat(message, sizeof(message), "NULL");
	}
	
	StrCat(message, sizeof(message), "/");
	
	if (MyItemList != INVALID_HANDLE && GetArraySize(MyItemList) > 0)
	{
		for (int i = 0; i < GetArraySize(MyItemList); i++)
		{
			GetArrayString(MyItemList, i, item, sizeof(item));
			
			if (i + 1 != GetArraySize(MyItemList))
				Format(item, sizeof(item), "%s,", item);
			else
				Format(item, sizeof(item), "%s", item);
			
			StrCat(message, sizeof(message), item);
		}
	}
	else
	{
		StrCat(message, sizeof(message), "NULL");
	}
	
	
	if (fakeValue != 1.0)
	{
		char fakeVal[100];
		Format(fakeVal, sizeof(fakeVal), "/%.2f", fakeValue);
		StrCat(message, sizeof(message), fakeVal);
	}
	else
	{
		StrCat(message, sizeof(message), "/-1");
	}
	
	//int id;
	//GetTrieValue(module, M_ID, id);
	
	//SendMessage(id, AS_CREATE_TRADEOFFER, message, sizeof(message));
	
	SendMessage(plugin, AS_CREATE_TRADEOFFER, message, sizeof(message));
}

public void OnPluginStart()
{
										//hehe
	RegAdminCmd("sm_asteambot_stats", CMD_ASStats, ADMFLAG_CONFIG, "Display stats about network data of ASteambot.");
	
	g_fwdASteambotMessage = CreateGlobalForward("ASteambot_Message", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	
	CVAR_Debug = CreateConVar("sm_asteambot_debug", "false", "Enable(true)/Disable(false) debug mode >>> WARNING <<< Enabling debug mode may print senstive infos in the game server console !");
	CVAR_SteambotServerIP = CreateConVar("sm_asteambot_server_ip", "XXX.XXX.XXX.XXX", "The ip of the server where the steambot is hosted.");
	CVAR_SteambotServerPort = CreateConVar("sm_asteambot_server_port", "4765", "The port of the server where the steambot is hosted, WATCH OUT ! In version 1.0 of the bot, the port is hardcoded and is 11000 !!");
	CVAR_SteambotTCPPassword = CreateConVar("sm_asteambot_tcp_password", "XYZ", "The password to allow TCP data to be read / send (TCPPassword in settings.json)");
	
	HookConVarChange(CVAR_Debug, CVARHOOK_DebugMode);
	
	AutoExecConfig(true, "asteambot_core", "asteambot");
	
	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL)
}

public void CVARHOOK_DebugMode(Handle cvar, const char[] oldValue, const char[] newValue)
{
	DEBUG = GetConVarBool(cvar);
}

public void OnMapEnd()
{
	/*SendMessage(serverID, AS_DISCONNECT, "byebyelul", 9);
	SocketDisconnect(clientSocket);*/
}

public void OnConfigsExecuted()
{
	char d[10];
	GetConVarString(CVAR_SteambotServerIP, steambotIP, sizeof(steambotIP));
	GetConVarString(CVAR_SteambotServerPort, steambotPort, sizeof(steambotPort));
	GetConVarString(CVAR_SteambotTCPPassword, steambotPassword, sizeof(steambotPassword));
	GetConVarString(CVAR_Debug, d, sizeof(d));
	DEBUG = StrEqual(d, "true");
	
	if (DEBUG)
		PrintToServer("ASteambot : DEBUG MODE IS 'ON'");
	else
		PrintToServer("ASteambot : DEBUG MODE IS 'OFF'");
	
	AttemptSteamBotConnection();
}

public void AttemptSteamBotConnection()
{
	if (connected)
		return;
	
	connected = false;
	clientSocket = SocketCreate(SOCKET_TCP, OnClientSocketError);
	SocketSetOption(clientSocket, SocketReceiveBuffer, MAX_DATA_SIZE);
	PrintToServer("%s - Attempt to connect to %s:%i ...", MODULE_NAME, steambotIP, StringToInt(steambotPort));
	SocketConnect(clientSocket, OnClientSocketConnected, OnChildSocketReceive, OnChildSocketDisconnected, steambotIP, StringToInt(steambotPort));
}

/////////////
// SOCKET  //
/////////////
public OnClientSocketConnected(Handle socket, any arg)
{
	PrintToServer("%s - CONNECTED to ASteambot.", MODULE_NAME);
	
	char data[200];
	char map[100];
	
	int pieces[4];
	int longip = GetConVarInt(FindConVar("hostip"));
	
	pieces[0] = (longip >> 24) & 0x000000FF;
	pieces[1] = (longip >> 16) & 0x000000FF;
	pieces[2] = (longip >> 8) & 0x000000FF;
	pieces[3] = longip & 0x000000FF;
	
	char gslttoken[50];
	GetServerAuthId(AuthId_SteamID64, gslttoken, sizeof(gslttoken));
	Format(data, sizeof(data), "%s-1,-1|%i&%s|%d.%d.%d.%d", steambotPassword, AS_REGISTER_SERVER, gslttoken, pieces[0], pieces[1], pieces[2], pieces[3]);
	
	Format(data, sizeof(data), "%s|%i", data, GetConVarInt(FindConVar("hostport")));
	
	GetHostName(map, sizeof(map));
	Format(data, sizeof(data), "%s|%s<EOF>", data, map);
	
	SocketSend(clientSocket, data, sizeof(data));
	
	EndTimer();
	
	connected = true;
}

public void OnClientSocketError(Handle socket, const int errorType, const int errorNum, any ary)
{
	connected = false;
	LogError("%s - socket error %d (error number %d)", MODULE_NAME, errorType, errorNum);
	CloseHandle(socket);
	
	if (errorNum == 3)
	{
		PrintToServer("*********************** ASTEAMBOT CORE ***********************");
		PrintToServer("* This error means you failed to configure the TCP port !    *");
		PrintToServer("* Check the documentation again. Have you opened the port on *");
		PrintToServer("* the machine running ASteambot ?                            *");
		PrintToServer("**************************************************************");
	}
	
	if (TimerReconnect == INVALID_HANDLE)
		TimerReconnect = CreateTimer(10.0, TMR_TryReconnection, _, TIMER_REPEAT);
}

public OnChildSocketReceive(Handle socket, char[] receiveData, const int dataSize, any hFile)
{
	if (DEBUG)
	{
		PrintToServer("%s %s", MODULE_NAME, receiveData);
		PrintToServer("%s Data Size : %i", MODULE_NAME, dataSize);
	}
	
	totalDataReceived += dataSize;
	
	if (StrContains(receiveData, "<EOF>") == -1)
	{
		PushArrayString(ARRAY_Data, receiveData);
		return;
	}
	
	PushArrayString(ARRAY_Data, receiveData);
	
	int stringSize = MAX_DATA_SIZE * GetArraySize(ARRAY_Data);
	char[] finalData = new char[stringSize];
	for (int i = 0; i < GetArraySize(ARRAY_Data); i++)
	{
		char[] data = new char[MAX_DATA_SIZE];
		GetArrayString(ARRAY_Data, i, data, MAX_DATA_SIZE);
		StrCat(finalData, stringSize, data);
	}
	
	ClearArray(ARRAY_Data);
	
	
	if (DEBUG)
	{
		PrintToServer("Data : %s", finalData);
		
		if (StrContains(finalData, steambotPassword) == -1)
		{
			PrintToServer(">>> PASSWORD INCORECT OR NOT FOUND");
			return;
		}
	}
	
	ReplaceString(finalData, stringSize, steambotPassword, "");
	ReplaceString(finalData, stringSize, "<EOF>", "");
	
	char[][] mc_data = new char[2][stringSize];
	char[][] moduleID_code = new char[2][10];
	
	ExplodeString(finalData, "|", mc_data, 2, stringSize);
	ExplodeString(mc_data[0], ")", moduleID_code, 2, stringSize);
	
	if (DEBUG)
	{
		PrintToServer("-----------------------");
		PrintToServer("Password : 		%s", steambotPassword);
		PrintToServer("Module ID :		%s", moduleID_code[0]);
		PrintToServer("ASteambot code : %s", moduleID_code[1]);
		PrintToServer("Data : 			%s", mc_data[1]);
		PrintToServer("-----------------------");
	}
	
	if (StrEqual(moduleID_code[1], "SRVID"))
	{
		serverID = StringToInt(mc_data[1]);
	}
	else
	{
		if (GetArraySize(modules) != 0)
		{
			int mID = StringToInt(mc_data[0]);
			int code = StringToInt(moduleID_code[1]);
			
			if (mID == -2)
			{
				Call_StartForward(g_fwdASteambotMessage);
				Call_PushCell(code);
				Call_PushString(mc_data[1]);
				Call_PushCell(stringSize);
				Call_Finish();
				
				if (maxDataSizeR < dataSize || maxDataSizeR == 0)
				{
					maxDataSizeR = dataSize;
					Format(bigestDataModuleR, sizeof(bigestDataModuleR), "<unknow>");
				}
				
				if (minDataSizeR > dataSize || minDataSizeR == 0)
				{
					minDataSizeR = dataSize;
					Format(smallestDataModuleR, sizeof(smallestDataModuleR), "<unknow>");
				}
			}
			else
			{
				Handle module = GetModuleByID(mID);
				if (module != INVALID_HANDLE)
				{
					Handle p;
					GetTrieValue(module, M_PLUGIN, p);
					
					char mName[50];
					GetTrieString(module, M_NAME, mName, sizeof(mName));
					
					if (DEBUG)
						PrintToServer("Module ID: %i - %s", mID, mName);
					
					if (dataSize > maxDataSizeR || maxDataSizeR == 0)
					{
						maxDataSizeR = dataSize;
						Format(bigestDataModuleR, sizeof(bigestDataModuleR), mName);
					}
					
					if (minDataSizeR > dataSize || minDataSizeR == 0)
					{
						minDataSizeR = dataSize;
						Format(smallestDataModuleR, sizeof(smallestDataModuleR), mName);
					}
					
					Function address = GetFunctionByName(p, "ASteambot_Message");
					
					if (address == INVALID_FUNCTION)
					{
						PrintToServer("****                    ASTEAMBOT                    ****");
						PrintToServer("Trying to call function ASteambot_Message");
						PrintToServer("on plugin '%s' but addresse is invalid !", mName);
						PrintToServer("Is the plugin registred with ASteambot_RegisterModule ?");
						PrintToServer("*********************************************************");
					}
					else
					{
						Call_StartFunction(p, address);
						Call_PushCell(code);
						Call_PushString(mc_data[1]);
						Call_PushCell(stringSize);
						Call_Finish();
					}
				}
			}
		}
	}
}

public Handle GetModuleByPlugin(Handle plugin)
{
	for (int i = 0; i < GetArraySize(modules); i++)
	{
		Handle module = GetArrayCell(modules, i);
		
		Handle p;
		GetTrieValue(module, M_PLUGIN, p);
		if (p == plugin)
			return module;
	}
	
	return INVALID_HANDLE;
}

public Handle GetModuleByID(int id)
{
	for (int i = 0; i < GetArraySize(modules); i++)
	{
		Handle module = GetArrayCell(modules, i);
		
		int idModule;
		GetTrieValue(module, M_ID, idModule);
		if (idModule == id)
			return module;
	}
	
	return INVALID_HANDLE;
}

public OnChildSocketDisconnected(Handle socket, any hFile)
{
	PrintToServer("%s - DISCONNECTED to ASteambot.", MODULE_NAME);
	connected = false;
	CloseHandle(socket);
	
	if (TimerReconnect == INVALID_HANDLE)
		TimerReconnect = CreateTimer(10.0, TMR_TryReconnection, _, TIMER_REPEAT);
}

///////////
// TIMER //
///////////
public Action TMR_TryReconnection(Handle timer, any none)
{
	AttemptSteamBotConnection();
}

///////////
// STOCK //
///////////
public bool SendMessage(Handle plugin, AS_MessageType messageType, char[] message, int msgSize)
{
	Handle module = GetModuleByPlugin(plugin);
	
	int mid;
	if (module != INVALID_HANDLE)
	{
		GetTrieValue(module, M_ID, mid);
	}
	else
	{
		PrintToServer("%s ERROR: Module not found ! Is it registred ?", MODULE_NAME);
		PrintToChatAll("%s ERROR: Module not found !", MODULE_NAME);
		
		return false;
	}
	
	Format(message, msgSize, "%s%i,%i|%i&%s<EOF>", steambotPassword, serverID, mid, messageType, message);
	
	if (DEBUG)
		PrintToServer(message);
	
	if (msgSize > maxDataSizeS)
	{
		maxDataSizeS = msgSize;
		GetTrieString(module, M_NAME, bigestDataModuleS, sizeof(bigestDataModuleS));
	}
	
	if (minDataSizeS > msgSize || minDataSizeS == 0)
	{
		minDataSizeS = msgSize;
		GetTrieString(module, M_NAME, smallestDataModuleS, sizeof(smallestDataModuleS));
	}
	
	totalDataSend += msgSize;
	
	if (clientSocket != INVALID_HANDLE)
	{
		SocketSend(clientSocket, message, msgSize);
	}
	else
	{
		EndTimer();
		TimerReconnect = CreateTimer(10.0, TMR_TryReconnection, _, TIMER_REPEAT);
	}
	
	return true;
}

public void EndTimer()
{
	if (TimerReconnect != INVALID_HANDLE)
	{
		KillTimer(TimerReconnect);
		TimerReconnect = INVALID_HANDLE;
	}
}

stock void GetHostName(char[] str, size)
{
	Handle hHostName;
	
	if (hHostName == INVALID_HANDLE)
		if ((hHostName = FindConVar("hostname")) == INVALID_HANDLE)
		return;
	
	GetConVarString(hHostName, str, size);
}

public bool IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

public int Native_FindClientBySteam64(Handle plugin, int numParams)
{
	char clientSteamID[100];
	
	GetNativeString(1, clientSteamID, sizeof(clientSteamID));
	
	/*
	char steamId64;
	if(StrContains(clientSteamID, "STEAM_") == -1)
	{
		steamId64 = StringToInt(clientSteamID);
		
		int universe = (steamId64 >> 56) & 0xFF;
		
		if (universe == 1)
			universe = 0;
		
		int accountIdLowBit = steamId64 & 1;
		
		int accountIdHighBits = (steamId64 >> 1) & 0x7FFFFFF;
		
		// should hopefully produce "STEAM_0:0:35928448"
		Format(clientSteamID, sizeof(clientSteamID), "STEAM_%i:%i:%i", universe, accountIdLowBit, accountIdHighBits); 
		
		PrintToServer(">> %s", clientSteamID);
	}*/
	
	char pSteamID64[100];
	char pSteamID[100];
	for (int i = MaxClients; i > 0; --i)
	{
		if (IsValidClient(i))
		{
			GetClientAuthId(i, AuthId_SteamID64, pSteamID64, sizeof(pSteamID64));
			GetClientAuthId(i, AuthId_Steam2, pSteamID, sizeof(pSteamID));

			if (StrEqual(clientSteamID, pSteamID64) || StrEqual(clientSteamID, pSteamID))
			{
				return i;
			}
		}
	}
	
	return -1;
}
