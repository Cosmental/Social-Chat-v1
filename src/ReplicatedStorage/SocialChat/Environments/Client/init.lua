--[[

    Name: Cos
    Date: 7/27/2022

    Description: This is the client sided version of the in game Chat system! This service ONLY handles visuals and some inputs; everything else
    is done by the ChatUI script inside of the VanillaUI module.

    --------------------------------------------------------------------------------------------------------------------------------------

    ## [DOCUMENTATION] ##

    SocialChatClient

        Functions:

                :CreateChatMessage()        ||  Parameters -> (speaker : string | Player, message : string, metadata : table? <opt.>, toPrivateRecipient : Player? <opt.>)
                                            ||  Returns -> nil
                                            ||
                ↳                           ||  Description: Creates a new system message using the provided parameters!
                                            ||
                ↳                           ||  NOTE: Metadata is only used to control message colors. This method is intended for the ChatUI
                                            ||        module, but this can be manipulated to create custom system messages as well.

                ---------------------------------------------------------------------------------------------------------------------------

                :CreateBubbleMessage()      ||  Parameters -> (Agent : Model, message : string, metadata : table?)
                                            ||  Returns -> nil
                                            ||
                ↳                           ||  Description: Creates a new BubbleChat message using the provided parameters.
                                            ||
                ↳                           ||  NOTE: This method will only work if the "IsBubbleChatEnabled" setting is enabled in the
                                            ||        ChatSystemConfigurations module!
                                            ||
                ↳                           ||  ⚠⚠ DEPRECIATION: ⚠⚠
                                            ||
                                            ||      In the forseeable future, I plan to add a BubbleChat controller in order to
                                            ||      allow NPCs to use SocialChat's bubble chat as well.

                ---------------------------------------------------------------------------------------------------------------------------

                :MuteClient()               ||  Parameters -> ()
                                            ||  Returns -> nil
                                            ||
                ↳                           ||  Description: Disables our own client's ChatBox.
                                            ||
                ↳                           ||  NOTE: This method is NOT replicated across clients. Our client can still chat by firing
                                            ||        the chat system's remoteEvent maliciously!
                                            ||
                                            ||        If you'd like to mute the client securely, consider SocialChatServer's
                                            ||        ":MuteClient()" method!

                ---------------------------------------------------------------------------------------------------------------------------

                :UnmuteClient()             ||  Parameters -> ()
                                            ||  Returns -> nil
                                            ||
                ↳                           ||  Description: Re-enables our own client's ChatBox.
                                            ||
                ↳                           ||  NOTE: This method is NOT replicated to the server. Using this method will NOT allow the
                                            ||        client to chat again if they are currently muted by the server!

                ---------------------------------------------------------------------------------------------------------------------------

                :RenderText()               ||  Parameters -> (text : string, container : Instance, metadata : table? <opt.>, parameters : table? <opt.>, additionalXSpace : number? <opt.>)
                                            ||  Returns -> {
                                            ||                 ["Objects"] : table, --> This is a table of all the individual word/emote objects! (contains Instances of class: Frame, ImageButton, TextLabel, & TextButton)
                                            ||                 ["Garbage"] = {
                                            ||                     ["Effects"] : table, --> This contains all of our rendered text effects! (intended for garbage collection)
                                            ||                     ["Emotes"] : table --> This contains all of our rendered GIF emoji SpriteClips! (intended for garbage collection)
                                            ||                 };
                                            ||
                                            ||                 ["isMultiLined"] : boolean, --> If true, the text provided requires more than one line of spacing to be fully rendered
                                            ||                 ["Scale"] = {
                                            ||                     ["X"] : number, --> The X space required to render the provided text ## < UDim2.fromOffset >
                                            ||                     ["Y"] : number --> The Y space required to render the provided text ## < UDim2.fromOffset >
                                            ||                 };
                                            ||             };
                                            ||
                ↳                           ||  Description: This method renders the provided text string in its own Frame by resizing itself
                                            ||               using the provided parameters!

                ---------------------------------------------------------------------------------------------------------------------------

                :GetModules()               ||  Parameters -> ()
                                            ||  Returns -> {...ChatSystemModules...}
                                            ||
                ↳                           ||  Description: This method returns all of our Service modules! This is mainly intended for
                                            ||               external API work.


        ## ---------------------------------------------------------------------------------------------------------------------------  ##
        ## ---------------------------------------------------------------------------------------------------------------------------  ##
        ## ---------------------------------------------------------------------------------------------------------------------------  ##

        Events:

                .PlayerChatted:Connect()    ||  Response Info -> (playerWhoChatted : Player, messageSent : string, chatMetaData : table)
                ↳                           ||  Description: Fires when a player sends a new chat message through SocialChat
                                            ||
                ↳                           ||  NOTE: The "messageSent" parameter IS filtered!

]]--

--// Services
local TweenService = game:GetService("TweenService");
local RunService = game:GetService("RunService");

--// Imports
local ChatUI = require(script.ChatUI);

local ChatSystemTags = require(script.Modules.ChatSystemTags);
local ChatSystemEmotes = require(script.Modules.ChatSystemEmotes);
local ChatSystemCommons = require(script.Modules.ChatSystemCommons);
local ChatSystemConfigurations = require(script.Modules.ChatSystemConfigurations);

--// Constants
local Player = game.Players.LocalPlayer
local Camera = workspace.CurrentCamera
local _chatEv = Instance.new("BindableEvent");

local ChatGUI
local ChatFrame
local ChatBox

local EmoteBubblePrefab = script.Presets.FrameEmoteHover
local EmoteSyntax = ChatSystemConfigurations.EmoteSyntax

local BubbleContainerPrefab = script.Presets.BubbleContainer
local BubbleMessagePrefab = script.Presets.FrameBubbleMessage
local MultiLinePrefab = script.Presets.FrameBubbleMultiLine

local SpaceLength
local AbsoluteFontSize
local AbsoluteEmoteSize

