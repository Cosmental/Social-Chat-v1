--[[

	Name: Cosmental
	Date: 8/1/2022
	
	Description: This modules holds data for our chat emotes. Seperate API parameters can be set to add extra "effects" to certain emotes

	--------------------------------------------------------------------------------------------------------------------------------------

	## TEMPLATE ##

	["EMOJI_NAME"] = {
		["Image"] = "emoji_asset_id", --> This should be your emoji's ASSET ID [ex: "rbxassetid://YOUR_ID_HERE"]
		["IsAnimated"] : boolean = true/false, -- If true, your emoji will instead turn into a GIF emoji! (do not set this to true if you dont want to animate your emoji)

		["OnEmoteFired"] = function(Emote : Instance) -- This method fires upon your emoji being created
			--[

				You can setup your gif emoji here using the SpriteClip module!

				If you need help setting up your emoji, you can find the documentation here:
				https://devforum.roblox.com/t/spriteclip-sprite-sheet-animation-module/294195

			]--

			return SpriteClip -- THIS MUST BE RETURNED OR ELSE THE SYSTEM WILL THROW AN ERROR!
		end,

		["OnEmoteSweeped"] = function(Emote : Instance, AnimationObject : SpriteClip?) -- This method fires upon your emoji being destroyed
			--[

				This method is intended for cleanup purposes! You can just use the code thats already here if you dont have any
				additional usage cases for it.

			]--
			
			AnimationObject:Destroy();
		end
	};

]]--

--// Imports
local SpriteClip

--// Module
local Emotes = {
	["cool"] = {
		["Image"] = "http://www.roblox.com/asset/?id=5817511712",
	};
	
	["birdrave"] = {
		["Image"] = "http://www.roblox.com/asset/?id=7145510451",
		["IsAnimated"] = true,
		
		["OnEmoteFired"] = function(Emote)
			local SpriteClipObject = SpriteClip.new();

			SpriteClipObject.InheritSpriteSheet = true
			SpriteClipObject.Adornee = Emote
			SpriteClipObject.SpriteSizePixel = Vector2.new(916 / 3, 960 / 4);
			SpriteClipObject.SpriteCountX = 3
			SpriteClipObject.SpriteCount = ((3 * 3) + 1);
			SpriteClipObject.FrameRate = 60

			SpriteClipObject:Play();			
			return SpriteClipObject --// Return our AnimationObject
		end,

		["OnEmoteSweeped"] = function(Emote, AnimationObject) --// Uses the collected AnimationObject
			AnimationObject:Destroy(); --// Stops our RunService emote
		end,
	};
};

return function (ChatUtilities : table)
	if (not SpriteClip) then
		SpriteClip = ChatUtilities.SpriteClip
	end
	
	return Emotes
end