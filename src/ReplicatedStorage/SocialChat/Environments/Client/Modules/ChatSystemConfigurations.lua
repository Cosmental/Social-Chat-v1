--[[

	Name: Cos
	Date: 7/28/2022
	
	Description: This module holds configuration data for the ChatSystem!

]]--

return {

	--// TEXT BOX CONFIGURATIONS

	["TextBoxHighlightingEnabled"] = true, -- Determines if the chat textbox will highlight keywords/phrases (opt.)
	["HighlightConfigurations"] = {
		["EmoteHighlightColor"] = Color3.fromRGB(255, 255, 0),
		["UsernameHighlightColor"] = Color3.fromRGB(90, 215, 255),
		["CommandHighlightColor"] = Color3.fromRGB(255, 55, 55)
	};
	
	--// CHAT VISUALS

	["Font"] = Enum.Font.SourceSansBold, -- Default chat font
	["FontSize"] = "Default", -- ChatFrame font size (if set to "Default", this will automatically scale with the user's screen size) [18]

	["TextStrokeTransparency"] = 0.8, -- TextLabel Property (applies to all chat labels)
	["TextTransparency"] = 0, -- TextLabel Property (applies to all chat labels)

	--// CHAT FRAME SETTINGS

	["IsTweeningAllowed"] = true, -- Determines if our Chat will tween new incomming messages smoothly
	["DormantLifespan"] = 5, -- Determines how long our chatGui remains visible without any inputs

	["EmoteHoverTweenInfo"] = TweenInfo.new(.3, Enum.EasingStyle.Exponential), -- TweenInfo used for the emote hover Instance in our chat system
	["TweenInfo"] = TweenInfo.new(.5, Enum.EasingStyle.Exponential), -- TweenInfo used for mostly every other tween that occurs within the chat system

	["ChatFrameBackgroundTransparency"] = 0.5,
	["ChatBoxBackgroundTransparency"] = 0.5,

	--// BUBBLE CHAT SETTINGS

	["IsBubbleChatEnabled"] = true, -- Determines if chat bubbles will be used alongside the chat system
	["IsBubbleTweeningAllowed"] = true, -- Determines if chat bubbles will smoothly tween when being destroyed/created

	["BubbleSizeOffset"] = 20, -- Determines the size offset between chat bubbles and their inner text. This is a visual setting but it is recommended that you do not edit this value.
	["BubbleLifespan"] = 10, -- This determines the lifespan of our chat bubbles. After this timespan (in seconds), your bubble with get garbage collected

	["AllowBubbleHiding"] = true, -- Allows players to hide their chat bubbles with a special prefix that can be used at the beginning of their chat message
	["BubbleHidePrefix"] = "/nb", -- If a player uses this prefix within their chat message, a text bubble will NOT be rendered (AllowBubbleHiding must be true for this to work)

	["MaximumRenderDistance"] = 100, -- This determines how far away a player can be in order for chat bubbles to render for them. If a player is further than the desired value, chat bubbles will automatically be hidden.
	["BubbleRenderLimitPerCharacter"] = 3, -- This determines how many chat bubbles can appear at once for individual players

	["BubbleTweenInfo"] = TweenInfo.new(.5, Enum.EasingStyle.Exponential),
	["BubbleTextSize"] = 18, -- WARNING: This will only affect the textsize of our bubble chat!

	["BubbleTextColor"] = Color3.fromRGB(255, 255, 255),
	["BubbleColor"] = Color3.fromRGB(0, 0, 0),
	["BubbleFont"] = Enum.Font.SourceSansBold, -- WARNING: This will NOT be the font for our custom chat system. This will only change our bubble chat text font!

	["BubbleBackgroundTransparency"] = 0.5,
	["BubbleTextStrokeTransparency"] = 0.9,
	["BubbleTextTransparency"] = 0,

	--// EMOTES

	["ChatEmoteSize"] = "Default", -- This is the displayed emote size for our chat frame {x, y} (if default, this will scale automatically) [20]
	["BubbleEmoteSize"] = 16, -- This is the displayed emote size for Chat Bubbles {x, y}
	["EmoteSyntax"] = ":", -- This will be the required syntax to use an emote (ex: ":troll:")
	["DisplayEmoteInfoOnHover"] = true, -- If true, a bubble will appear above our emote upon our client hovering over to display its usage keycode
		
	--// MISC

	["MaxMessagesAllowed"] = 50, -- Determines how many messages we can log before cleaning up our chat logs

	["FriendJoinMessagesEnabled"] = true, -- Determines if a friend join message will display whenever a friend joins our client's game
	["FriendJoinMessage"] = "{System} Your friend %s has joined the server.", -- This will be the format text for our join message (if enabled)

	["CreditOutputEnabled"] = true, -- Crediting me is not required but heavily appreciated! If you would like to hide the credits message for any particular reason, set this value to "false"
	["DebugOutputEnabled"] = false, -- Used for debugging

};