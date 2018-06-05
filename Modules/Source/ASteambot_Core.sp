#include <sourcemod>
#include <sdktools>
#include <socket>
#include <ASteambot>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma dynamic 131072

#define PLUGIN_AUTHOR 	"Arkarr"
#define PLUGIN_VERSION 	"3.6"
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

int moduleID;
int serverID;

bool DEBUG;
bool connected;

//Release note
/*
*Testing updater support
*If you see this, updater is already updating ASteambot Core by himself!
*Updater version: 3
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
	CreateNative("ASteambot_SendMesssage", Native_SendMesssage);
	CreateNative("ASteambot_CreateTradeOffer", Native_CreateTradeOffer);
	
	RegPluginLibrary("ASteambot");

	return APLRes_Success;
}

//////////////
//  NATIVE  //
//////////////
public Native_RegisterModule(Handle plugin, int numParams)
{
	Handle module;
	char mName[50];
	moduleID++;
	
	if(DEBUG)
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
	
	module = CreateTrie();
	SetTrieValue(module, M_PLUGIN, plugin);
	SetTrieValue(module, M_ID, moduleID);
	SetTrieString(module, M_NAME, mName);

	PushArrayCell(modules, module);
	
	if(DEBUG)
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
	for(int i = 0; i < GetArraySize(modules); i++)
	{
		Handle module = GetArrayCell(modules, i);
		
		Handle p;
		GetTrieValue(module, M_PLUGIN, p);
		if(p == plugin)
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

public int Native_SendMesssage(Handle plugin, int numParams)
{
	if(!ASteambot_IsConnected())
		return false;
		
	char message[950];
	AS_MessageType messageType = GetNativeCell(1);
	GetNativeString(2, message, sizeof(message));
	Handle module = GetModuleByPlugin(plugin);
	
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
	}
	
	return true;
}

public int Native_CreateTradeOffer(Handle plugin, int numParams)
{
	char message[MAX_DATA_SIZE]; //bad
	
	int client = GetNativeCell(1);
	Handle ItemList = GetNativeCell(2);
	Handle MyItemList = GetNativeCell(3);
	float fakeValue = GetNativeCell(4);
	Handle module = GetModuleByPlugin(plugin);
	
	char clientSteamID[40];
	GetClientAuthId(client, AuthId_Steam2, clientSteamID, sizeof(clientSteamID));
	
	Format(message, sizeof(message), "%s/", clientSteamID)
	
	char item[30];
	for (int i = 0; i < GetArraySize(ItemList); i++)
	{
		GetArrayString(ItemList, i, item, sizeof(item));
		
		if(i+1 != GetArraySize(ItemList))
			Format(item, sizeof(item), "%s,", item);
		else
			Format(item, sizeof(item), "%s", item);
			
		StrCat(message, sizeof(message), item);
	}
	
	StrCat(message, sizeof(message), "/");
	
	if(MyItemList != INVALID_HANDLE && GetArraySize(MyItemList) > 0)
	{
		for (int i = 0; i < GetArraySize(MyItemList); i++)
		{
			GetArrayString(MyItemList, i, item, sizeof(item));
			
			if(i+1 != GetArraySize(MyItemList))
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
	
	
	if(fakeValue != 1.0)
	{
		char fakeVal[100];
		Format(fakeVal, sizeof(fakeVal), "/%.2f", fakeValue);
		StrCat(message, sizeof(message), fakeVal);
	}
	else
	{
		StrCat(message, sizeof(message), "/-1");
	}
	
	int id;
	GetTrieValue(module, M_ID, id);
	
	SendMessage(id, AS_CREATE_TRADEOFFER, message, sizeof(message));
}

public void OnPluginStart()
{	
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
	
	if(DEBUG)
		PrintToServer("ASteambot : DEBUG MODE IS 'ON'");
	else
		PrintToServer("ASteambot : DEBUG MODE IS 'OFF'");
	
	AttemptSteamBotConnection();
}

public void AttemptSteamBotConnection()
{
	if(connected)
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

public OnClientSocketError(Handle socket, const int errorType, const int errorNum, any ary)
{
	connected = false;
	LogError("%s - socket error %d (errno %d)", MODULE_NAME, errorType, errorNum);
	CloseHandle(socket);
	
	if(errorNum == 3)
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
	PrintToServer(receiveData);
	if(StrContains(receiveData, "<EOF>") == -1)
	{
		if(DEBUG)
			PrintToServer("Data Size : %i", dataSize);
			
		PushArrayString(ARRAY_Data, receiveData);
		return;
	}
	PushArrayString(ARRAY_Data, receiveData);
	
	int stringSize = (MAX_DATA_SIZE) * GetArraySize(ARRAY_Data);
	char[] finalData = new char[stringSize];
	for (int i = 0; i < GetArraySize(ARRAY_Data); i++)
	{
		char[] data = new char[MAX_DATA_SIZE];
		GetArrayString(ARRAY_Data, i, data, MAX_DATA_SIZE);
		StrCat(finalData, stringSize, data);
	}
	ClearArray(ARRAY_Data);
		
	if(StrContains(finalData, steambotPassword) == -1)
	{
		if(DEBUG)
			PrintToServer(">>> PASSWORD INCORECT");
			
		return;
	}
	
	PrintToServer(">>> %s", finalData);
	
	ReplaceString(finalData, stringSize, steambotPassword, "");
	ReplaceString(finalData, stringSize, "<EOF>", "");
	
	char[][] mc_data = new char[2][stringSize];
	char[][] moduleID_code = new char[2][10];
	
	ExplodeString(finalData, "|", mc_data, 2, stringSize);
	ExplodeString(mc_data[0], ")", moduleID_code, 2, stringSize);
	
	if(DEBUG)
	{
		PrintToServer("-----------------------");
		PrintToServer("Password : 		%s", steambotPassword);
		PrintToServer("Module ID :		%s", moduleID_code[0]);
		PrintToServer("ASteambot code : %s", moduleID_code[1]);
		PrintToServer("Data : 			%s", mc_data[1]);
		PrintToServer("-----------------------");
	}

	if(StrEqual(moduleID_code[1], "SRVID"))
	{
		serverID = StringToInt(mc_data[1]);
	}
	else
	{
		if(GetArraySize(modules) != 0)
		{
			int mID = StringToInt(mc_data[0]);
			int code = StringToInt(moduleID_code[1]);
			
			if(mID == -2)
			{
				Call_StartForward(g_fwdASteambotMessage);
				Call_PushCell(code);
				Call_PushString(mc_data[1]);
				Call_PushCell(stringSize);
				Call_Finish();
			}
			else
			{
				Handle module = GetModuleByID(mID);
				if(module != INVALID_HANDLE)
				{
					Handle p;
					GetTrieValue(module, M_PLUGIN, p);
					
					if(DEBUG)
					{
						char mName[50];
						GetTrieString(module, M_NAME, mName, sizeof(mName));
						PrintToServer("Module ID: %i - %s", mID, mName);
					}
					
					Call_StartFunction(p, GetFunctionByName(p, "ASteambot_Message"));
					Call_PushCell(code);
					Call_PushString(mc_data[1]);
					Call_PushCell(stringSize);
					Call_Finish();
				}
			}
		}		
	}
}

public Handle GetModuleByPlugin(Handle plugin)
{
	for(int i = 0; i < GetArraySize(modules); i++)
	{
		Handle module = GetArrayCell(modules, i);
		
		Handle p;
		GetTrieValue(module, M_PLUGIN, p);
		if(p == plugin)
			return module;
	}
	
	return INVALID_HANDLE;
}

public Handle GetModuleByID(int id)
{
	for(int i = 0; i < GetArraySize(modules); i++)
	{
		Handle module = GetArrayCell(modules, i);
		
		int idModule;
		GetTrieValue(module, M_ID, idModule);
		if(idModule == id)
			return module;
	}
	
	return INVALID_HANDLE;
}

public OnChildSocketDisconnected(Handle socket, any hFile)
{
	PrintToServer("%s - DISCONNECTED to ASteambot.", MODULE_NAME);
	connected = false;
	CloseHandle(socket);
	
	if(TimerReconnect == INVALID_HANDLE)
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
stock void SendMessage(int mid, AS_MessageType messageType, char[] message, int msgSize)
{
	Format(message, msgSize, "%s%i,%i|%i&%s<EOF>", steambotPassword, serverID, mid, messageType, message);
	
	if(DEBUG)
		PrintToServer(message);
	
	if(clientSocket != INVALID_HANDLE)
	{
		SocketSend(clientSocket, message, msgSize);
	}
	else
	{
		EndTimer();
		TimerReconnect = CreateTimer(10.0, TMR_TryReconnection, _, TIMER_REPEAT);
	}
		
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