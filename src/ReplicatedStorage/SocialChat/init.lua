--[[

    Name: Cos
    Date: 8/12/2022

    Description: Social Chat is an open sourced Chat System made by @CosRBX on Twitter! This module serves as the main initializer for
    the Chat System. This module should only be initialized ONCE, afterwards you may require it for additional API resourcing.

    ------------------------------------------------------------------------------------------------------------------------------------

    GitHub Resource: https://github.com/Cosmental/Social-Chat

]]--

--// Imports
local Environments = script.Environments
local Utilities = script.Utilities

local ServerChat = require(Environments.Server);
local ClientChat = require(Environments.Client);

--// Constants
local IsServer = game:GetService("RunService"):IsServer();
local ChatRemotes = script.Remotes

--// States
local wasInitialized : boolean

--// Initializer
function getSocialChat()
    if (not wasInitialized) then
        if (IsServer) then
            ServerChat:Init(ChatRemotes);
        else
            local ChatUtilities = {}; -- Our client has some client utilities it requires before a proper initialization

            for _, Utility in pairs(Utilities:GetChildren()) do
                if (not Utility:IsA("ModuleScript")) then continue; end

                local Success, Response = pcall(function()
                    return require(Utility);
                end);

                if (Success) then
                    ChatUtilities[Utility.Name] = Response
                else
                    error(string.format(
                        "SocialChat Utility Error!\n\t\t\t\t\t\t\t\t\t%s failed to initialize!\n\t\t\t\t\t\t\t\t\tReason: \"%s\"",
                        Utility.Name,
                        Response or "Unexpected Error Callback"
                    ));
                end
            end

            --// Temporary Fixes
            --\\ These are un-needed fixes that are automatically applied to the game which can be fixed through a simple setting (most likely)

            if (game.Chat.LoadDefaultChat) then
                warn("\n\t\t\t\t\t\t\t\t\t\"LoadDefaultChat\" is currently enabled!\n\t\t\t\t\t\t\t\t\tAn automatic ChatSystem patch has been applied to provide stability to SocialChat.\n\n\t\t\t\t\t\t\t\t\tPlease Ensure that this setting is disabled through your Explore via\n\t\t\t\t\t\t\t\t\t\"Chat > Properties > Behavior > LoadDefaultChat (disable the checkmark)\"\n\n");
                game.Players.LocalPlayer.PlayerGui:WaitForChild("Chat"):Destroy();
            end

            --// Game Setup
            if (not game:IsLoaded()) then
                game.Loaded:Wait(); -- Wait for our game to load on our client
            end

            game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false);
            script.Chat.Parent = game.Players.LocalPlayer.PlayerGui -- Our ChatGUI needs to be parented BEFORE we initialize our Service!
            
            ClientChat:Init(ChatUtilities, ChatRemotes);
        end
    end

    return (
        ((IsServer) and (ServerChat))
            or (ClientChat)
    );
end

return getSocialChat();