-- ================================================
--   Tab Visual
-- ================================================

local function init(ctx)
    local Tabs         = ctx.Tabs
    local Fluent       = ctx.Fluent
    local RS           = ctx.RS
    local LocalPlayer  = ctx.LocalPlayer
    local WorldTiles   = ctx.WorldTiles
    local WorldManager = ctx.WorldManager

    local worldInfoParagraph = Tabs.Visual:AddParagraph({
        Title   = "World Info",
        Content = "Tekan Refresh untuk scan.",
    })

    local playerPosParagraph = Tabs.Visual:AddParagraph({
        Title   = "Player Position",
        Content = "...",
    })

    local function getWorldInfo()
        local count = 0
        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge

        for x, col in pairs(WorldTiles) do
            if type(col) == "table" then
                for y, layers in pairs(col) do
                    if type(layers) == "table" then
                        for layer, tile in pairs(layers) do
                            count = count + 1
                            if x < minX then minX = x end
                            if x > maxX then maxX = x end
                            if y < minY then minY = y end
                            if y > maxY then maxY = y end
                        end
                    end
                end
            end
        end

        return count, minX, maxX, minY, maxY
    end

    Tabs.Visual:AddButton({
        Title       = "Refresh World Info",
        Description = "Scan data tile dunia",
        Callback    = function()
            local loaded = game.ReplicatedStorage.WorldTiles:GetAttribute("loaded")
            if not loaded then
                Fluent:Notify({ Title = "World Info", Content = "World belum loaded!", Duration = 2 })
                return
            end

            local count, minX, maxX, minY, maxY = getWorldInfo()
            if count > 0 then
                local wName = workspace:GetAttribute("WorldName") or "Unknown"
                local sizeX = maxX - minX + 1
                local sizeY = maxY - minY + 1
                worldInfoParagraph:SetTitle("World Info — " .. wName)
                worldInfoParagraph:SetDesc(
                    "Total Tiles: " .. count
                    .. "\nX: " .. minX .. " → " .. maxX .. "  (" .. sizeX .. ")"
                    .. "\nY: " .. minY .. " → " .. maxY .. "  (" .. sizeY .. ")"
                    .. "\nUkuran: " .. sizeX .. " x " .. sizeY .. " tiles"
                )
            else
                worldInfoParagraph:SetDesc("Tidak ada tile ditemukan.")
            end
            Fluent:Notify({ Title = "World Info", Content = "Data updated!", Duration = 2 })
        end,
    })

    -- Real-time player position
    local posTrackConn = nil

    Tabs.Visual:AddToggle("TrackPosition", {
        Title   = "Track Player Position",
        Default = false,
        Callback = function(val)
            if val then
                posTrackConn = RS.Heartbeat:Connect(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if not root then return end
                    local wx, wy = root.Position.X, root.Position.Y
                    local tx = math.floor(wx / 4.5 + 0.5)
                    local ty = math.floor(wy / 4.5 + 0.5)
                    playerPosParagraph:SetDesc(
                        "World: " .. string.format("%.1f, %.1f", wx, wy)
                        .. "\nTile: " .. tx .. ", " .. ty
                    )
                end)
            else
                if posTrackConn then
                    posTrackConn:Disconnect()
                    posTrackConn = nil
                end
                playerPosParagraph:SetDesc("...")
            end
        end,
    })
end

return init
