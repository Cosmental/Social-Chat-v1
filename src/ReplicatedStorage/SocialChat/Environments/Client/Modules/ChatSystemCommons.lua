--[[

    Name: Cos
    Date: 8/27/2022

    Description: This module holds common functions used within the ChatSystem!

]]--

--// Module
local ChatSystemCommons = {};

--// Services
local TextService = game:GetService("TextService");

--// Imports
local ChatSystemConfigurations = require(script.Parent.ChatSystemConfigurations);
local ChatSystemTags = require(script.Parent.ChatSystemTags);
local ChatSystemEmotes

--// Constants
local ChatGUI
local ChatFrame
local ChatBox

local AbsoluteFontSize

local OperatorFormatting = "<font color=\"rgb(150, 150, 150)\"><stroke thickness=\"0\">%s</stroke></font>"
local MarkdownFormatting = { -- used for markdown embedding
    [1] = {
        ["operator"] = "**",
        
        ["format"] = "<stroke thickness=\".3\" color=\"rgb(255,255,255)\">%s</stroke>",
		["query"] = "[^%*]%*%*(.-)%*%*"
    };

    [2] = {
        ["operator"] = "*",

        ["format"] = "<i>%s</i>",
		["query"] = "[^%*]%*(.-)%*"
    };

    [3] = {
        ["operator"] = "__",

        ["format"] = "<u>%s</u>",
		["query"] = "[^%*]__(.-)__"
    };

    [4] = {
        ["operator"] = "~~",

        ["format"] = "<s>%s</s>",
		["query"] = "[^%*]~~(.-)~~"
    };
};

--// Initialization
function ChatSystemCommons:Init()
    ChatGUI = game.Players.LocalPlayer.PlayerGui.Chat.FrameChat
    ChatFrame = ChatGUI.FrameChatList
    ChatBox = ChatGUI.FrameChatBox.InputBoxChat

    AbsoluteFontSize = (
        ((ChatSystemConfigurations.FontSize == "Default") and (ChatBox.TextBounds.Y + 2))
            or (ChatSystemConfigurations.FontSize)
    );

    ChatSystemCommons.SpaceLength = ChatSystemCommons:GetTextSize(" ", ChatFrame);
    ChatSystemEmotes = require(script.Parent.ChatSystemEmotes)();
end

--// Common Methods

--- Returns the absoluteSize for the provided string
function ChatSystemCommons:GetTextSize(text : string, parentObject : Instance, byGrapheme : boolean?, CustomTextParams : table?) : Vector2 | boolean?
    local AbsX = parentObject.AbsoluteSize.X
    local AbsY = parentObject.AbsoluteSize.Y

    if (byGrapheme) then
        local doesWordOverflow = false
        local GraphemeX = 0
        local GraphemeY = ChatSystemCommons.SpaceLength.Y

        for _, Grapheme in pairs(text:split("")) do
            local GraphemeSize = TextService:GetTextSize(
                Grapheme,
                ((CustomTextParams) and (CustomTextParams.FontSize)) or (AbsoluteFontSize),
                ((CustomTextParams) and (CustomTextParams.Font)) or (ChatSystemConfigurations.Font),
                Vector2.new(AbsX, AbsY)
            );

            GraphemeX += GraphemeSize.X

            if (GraphemeX >= AbsX) then
                GraphemeX = 0
                GraphemeY += (((CustomTextParams) and (CustomTextParams.FontSize)) or (ChatSystemCommons.SpaceLength.Y));

                doesWordOverflow = true
            end
        end

        return Vector2.new(
            (((doesWordOverflow) and (AbsX)) or (GraphemeX)),
            GraphemeY
        ), doesWordOverflow
    else
        return TextService:GetTextSize(
            text,
            ((CustomTextParams) and (CustomTextParams.FontSize)) or (AbsoluteFontSize),
            ((CustomTextParams) and (CustomTextParams.Font)) or (ChatSystemConfigurations.Font),
            Vector2.new(AbsX, AbsY)
        );
    end
end

--- Applies a TextLabel/TextButton Color scheme based on the provided "tagColor" parameter
function ChatSystemCommons:ApplyLabelColor(Graphemes : table, tagColor : string | Color3, UniqueTagsOnly : boolean?) : table?

    --// Extract TextObjects from our Grapheme table
    local function extractTextObjects(fromArray : table) : table
        local extractedObjects = {};

        for _, Object in pairs(fromArray) do
            if ((Object:IsA("TextLabel")) or (Object:IsA("TextButton"))) then
                table.insert(extractedObjects, Object);
            elseif (next(Object:GetChildren())) then
                for _, v in pairs(extractTextObjects(Object:GetChildren())) do
                    table.insert(extractedObjects, v);
                end
            end
        end

        return extractedObjects
    end

    local textObjects = extractTextObjects(Graphemes);

    --// Now we can color our TextObjects
    if ((typeof(tagColor) == "Color3") and (not UniqueTagsOnly)) then
        for _, Label in pairs(textObjects) do
            Label.TextColor3 = tagColor
        end
    elseif (type(tagColor) == "string") then
        local UniqueTag = ChatSystemTags[tagColor];

        if (UniqueTag) then
            return coroutine.wrap(UniqueTag.OnCalled)(textObjects);
        else
            warn("No tag data was found for "..(tagColor).."!");
        end
    end

