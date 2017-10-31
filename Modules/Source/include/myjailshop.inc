/*
 * MyJailShop - Include File.
 * by: shanapu
 * https://github.com/shanapu/MyJailShop/
 *
 * This file is part of the MyJailShop SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */


#if defined _myjailshop_included_
	#endinput
#endif
#define _myjailshop_included_


public SharedPlugin:__pl_myjailshop =
{
	name = "myjailshop", 
	file = "myjailshop.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_myjailshop_SetNTVOptional()
{
	MarkNativeAsOptional("MyJailShop_SetCredits");
	MarkNativeAsOptional("MyJailShop_GetCredits");
}
#endif


/*********************************************************
 * Called when a client get credits and sm_jailshop_credits_system "0"
 *
 * @param client		The client who get the credits
 * @Return				The credits of the client
 *********************************************************/
forward int MyJailShop_OnGetCredits(int client);



/*********************************************************
 * Called when a clients credits are set and sm_jailshop_credits_system "0"
 *
 * @param client		The client who get the credits
 * @param Credits	Amount of credits
 * @NoReturn
 *********************************************************/
forward void MyJailShop_OnSetCredits(int client, int NewCreditsAmount);



/*********************************************************
 * Called when a client get credits
 *
 * @param client		The client who get the credits
 * @param extraCredits	Amount of credits
 * @NoReturn
 *********************************************************/
forward void MyJailShop_OnPlayerGetCredits(int client, int extraCredits);


/*********************************************************
 * Called when a client buy an item
 *
 * @param client		The client who bought the item
 * @param item			The name of the item.
 * @NoReturn
 *********************************************************/
forward void MyJailShop_OnPlayerBuyItem(int client, char [] item);



/*********************************************************
 * Get the Credits of the client
 *
 * @param client		The client to get the credits
 * @Return				The credits of the client
 *********************************************************/
native int MyJailShop_GetCredits(int client);


/*********************************************************
 * Set new Credits of the client
 *
 * @param client		The client to set the credits
 * @NoReturn
 *********************************************************/
native void MyJailShop_SetCredits(int client, int newCredits);