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

--- Creates and returns a preset TextLabel! This is purely for readability
function ChatSystemCommons:CreateLabel(fromSize : Vector2, CustomFont : Enum.Font?) : TextLabel
    local NewLabel = Instance.new("TextLabel");
    
    if (ChatSystemConfigurations.DebugOutputEnabled) then
        NewLabel.BackgroundColor3 = BrickColor.random().Color
        NewLabel.BackgroundTransparency = 0.8
    else
        NewLabel.BackgroundTransparency = 1
    end

    NewLabel.TextStrokeTransparency = 0.8
    NewLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
    NewLabel.Size = UDim2.fromOffset(fromSize.X, fromSize.Y);
    
    NewLabel.TextXAlignment = Enum.TextXAlignment.Left
    NewLabel.TextSize = AbsoluteFontSize
    NewLabel.Font = ((CustomFont) or (ChatSystemConfigurations.Font));

    return NewLabel
end

--- Creates and returns a preset TextButton! This is purely for readability
function ChatSystemCommons:CreateButton(fromSize : Vector2, CustomFont : Enum.Font?) : TextButton
    local NewButton = Instance.new("TextButton");

    if (ChatSystemConfigurations.DebugOutputEnabled) then
        NewButton.BackgroundColor3 = BrickColor.random().Color
        NewButton.BackgroundTransparency = 0.8
    else
        NewButton.BackgroundTransparency = 1
    end

    NewButton.TextStrokeTransparency = 0.8
    NewButton.TextColor3 = Color3.fromRGB(255, 255, 255);
    NewButton.Size = UDim2.fromOffset(fromSize.X, fromSize.Y);

    NewButton.TextXAlignment = Enum.TextXAlignment.Left
    NewButton.Font = ((CustomFont) or (ChatSystemConfigurations.Font));

    NewButton.TextScaled = true
    NewButton.TextWrapped = true

    return NewButton
end

--- Creates and returns a preset Frame! This is purely for readability
function ChatSystemCommons:CreateFrame(fromSize : Vector2) : Frame
    local NewFrame = Instance.new("Frame");

	NewFrame.Size = UDim2.fromOffset(fromSize.X, math.max(fromSize.Y, ChatSystemCommons.SpaceLength.Y));
    NewFrame.BackgroundTransparency = 1
    NewFrame.ClipsDescendants = true

	return NewFrame
end

return ChatSystemCommons