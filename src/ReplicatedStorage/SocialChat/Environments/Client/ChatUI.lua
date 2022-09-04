--[[

    Name: Cos
    Date: 7/31/2022

    Description: Handles the in game ChatUI! (Rendering is handled by ChatService)

]]--

--// Module
local ChatUI = {};
ChatUI.__index = ChatUI

--// Services
local UserInputService = game:GetService("UserInputService");
local TweenService = game:GetService("TweenService");
local TextService = game:GetService("TextService");
local RunService = game:GetService("RunService");
local Chat = game:GetService("Chat");

local ChatService

--// Imports
local ChatEmotes
local ChatCommons
local ChatSettings

local TopbarPlus

--// Constants
local Player = game.Players.LocalPlayer
local ChatEvents

local ChatGUI
local ChatFrame

local ChatBox
local DisplayLabel

local CustomEmoteList = {};
local EmoteSyntax

local MarkdownEmbeds = {'**', '*', "__", "~"}; -- used for ipairs formatting
local RichTextFormat = "<font color =\"rgb(%s, %s, %s)\">%s</font>"

local CurrentFontSize : number
local AbsoluteDisplaySize : number

local SelectionFrame = Instance.new("Frame");
local CursorFrame = Instance.new("Frame");

--// States
local isClientMuted : boolean
local isMouseOnChat : boolean
local isChatHidden : boolean = false
local isBoxHidden : boolean = true

local canChatHide : boolean
local focusLostAt : number

local currentEmoteTrack : string?
local isHoldingCTRL : boolean?

local LastSavedCursorPosition : number = 0
local CursorTick : number = os.clock();
local FocusPoint : number = 0