end

--- Applies an Emoji to the given ImageObject using the provided Emote query string
function ChatSystemCommons:ApplyEmoji(ImageObject : Instance, Emote : string) : table?
    local EmoteInfo = ChatSystemEmotes[Emote];
    ImageObject.Image = EmoteInfo.Image
    
    if (EmoteInfo.IsAnimated) then -- Emote is animated!
        return coroutine.wrap(EmoteInfo.OnEmoteFired)(ImageObject);
    end
end

--- Formats our Markdown text into rich or plain text!
function ChatSystemCommons:MarkdownAsync(text : string, keepMarkdownOperators : boolean?) : string
    local movement = 0
    local data = {};

	for _, markdownData in ipairs(MarkdownFormatting) do
        local formattedOperator = string.format(OperatorFormatting, markdownData.operator);

		repeat
			local starts, ends, plainTxt = string.find(" "..text, markdownData.query, movement); -- The regex we are using requires at least one space to work

            local isEmpty : boolean = ((plainTxt) and (plainTxt:find("^%s*$")));
            local isRich : boolean = (
                (starts and ends)
                    and (text:sub(starts - 1, starts - 1) == ">")
                    and (text:sub(ends, ends) == "<")
            );

			if (((starts and ends) and (not isEmpty)) and (not isRich)) then -- Make sure our regex starts and ends somewhere AND isnt just whitetext
                local replacementText = (
                    ((keepMarkdownOperators) and string.format(markdownData.format, (formattedOperator..plainTxt..formattedOperator)))
                    or (string.format(markdownData.format, plainTxt))
                );
            
                text = (
                    text:sub(1, starts - 1)..
                    replacementText..
                    (text:sub(ends))
                );

                table.insert(data, {
                    ["Text"] = plainTxt,
                    ["Meta"] = markdownData,

                    ["Indexing"] = {
                        ["Starts"] = starts - movement,
                        ["Ends"] = ends - movement
                    },
                });

                if (keepMarkdownOperators) then
                    movement += ((starts - movement) + (markdownData.format:len() - 2) + (formattedOperator:len() * 2) + plainTxt:len());
                else
                    movement += ((starts - movement) + (markdownData.format:len() - 2) + plainTxt:len());
                end
            elseif (isEmpty or isRich) then
                movement += markdownData.operator:len();
			end
		until
		((not starts or not ends));
	end
    
	return text, data
end

--// INSTANCING
--\\ These methods are purely for the sake of better readability

--- Creates and returns a preset TextLabel!
function ChatSystemCommons:CreateLabel(fromSize : Vector2, CustomFont : Enum.Font?) : TextLabel
    local NewLabel = Instance.new("TextLabel");
    
    if (ChatSystemConfigurations.DebugOutputEnabled) then
        NewLabel.BackgroundColor3 = BrickColor.random().Color
        NewLabel.BackgroundTransparency = 0.8
    else
        NewLabel.BackgroundTransparency = 1
    end

    NewLabel.RichText = true
    NewLabel.TextStrokeTransparency = 0.8
    NewLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
    NewLabel.Size = UDim2.fromOffset(fromSize.X, fromSize.Y);
    
    NewLabel.TextXAlignment = Enum.TextXAlignment.Left
    NewLabel.TextSize = AbsoluteFontSize
    NewLabel.Font = ((CustomFont) or (ChatSystemConfigurations.Font));

    return NewLabel
end

--- Creates and returns a preset TextButton!
function ChatSystemCommons:CreateButton(fromSize : Vector2, CustomFont : Enum.Font?) : TextButton
    local NewButton = Instance.new("TextButton");

    if (ChatSystemConfigurations.DebugOutputEnabled) then
        NewButton.BackgroundColor3 = BrickColor.random().Color
        NewButton.BackgroundTransparency = 0.8
    else
        NewButton.BackgroundTransparency = 1
    end

    NewButton.RichText = true
    NewButton.TextStrokeTransparency = 0.8
    NewButton.TextColor3 = Color3.fromRGB(255, 255, 255);
    NewButton.Size = UDim2.fromOffset(fromSize.X, fromSize.Y);

    NewButton.TextXAlignment = Enum.TextXAlignment.Left
    NewButton.Font = ((CustomFont) or (ChatSystemConfigurations.Font));

    NewButton.TextScaled = true
    NewButton.TextWrapped = true

    return NewButton
end

--- Creates and returns a preset Frame!
function ChatSystemCommons:CreateFrame(fromSize : Vector2) : Frame
    local NewFrame = Instance.new("Frame");

	NewFrame.Size = UDim2.fromOffset(fromSize.X, math.max(fromSize.Y, ChatSystemCommons.SpaceLength.Y));
    NewFrame.BackgroundTransparency = 1
    NewFrame.ClipsDescendants = true

	return NewFrame
end

return ChatSystemCommons