local MalformedParamsError = [[
SocialChat Parameter Violation: Your parameters were malformed!
                                    Expected format:
                                    {
                                        ["emotesEnabled"] = boolean, -- opt. (def: true)
                                        ["effectsEnabled"] = boolean, -- opt. (def: true)
                                        
                                        ["chatMeta"] = { -- opt. (def: ChatSystemConfigurations)
                                            ["Font"] = Enum.Font,
                                            ["FontSize"] = number,
                                        }
                                    };
]];

--// States
local BubbleContainerLog = {};
local ChatLog = {};

--// Module
local SocialChat = {};
SocialChat.PlayerChatted = _chatEv.Event

--// Initialization
function SocialChat:Init(ChatUtilities : table, Remotes : Instance)
    ChatGUI = Player.PlayerGui.Chat.FrameChat
    ChatFrame = ChatGUI.FrameChatList
    ChatBox = ChatGUI.FrameChatBox.InputBoxChat

    ChatSystemEmotes = ChatSystemEmotes(ChatUtilities);
    ChatUI:Init(SocialChat, ChatUtilities, Remotes);
    ChatSystemCommons:Init();

    SpaceLength = ChatSystemCommons.SpaceLength
    AbsoluteFontSize = (
        ((ChatSystemConfigurations.FontSize == "Default") and (ChatBox.TextBounds.Y + 2))
            or (ChatSystemConfigurations.FontSize)
    );

    AbsoluteEmoteSize = (
        ((ChatSystemConfigurations.ChatEmoteSize == "Default") and (AbsoluteFontSize + 2))
            or (ChatSystemConfigurations.ChatEmoteSize)
    );

    --// Chat Canvas Handling
	local Layout = ChatFrame:FindFirstChildWhichIsA("UIGridStyleLayout");
    assert(Layout, "\"ChatFrame\" is missing an instance of classType \"UIGridStyleLayout\"! (this is required to resize our ScrolingFrame properly)");

	local LastSize
	
	local function GetCanvasSize()
		local yCanvasSize = ChatFrame.CanvasSize.Y.Offset
		local yAbsoluteSize = ChatFrame.AbsoluteSize.Y
		
		return (yCanvasSize - yAbsoluteSize);
	end
	
	local function IsScrolledDown()
		local yScrolledPosition = ChatFrame.CanvasPosition.Y
		local AbsoluteCanvas = GetCanvasSize();
		
		--// Comparing
		local AbsoluteScroll = tonumber(string.format("%0.3f", yScrolledPosition));		
		local WasScrolledDown = (LastSize and (AbsoluteScroll + 2 >= tonumber(string.format("%0.3f", LastSize))));
		
		LastSize = AbsoluteCanvas
		return WasScrolledDown
	end
	
	local function UpdateCanvas()
		local AbsoluteContentSize = Layout.AbsoluteContentSize
		ChatFrame.CanvasSize = UDim2.new(0, 0, 0, AbsoluteContentSize.Y + 5);
		
		--// Solve for scrolling
		local CurrentCanvasSize = GetCanvasSize();
		local SizeOffset = ((LastSize and CurrentCanvasSize - LastSize) or 0);
		
		local WasAtBottom = IsScrolledDown();
		
		if (not WasAtBottom) then
			ChatFrame.CanvasPosition = Vector2.new(
				0, (ChatFrame.CanvasPosition.Y - SizeOffset));
		else
			ChatFrame.CanvasPosition = Vector2.new(0, 9e9);
		end
	end
	
	Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas);
	ChatFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateCanvas);

    --// Crediting
    --\\ Read the "ChatSystemConfigurations" module for more information on this section!

    if ((ChatSystemConfigurations.CreditOutputEnabled) and (not RunService:IsStudio())) then
        warn([[

                    ------------------------------------------------------------------------------------------------------------
                    ------------------------------------------------------------------------------------------------------------

                    This game uses Cosmental's SocialChat module!
                    
                    Do you want your games to have a similar Chat System? Grab your copy here!									
                    >> [https://github.com/Cosmental/Social-Chat] <<
                    
                    ## Additional Credits ##
                    
                    - @nooneisback for their SpriteClip module (gif player)
                    - @ForeverHD and the Nanoblock team for their TopbarPlus API!
                    
                    ------------------------------------------------------------------------------------------------------------
                    ------------------------------------------------------------------------------------------------------------

        ]])
    end

    --// Server Signalling
    --\\ We need to tell our server that our client is preloaded in order for our chat system to work!

    Remotes.ClientReady:FireServer();
end

--// Chat Methods

--- Submits a chat message into our chat GUI using the provided parameters
function SocialChat:CreateChatMessage(speaker : string | Player, message : string, metadata : table?, toPrivateRecipient : Player?)
    assert((not speaker) or ((type(speaker) == "string") or (typeof(speaker) == "Instance")), "SocialChat Client Message Error: The provided speaker violates its own typedata. (expected \"string\" or \"Instance\", got "..(typeof(speaker)).."");
    assert(type(message) == "string", "SocialChat Client Message Error: Messages can currently only be formatted as type: \"string\", got "..(type(message)));
    assert((not metadata) or (type(metadata) == "table"), "SocialChat Client Message Error: The provided metadata was not of valid type: \"table\"! (got "..(type(metadata))..")");
    assert((not toPrivateRecipient) or ((typeof(toPrivateRecipient) == "Instance") and (toPrivateRecipient:IsA("Player"))), "SocialChat Client Message Error: The provided private message recipient was not of classtype \"Player\", got "..(typeof(toPrivateRecipient)));

    --// Data Setup
    local TagText = (
        ((toPrivateRecipient) and (
            ((toPrivateRecipient == Player) and ("{From \""..(speaker.Name).."\"} "))
            or ("{To \""..(toPrivateRecipient.Name).."\"} ")
        ))
            or (((metadata) and ((metadata.TagName) and (metadata.TagName:len() > 0)))
                and ("["..(metadata.TagName).."] "))
                or ""
	);

	local UserText = (
		(speaker and "["..(tostring(speaker)).."]: ")
			or ""
	);

    local SpeakerUsernameLength = ChatSystemCommons:GetTextSize(UserText, ChatFrame);
    local SpeakerTagLength = ChatSystemCommons:GetTextSize(TagText, ChatFrame);

    local RenderResult = SocialChat:RenderText(message, ChatFrame, metadata, nil, (SpeakerUsernameLength.X + SpeakerTagLength.X));
    
    --// Tag Label Solving
    local SpeakerTagLabel = ChatSystemCommons:CreateLabel(SpeakerTagLength);

    SpeakerTagLabel.Name = "TagLabel"
    SpeakerTagLabel.Text = TagText

    if ((metadata) and ((metadata.TagColor) and (not toPrivateRecipient))) then
        local LabelEffect = ChatSystemCommons:ApplyLabelColor({SpeakerTagLabel}, metadata.TagColor);

        if (LabelEffect) then
            table.insert(RenderResult.Garbage.Effects, {
                ["EffectName"] = metadata.TagColor,
                ["Effect"] = LabelEffect
            });
        end
    elseif (toPrivateRecipient) then
        SpeakerTagLabel.RichText = true
        SpeakerTagLabel.Text = "<i>"..(TagText).."</i>"
    end

    --// Username Label Solving
    local SpeakerUsernameLabel = ChatSystemCommons:CreateButton(SpeakerUsernameLength);

    SpeakerUsernameLabel.Position = UDim2.fromOffset(SpeakerTagLength.X, 0);
    SpeakerUsernameLabel.Name = "UsernameLabel"
    SpeakerUsernameLabel.Text = UserText

    if ((metadata) and (metadata.SpeakerColor)) then
        local LabelEffect = ChatSystemCommons:ApplyLabelColor({SpeakerUsernameLabel}, metadata.SpeakerColor);

        if (LabelEffect) then
            table.insert(RenderResult.Garbage.Effects, {
                ["EffectName"] = metadata.SpeakerColor,
                ["Effect"] = LabelEffect
            });
        end
    end

    --// Whisper shortcut
    if (type(speaker) ~= "string") then
        SpeakerUsernameLabel.MouseButton1Click:Connect(function()
            if (speaker == Player) then return; end -- you cant whisper to yourself silly! xD
            ChatUI:SetText("/w "..(speaker.Name).." ");
        end);
    end

    --// Container Frame Handling
    local ClientMessageFrame = ChatSystemCommons:CreateFrame(Vector2.new(ChatFrame.AbsoluteSize.X, RenderResult.Scale.Y));
    ClientMessageFrame.Name = ("ClientMessage_"..(tostring(speaker)));

    if (ChatSystemConfigurations.IsTweeningAllowed) then
        local TweenFrame = ChatSystemCommons:CreateFrame(Vector2.new(0, 0));
        TweenFrame.Position = UDim2.fromOffset(-25, 10);
        TweenFrame.Size = UDim2.fromScale(1, 1);
        TweenFrame.Name = "MessageTweenFrame"

        local TextObjectProperties = {
            TextTransparency = ChatSystemConfigurations.TextTransparency,
            TextStrokeTransparency = ChatSystemConfigurations.TextStrokeTransparency
        };

        for _, ChatObject in pairs(RenderResult.Objects) do
            if (not next(ChatObject:GetChildren())) then
                ChatObject.Parent = TweenFrame
                continue;
            end

            for _, ChatSubObject in pairs(ChatObject:GetChildren()) do
                if ((not ChatSubObject:IsA("TextLabel")) and (not ChatSubObject:IsA("TextButton")) and (not ChatSubObject:IsA("ImageButton"))) then continue; end
    
                if (ChatSubObject:IsA("ImageButton")) then
                    ChatSubObject.ImageTransparency = 1

                    TweenService:Create(ChatSubObject, ChatSystemConfigurations.TweenInfo, {
                        ImageTransparency = 0
                    }):Play();
                else
                    ChatSubObject.TextTransparency = 1
                    ChatSubObject.TextStrokeTransparency = 1
        
                    TweenService:Create(ChatSubObject, ChatSystemConfigurations.TweenInfo, TextObjectProperties):Play();
                end
            end

            ChatObject.Parent = TweenFrame
        end

        SpeakerTagLabel.TextTransparency = 1
        SpeakerTagLabel.TextStrokeTransparency = 1
        SpeakerTagLabel.Parent = TweenFrame
        TweenService:Create(SpeakerTagLabel, ChatSystemConfigurations.TweenInfo, TextObjectProperties):Play();

        SpeakerUsernameLabel.TextTransparency = 1
        SpeakerUsernameLabel.TextStrokeTransparency = 1
        SpeakerUsernameLabel.Parent = TweenFrame
        TweenService:Create(SpeakerUsernameLabel, ChatSystemConfigurations.TweenInfo, TextObjectProperties):Play();

        TweenFrame.Parent = ClientMessageFrame
        TweenService:Create(TweenFrame, ChatSystemConfigurations.TweenInfo, {
            Position = UDim2.fromOffset(0, 0)
        }):Play();
    else
        for _, WordObject in pairs(RenderResult.Objects) do
            WordObject.Parent = ClientMessageFrame
        end

        SpeakerTagLabel.Parent = ClientMessageFrame
        SpeakerUsernameLabel.Parent = ClientMessageFrame
    end

    table.insert(ChatLog, {
        ["MessageFrame"] = ClientMessageFrame,
        ["GarbageCollection"] = {
            ["EmoteCollection"] = RenderResult.Garbage.Emotes,
            ["LabelCollection"] = RenderResult.Garbage.Effects
        };
    });

    ClientMessageFrame.Parent = ChatFrame

    --// Message Cleanup
    if (table.getn(ChatLog) > ChatSystemConfigurations.MaxMessagesAllowed) then
        local OldestMessage = ChatLog[1];
        table.remove(ChatLog, 1);

        --// Emote cleanup
        for _, CollectedGarbage in pairs(OldestMessage.GarbageCollection.EmoteCollection) do
            ChatSystemEmotes[CollectedGarbage.Emote].OnEmoteSweeped(CollectedGarbage.EmoteObject, CollectedGarbage.SpriteClip);
        end

        --// Label effect cleanup
        for _, CollectedGarbage in pairs(OldestMessage.GarbageCollection.LabelCollection) do
            ChatSystemTags[CollectedGarbage.EffectName].OnRemoved(CollectedGarbage.Effect);
        end

        OldestMessage.MessageFrame:Destroy();
    end

    --// API Signaling
    if ((typeof(speaker) == "Instance") and (speaker:IsA("Player"))) then
        _chatEv:Fire(speaker, message, {
            ["metadata"] = metadata,
            ["isWhisperMessage"] = (toPrivateRecipient ~= nil)
        });
    end
end

--- Creates a new chat bubble for X player upon chatting
function SocialChat:CreateBubbleMessage(Agent : Model, message : string, metadata : table?)
    assert((typeof(Agent) == "Instance") and (Agent:IsA("Model")), "SocialChat Bubble Chat Error: The provided Agent parameter was not of classType \"Model\". (got "..(typeof(Agent)).."");
    assert(type(message) == "string", "SocialChat Bubble Chat Error: Messages can currently only be formatted as type: \"string\", got "..(type(message)));
    assert((not metadata) or (type(metadata) == "table"), "SocialChat Bubble Chat Error: The provided metadata was not of valid type: \"table\"! (got "..(type(metadata))..")");

    if (not ChatSystemConfigurations.IsBubbleChatEnabled) then return; end

    local AgentHead = Agent:FindFirstChild("Head");
    if (not AgentHead) then return; end

    local BubbleContainer = ((AgentHead:FindFirstChild(BubbleContainerPrefab.Name)) or (SetupBubbleChat(Agent)));

    local MessageContainer = BubbleMessagePrefab:Clone();
    local LineSpaceX = (BubbleContainer.Size.X.Offset - 10); -- We need to subtract 10 from our AbsX size for aesthetic purposes

    local BubbleTextColor = ((metadata.BubbleTextColor) or (ChatSystemConfigurations.BubbleTextColor));
    local BubbleTextStrokeColor = ((metadata.BubbleTextStrokeColor) or (ChatSystemConfigurations.BubbleTextStrokeColor));

    local BubbleSizeParameters = {
        ["Font"] = ChatSystemConfigurations.BubbleFont,
        ["FontSize"] = ChatSystemConfigurations.BubbleTextSize
    };

    local RenderResult = SocialChat:RenderText(message, BubbleContainer, metadata, {
        ["effectsEnabled"] = ChatSystemConfigurations.DoesChatBubbleRenderEffects,
        ["chatMeta"] = BubbleSizeParameters,

        ["isBubbleChat"] = true -- THIS IS REQUIRED FOR INTENDED BEHAVIOR CHANGES! (DO NOT EDIT)
    }); 

    local wereSpecialEffectsRendered : boolean = next(RenderResult.Garbage.Effects);

    --// Individual word rendering
    local AbsoluteBubblePosX = 0
    local VisibleGraphemes = {};

    local SpaceSize = ChatSystemCommons:GetTextSize(" ", BubbleContainer.FrameBackground, nil, BubbleSizeParameters);
    local CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);

    for Index, RenderObject in pairs(RenderResult.Objects) do
        if (RenderObject:IsA("ImageButton")) then -- This word is an emote!
            if ((AbsoluteBubblePosX + ChatSystemConfigurations.BubbleEmoteSize) > LineSpaceX) then
                AbsoluteBubblePosX = 0

                CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);
            end

            AbsoluteBubblePosX += ChatSystemConfigurations.BubbleEmoteSize
            RenderObject.Parent = CurrentLine

            table.insert(VisibleGraphemes, RenderObject);
        else -- This is an individual label (probably...)
            if (next(RenderObject:GetChildren())) then
                for _, subRenderChild in pairs(RenderObject:GetChildren()) do
                    if ((AbsoluteBubblePosX + subRenderChild.AbsoluteSize.X) > LineSpaceX) then
                        AbsoluteBubblePosX = 0

                        CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);
                    end

                    if (subRenderChild:IsA("TextLabel")) then
                        subRenderChild.TextSize = BubbleSizeParameters.FontSize
                    end
        
                    AbsoluteBubblePosX += subRenderChild.AbsoluteSize.X
                    subRenderChild.Parent = CurrentLine

                    if (not wereSpecialEffectsRendered) then
                        subRenderChild.TextColor3 = BubbleTextColor
                        subRenderChild.TextStrokeColor3 = BubbleTextStrokeColor
                    end

                    table.insert(VisibleGraphemes, subRenderChild);
                end

                RenderObject:Destroy();
            else
                if ((AbsoluteBubblePosX + RenderObject.AbsoluteSize.X) > LineSpaceX) then
                    AbsoluteBubblePosX = 0
                    CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);
                end

                if (not wereSpecialEffectsRendered) then
                    RenderObject.TextColor3 = BubbleTextColor
                    RenderObject.TextStrokeColor3 = BubbleTextStrokeColor
                end
    
                AbsoluteBubblePosX += RenderObject.AbsoluteSize.X
                RenderObject.Parent = CurrentLine

                table.insert(VisibleGraphemes, RenderObject);
            end
        end

        if (Index == #message:split(" ")) then continue; end -- We dont want to add extra spacing at the end of our message LOL
        local SpaceLabel = ChatSystemCommons:CreateLabel(SpaceSize, ChatSystemConfigurations.BubbleFont);

        SpaceLabel.Name = "SPACELABEL_VISUAL"
        SpaceLabel.Text = ""

        SpaceLabel.Parent = CurrentLine
        AbsoluteBubblePosX += SpaceSize.X
    end

    --// Container rendering
    MessageContainer.Size = UDim2.fromOffset(
        (((RenderResult.isMultiLined) and (BubbleContainer.Size.X.Offset)) or (RenderResult.Scale.X + ChatSystemConfigurations.BubbleSizeOffset)),
        (((RenderResult.isMultiLined) and (RenderResult.Scale.Y + SpaceLength.Y)) or (SpaceSize.Y)) + ChatSystemConfigurations.BubbleSizeOffset
    ); -- Due to how Billboard GUIs behave, we need to add additional "Y" Length due to the API being intended for 2 dimensional GUI frames

    local ContainerBackground = MessageContainer.BackgroundBubble
    local ContainerCarrot = MessageContainer.Carrot

    ContainerBackground.BackgroundColor3 = ChatSystemConfigurations.BubbleColor
    ContainerCarrot.ImageColor3 = ChatSystemConfigurations.BubbleColor

    ContainerBackground.BackgroundTransparency = ChatSystemConfigurations.BubbleBackgroundTransparency
    ContainerCarrot.ImageTransparency = ChatSystemConfigurations.BubbleBackgroundTransparency

    MessageContainer.Name = ("ClientBubbleMessage_"..(Agent.Name));
    MessageContainer.Parent = BubbleContainer.FrameBackground

    if ((metadata) and (metadata.BubbleBackgroundColor)) then
        MessageContainer.BackgroundBubble.BackgroundColor3 = metadata.BubbleBackgroundColor
        MessageContainer.Carrot.ImageColor3 = metadata.BubbleBackgroundColor
    end

    --// Log management
    local AgentBubbleLogs = BubbleContainerLog[Agent];
    local BubblePosition = (table.getn(AgentBubbleLogs) + 1);

    table.insert(AgentBubbleLogs, {
        ["MessageFrame"] = MessageContainer,
        ["ObjectList"] = VisibleGraphemes,

        ["RealSize"] = MessageContainer.AbsoluteSize,
        ["IsRendered"] = true,

        ["GarbageCollection"] = {
            ["EmoteCollection"] = RenderResult.Garbage.Emotes,
            ["LabelCollection"] = RenderResult.Garbage.Effects
        };
    });

    --// Previous carrot hiding
    if (AgentBubbleLogs[BubblePosition - 1]) then
        local PreviousMessage = AgentBubbleLogs[BubblePosition - 1];
        PreviousMessage.MessageFrame.Carrot.Visible = false
    end

    ShowBubble(MessageContainer, VisibleGraphemes);

    --// Lifespan handling
    coroutine.wrap(function()
        task.wait(ChatSystemConfigurations.BubbleLifespan);

        local BubbleObjectIndex

        for Index, Message in pairs(BubbleContainerLog[Agent]) do
            if (Message.MessageFrame == MessageContainer) then
                BubbleObjectIndex = Index
            end
        end

        if (not BubbleObjectIndex) then return; end -- We dont need to destroy our bubble TWICE!
        local BubbleObject = AgentBubbleLogs[BubbleObjectIndex];
        table.remove(AgentBubbleLogs, BubbleObjectIndex);

        HideBubble(MessageContainer, VisibleGraphemes);
        DestroyBubble(BubbleObject);
    end)();

    --// Bubble Limitation logging
    if (table.getn(AgentBubbleLogs) > ChatSystemConfigurations.BubbleRenderLimitPerCharacter) then
        local OldestBubble = AgentBubbleLogs[1];
        table.remove(AgentBubbleLogs, 1);
        
        coroutine.wrap(function()
            HideBubble(OldestBubble.MessageFrame, OldestBubble.ObjectList);
            DestroyBubble(OldestBubble);
        end)();
    end
end

--- Mutes our current client (⚠️**NOT REPLICATED**⚠️)
function SocialChat:MuteClient()
    TweenService:Create(ChatBox, ChatSystemConfigurations.TweenInfo, {
        PlaceholderColor3 = Color3.fromRGB(240, 80, 70);
    }):Play();

    
    ChatBox.PlaceholderText = "You are currently muted"
    ChatBox.TextEditable = false
    ChatBox:ReleaseFocus();
    ChatBox.Text = ""
end

--- Unmutes our client (⚠️**NOT REPLICATED**⚠️)
function SocialChat:UnmuteClient()
    TweenService:Create(ChatBox, ChatSystemConfigurations.TweenInfo, {
        PlaceholderColor3 = Color3.fromRGB(141, 141, 141);
    }):Play();

    ChatBox.PlaceholderText = "Type '/' to chat"
    ChatBox.TextEditable = true
end

--// Additional Methods \\--

--- Renders the provided text on a Frame using the provided parameter table
function SocialChat:RenderText(text : string, container : Instance, metadata : table?, parameters : table?, additionalXSpace : number?) : table
    assert(type(text) == "string", "SocialChat Rendering Error: Messages can currently only be formatted as type: \"string\", got "..(type(text)));
    assert((typeof(container) == "Instance") and ((container:IsA("GuiObject") or container:IsA("BillboardGui"))), "The provided \"container\" parameter was not an Instance of class \"GuiObject\". This parameter is required for proper scaling!");
    assert((not metadata) or (type(metadata) == "table"), "SocialChat Rendering Error: The provided metadata was not of valid type: \"table\"! (got "..(type(metadata))..")");
    assert((not parameters) or (verifyParameters(parameters)), MalformedParamsError);
    assert((not additionalXSpace) or (type(additionalXSpace) == "number"), "SocialChat Rendering Error: The provided \"additionalXSpace\" parameter was not of type \"number\", got "..(type(additionalXSpace)));

    --[[

        Metadata helps define how our rendered text will look like!

            >> Metadata Structure:

            {

                --// TAG DATA \\--

                ["TagName"] = "DISPLAYED_CHAT_NAME_HERE",
                ["TagColor"] = Color3.fromRGB(255, 255, 255),
                ["SpeakerColor"] = Color3.fromRGB(255, 0, 0),
                ["MessageColor"] = Color3.fromRGB(0, 215, 255),

                --// BUBBLE CHAT \\--

                ["BubbleTextColor"] = Color3.fromRGB(255, 0, 0),
                ["BubbleBackgroundColor"] = Color3.fromRGB(255, 255, 255),

            };

        ---------------------------------------------------------------------------------------------------------------

        Parameters are used to change the way chat rendering works!

            >> Parameters Structure:

            {
                
                --// CONFIGURATIONS \\--

                ["emotesEnabled"] = boolean?, -- determines if emotes will be rendered within this message
                ["effectsEnabled"] = boolean?, -- determines if special tag effects will render within this message (eg. rainbow tags etc.)

                --// EXTRA METADATA \\--

                ["chatMeta"] = { -- holds information related to our chat message that will be defaulted into based on rendering params

                    ["Font"] = Enum.Font, -- TextFont applicable (applies to all rendering)
                    ["FontSize"] = number, -- TextSize applicable (applies to all rendering)
                
                };

            };

    ]]--

    local EmoteCollection = {};
    local RenderedObjects = {};

    local EmotesEnabled = (((parameters) and (parameters.emotesEnabled)) or (true));
    local EffectRenderingEnabled = (((parameters) and (parameters.effectsEnabled)) or (true));
    local IsBubbleChat = ((parameters) and (parameters.isBubbleChat));

    local TotalScaleX = ((additionalXSpace) or (0));
    local TotalScaleY = 0

    for _, Word in pairs(text:split(" ")) do
        local isEmote = ((Word:sub(1, 1) == EmoteSyntax) and (Word:sub(#Word, #Word) == EmoteSyntax));
        local emoteName = (Word:sub(2, #Word - 1));

        if (ChatSystemConfigurations.DebugOutputEnabled) then
            print("\n\nSOCIALCHAT DEBUG: RENDERING WORD \""..(Word).."\".\n\t\t\t\t\t\t\t\t\tTextScaleX:", TotalScaleX, "\n\t\t\t\t\t\t\t\t\tTextScaleY:", TotalScaleY, "\n\n");
        end

        if ((isEmote) and (ChatSystemEmotes[emoteName]) and (EmotesEnabled)) then -- This word is an emote!
            local EmoteButton = Instance.new("ImageButton");
            local SpriteClipObject = ChatSystemCommons:ApplyEmoji(EmoteButton, emoteName);

            if ((TotalScaleX + AbsoluteEmoteSize) >= ChatFrame.AbsoluteSize.X) then
                TotalScaleX = 0
                TotalScaleY += SpaceLength.Y
            end

            if (SpriteClipObject) then
                table.insert(EmoteCollection, {
                    ["Emote"] = emoteName,
                    ["EmoteObject"] = EmoteButton,
                    ["SpriteClip"] = SpriteClipObject
                });
            end

            EmoteButton.BackgroundTransparency = 1
            EmoteButton.Name = "Emoji_"..(emoteName);

            EmoteButton.Position = UDim2.fromOffset(TotalScaleX, TotalScaleY);
            EmoteButton.Size = UDim2.fromOffset(
                (((IsBubbleChat) and (ChatSystemConfigurations.BubbleEmoteSize)) or (AbsoluteEmoteSize)),
                (((IsBubbleChat) and (ChatSystemConfigurations.BubbleEmoteSize)) or (AbsoluteEmoteSize))
            );

            --// Emote Hover Functuality (opt.)
            if (ChatSystemConfigurations.DisplayEmoteInfoOnHover) then
                local HoverInstance = CreateEmoteHoverObject(emoteName);

                local RealPosition = HoverInstance.Position
                local OriginalProperties = {
                    ["MainFrame"] = {
                        ["BackgroundTransparency"] = HoverInstance.BackgroundTransparency,
                        ["Position"] = HoverInstance.Position - UDim2.fromOffset(0, 25),
                        ["Size"] = HoverInstance.Size
                    },

                    ["Carrot"] = {
                        ["BackgroundTransparency"] = HoverInstance.FrameCarrot.BackgroundTransparency
                    },

                    ["Label"] = {
                        ["TextTransparency"] = HoverInstance.LabelEmoteName.TextTransparency
                    }
                };

                HoverInstance.BackgroundTransparency = 1
                HoverInstance.LabelEmoteName.TextTransparency = 1
                HoverInstance.FrameCarrot.BackgroundTransparency = 1
                HoverInstance.Parent = EmoteButton

                EmoteButton.MouseEnter:Connect(function()
                    TweenService:Create(HoverInstance, ChatSystemConfigurations.EmoteHoverTweenInfo, OriginalProperties.MainFrame):Play();
                    TweenService:Create(HoverInstance.FrameCarrot, ChatSystemConfigurations.EmoteHoverTweenInfo, OriginalProperties.Carrot):Play();
                    TweenService:Create(HoverInstance.LabelEmoteName, ChatSystemConfigurations.EmoteHoverTweenInfo, OriginalProperties.Label):Play();
                end);

                EmoteButton.MouseLeave:Connect(function()
                    TweenService:Create(HoverInstance, ChatSystemConfigurations.EmoteHoverTweenInfo, {
                        ["BackgroundTransparency"] = 1,
                        ["Position"] = RealPosition - UDim2.fromOffset(0, 10),
                        ["Size"] = UDim2.fromOffset(50, 5)
                    }):Play();

                    TweenService:Create(HoverInstance.FrameCarrot, ChatSystemConfigurations.EmoteHoverTweenInfo, {
                        ["BackgroundTransparency"] = 1
                    }):Play();

                    TweenService:Create(HoverInstance.LabelEmoteName, ChatSystemConfigurations.EmoteHoverTweenInfo, {
                        ["TextTransparency"] = 1
                    }):Play();
                end);
            end

            table.insert(RenderedObjects, EmoteButton);
            TotalScaleX += (AbsoluteEmoteSize + SpaceLength.X);
        elseif (Word:lower() == "/shrug") then
            local ShrugWordSize = ChatSystemCommons:GetTextSize("¯\\_(ツ)_/¯", container, false, ((parameters) and (parameters.chatMeta)));
            local ShrugLabel = ChatSystemCommons:CreateLabel(ShrugWordSize);

            if ((TotalScaleX + ShrugWordSize.X) >= container.AbsoluteSize.X) then
                TotalScaleX = 0
                TotalScaleY += SpaceLength.Y
            end

            ShrugLabel.Text = "¯\\_(ツ)_/¯"
            ShrugLabel.Name = "WordLabel_Shrug"
            ShrugLabel.Position = UDim2.fromOffset(TotalScaleX, TotalScaleY);

            table.insert(RenderedObjects, ShrugLabel);
            TotalScaleX += ShrugWordSize.X
        else -- This is a normal text word! (probably)
            local WordSize, doesWordOverflow = ChatSystemCommons:GetTextSize(Word, container, true, ((parameters) and (parameters.chatMeta)));
            local WordFrame = ChatSystemCommons:CreateFrame(WordSize);

            if (((TotalScaleX + WordSize.X) >= container.AbsoluteSize.X) or (doesWordOverflow)) then
                TotalScaleX = 0
                TotalScaleY += SpaceLength.Y

                if (ChatSystemConfigurations.DebugOutputEnabled) then
                    warn("SOCIALCHAT DEBUG: NewLine created for string", Word);
                end
            end

            WordFrame.Position = UDim2.fromOffset(TotalScaleX, TotalScaleY);
            
            --// Grapheme Rendering
            local GraphemePosX = 0
            local GraphemePosY = 0

            for _, codepoint in utf8.codes(Word) do
                local Grapheme = utf8.char(codepoint);

                local GraphemeSize = ChatSystemCommons:GetTextSize(Grapheme, container, false, ((parameters) and (parameters.chatMeta)));
                local GraphemeLabel = ChatSystemCommons:CreateLabel(GraphemeSize);

                if ((TotalScaleX + GraphemeSize.X) > container.AbsoluteSize.X) then
                    GraphemePosX = 0
                    GraphemePosY += SpaceLength.Y
                end

                GraphemeLabel.Text = Grapheme
                GraphemeLabel.Name = "Grapheme_"..(Grapheme);
                GraphemeLabel.Position = UDim2.fromOffset(GraphemePosX, GraphemePosY);

                GraphemeLabel.Parent = WordFrame
                TotalScaleX += GraphemeSize.X
                GraphemePosX += GraphemeSize.X
            end

            WordFrame.Name = "FrameContainer_"..(Word);
            table.insert(RenderedObjects, WordFrame);
        end

        TotalScaleX += SpaceLength.X
    end

    local metaColor = ((metadata)
        and (((IsBubbleChat) and (metadata.BubbleTextColor)) -- BubbleChat TextColor
        or ((not IsBubbleChat) and (metadata.MessageColor))) -- Default Message Color
    );
    
    local RenderedEffects = {};

    if ((metaColor) and (EffectRenderingEnabled)) then
        local specialEffect = ChatSystemCommons:ApplyLabelColor(RenderedObjects, metaColor);
        
        if (specialEffect) then
            RenderedEffects = {
                ["EffectName"] = metaColor,
                ["Effect"] = specialEffect
            };
        end
    end

    local isMultiLined = (TotalScaleY > 0);

    return {
        ["Objects"] = RenderedObjects,
        ["Garbage"] = {
            ["Effects"] = RenderedEffects,
            ["Emotes"] = EmoteCollection
        };

        ["isMultiLined"] = isMultiLined,
        ["Scale"] = {
            ["X"] = TotalScaleX,
            ["Y"] = TotalScaleY + SpaceLength.Y
        };
    };
end

--- Returns any submodules found within SocialChat. (This is intended for PiFramework usage)
function SocialChat:GetModules() : table
    if (type(ChatSystemEmotes) == "function") then -- ChatSystemEmotes hasnt been initialized! (Yield)
        repeat
            task.wait();
        until
        type(ChatSystemEmotes) == "table" -- ChatSystemEmotes has been initialized! (End Yield)
    end

    return {
        ["Tags"] = ChatSystemTags,
        ["Emotes"] = ChatSystemEmotes,
        ["Settings"] = ChatSystemConfigurations,
        ["VERSION"] = require(script.Modules.VERSION)
    };
end

--// Functions

--- Creates and returns a preset EmoteHoverObject! This is purely for readability
function CreateEmoteHoverObject(emoteName : string)
    local EmoteBounds = ChatSystemCommons:GetTextSize(emoteName, ChatFrame);
    local NewHoverObject = EmoteBubblePrefab:Clone();

    NewHoverObject.LabelEmoteName.Text = ((ChatSystemConfigurations.EmoteSyntax)..(emoteName)..(ChatSystemConfigurations.EmoteSyntax));
    
    if (EmoteBounds.X > NewHoverObject.AbsoluteSize.X) then
        NewHoverObject.Size = UDim2.fromOffset(EmoteBounds.X + 2, NewHoverObject.Size.Y.Offset);
        NewHoverObject.LabelEmoteName.Size = UDim2.fromOffset(EmoteBounds.X, NewHoverObject.LabelEmoteName.Size.Y.Offset);
    end

    return NewHoverObject
end

--- This is purely for error checking
function verifyParameters(parameters : table)
    for Key, Value in pairs(parameters) do
        if ((Key == "emotesEnabled") and (type(Value) ~= "boolean")) then return; end
        if ((Key == "effectsEnabled") and (type(Value) ~= "boolean")) then return; end
        
        if (Key == "chatMeta") then
            if (type(Value) ~= "table") then return; end
            if ((Value["Font"]) and (not table.find(Enum.Font:GetEnumItems(), Value.Font))) then return; end
            if ((Value["FontSize"]) and (type(Value.FontSize) ~= "number")) then return; end
        end
    end

    return true
end

--// Bubble Methods

--- Hides a bubble by tweening it (or disabiling its visiblity) [YIELDS]
function HideBubble(BubbleContainer : Frame, BubbleObjects : table)
    if (ChatSystemConfigurations.IsBubbleTweeningAllowed) then
        local MainTween = TweenService:Create(BubbleContainer, ChatSystemConfigurations.BubbleTweenInfo, {
            Size = UDim2.new(0, 0, 0, 0)
        });

        TweenService:Create(BubbleContainer.BackgroundBubble, ChatSystemConfigurations.BubbleTweenInfo, {
            BackgroundTransparency = 1
        }):Play();

        TweenService:Create(BubbleContainer.Carrot, ChatSystemConfigurations.BubbleTweenInfo, {
            ImageTransparency = 1
        }):Play();

        --// Individual tweening
        for _, renderedObject in pairs(BubbleObjects) do
            if (renderedObject:IsA("TextLabel")) then
                TweenService:Create(renderedObject, ChatSystemConfigurations.BubbleTweenInfo, {
                    TextTransparency = 1,
                    TextStrokeTransparency = 1
                }):Play();
            elseif (renderedObject:IsA("ImageButton")) then
                TweenService:Create(renderedObject, ChatSystemConfigurations.BubbleTweenInfo, {
                    ImageTransparency = 1
                }):Play();
            end
        end

        MainTween:Play();
        MainTween.Completed:Wait();
    else
        BubbleContainer.Visible = false
    end
end

--- Displays a bubble by tweening it (or enabling its visiblity)
function ShowBubble(BubbleContainer : Frame, BubbleObjects : table, ForcedSize : Vector2?)
    if (ChatSystemConfigurations.IsBubbleTweeningAllowed) then
        BubbleContainer.BackgroundBubble.BackgroundTransparency = 1
        BubbleContainer.Carrot.ImageTransparency = 1

        for _, Object in pairs(BubbleObjects) do
            if (Object:IsA("TextLabel")) then
                Object.TextTransparency = 1
                Object.TextStrokeTransparency = 1
            elseif (Object:IsA("ImageButton")) then
                Object.ImageTransparency = 1
            end
        end

        local OriginalSize = (((ForcedSize) and (UDim2.fromOffset(ForcedSize.X, ForcedSize.Y))) or (BubbleContainer.Size));
        BubbleContainer.Size = UDim2.new(0, 0, 0, 0);

        --// Tweening
        TweenService:Create(BubbleContainer, ChatSystemConfigurations.BubbleTweenInfo, {
            Size = OriginalSize
        }):Play();

        TweenService:Create(BubbleContainer.BackgroundBubble, ChatSystemConfigurations.BubbleTweenInfo, {
            BackgroundTransparency = ChatSystemConfigurations.BubbleBackgroundTransparency
        }):Play();

        TweenService:Create(BubbleContainer.Carrot, ChatSystemConfigurations.BubbleTweenInfo, {
            ImageTransparency = ChatSystemConfigurations.BubbleBackgroundTransparency
        }):Play();

        --// Individual Tweening
        for _, renderedObject in pairs(BubbleObjects) do
            if (renderedObject:IsA("TextLabel")) then
                TweenService:Create(renderedObject, ChatSystemConfigurations.BubbleTweenInfo, {
                    TextTransparency = ChatSystemConfigurations.BubbleTextTransparency,
                    TextStrokeTransparency = ChatSystemConfigurations.BubbleTextStrokeTransparency
                }):Play();
            elseif (renderedObject:IsA("ImageButton")) then
                TweenService:Create(renderedObject, ChatSystemConfigurations.BubbleTweenInfo, {
                    ImageTransparency = 0
                }):Play();
            end
        end
    else
        BubbleContainer.Visible = true
    end
end

--- Returns a new ChatBubble line along with its AbsoluteSize. This is just for readability/simplifying code
function CreateNewChatBubbleLine(Container : Instance, YSize : number) : Frame | Vector2
    local newLine = MultiLinePrefab:Clone();
    local lineAbsX = newLine.AbsoluteSize.X

    newLine.Size = UDim2.fromOffset(lineAbsX, YSize);
    newLine.Parent = Container

    return newLine
end

--- Destroys a chat bubble
function DestroyBubble(BubbleObject : Instance)
    for _, CollectedGarbage in pairs(BubbleObject.GarbageCollection.EmoteCollection) do
        ChatSystemEmotes[CollectedGarbage.Emote].OnEmoteSweeped(CollectedGarbage.EmoteObject, CollectedGarbage.SpriteClip);
    end

    local BubbleGarbage = BubbleObject.GarbageCollection.LabelCollection

    ChatSystemTags[BubbleGarbage.EffectName].OnRemoved(BubbleGarbage.Effect);
    BubbleObject.MessageFrame:Destroy();
end

--- Creates a new chat bubble for the provided Agent
function SetupBubbleChat(Agent : Model)
    if (BubbleContainerLog[Agent]) then return; end --> Prevent duplicates!

    local NewContainer = BubbleContainerPrefab:Clone();
    local Head = Agent:WaitForChild("Head");

    NewContainer.Adornee = Head
    NewContainer.Parent = Head

    BubbleContainerLog[Agent] = {};

    if (ChatSystemConfigurations.DebugOutputEnabled) then
        print("SOCIALCHAT DEBUG: Registered new chat bubble data for agent "..(Agent.Name));
    end

    --// Render distance
    RunService.RenderStepped:Connect(function()
        local distanceToCamera = math.floor((Camera.CFrame.Position - Head.Position).Magnitude);

        if (distanceToCamera > ChatSystemConfigurations.MaximumRenderDistance) then
            for _, BubbleInfo in pairs(BubbleContainerLog[Agent]) do
                if (not BubbleInfo.IsRendered) then continue; end

                BubbleInfo.IsRendered = false
                HideBubble(BubbleInfo.MessageFrame, BubbleInfo.ObjectList);
            end
        else
            for _, BubbleInfo in pairs(BubbleContainerLog[Agent]) do
                if (BubbleInfo.IsRendered) then continue; end

                BubbleInfo.IsRendered = true
                ShowBubble(BubbleInfo.MessageFrame, BubbleInfo.ObjectList, BubbleInfo.RealSize);
            end
        end
    end);

    task.wait(.1); -- New Chat Bubbles need some time to resize and fit their new containers
    return NewContainer
end

return SocialChat