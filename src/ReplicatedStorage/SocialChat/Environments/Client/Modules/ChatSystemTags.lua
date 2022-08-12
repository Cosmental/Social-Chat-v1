--[[

	Name: Cos
	Date: 7/31/2022

	Description: This module holds rendering data for SPECIAL name tags! If you want to edit who can use a tag, check the server config file.

	--------------------------------------------------------------------------------------------------------------------------------------

	## TEMPLATE ##

	["UNIQUE_TAG_NAME"] = {
		["OnCalled"] = function(graphemes : table) -- This method is called during the coloring process of any rendered text string
			--[

				The graphemes table contains a list of all the individual grapheme textLabels that any rendered message generates! You
				can make unique tag effects by looping through each label and applying a color to it!

			]--

			return RenderSteppedConnection... -- This should be returned for cleanup purposes
		end,
		
		["OnRemoved"] = function(tagRenderStep : RBXScriptConnection) -- This method is called when your chat message gets garbage collected! [for cleanup purposes]
			tagRenderStep:Disconnect();
		end,
	};

]]--

--// Services
local RunService = game:GetService("RunService");

--// Module
return {
	["Rainbow"] = {
		["OnCalled"] = function(graphemes : table)
			local LoopDuration = 5

			return RunService.Heartbeat:Connect(function()
				for Index, Grapheme in pairs(graphemes) do
					local NewHue = ((tick() - (Index / 10)) % (LoopDuration / LoopDuration));
					local Color = Color3.fromHSV(NewHue, 1, 1);

					Grapheme.TextColor3 = Color
				end
			end);
		end,
		
		["OnRemoved"] = function(tagRenderStep : RBXScriptConnection)
			tagRenderStep:Disconnect(); --// Stops our Tweening
		end,
	};
};