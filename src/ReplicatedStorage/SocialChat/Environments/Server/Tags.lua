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
			["RankRequirement"] = 0,
		};

		["TagData"] = {
			["SpeakerColor"] = Color3.fromRGB(255, 100, 100),
            ["MessageColor"] = Color3.fromRGB(200, 200, 200)
		};

		["Priority"] = 0,
	};

	["Cos"] = {
		["Requirements"] = {
			["UserIds"] = {
				876817222 -- Cos
			},

			["GroupId"] = 0,
			["RankRequirement"] = 0,
		};

		["TagData"] = {
			["TagName"] = "Creator",
			
			["TagColor"] = Color3.fromRGB(255, 35, 35),
			["SpeakerColor"] = Color3.fromRGB(70, 35, 255)
		};

		["Priority"] = 0,
	};
};