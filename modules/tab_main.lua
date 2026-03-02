-- ================================================
--   Tab Main
-- ================================================

local function init(ctx)
    local Tabs        = ctx.Tabs
    local Fluent      = ctx.Fluent
    local LocalPlayer = ctx.LocalPlayer
    local Players     = ctx.Players

    local gameInfo = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset)

    Tabs.Main:AddParagraph({
        Title   = "Player Info",
        Content = "Username: " .. LocalPlayer.Name
            .. "\nDisplay: " .. LocalPlayer.DisplayName
            .. "\nUser ID: " .. tostring(LocalPlayer.UserId),
    })

    Tabs.Main:AddParagraph({
        Title   = "Game Info",
        Content = "Name: " .. (gameInfo.Name or "Unknown")
            .. "\nPlace ID: " .. tostring(game.PlaceId)
            .. "\nGame ID: " .. tostring(game.GameId)
            .. "\nServer: " .. game.JobId:sub(1, 20) .. "..."
            .. "\nPlayers: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers,
    })

    Tabs.Main:AddButton({
        Title       = "Rejoin Server",
        Description = "Teleport kembali ke server ini",
        Callback    = function()
            Fluent:Notify({ Title = "Rejoining...", Content = "Tunggu sebentar.", Duration = 3 })
            task.wait(1.5)
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end,
    })

    Tabs.Main:AddButton({
        Title       = "Copy Username",
        Description = "Salin username ke clipboard",
        Callback    = function()
            setclipboard(LocalPlayer.Name)
            Fluent:Notify({ Title = "Disalin!", Content = "Username: " .. LocalPlayer.Name, Duration = 2 })
        end,
    })
end

return init
