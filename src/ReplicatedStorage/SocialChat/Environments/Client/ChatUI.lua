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
local ChatSettings

local TopbarPlus

--// Constants
local Player = game.Players.LocalPlayer
local ChatEvents

local ChatGUI
local ChatFrame

local ChatBox
local DisplayLabel

local OriginalBoxSize
local RichTextFormat = "<font color =\"rgb(%s, %s, %s)\">%s</font>"

local CustomEmoteList = {};
local EmoteSyntax

local ScalingBounds
local SpacingBounds

--// States
local isClientMuted : boolean
local isMouseOnChat : boolean
local isChatHidden : boolean = false
local isBoxHidden : boolean = true

local canChatHide : boolean
local focusLostAt : number

local currentEmoteTrack : string?

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
    OriginalBoxSize = ChatBox.AbsoluteSize

    --// Selection Frame
    --\\ This section simulates a "selection box" for our DisplayLabel!

    local SelectionFrame = Instance.new("Frame");

    SelectionFrame.BackgroundColor3 = Color3.fromRGB(106, 159, 248);
    SelectionFrame.Name = "SelectionFrame"
    SelectionFrame.BorderSizePixel = 0
    SelectionFrame.Visible = false

    SelectionFrame.ZIndex = 2
    SelectionFrame.Parent = DisplayLabel

    local CursorFrame = Instance.new("Frame");
    
    CursorFrame.Size = UDim2.fromOffset(2, DisplayLabel.AbsoluteSize.Y);
    CursorFrame.Visible = false

    CursorFrame.Name = "CursorFrame"
    CursorFrame.BorderSizePixel = 0
    CursorFrame.Parent = DisplayLabel

    local function updateSelectionBox()
        --[[local selectionInfo = ChatUI:GetSelected();
        
        if (selectionInfo) then
            SelectionFrame.Size = UDim2.fromOffset(selectionInfo.SelectionSize, DisplayLabel.AbsoluteSize.Y + 4);
            SelectionFrame.Position = UDim2.fromOffset(selectionInfo.StartPos, 0);
            SelectionFrame.Visible = true
        else
            SelectionFrame.Visible = false
        end]]
    end

    local function updateCursorPos()
        --[[local currentPos = ChatBox.CursorPosition
        local textBeforeCursorSize : number = TextService:GetTextSize(
            ChatBox.Text:sub(1, currentPos),
            DisplayLabel.TextSize,
            DisplayLabel.Font,
            Vector2.new(math.huge, math.huge)
        );

        CursorFrame.Position = UDim2.fromOffset(textBeforeCursorSize.X, 0);]]
    end

    ChatBox:GetPropertyChangedSignal("SelectionStart"):Connect(updateSelectionBox);
    ChatBox:GetPropertyChangedSignal("CursorPosition"):Connect(function()
        updateSelectionBox();
        updateCursorPos();
    end);

    --// Setup
    local ChatModules = ChatService:GetModules();

    ChatEmotes = ChatModules.Emotes
    ChatSettings = ChatModules.Settings
    EmoteSyntax = ChatSettings.EmoteSyntax

    ScalingBounds = ChatBox.TextBounds

    DisplayLabel.TextSize = ScalingBounds.Y
    ChatBox.TextSize = ScalingBounds.Y

    SpacingBounds = TextService:GetTextSize(
        " ",
        ChatBox.UITextSizeConstraint.MaxTextSize,
        ChatBox.Font,
        OriginalBoxSize
    );

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
        ChatBox:CaptureFocus();
    end);

    ChatBox.FocusLost:Connect(function(enterPressed : boolean)
        CursorFrame.Visible = false
        canChatHide = (not isMouseOnChat);
        focusLostAt = os.clock();

        if (ChatBox.Text:len() == 0) then
            ChatBox.PlaceholderText = "Type '/' to chat"
            SetTextBoxVisible(true);

            return;
        end

        if (not enterPressed) then return; end

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
        elseif (ChatBox.Text:lower() == "/console") then
            game.StarterGui:SetCore("DevConsoleVisible", true);
        else
            ChatEvents.ChatReplicate:FireServer(ChatBox.Text);
        end
        
        ChatBox.PlaceholderText = "Type '/' to chat"
        SetTextBoxVisible(true);
        ChatBox.Text = ""
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

        DisplayLabel.Text = NewMaskingText

        --// Masking layer text handling
        --\\ This is done because our text tends to go off screen if we dont do this. This is more of an instance hacky tactic

        local CurrentBounds = TextService:GetTextSize(
            ChatBox.Text,
            ScalingBounds.Y,
            ChatBox.Font,
            Vector2.new(4000, 4000)
        );

        if ((CurrentBounds.X + SpacingBounds.X) >= ChatBox.AbsoluteSize.X) then
            DisplayLabel.TextXAlignment = Enum.TextXAlignment.Right
            ChatBox.TextXAlignment = Enum.TextXAlignment.Right

            DisplayLabel.TextScaled = false
            DisplayLabel.TextWrapped = false

            ChatBox.TextScaled = false
            ChatBox.TextWrapped = false
        else
            DisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
            ChatBox.TextXAlignment = Enum.TextXAlignment.Left

            DisplayLabel.TextScaled = true
            DisplayLabel.TextWrapped = true

            ChatBox.TextScaled = true
            ChatBox.TextWrapped = true
        end

    end);

    --// Visibility
    ChatBox.Focused:Connect(function()
        canChatHide = false
        CursorFrame.Visible = true
        ChatBox.PlaceholderText = ""

        SetTextBoxVisible(false);
        SetChatHidden(false);
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

    ChatBox:CaptureFocus();
    SetTextBoxVisible(false);
end

--- Returns Selection data based on our ChatBox's behavior
function ChatUI:GetSelected()
    if ((ChatBox.CursorPosition == -1) or (ChatBox.SelectionStart == -1)) then return; end
    
    local selectionStart : number = math.min(ChatBox.CursorPosition, ChatBox.SelectionStart);
    local selectionEnd : number = math.max(ChatBox.CursorPosition, ChatBox.SelectionStart);

    print(selectionStart, selectionEnd)

    local priorText : string = ChatBox.Text:sub(1, selectionStart - 1);
    local afterText : string = ChatBox.Text:sub(selectionEnd + 1);

    local priorTextSize : number = TextService:GetTextSize(
        priorText,
        DisplayLabel.TextSize,
        DisplayLabel.Font,
        Vector2.new(math.huge, math.huge)
    );

    local afterTextSize = TextService:GetTextSize(
        afterText,
        DisplayLabel.TextSize,
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
        ["StartPos"] = priorTextSize.X % ChatBox.AbsoluteSize.X,
        ["EndPos"] = (ChatBox.TextBounds.X - afterTextSize.X) % ChatBox.AbsoluteSize.X,

        ["SelectionSize"] = absSelectionSize,
        ["Text"] = selectedText
    };
end

--// Functions

--- Sets the visibility of our masking label based on the provided boolean parameter
function SetTextBoxVisible(isEnabled : boolean)
    isBoxHidden = (not isEnabled);

    if (isEnabled) then
        ChatBox.TextTransparency = ChatSettings.TextTransparency
        ChatBox.TextStrokeTransparency = ChatSettings.TextStrokeTransparency
    else
        ChatBox.TextTransparency = .5
        ChatBox.TextStrokeTransparency = 1
    end
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

function pickRandomDanceEmote(RigType : Enum.HumanoidRigType) : string
    local contenders = {
        CustomEmoteList["dance1"][RigType],
        CustomEmoteList["dance2"][RigType],
        CustomEmoteList["dance3"][RigType]
    };

    return contenders[math.random(#contenders)];
end

return ChatUI