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
local TextService = game:GetService("TextService");
local RunService = game:GetService("RunService");

--// Imports
local ChatUI = require(script.ChatUI);

local ChatSystemTags = require(script.Modules.ChatSystemTags);
local ChatSystemEmotes = require(script.Modules.ChatSystemEmotes);
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
    SpaceLength = GetTextSize(" ", ChatFrame);

    --// Chat Bubble Setup
    local function onCharacterAdded(Character : Model)
        local NewContainer = BubbleContainerPrefab:Clone();
        local Head = Character:WaitForChild("Head");

        NewContainer.Adornee = Head
        NewContainer.Parent = Head

        BubbleContainerLog[Character] = {};

        --// Render distance
        RunService.RenderStepped:Connect(function()
            local distanceToCamera = math.floor((Camera.CFrame.Position - Head.Position).Magnitude);

            if (distanceToCamera > ChatSystemConfigurations.MaximumRenderDistance) then
                for _, BubbleInfo in pairs(BubbleContainerLog[Character]) do
                    if (not BubbleInfo.IsRendered) then continue; end

                    BubbleInfo.IsRendered = false
                    HideBubble(BubbleInfo.MessageFrame, BubbleInfo.ObjectList);
                end
            else
                for _, BubbleInfo in pairs(BubbleContainerLog[Character]) do
                    if (BubbleInfo.IsRendered) then continue; end

                    BubbleInfo.IsRendered = true
                    ShowBubble(BubbleInfo.MessageFrame, BubbleInfo.ObjectList, BubbleInfo.RealSize);
                end
            end
        end);
    end

    local function onPlayerAdded(Player : Player)
        onCharacterAdded(Player.Character or Player.CharacterAdded:Wait());
        Player.CharacterAdded:Connect(onCharacterAdded);
    end

    for _, Player in pairs(game.Players:GetPlayers()) do
        onPlayerAdded(Player);
    end

    game.Players.PlayerAdded:Connect(onPlayerAdded);

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

    local SpeakerUsernameLength = GetTextSize(UserText, ChatFrame);
    local SpeakerTagLength = GetTextSize(TagText, ChatFrame);

    local RenderResult = SocialChat:RenderText(message, ChatFrame, metadata, nil, (SpeakerUsernameLength.X + SpeakerTagLength.X));
    
    --// Tag Label Solving
    local SpeakerTagLabel = CreateLabel(SpeakerTagLength);

    SpeakerTagLabel.Name = "TagLabel"
    SpeakerTagLabel.Text = TagText

    if ((metadata) and ((metadata.TagColor) and (not toPrivateRecipient))) then
        local LabelEffect = ApplyLabelColor({SpeakerTagLabel}, metadata.TagColor);

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
    local SpeakerUsernameLabel = CreateButton(SpeakerUsernameLength);

    SpeakerUsernameLabel.Position = UDim2.fromOffset(SpeakerTagLength.X, 0);
    SpeakerUsernameLabel.Name = "UsernameLabel"
    SpeakerUsernameLabel.Text = UserText

    if ((metadata) and (metadata.SpeakerColor)) then
        local LabelEffect = ApplyLabelColor({SpeakerUsernameLabel}, metadata.SpeakerColor);

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
    local ClientMessageFrame = CreateFrame(Vector2.new(ChatFrame.AbsoluteSize.X, RenderResult.Scale.Y));
    ClientMessageFrame.Name = ("ClientMessage_"..(tostring(speaker)));

    if (ChatSystemConfigurations.IsTweeningAllowed) then
        local TweenFrame = CreateFrame(Vector2.new(0, 0));
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

    local BubbleContainer = AgentHead:FindFirstChild(BubbleContainerPrefab.Name);
    if (not BubbleContainer) then return; end

    local MessageContainer = BubbleMessagePrefab:Clone();
    local LineSpaceX = (BubbleContainer.Size.X.Offset - 10); -- We need to subtract 10 from our AbsX size for aesthetic purposes

    local BubbleSizeParameters = {
        ["Font"] = ChatSystemConfigurations.BubbleFont,
        ["FontSize"] = ChatSystemConfigurations.BubbleTextSize
    };

    local RenderResult = SocialChat:RenderText(message, BubbleContainer, metadata, {
        ["effectsEnabled"] = false,
        ["chatMeta"] = BubbleSizeParameters
    });

    --// Individual word rendering
    local AbsoluteBubblePosX = 0
    local AbsoluteBubbleSizeY = 0
    local VisibleGraphemes = {};

    local SpaceSize = GetTextSize(" ", BubbleContainer.FrameBackground, nil, BubbleSizeParameters);
    local CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);

    for Index, RenderObject in pairs(RenderResult.Objects) do
        if (RenderObject:IsA("ImageButton")) then -- This word is an emote!
            if ((AbsoluteBubblePosX + ChatSystemConfigurations.BubbleEmoteSize) > LineSpaceX) then
                AbsoluteBubblePosX = 0
                AbsoluteBubbleSizeY += SpaceSize.Y
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
                        AbsoluteBubbleSizeY += SpaceSize.Y
                        CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);
                    end
        
                    AbsoluteBubblePosX += subRenderChild.AbsoluteSize.X
                    subRenderChild.Parent = CurrentLine

                    table.insert(VisibleGraphemes, subRenderChild);
                end

                RenderObject:Destroy();
            else
                if ((AbsoluteBubblePosX + RenderObject.AbsoluteSize.X) > LineSpaceX) then
                    AbsoluteBubblePosX = 0
                    AbsoluteBubbleSizeY += SpaceSize.Y
                    CurrentLine = CreateNewChatBubbleLine(MessageContainer.BackgroundBubble, SpaceSize.Y);
                end
    
                AbsoluteBubblePosX += RenderObject.AbsoluteSize.X
                RenderObject.Parent = CurrentLine

                table.insert(VisibleGraphemes, RenderObject);
            end
        end

        if (Index == #message:split(" ")) then continue; end -- We dont want to add extra spacing at the end of our message LOL
        local SpaceLabel = CreateLabel(SpaceSize, ChatSystemConfigurations.BubbleFont);

        SpaceLabel.Name = "SPACELABEL_VISUAL"
        SpaceLabel.Text = ""
        SpaceLabel.Parent = CurrentLine
        AbsoluteBubblePosX += SpaceSize.X
    end

    --// Container rendering
    MessageContainer.Size = UDim2.fromOffset(
        (((RenderResult.isMultiLined) and (BubbleContainer.Size.X.Offset)) or (RenderResult.Scale.X + ChatSystemConfigurations.BubbleSizeOffset)),
        (((RenderResult.isMultiLined) and (RenderResult.Scale.Y + SpaceSize.Y)) or (SpaceSize.Y)) + ChatSystemConfigurations.BubbleSizeOffset
    );

    local ContainerBackground = MessageContainer.BackgroundBubble
    local ContainerCarrot = MessageContainer.Carrot

    ContainerBackground.BackgroundColor3 = ChatSystemConfigurations.BubbleColor
    ContainerCarrot.ImageColor3 = ChatSystemConfigurations.BubbleColor

    ContainerBackground.BackgroundTransparency = ChatSystemConfigurations.BubbleBackgroundTransparency
    ContainerCarrot.ImageTransparency = ChatSystemConfigurations.BubbleBackgroundTransparency

    MessageContainer.Name = ("ClientBubbleMessage_"..(Agent.Name));
    MessageContainer.Parent = BubbleContainer.FrameBackground

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

        metadata structure:

        {

            --// TAG DATA \\--

            ["TagName"] = "DISPLAYED_CHAT_NAME_HERE",

            ["TagColor"] = Color3.fromRGB(255, 255, 255),
            ["SpeakerColor"] = Color3.fromRGB(255, 0, 0),
            ["MessageColor"] = Color3.fromRGB(0, 215, 255),

        };

    ]]--

    local EmoteCollection = {};
    local RenderedEffects = {};
    local RenderedObjects = {};

    local EmotesEnabled = (((parameters) and (parameters.emotesEnabled)) or (true));
    local EffectRenderingEnabled = (((parameters) and (parameters.effectsEnabled)) or (true));

    local TotalScaleX = ((additionalXSpace) or (0));
    local TotalScaleY = 0

    for _, Word in pairs(text:split(" ")) do
        local isEmote = ((Word:sub(1, 1) == EmoteSyntax) and (Word:sub(#Word, #Word) == EmoteSyntax));
        local emoteName = (Word:sub(2, #Word - 1));

        if ((isEmote) and (ChatSystemEmotes[emoteName]) and (EmotesEnabled)) then -- This word is an emote!
            local EmoteButton = Instance.new("ImageButton");
            local SpriteClipObject = ApplyEmoji(EmoteButton, emoteName);

            if ((TotalScaleX + ChatSystemConfigurations.ChatEmoteSize) > ChatFrame.AbsoluteSize.X) then
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
            EmoteButton.Size = UDim2.fromOffset(ChatSystemConfigurations.ChatEmoteSize, ChatSystemConfigurations.ChatEmoteSize);

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

                EmoteButton.MouseEnter:Connect(function(X : number, Y : number)
                    TweenService:Create(HoverInstance, ChatSystemConfigurations.EmoteHoverTweenInfo, OriginalProperties.MainFrame):Play();
                    TweenService:Create(HoverInstance.FrameCarrot, ChatSystemConfigurations.EmoteHoverTweenInfo, OriginalProperties.Carrot):Play();
                    TweenService:Create(HoverInstance.LabelEmoteName, ChatSystemConfigurations.EmoteHoverTweenInfo, OriginalProperties.Label):Play();
                end);

                EmoteButton.MouseLeave:Connect(function(X : number, Y : number)
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
            TotalScaleX += (ChatSystemConfigurations.ChatEmoteSize + SpaceLength.X);
        elseif (Word:lower() == "/shrug") then
            local ShrugWordSize = GetTextSize("¯\\_(ツ)_/¯", container);
            local ShrugLabel = CreateLabel(ShrugWordSize);

            if ((TotalScaleX + ShrugWordSize.X) > container.AbsoluteSize.X) then
                TotalScaleX = 0
                TotalScaleY += SpaceLength.Y
            end

            ShrugLabel.Text = "¯\\_(ツ)_/¯"
            ShrugLabel.Name = "WordLabel_Shrug"
            ShrugLabel.Position = UDim2.fromOffset(TotalScaleX, TotalScaleY);

            table.insert(RenderedObjects, ShrugLabel);
            TotalScaleX += ShrugWordSize.X
        else -- This is a normal text word! (probably)
            local WordSize, doesWordOverflow = GetTextSize(Word, container, true);
            local WordFrame = CreateFrame(WordSize);

            if ((TotalScaleX + WordSize.X) > container.AbsoluteSize.X) then
                TotalScaleX = 0
                TotalScaleY += SpaceLength.Y
            end

            WordFrame.Position = UDim2.fromOffset(
                (((doesWordOverflow) and (0)) or (TotalScaleX)),
                TotalScaleY
            );
            
            if (doesWordOverflow) then
                TotalScaleY += WordSize.Y
            end
            
            --// Grapheme Rendering
            local GraphemePosX = 0
            local GraphemePosY = 0

            for _, Grapheme in pairs(Word:split("")) do
                local GraphemeSize = GetTextSize(Grapheme, WordFrame);
                local GraphemeLabel = CreateLabel(GraphemeSize);

                if ((GraphemePosX + GraphemeSize.X) > WordSize.X) then
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

    if ((metadata) and (metadata.MessageColor) and (EffectRenderingEnabled)) then
        local LabelEffect = ApplyLabelColor(RenderedObjects, metadata.MessageColor);
        
        if (LabelEffect) then
            table.insert(RenderedEffects, {
                ["EffectName"] = metadata.MessageColor,
                ["Effect"] = LabelEffect
            });
        end
    end

    return {
        ["Objects"] = RenderedObjects,
        ["Garbage"] = {
            ["Effects"] = RenderedEffects,
            ["Emotes"] = EmoteCollection
        };

        ["isMultiLined"] = (TotalScaleY > 0),
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

--- Returns the absoluteSize for the provided string
function GetTextSize(text : string, parentObject : Instance, byGrapheme : boolean?, CustomTextParams : table?) : Vector2 | boolean?
    local AbsX = parentObject.AbsoluteSize.X
    local AbsY = parentObject.AbsoluteSize.Y

    if (byGrapheme) then
        local doesWordOverflow = false
        local GraphemeX = 0
        local GraphemeY = 0

        for _, Grapheme in pairs(text:split("")) do
            local GraphemeSize = TextService:GetTextSize(
                Grapheme,
                ((CustomTextParams) and (CustomTextParams.FontSize)) or (ChatSystemConfigurations.FontSize),
                ((CustomTextParams) and (CustomTextParams.Font)) or (ChatSystemConfigurations.Font),
                Vector2.new(AbsX, AbsY)
            );

            if (GraphemeX >= AbsX) then
                GraphemeX = 0
                GraphemeY += SpaceLength.Y
                doesWordOverflow = true
            end

            GraphemeX += GraphemeSize.X
        end

        return Vector2.new(
            (((doesWordOverflow) and (AbsX)) or (GraphemeX)),
            GraphemeY
        ), doesWordOverflow
    else
        return TextService:GetTextSize(
            text,
            ((CustomTextParams) and (CustomTextParams.FontSize)) or (ChatSystemConfigurations.FontSize),
            ((CustomTextParams) and (CustomTextParams.Font)) or (ChatSystemConfigurations.Font),
            Vector2.new(AbsX, AbsY)
        );
    end
end

--- Applies a TextLabel/TextButton Color scheme based on the provided "tagColor" parameter
function ApplyLabelColor(Graphemes : table, tagColor : string | Color3, UniqueTagsOnly : boolean?) : table?

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
function ApplyEmoji(ImageObject : Instance, Emote : string) : table?
    local EmoteInfo = ChatSystemEmotes[Emote];
    ImageObject.Image = EmoteInfo.Image
    
    if (EmoteInfo.IsAnimated) then -- Emote is animated!
        return coroutine.wrap(EmoteInfo.OnEmoteFired)(ImageObject);
    end
end

--- Creates and returns a preset TextLabel! This is purely for readability
function CreateLabel(fromSize : Vector2, CustomFont : Enum.Font?) : TextLabel
    local NewLabel = Instance.new("TextLabel");
    
    NewLabel.BackgroundTransparency = 1
    NewLabel.TextStrokeTransparency = 0.8
    NewLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
    NewLabel.Size = UDim2.fromOffset(fromSize.X, fromSize.Y);
    
    NewLabel.TextXAlignment = Enum.TextXAlignment.Left
    NewLabel.TextSize = ChatSystemConfigurations.FontSize
    NewLabel.Font = ((CustomFont) or (ChatSystemConfigurations.Font));

    return NewLabel
end

--- Creates and returns a preset TextButton! This is purely for readability
function CreateButton(fromSize : Vector2, CustomFont : Enum.Font?) : TextButton
    local NewButton = Instance.new("TextButton");

    NewButton.BackgroundTransparency = 1
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
function CreateFrame(fromSize : Vector2) : Frame
    local NewFrame = Instance.new("Frame");

	NewFrame.BackgroundTransparency = 1
	NewFrame.ClipsDescendants = false

	NewFrame.Size = UDim2.fromOffset(fromSize.X, fromSize.Y);
	return NewFrame
end

--- Returns a new ChatBubble line along with its AbsoluteSize. This is just for readability/simplifying code
function CreateNewChatBubbleLine(Container : Instance, YSize : number) : Frame | Vector2
    local newLine = MultiLinePrefab:Clone();
    local lineAbsX = newLine.AbsoluteSize.X

    newLine.Size = UDim2.fromOffset(lineAbsX, YSize);
    newLine.Parent = Container

    return newLine
end

--- Creates and returns a preset EmoteHoverObject! This is purely for readability
function CreateEmoteHoverObject(emoteName : string)
    local EmoteBounds = GetTextSize(emoteName, ChatFrame);
    local NewHoverObject = EmoteBubblePrefab:Clone();

    NewHoverObject.LabelEmoteName.Text = ((ChatSystemConfigurations.EmoteSyntax)..(emoteName)..(ChatSystemConfigurations.EmoteSyntax));
    
    if (EmoteBounds.X > NewHoverObject.AbsoluteSize.X) then
        NewHoverObject.Size = UDim2.fromOffset(EmoteBounds.X + 2, NewHoverObject.Size.Y.Offset);
        NewHoverObject.LabelEmoteName.Size = UDim2.fromOffset(EmoteBounds.X, NewHoverObject.LabelEmoteName.Size.Y.Offset);
    end

    return NewHoverObject
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

--- Destroys a chat bubble
function DestroyBubble(BubbleObject : Instance)
    for _, CollectedGarbage in pairs(BubbleObject.GarbageCollection.EmoteCollection) do
        ChatSystemEmotes[CollectedGarbage.Emote].OnEmoteSweeped(CollectedGarbage.EmoteObject, CollectedGarbage.SpriteClip);
    end

    for _, CollectedGarbage in pairs(BubbleObject.GarbageCollection.LabelCollection) do
        ChatSystemTags[CollectedGarbage.EffectName].OnRemoved(CollectedGarbage.Effect);
    end

    BubbleObject.MessageFrame:Destroy();
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

return SocialChat