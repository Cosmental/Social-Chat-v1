--[[

    Name: Cos
    Date: 7/27/2022

    Description: This Service handles chat related methods in game!

    --------------------------------------------------------------------------------------------------------------------------------------

    ## [DOCUMENTATION] ##

    SocialChatServer

        Functions:

                :MuteClient()               ||  Parameters -> (Client : Player, Duration : number [opt.])
                ↳                           ||  Description: Mutes the provided client for "n" duration (if any)
                                            ||
                ↳                           ||  NOTE: The "Duration" parameter is OPTIONAL. If no duration is provided, the client must
                                            ||        be unmuted by calling the :UnmuteClient() method!

        ---------------------------------------------------------------------------------------------------------------------------

                :UnmuteClient()             ||  Parameters -> (Client : Player)
                ↳                           ||  Description: Unmutes the provided client (if they were previously muted)

        ## ---------------------------------------------------------------------------------------------------------------------------  ##
        ## ---------------------------------------------------------------------------------------------------------------------------  ##
        ## ---------------------------------------------------------------------------------------------------------------------------  ##

        Events:
        
                .PlayerChatted:Connect()    ||  Response Info -> (playerWhoChatted : Player, messageSent : string, chatMetaData : table)
                ↳                           ||  Description: Fires when a player sends a new chat message through SocialChat
                                            ||
                ↳                           ||  NOTE: The "messageSent" parameter is NOT filtered!

]]--

--// Services
local TextService = game:GetService("TextService");
local RunService = game:GetService("RunService");

--// Imports
local ChatSystemTags = require(script.Tags);
local ChatSystemSettings = require(script.Settings);

--// Constants
local _chatEv = Instance.new("BindableEvent");
local ChatEvents

--// States
local ClientMetadata = {}; --> {["ChatTag"] = table, ["MutedClients"] = table, ["ChatLimit"] = number}
local PubliclyMutedClients = {};

--// Module
local SocialChatServer = {};
SocialChatServer.PlayerChatted = _chatEv.Event

