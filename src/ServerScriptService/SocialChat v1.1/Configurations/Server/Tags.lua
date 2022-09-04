--[[

    Name: Cosmental
	Date: 7/31/2021
	
	Description: This module holds data for in game chat tags and ranks. (This data will be passed to our client(s) for seperate rendering)

]]--

return {
    ["SERVER"] = {
		["Requirements"] = {
			["UserIds"] = {},

			["GroupId"] = 0,
			["AcceptedRanks"] = {0},
		};

		["TagData"] = {
			["SpeakerColor"] = Color3.fromRGB(255, 100, 100),
            ["MessageColor"] = Color3.fromRGB(200, 200, 200)
		};

		["Priority"] = 0,
	};

	["Cos"] = {
		["Requirements"] = {
			["UserIds"] = {},

			["GroupId"] = 4635482,
			["AcceptedRanks"] = {255},
		};

		["TagData"] = {
			["TagName"] = "Creator",
			["TagColor"] = Color3.fromRGB(255, 35, 35),
			["BubbleTextColor"] = "Rainbow",
		};

		["Priority"] = 0,
	};
};