--// Initialization
function ChatUI:Init(ChatController : table, ChatUtilities : table, ChatRemotes : Instance)
    local self = setmetatable({}, ChatUI);
    ChatEvents = ChatRemotes

    ChatService = ChatController
    TopbarPlus = ChatUtilities.TopbarPlus

    --// Referencing
    --\\ This is done during initialization because we know our module SHOULD initialize after our ChatGUI has been parented!

    ChatGUI = Player.PlayerGui.Chat.FrameChat
    ChatFrame = ChatGUI.FrameChatList

    ChatBox = ChatGUI.FrameChatBox.InputBoxChat
    DisplayLabel = ChatGUI.FrameChatBox.LabelDisplayTypedChat

    --// Selection Frame
    --\\ This section simulates a "selection box" for our DisplayLabel!

    SelectionFrame.BackgroundColor3 = Color3.fromRGB(106, 159, 248);
    SelectionFrame.Name = "SelectionFrame"
    SelectionFrame.BorderSizePixel = 0
    SelectionFrame.Visible = false

    SelectionFrame.ZIndex = 2
    SelectionFrame.Parent = DisplayLabel

    CursorFrame.Size = UDim2.fromOffset(1.5, DisplayLabel.AbsoluteSize.Y);
    CursorFrame.Position = UDim2.fromScale(0, 0.5);
    CursorFrame.AnchorPoint = Vector2.new(0, 0.5);

    CursorFrame.Name = "CursorFrame"
    CursorFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
    CursorFrame.BorderSizePixel = 0
    CursorFrame.ZIndex = 5
    CursorFrame.Visible = false
    CursorFrame.Parent = DisplayLabel

    local function updateSelectionBox()
        local selectionInfo = ChatUI:GetSelected();
        
        if (selectionInfo) then
            SelectionFrame.Size = UDim2.fromOffset(selectionInfo.SelectionSize, DisplayLabel.AbsoluteSize.Y + 4);
            SelectionFrame.Position = UDim2.fromOffset(selectionInfo.StartPos, 0);
            SelectionFrame.Visible = true
        else
            SelectionFrame.Visible = false
        end
    end

    local function updateCursorPos()
        RunService.RenderStepped:Wait();

        local currentPos = ChatBox.CursorPosition

        if (ChatBox:IsFocused()) then
            LastSavedCursorPosition = currentPos
            CursorFrame.Visible = true
            CursorTick = os.clock();
        end

        if (currentPos ~= -1) then
            local textBeforeCursorSize : number = TextService:GetTextSize(
                ChatBox.Text:sub(0, currentPos - 1),
                CurrentFontSize,
                DisplayLabel.Font,
                Vector2.new(math.huge, math.huge)
            );
            
            CursorFrame.Position = UDim2.new(0, textBeforeCursorSize.X, 0.5, 0);
        end
    end

    ChatBox:GetPropertyChangedSignal("SelectionStart"):Connect(updateSelectionBox);
    ChatBox:GetPropertyChangedSignal("CursorPosition"):Connect(function()
        updateSelectionBox();
        updateTextPosition();
        updateCursorPos();
    end)

    --// Setup
    local ChatModules = ChatService:GetModules();

    ChatEmotes = ChatModules.Emotes
    ChatCommons = ChatModules.Commons
    ChatSettings = ChatModules.Settings
    EmoteSyntax = ChatSettings.EmoteSyntax

    CurrentFontSize = math.min(ChatBox.AbsoluteSize.Y, ChatSettings.ChatBoxFontSize);
    AbsoluteDisplaySize = DisplayLabel.AbsoluteSize.X

    ChatBox.TextSize = CurrentFontSize
    DisplayLabel.TextSize = CurrentFontSize

    if (not Chat:CanUserChatAsync(Player.UserId)) then -- We need to respect client boundries (if any)
        ChatGUI.Visible = false
        return;
    end

    --// Emote setup
    for Key, Data in pairs(ChatSettings.CustomDanceEmotes) do
        CustomEmoteList[Key] = {};

        for RigType, animationId in pairs(Data) do
            local animObj = Instance.new("Animation");

            animObj.Name = (Key..(((RigType == Enum.HumanoidRigType.R15) and ("_R15")) or ("_R6")));
            animObj.AnimationId = animationId

            CustomEmoteList[Key][RigType] = animObj
        end
    end

    --// Topbar Setup
    local ChatToggleButton = TopbarPlus.new();

    ChatToggleButton:setImage("rbxasset://textures/ui/TopBar/chatOn.png")
        :setCaption("SocialChat "..(ChatModules.VERSION))
        :select()
        :bindToggleItem(ChatGUI)
        :setProperty("deselectWhenOtherIconSelected", false)
        :setOrder(1)

    ChatToggleButton:bindEvent("selected", function()
        focusLostAt = os.clock();
        canChatHide = true
        
        ChatToggleButton:clearNotices();
        SetChatHidden(false);
    end);

    ChatToggleButton:bindEvent("deselected", function()
        SetChatHidden(true);
    end);

    --// TextBox Clicking simulation
    --\\ Since our method of setting up the chat system is a little hacky, we need an alternate way for Mobile clients to click on the Chatbox!

    DisplayLabel.InputBegan:Connect(function(Input)
        if (ChatBox:IsFocused()) then return; end

        if ((Input.UserInputType == Enum.UserInputType.Touch) or (Input.UserInputType == Enum.UserInputType.MouseButton1)) then
            ChatBox.CursorPosition = LastSavedCursorPosition
            SetTextBoxVisible(false);
            SetChatHidden(false);

            ChatBox:CaptureFocus();
        end
    end);

    --// Events
    ChatEvents.ChatReplicate.OnClientEvent:Connect(function(speaker : string | Player, message : string, tagInfo : table, toRecipient : Player?)
        local didUserRequestHidenBubble = (message:sub(1, #ChatSettings.BubbleHidePrefix) == ChatSettings.BubbleHidePrefix);

        ChatService:CreateChatMessage(
            speaker,
            (((didUserRequestHidenBubble) and (message:sub(#ChatSettings.BubbleHidePrefix + 2))) or (message)),
            tagInfo,
            toRecipient
        );

        if (ChatToggleButton:getToggleState() == "deselected") then
            ChatToggleButton:notify();
        end

        if (typeof(speaker) ~= "Instance") then return; end
        local messageHasMoreThanOneWord = (#message:split(" ") > 1);

        if ((not ChatSettings.AllowBubbleHiding) or ((not didUserRequestHidenBubble) or (not messageHasMoreThanOneWord))) then
            ChatService:CreateBubbleMessage(speaker.Character, message, tagInfo);
        end
    end);

    ChatEvents.ChatMute.OnClientEvent:Connect(function(isMuted : boolean)
        isClientMuted = isMuted
        SetTextBoxVisible(true);
        LastSavedCursorPosition = 0

        if (isMuted) then
            ChatService:MuteClient();
        else
            ChatService:UnmuteClient();
        end
    end);

    --// Inputs
    UserInputService.InputBegan:Connect(function(keyInput : InputObject, wasProcessed : boolean)
        if (wasProcessed) then return; end
        if (keyInput.KeyCode ~= Enum.KeyCode.Slash) then return; end
        if (isClientMuted) then return; end

        if (ChatToggleButton:getToggleState() == "deselected") then
            ChatToggleButton:select();
        end

        game:GetService("RunService").RenderStepped:Wait();
        ChatBox.CursorPosition = LastSavedCursorPosition

        SetTextBoxVisible(false);
        SetChatHidden(false);

        ChatBox:CaptureFocus();
    end);

    ChatBox.FocusLost:Connect(function(enterPressed : boolean)
        canChatHide = (not isMouseOnChat);
        focusLostAt = os.clock();
        
        CursorFrame.Visible = false
        
        if (ChatBox.Text:len() == 0) then
            ChatBox.PlaceholderText = "Type '/' to chat"
            SetTextBoxVisible(true);
            return;
        end
        
        if (not enterPressed) then return; end
        LastSavedCursorPosition = 0

        if ((ChatBox.Text:sub(1, 3) == "/w ") and (#ChatBox.Text:split(" ") >= 3)) then
            local TargetUsername = ChatBox.Text:split(" ")[2];
            local TargetClient = QuerySearch(TargetUsername);

            if ((TargetClient) and (TargetClient ~= Player)) then
                ChatEvents.ChatReplicate:FireServer(ChatBox.Text:sub(TargetUsername:len() + 5), TargetClient);
            elseif (TargetClient == Player) then
                ChatService:CreateChatMessage(
                    nil,
                    "You can not send yourself a private message.",
                    {
                        ["MessageColor"] = Color3.fromRGB(255, 45, 45)
                    }
                );
            else
                ChatService:CreateChatMessage(
                    nil,
                    "\""..(ChatBox.Text:split(" ")[2]).."\" is not a valid player. You can only send private messages to players in the server!",
                    {
                        ["MessageColor"] = Color3.fromRGB(255, 45, 45)
                    }
                );
            end
        elseif ((ChatBox.Text:sub(1, 3) == "/e ") and (#ChatBox.Text:split(" ") >= 2)) then
            local Character = Player.Character
            if (not Character) then return; end

            local Humanoid = Character:FindFirstChildOfClass("Humanoid");
            if (not Humanoid) then return; end

            local Animator = Humanoid:FindFirstChildOfClass("Animator");
            if (not Animator) then return; end

            local emoteName = ChatBox.Text:sub(4);
            local customEmote = (
                ((emoteName == "dance") and (pickRandomDanceEmote(Humanoid.RigType)))
                    or ((CustomEmoteList[emoteName]) and (CustomEmoteList[emoteName][Humanoid.RigType]))
            );

            local doesOwnEmote = (Humanoid.HumanoidDescription:GetEmotes()[emoteName]);

            if (customEmote) then
                if (Humanoid.FloorMaterial == Enum.Material.Air) then return; end

                local Track = Animator:LoadAnimation(customEmote);

                if (currentEmoteTrack) then
                    currentEmoteTrack:Stop();
                end

                Track.Priority = Enum.AnimationPriority.Action4
                currentEmoteTrack = Track
                Track:Play();

                Humanoid.Died:Connect(function()
                    Track:Stop();
                    currentEmoteTrack = nil
                end);

                Humanoid.Running:Connect(function()
                    Track:Stop();
                    currentEmoteTrack = nil
                end);
            elseif (doesOwnEmote) then
                if (currentEmoteTrack) then
                    currentEmoteTrack:Stop();
                    currentEmoteTrack = nil
                end

                Humanoid:PlayEmote(emoteName);
            else
                ChatController:CreateChatMessage(
                    nil,
                    "\""..(emoteName).."\" is not a valid emote!",
                    {
                        ["MessageColor"] = Color3.fromRGB(255, 75, 75)
                    }
                );
            end
        elseif (ChatBox.Text == "/console") then
            game.StarterGui:SetCore("DevConsoleVisible", true);
        else
            ChatEvents.ChatReplicate:FireServer(ChatBox.Text);
        end
        
        ChatBox.PlaceholderText = "Type '/' to chat"
        SetTextBoxVisible(true);
        ChatBox.Text = ""
    end);

    --// Rich Text Support
    UserInputService.InputBegan:Connect(function(input : InputObject)
        if (not ChatSettings.AllowMarkdown) then return; end

        local richEmbed = (
            ((input.KeyCode == Enum.KeyCode.B) and ("**")) or -- **bold**
            ((input.KeyCode == Enum.KeyCode.I) and ("*")) or -- *italic*
            ((input.KeyCode == Enum.KeyCode.U) and ("__")) or -- __underlined__
            ((input.KeyCode == Enum.KeyCode.S) and ("~~")) -- s̶t̶r̶i̶k̶e̶-̶t̶h̶r̶o̶u̶g̶h̶
        );

        local selectedText, startIndex, endIndex = getSelected();

        if (input.KeyCode == Enum.KeyCode.LeftControl) then
            isHoldingCTRL = true
        elseif ((isHoldingCTRL) and (richEmbed) and (ChatBox:IsFocused()) and (selectedText)) then
            local selectionA, selectionB = ChatBox.CursorPosition, ChatBox.SelectionStart
            local isMarkedDown : boolean

            for _, embedGrapheme in ipairs(MarkdownEmbeds) do -- must loop in order, otherwise we can flag for italics when we have bold md's!
                isMarkedDown = (
                    (selectedText:sub(1, embedGrapheme:len()) == embedGrapheme)
                    and ((selectedText:sub((selectedText:len() - embedGrapheme:len()) + 1)) == embedGrapheme)
                );

                if (isMarkedDown) then
                    if (embedGrapheme ~= richEmbed) then
                        selectedText = string.gsub(
                            selectedText,
                            embedGrapheme,
                            ""
                        );

                        if (embedGrapheme:len() == richEmbed:len()) then break; end

                        local offsetValue = (
                            ((embedGrapheme:len() < richEmbed:len()) and (richEmbed:len()))
                                or (-embedGrapheme:len())
                        );
                        
                        if (selectionA > selectionB) then
                            selectionA += offsetValue
                        else
                            selectionB += offsetValue
                        end
                    end

                    break;
                end
            end

            local enrichedText = (
                (isMarkedDown) and (string.gsub(selectedText, richEmbed, ""))
                    or ((richEmbed)..(selectedText)..(richEmbed))
            );

            local constructed = string.format("%s%s%s",
                ChatBox.Text:sub(1, startIndex - 1),
                enrichedText,
                ChatBox.Text:sub(endIndex)
            );

            RunService.RenderStepped:Wait();
            ChatBox.Text = constructed

            local selectionAlpha = (
                (isMarkedDown) and (-richEmbed:len() * 2)
                or (richEmbed:len() * 2)
            );

            if (selectionA > selectionB) then
                ChatBox.CursorPosition = (selectionA + selectionAlpha);
                ChatBox.SelectionStart = selectionB
            else
                ChatBox.CursorPosition = selectionA
                ChatBox.SelectionStart = (selectionB + selectionAlpha);
            end
        end
    end);

    UserInputService.InputEnded:Connect(function(input : InputObject)
        if (input.KeyCode == Enum.KeyCode.LeftControl) then
            isHoldingCTRL = false
        end
    end);

    --// Box Handling
    ChatBox:GetPropertyChangedSignal("Text"):Connect(function()

        --// Highlights
        --\\ If the highlight option in our settings is set to TRUE, then we can highlight certain keywords and phrases in our masking label!

        local NewMaskingText = ""

        for Index, Word in pairs(ChatBox.Text:split(" ")) do
            local isEmote = ((Word:sub(1, 1) == EmoteSyntax) and (Word:sub(#Word, #Word) == EmoteSyntax));

            if ((isEmote) and (Word:len() > 2) and (ChatEmotes[Word:sub(2, #Word - 1)])) then -- This word is an emote!
                NewMaskingText = NewMaskingText..(string.format(
                    RichTextFormat,
                    GetFlatColor(ChatSettings.HighlightConfigurations.EmoteHighlightColor.R),
                    GetFlatColor(ChatSettings.HighlightConfigurations.EmoteHighlightColor.G),
                    GetFlatColor(ChatSettings.HighlightConfigurations.EmoteHighlightColor.B),
                    Word
                ));
            elseif (QuerySearch(Word)) then -- This word is a player's name!
                NewMaskingText = NewMaskingText..(string.format(
                    RichTextFormat,
                    GetFlatColor(ChatSettings.HighlightConfigurations.UsernameHighlightColor.R),
                    GetFlatColor(ChatSettings.HighlightConfigurations.UsernameHighlightColor.G),
                    GetFlatColor(ChatSettings.HighlightConfigurations.UsernameHighlightColor.B),
                    Word
                ));
            elseif ((Word == "/e") or (Word == "/w") or (Word == "/shrug") or (Word == ChatSettings.BubbleHidePrefix)) then
                NewMaskingText = NewMaskingText..(string.format(
                    RichTextFormat,
                    GetFlatColor(ChatSettings.HighlightConfigurations.CommandHighlightColor.R),
                    GetFlatColor(ChatSettings.HighlightConfigurations.CommandHighlightColor.G),
                    GetFlatColor(ChatSettings.HighlightConfigurations.CommandHighlightColor.B),
                    Word
                ));
            else
                NewMaskingText = ((NewMaskingText)..(Word))
            end

            if (Index == #ChatBox.Text:split(" ")) then continue; end
            NewMaskingText = ((NewMaskingText)..(" ")); -- We need to add spacing between words!
        end

        DisplayLabel.Text = (
            (ChatSettings.AllowMarkdown) and (ChatCommons:MarkdownAsync(NewMaskingText, true))
                or (NewMaskingText)
        );

        CursorTick = os.clock();

        if (ChatBox:IsFocused()) then
            CursorFrame.Visible = true
        end

        updateCursorPos();
        updateTextPosition();

    end);

    --// Visibility
    ChatBox.Focused:Connect(function()
        canChatHide = false
        ChatBox.PlaceholderText = ""

        updateTextPosition();
        updateCursorPos();
    end);
    
    ChatGUI.MouseEnter:Connect(function()
        canChatHide = false
        isMouseOnChat = true
        if (not isChatHidden) then return; end
        
        SetChatHidden(false);
    end);

    ChatGUI.MouseLeave:Connect(function()
        isMouseOnChat = false
        if (ChatBox:IsFocused()) then return; end

        canChatHide = true
        focusLostAt = os.clock();
    end);

    RunService.RenderStepped:Connect(function()
        if (((os.clock() - CursorTick) >= 0.5) and (isBoxHidden) and (ChatBox:IsFocused())) then
            CursorTick = os.clock();
            CursorFrame.Visible = not CursorFrame.Visible
        end

        if (not canChatHide) then return; end
        if (ChatBox:IsFocused()) then return; end
        if ((os.clock() - focusLostAt) < ChatSettings.DormantLifespan) then return; end

        SetChatHidden(true);
        canChatHide = false
    end);

    --// Friend joining
    if (ChatSettings.FriendJoinMessagesEnabled) then
        game.Players.PlayerAdded:Connect(function(playerWhoJoined : Player)
            if (Player:IsFriendsWith(playerWhoJoined.UserId)) then
                ChatService:CreateChatMessage(
                    nil,
                    string.format(ChatSettings.FriendJoinMessage, playerWhoJoined.Name),
                    {}
                );
            end
        end);
    end
end

--// Public Methods

--- Hides the ChatFrame GUI
function ChatUI:Enable()
    ChatFrame.Visible = true
end

--- Enables the ChatFrame GUI
function ChatUI:Disable()
    ChatFrame.Visible = false
end

--- Sets the current chat text to the provided string
function ChatUI:SetText(desiredText : string)
    ChatBox.PlaceholderText = ""
    ChatBox.Text = desiredText

    ChatBox.CursorPosition = desiredText:len();
    SetTextBoxVisible(false);
    SetChatHidden(false);

    ChatBox:CaptureFocus();
end

--- Returns Selection data based on our ChatBox's behavior
function ChatUI:GetSelected()
    if ((ChatBox.CursorPosition == -1) or (ChatBox.SelectionStart == -1)) then return; end
    
    local selectionStart : number = math.min(ChatBox.CursorPosition, ChatBox.SelectionStart);
    local selectionEnd : number = math.max(ChatBox.CursorPosition, ChatBox.SelectionStart) - 1;

    local priorText : string = ChatBox.Text:sub(0, selectionStart - 1);
    local afterText : string = ChatBox.Text:sub(selectionEnd + 1);

    local priorTextSize : number = TextService:GetTextSize(
        priorText,
        CurrentFontSize,
        DisplayLabel.Font,
        Vector2.new(math.huge, math.huge)
    );

    local afterTextSize = TextService:GetTextSize(
        afterText,
        CurrentFontSize,
        DisplayLabel.Font,
        Vector2.new(math.huge, math.huge)
    );

    local absSelectionSize = ((ChatBox.TextBounds.X - afterTextSize.X) - priorTextSize.X);
    local selectedText = string.sub(
        ChatBox.Text,
        selectionStart,
        selectionEnd
    );

    return {
        ["StartPos"] = priorTextSize.X,
        ["EndPos"] = ChatBox.TextBounds.X - afterTextSize.X,

        ["SelectionSize"] = absSelectionSize,
        ["Text"] = selectedText
    };
end

--// Functions

--- Sets the visibility of our masking label based on the provided boolean parameter
function SetTextBoxVisible(isEnabled : boolean)
    isBoxHidden = (not isEnabled);
    ChatBox.Visible = isEnabled
    CursorFrame.Visible = isBoxHidden
end

--- Sets the chatGui background's visibility state to the provided state
function SetChatHidden(setHidden : boolean)
    if (isChatHidden == setHidden) then return; end
    if ((setHidden) and (ChatBox:IsFocused())) then SetChatHidden(false); return; end

    if (setHidden) then
        local MainTween = TweenService:Create(ChatGUI, TweenInfo.new(0.5), {
            BackgroundTransparency = 1
        });

        TweenService:Create(ChatGUI.FrameChatBox, TweenInfo.new(0.5), {
            BackgroundTransparency = 1
        }):Play();

        TweenService:Create(ChatBox, TweenInfo.new(0.5), {
            TextTransparency = 1,
            TextStrokeTransparency = 1
        }):Play();

        TweenService:Create(DisplayLabel, TweenInfo.new(0.5), {
            TextTransparency = 1,
            TextStrokeTransparency = 1
        }):Play();

        MainTween:Play();
        MainTween.Completed:Connect(function(playbackState)
            if (playbackState == Enum.PlaybackState.Completed) then
                isChatHidden = true
            end
        end);
    else
        local MainTween = TweenService:Create(ChatGUI, TweenInfo.new(0.5), {
            BackgroundTransparency = ChatSettings.ChatFrameBackgroundTransparency
        });

        TweenService:Create(ChatGUI.FrameChatBox, TweenInfo.new(0.5), {
            BackgroundTransparency = ChatSettings.ChatBoxBackgroundTransparency
        }):Play();

        TweenService:Create(ChatBox, TweenInfo.new(0.5), {
            TextTransparency = ((((ChatBox.Text:len() > 0) or (isBoxHidden)) and (1)) or (ChatSettings.TextTransparency)),
            TextStrokeTransparency = ((((ChatBox.Text:len() > 0) or (isBoxHidden)) and (1)) or (ChatSettings.TextStrokeTransparency))
        }):Play();

        TweenService:Create(DisplayLabel, TweenInfo.new(0.5), {
            TextTransparency = ChatSettings.TextTransparency,
            TextStrokeTransparency = ChatSettings.TextStrokeTransparency
        }):Play();

        MainTween:Play();
        MainTween.Completed:Connect(function(playbackState)
            if (playbackState == Enum.PlaybackState.Completed) then
                isChatHidden = false
            end
        end);
    end
end

--- Searches for a given player using the provided username string! (not case sensitive)
function QuerySearch(QueryUsername : string)
    for _, Player in pairs(game.Players:GetPlayers()) do
        if (Player.Name:lower() == QueryUsername:lower()) then
            return Player
        end
    end
end

--- Returns a flat color RGB value based on the provided parameters. This is required for rich text because it tends to break with decimals
function GetFlatColor(OriginalColor : number)
    return math.floor(OriginalColor * 255);
end

--- Returns the currently selected TextBox text (if any)
function getSelected() : string | number | number
	if ((ChatBox.CursorPosition == -1) or (ChatBox.SelectionStart == -1)) then return; end
    
    local startPos : number = math.min(ChatBox.CursorPosition, ChatBox.SelectionStart);
    local endPos : number = math.max(ChatBox.CursorPosition, ChatBox.SelectionStart);

    local selectedText : string = string.sub(
        ChatBox.Text,
        startPos,
        endPos - 1
    );

    return selectedText, startPos, endPos
end

--- Picks a random dance emote! (simulates roblox chat behavior)
function pickRandomDanceEmote(RigType : Enum.HumanoidRigType) : string
    local contenders = {
        CustomEmoteList["dance1"][RigType],
        CustomEmoteList["dance2"][RigType],
        CustomEmoteList["dance3"][RigType]
    };

    return contenders[math.random(#contenders)];
end

--- Updates our DisplayLabel position which respects cursorPosition following!
function updateTextPosition()
    local CursorPosition = ChatBox.CursorPosition
    local AbsX = math.floor(ChatBox.Parent.AbsoluteSize.X);
    local Padding = 5

    if (CursorPosition ~= -1) then -- Make sure we have a valid cursor position
        local TotalWidth = TextService:GetTextSize(
            ChatBox.Text,
            ChatBox.TextSize,
            ChatBox.Font,
            Vector2.new(math.huge, math.huge)
        ).X

        local CursorWidth = TextService:GetTextSize(
            ChatBox.Text:sub(1, CursorPosition - 1),
            ChatBox.TextSize,
            ChatBox.Font,
            Vector2.new(math.huge, math.huge)
        ).X

        local WidthOffset = (((FocusPoint + AbsX) + Padding + 2) - CursorWidth);

        local IsOffScreenOnLeft = ((AbsX < WidthOffset));
        local IsOffScreenOnRight = (CursorWidth > FocusPoint + AbsX);
        local IsOffScreen = (IsOffScreenOnLeft or IsOffScreenOnRight);

        local CurrentCursorPos = (ChatBox.Position.X.Offset + CursorWidth);

        --[[

            warn("-------------------------------------------------------------");
            print("OFF:", IsOffScreen);
            print("RIGHT:", IsOffScreenOnRight);
            print("LEFT:", IsOffScreenOnLeft);
            print("WIDTH OFFSET:", WidthOffset);
            print("FOCUS POINT:", FocusPoint);
            print("CURSOR WIDTH:", CursorWidth);

        ]]--
        
        if ((CurrentCursorPos < Padding) and (not IsOffScreen)) then
            DisplayLabel.Position = UDim2.new(0, Padding, 0.5, 0);
            DisplayLabel.Size = UDim2.new(0.98, 0, 0.8, 0);
            
            FocusPoint = 0
        elseif (IsOffScreen) then
            if (IsOffScreenOnLeft) then
                local CursorStart = math.min(CursorPosition, LastSavedCursorPosition);
                local CursorEnd = math.max(CursorPosition, LastSavedCursorPosition);

                local ChangeWidth = TextService:GetTextSize(
                    ChatBox.Text:sub(CursorStart, CursorEnd),
                    ChatBox.TextSize,
                    ChatBox.Font,
                    Vector2.new(math.huge, math.huge)
                ).X

                FocusPoint = math.max(FocusPoint - ChangeWidth,  0)
                DisplayLabel.Position = UDim2.new(0, -CursorWidth + Padding, 0.5, 0);
            elseif (IsOffScreenOnRight) then
                FocusPoint = math.max(CursorWidth - AbsX, 0);

                DisplayLabel.Size = UDim2.new(0, AbsoluteDisplaySize + math.max(TotalWidth - AbsX, 0), 0.8, 0); -- We need to constantly grow our DisplayLabel in order to keep the system functional
                DisplayLabel.Position = UDim2.new(0, AbsX - CursorWidth - Padding - 2, 0.5, 0);
            end
        end
    end
end

return ChatUI