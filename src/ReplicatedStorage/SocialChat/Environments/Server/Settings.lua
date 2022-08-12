--[[

	Name: Cosmental
	Date: 8/12/2022
	
	Description: This module holds configuration data for our chat system!

]]--

return {

	--// SYSTEM CONFIGURATIONS

	["MaximumMessagesPer10Seconds"] = 10, -- Determines how many messages users can send every 10 seconds (10 is the recommended amount)
	["MaxMessageLength"] = 150, -- Determines how many characters can be inside of a message. This is mostly to prevent message flooding...

	--// SERVER MESSAGE CONFIGURATIONS

	["JoinMessagesEnabled"] = true, -- If true, SERVER join messages will send upon a player joining the server
	["JoinMessage"] = "%s has joined the server", -- This will be the join message that sends upon a player joining. (%s will automatically change into the players name)

	["LeaveMessagesEnabled"] = false, -- If true, SERVER leaving messages will send whenever a player is exiting the server
	["LeaveMessage"] = "%s has left the server", -- This will be the leaving message that sends upon a player leaving. (%s will automatically change into the players name)

	["ErrorTagColor"] = Color3.fromRGB(255, 45, 45),
	["SystemMessageColor"] = Color3.fromRGB(255, 255, 255),

	["UseDisplayNamesForServerMessages"] = true, -- If true, Player display names will be used for server messages instead of using their actual usernames

	--// META

	["UsernameColors"] = { -- These colors will be used and given out to players who join the server randomly (opt.) [Must be a Color3]
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(100, 100, 255),
		Color3.fromRGB(70, 255, 100),
		Color3.fromRGB(255, 120, 255),
		Color3.fromRGB(105, 225, 255),
		Color3.fromRGB(240, 240, 125),
		Color3.fromRGB(255, 180, 15),
		Color3.fromRGB(255, 65, 160),
		Color3.fromRGB(255, 150, 210)
	};

};