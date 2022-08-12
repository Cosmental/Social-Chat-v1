--[[

    Name: Cos
    Date: 7/31/2022

    Description: Handles the in game ChatUI! (Rendering is handled by ChatService)

]]--

--// Module
local ChatUIMaster = {};
ChatUIMaster.__index = ChatUIMaster

--// Services
local UserInputService = game:GetService("UserInputService");
local TweenService = game:GetService("TweenService");
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
local EmoteSyntax

--// States
local isClientMuted : boolean
local isMouseOnChat : boolean
local isChatHidden : boolean
local isBoxHidden : boolean = true
local canChatHide : boolean
local focusLostAt : number

--// Initialization
function ChatUIMaster:Init(ChatController : table, ChatUtilities : table, ChatRemotes : Instance)
    local self = setmetatable({}, ChatUIMaster);
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

    --// Setup
    local ChatModules = ChatService:GetModules();

    ChatEmotes = ChatModules.Emotes
    ChatSettings = ChatModules.Settings
    EmoteSyntax = ChatSettings.EmoteSyntax

    if (not Chat:CanUserChatAsync(Player.UserId)) then -- We need to respect client boundries (if any)
        ChatGUI.Visible = false
        return;
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

        if ((ChatSettings.AllowBubbleHiding) and ((not didUserRequestHidenBubble) or (not messageHasMoreThanOneWord))) then
            ChatService:CreateBubbleMessage(speaker.Character, message, tagInfo);
        end
    end);

    ChatEvents.ChatMute.OnClientEvent:Connect(function(isMuted : boolean)
        isClientMuted = isMuted
        SetBoxDisplay(true);

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
        
        ChatBox.PlaceholderText = ""
        SetBoxDisplay(false);
    end);

    ChatBox.FocusLost:Connect(function(enterPressed : boolean)
        canChatHide = (not isMouseOnChat);
        focusLostAt = os.clock();

        if (ChatBox.Text:len() == 0) then
            ChatBox.PlaceholderText = "Type '/' to chat"
            DisplayLabel.Text = ""

            SetBoxDisplay(true);
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
        else
            ChatEvents.ChatReplicate:FireServer(ChatBox.Text);
        end
        
        ChatBox.PlaceholderText = "Type '/' to chat"
        SetBoxDisplay(true);

        DisplayLabel.Text = ""
        ChatBox.Text = ""
    end);

    --// Box Handling
    ChatBox:GetPropertyChangedSignal("Text"):Connect(function()

        --// Highlights
        --\\ If the highlight option in our settings is set to TRUE, then we can highlight certain keywords and phrases in our masking label!

        local NewMaskingText = ""

        for _, Word in pairs(ChatBox.Text:split(" ")) do
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

            NewMaskingText = ((NewMaskingText)..(" ")); -- We need to add spacing between words!
        end

        DisplayLabel.Text = NewMaskingText

        --// Masking layer text handling
        --\\ This is done because our text tends to go off screen if we dont do this. This is more of an instance hacky tactic

        local CurrentBounds = ChatBox.TextBounds

        if (CurrentBounds.X >= OriginalBoxSize.X) then
            DisplayLabel.TextXAlignment = Enum.TextXAlignment.Right
        else
            DisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
        end

    end);

    --// Visibility
    ChatBox.Focused:Connect(function()
        canChatHide = false
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
function ChatUIMaster:Enable()
    ChatFrame.Visible = true
end

--- Enables the ChatFrame GUI
function ChatUIMaster:Disable()
    ChatFrame.Visible = false
end

--- Sets the current chat text to the provided string
function ChatUIMaster:SetText(desiredText : string)
    ChatBox.PlaceholderText = ""
    ChatBox.Text = desiredText

    ChatBox:CaptureFocus();
    SetBoxDisplay(false);
end

--// Functions

--- Sets the visibility of our masking label based on the provided boolean parameter
function SetBoxDisplay(isEnabled : boolean)
    isBoxHidden = (not isEnabled);

    if (isEnabled) then
        ChatBox.TextTransparency = ChatSettings.TextTransparency
        ChatBox.TextStrokeTransparency = ChatSettings.TextStrokeTransparency
    else
        ChatBox.TextTransparency = 1
        ChatBox.TextStrokeTransparency = 1
    end
end

--- Sets the chatGui background's visibility state to the provided state
function SetChatHidden(setHidden : boolean)
    if (isChatHidden == setHidden) then return; end

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

return ChatUIMaster