--// Initialization
function SocialChatServer:Init(Remotes : Instance)
    ChatEvents = Remotes

    RunService.Heartbeat:Connect(function()
        if (not next(PubliclyMutedClients)) then return; end

        local timeNow = os.clock();

        for Client, MuteInfo in pairs(PubliclyMutedClients) do
            local timePassed = (timeNow - MuteInfo.StartedAt);
            if (timePassed < MuteInfo.Duration) then continue; end

            SocialChatServer:UnmuteClient(Client);
        end
    end);
    
    --// Player Events
    ChatEvents.ClientReady.OnServerEvent:Connect(function(Player : Player)
        ClientMetadata[Player] = {
            ["ChatTag"] = GetTag(Player) or {
                ["SpeakerColor"] = getRandomSpeakerColor(), -- New players should get a randomized chat tag color everytime they join
                ["MessageColor"] = Color3.fromRGB(255, 255, 255)
            };

            ["MutedClients"] = {}, -- This holds info towards muted clients for this specific player
            ["ChatLimit"] = ChatSystemSettings.MaximumMessagesPer10Seconds
        };

        if (ChatSystemSettings.JoinMessagesEnabled) then
            ChatEvents.ChatReplicate:FireAllClients(
                "SERVER",
                string.format(ChatSystemSettings.JoinMessage, ((ChatSystemSettings.UseDisplayNamesForServerMessages) and (Player.DisplayName)) or (Player.Name)),
                ChatSystemTags.SERVER.TagData
            );
        end
    end);

    if (ChatSystemSettings.LeaveMessagesEnabled) then
        game.Players.PlayerRemoving:Connect(function(Player : Player)
            ChatEvents.ChatReplicate:FireAllClients(
                "SERVER",
                string.format(ChatSystemSettings.LeaveMessage, ((ChatSystemSettings.UseDisplayNamesForServerMessages) and (Player.DisplayName)) or (Player.Name)),
                ChatSystemTags.SERVER.TagData
            );
        end);
    end
    
    --// Events
    ChatEvents.ChatReplicate.OnServerEvent:Connect(function(Player : Player, Message : string, PrivateRecipient : Player?)
        if (not ClientMetadata[Player]) then return; end
        if (PubliclyMutedClients[Player]) then return; end
        if (Message:sub(1, 2) == "/e") then return; end -- We can ignore character emotes

        local MetaData = ClientMetadata[Player];

        --// Message limiting
        if (Message:len() > ChatSystemSettings.MaxMessageLength) then
            SendSystemMessage(
                Player,
                "Messages can not have over "..(ChatSystemSettings.MaxMessageLength).." string characters!",
                ChatSystemSettings.ErrorTagColor
            );

            return;
        end

        if (MetaData.ChatLimit <= 0) then
            SendSystemMessage(
                Player,
                "You're sending messages too quickly!",
                ChatSystemSettings.ErrorTagColor
            );

            return;
        end

        --// Mute command
        if (not PrivateRecipient) then -- You cant mute someone while whispering!
            local isMuteCommand = (Message:sub(1, 5) == "/mute");
            local isUnmuteCommand = (Message:sub(1, 7) == "/unmute");

            if (((isMuteCommand) or (isUnmuteCommand)) and (#Message:split(" ") == 2)) then
                local QueryUsername = Message:sub((isMuteCommand and 7) or (isUnmuteCommand and 9));
                local Victim = QuerySearch(QueryUsername);

                if (not Victim) then
                    SendSystemMessage(
                        Player,
                        "Failed to "..((isMuteCommand and "mute") or (isUnmuteCommand and "unmute")).." \""..(QueryUsername).."\"! (The provided player is not currently in this server)",
                        ChatSystemSettings.ErrorTagColor
                    );
                elseif (Victim ~= Player) then -- Make sure we dont mute ourselves!!
                    local VictimMutePosition = table.find(MetaData.MutedClients, Victim);
                    if (((isMuteCommand) and (VictimMutePosition)) or ((isUnmuteCommand) and (not VictimMutePosition))) then return; end -- Victim is already muted/unmuted!
                    
                    if (isMuteCommand) then
                        table.insert(MetaData.MutedClients, Victim);
                    else
                        table.remove(MetaData.MutedClients, VictimMutePosition);
                    end

                    SendSystemMessage(
                        Player,
                        "Successfully "..((isMuteCommand and "muted") or (isUnmuteCommand and "unmuted")).." \""..(QueryUsername).."\"!",
                        ChatSystemSettings.SystemMessageColor
                    );
                end

                return;
            end
        end

        --// API Functuality
        _chatEv:Fire(Player, Message, {
            ["TagData"] = MetaData.ChatTag,

            ["wasWhispered"] = PrivateRecipient ~= nil,
            ["whisperRecipient"] = PrivateRecipient
        });

        --// Message Handling
		local Success, Response = pcall(function()
			return TextService:FilterStringAsync(Message, Player.UserId);
		end);

        if (Success) then
            if (PrivateRecipient) then
                local RecieverMutedClientSettings = ClientMetadata[PrivateRecipient].MutedClients
                local isSpeakerMutedByReciever = table.find(RecieverMutedClientSettings, Player);

                if (isSpeakerMutedByReciever) then -- Make sure that the sender isnt muted by the recipient
                    SendSystemMessage(
                        Player,
                        "Failed to send private message. (You are currently muted by the recipient)",
                        ChatSystemSettings.ErrorTagColor
                    );

                    return;
                end

                local FilterSuccess, FilterResponse = pcall(function()
                    return Response:GetChatForUserAsync(PrivateRecipient.UserId);
                end);

                if (FilterSuccess) then
                    ChatEvents.ChatReplicate:FireClient(PrivateRecipient, Player, FilterResponse, MetaData.ChatTag, PrivateRecipient);
                    ChatEvents.ChatReplicate:FireClient(Player, Player, FilterResponse, MetaData.ChatTag, PrivateRecipient);
                else
                    warn("Failed to filter private message for user \""..(Player.Name).."\". Response: "..(Response));
                end
            else
                for _, Reciever in pairs(game.Players:GetPlayers()) do
                    if (Reciever ~= Player) then
                        local RecieverMutedClientSettings = ClientMetadata[Reciever].MutedClients
                        local isSpeakerMutedByReciever = table.find(RecieverMutedClientSettings, Player);
    
                        if (isSpeakerMutedByReciever) then continue; end
                    end
    
                    local FilterSuccess, FilterResponse = pcall(function()
                        return Response:GetChatForUserAsync(Reciever.UserId);
                    end);
    
                    if (FilterSuccess) then -- If we filtered our message properly, then we can send it
                        ChatEvents.ChatReplicate:FireClient(Reciever, Player, FilterResponse, MetaData.ChatTag);
                    else
                        warn("Failed to filter message for user \""..(Player.Name).."\". Response: "..(Response));
                    end
                end
            end
        else
            SendSystemMessage(
                Player,
                "Something went wrong with your previous request. (Roblox servers may be down)\n["..(Response or "Unknown Filter Error").."]",
                ChatSystemSettings.ErrorTagColor
            );

            error("SocialChatServer Error for user ("..(Player.Name).."). Response: "..(Response or "No response provided!"));
            return;
        end

        MetaData.ChatLimit -= 1

        coroutine.wrap(function()
            task.wait(10);
            MetaData.ChatLimit += 1
        end)();
    end);
end

--// Methods

--- This method mutes a client for EVERYONE. The provided client will not be able to send any messages until they are unmuted. (or their mute duration expires)
function SocialChatServer:MuteClient(Client : Player, Duration : number?)
    assert(typeof(Client) == "Instance", "The provided client was not an \"Instance\"! (Got: \""..(typeof(Client)).."\")");
    assert(Client:IsA("Player"), "The provided Instance was not of class \"Player\". (Got: \""..(Client.ClassName).."\")");
    assert(type(Duration) == "number", "The provided time duration was not of type \"number\". (Got: \""..(type(Duration)).."\")");
    assert(Duration > 0, "The provided duration was equal to or less than \"0\". (Your time duration must be greated than 0 seconds!)");

    PubliclyMutedClients[Client] = {
        ["StartedAt"] = os.clock(),
        ["Duration"] = Duration
    };

    ChatEvents.ChatMute:FireClient(Client, true);
end

--- This method unmutes a previously muted client
function SocialChatServer:UnmuteClient(Client : Player)
    assert(typeof(Client) == "Instance", "The provided client was not an \"Instance\"! (Got: \""..(typeof(Client)).."\")");
    assert(Client:IsA("Player"), "The provided Instance was not of class \"Player\". (Got: \""..(Client.ClassName).."\")");

    PubliclyMutedClients[Client] = nil
    ChatEvents.ChatMute:FireClient(Client, false);
end

--// Functions

--- Returns the requested player's chat tag
function GetTag(Player : Player)
    local OwnedTag, Priority = nil, math.huge

	--// Find our Players tag
	for _, Tag in pairs(ChatSystemTags) do
		if (Tag.Priority >= Priority) then continue; end --// Skips this tag if its equal to/over our priority
		local Requirements = Tag.Requirements

		--// Requirement checking
		if (not table.find(Requirements.UserIds, Player.UserId)) then
			if ((Requirements.GroupId > 0) and (Player:IsInGroup(Requirements.GroupId))) then
				local Ranks = Requirements.AcceptedRanks

				if (not next(Ranks)) then
					continue;
				else
					local PlayerRank = Player:GetRankInGroup(Requirements.GroupId);
					local IsOfValidRank
					
					for _, Rank in pairs(Ranks) do --// Go through each valid rank allowed for X tag
						if (PlayerRank >= Rank) then
							IsOfValidRank = true
							break; --// Ends our search here
						end
					end
					
					if (not IsOfValidRank) then continue; end
				end
			else
				continue;
			end
		end

		--// Updating our Data
		OwnedTag = Tag.TagData
		Priority = Tag.Priority
	end

    return OwnedTag
end

--- Creates a system message using the provided parameters
function SendSystemMessage(ToClient : Player, Message : string, TagColor : Color3)
    ChatEvents.ChatReplicate:FireClient(ToClient,
        nil,
        Message,
        {
            ["MessageColor"] = TagColor
        }
    );
end

--- Searches for a given player using the provided username string! (not case sensitive)
function QuerySearch(QueryUsername : string)
    for _, Player in pairs(game.Players:GetPlayers()) do
        if (Player.Name:lower() == QueryUsername:lower()) then
            return Player
        end
    end
end

--- Returns a random Speaker color
function getRandomSpeakerColor() : Color3
    if (next(ChatSystemSettings.UsernameColors)) then
        return ChatSystemSettings.UsernameColors[math.random(#ChatSystemSettings.UsernameColors)];
    else
        return BrickColor.random().Color
    end
end

return SocialChatServer