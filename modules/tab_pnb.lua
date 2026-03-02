-- ================================================
--   Tab PnB — Put and Break
-- ================================================

local function init(ctx)
    local Tabs       = ctx.Tabs
    local Fluent     = ctx.Fluent
    local Options    = ctx.Options
    local WorldManager = ctx.WorldManager
    local Inventory  = ctx.Inventory
    local RemoteFist = ctx.RemoteFist
    local RemotePlace = ctx.RemotePlace

    local playerTile          = ctx.playerTile
    local startFly            = ctx.startFly
    local stopFly             = ctx.stopFly
    local getUncollectedItems = ctx.getUncollectedItems
    local findStack           = ctx.findStack

    local farmActive = false

    -- Scan semua item unik yang bisa di-place di inventory
    local function getPlaceableItems()
        local ItemsManager = ctx.ItemsManager
        local seen = {}
        local list = {}
        for _, stack in pairs(Inventory.Stacks) do
            if stack and stack.Id and not seen[stack.Id] then
                local data = ItemsManager.ItemsData[stack.Id]
                if data and data.Tile then
                    seen[stack.Id] = true
                    table.insert(list, stack.Id)
                end
            end
        end
        table.sort(list)
        return list
    end

    -- Farm: place → punch sampai hancur → collect → balik → repeat
    local function startFarm(tileX, tileY, itemId)
        farmActive = true

        local standX, standY = playerTile()

        task.spawn(function()
            while farmActive do
                local px, py = playerTile()
                local dx, dy = math.abs(tileX - px), math.abs(tileY - py)
                if dx > 2 or dy > 2 then
                    startFly(standX, standY)
                    while ctx.getFlyConn() and farmActive do task.wait(0.1) end
                    if not farmActive then break end
                    task.wait(0.2)
                end

                local existingTile = WorldManager.GetTile(tileX, tileY, 1)
                if not existingTile then
                    local stackIdx = findStack(itemId)
                    if not stackIdx then
                        Fluent:Notify({ Title = "Auto Farm", Content = "Item habis! (" .. itemId .. ")", Duration = 3 })
                        break
                    end
                    RemotePlace:FireServer(Vector2.new(tileX, tileY), stackIdx)
                    task.wait(0.2)
                end

                while farmActive and WorldManager.GetTile(tileX, tileY, 1) do
                    RemoteFist:FireServer(Vector2.new(tileX, tileY))
                    task.wait(0.16)
                end

                if not farmActive then break end

                task.wait(0.3)
                local items = getUncollectedItems()
                if #items > 0 then
                    for _, item in ipairs(items) do
                        if item.part and item.part.Parent and not item.part:GetAttribute("t") then
                            local ix = math.floor(item.part.Position.X / 4.5 + 0.5)
                            local iy = math.floor(item.part.Position.Y / 4.5 + 0.5)
                            if math.abs(ix - tileX) <= 3 and math.abs(iy - tileY) <= 3 then
                                startFly(ix, iy)
                                while ctx.getFlyConn() and farmActive do task.wait(0.1) end
                                task.wait(0.3)
                            end
                        end
                    end
                end

                if not farmActive then break end

                local cx, cy = playerTile()
                if cx ~= standX or cy ~= standY then
                    startFly(standX, standY)
                    while ctx.getFlyConn() and farmActive do task.wait(0.1) end
                    task.wait(0.2)
                end

                if not farmActive then break end
                task.wait(0.1)
            end

            farmActive = false
            if Options.AutoFarm then Options.AutoFarm:SetValue(false) end
            Fluent:Notify({ Title = "Auto Farm", Content = "Farm berhenti.", Duration = 2 })
        end)
    end

    local function stopFarm()
        farmActive = false
        stopFly()
    end

    -- --------- Farm UI ---------

    Tabs.PnB:AddParagraph({
        Title   = "Put and Break",
        Content = "Place block → Punch sampai hancur → Collect drop → Repeat",
    })

    local farmItemDropdown = Tabs.PnB:AddDropdown("FarmItem", {
        Title   = "Item to Farm",
        Values  = {},
        Multi   = false,
        Default = nil,
    })

    Tabs.PnB:AddButton({
        Title       = "Refresh Items",
        Description = "Scan inventory untuk item yang bisa di-place",
        Callback    = function()
            local items = getPlaceableItems()
            farmItemDropdown:SetValues(items)
            if #items > 0 then
                Fluent:Notify({ Title = "Farm", Content = #items .. " item ditemukan.", Duration = 2 })
            else
                Fluent:Notify({ Title = "Farm", Content = "Tidak ada item yang bisa di-place!", Duration = 2 })
            end
        end,
    })

    Tabs.PnB:AddInput("FarmX", {
        Title       = "Farm Tile X",
        Default     = "50",
        Placeholder = "Tile X",
        Numeric     = true,
    })

    Tabs.PnB:AddInput("FarmY", {
        Title       = "Farm Tile Y",
        Default     = "10",
        Placeholder = "Tile Y",
        Numeric     = true,
    })

    Tabs.PnB:AddButton({
        Title       = "Set Farm Posisi Sekarang +1",
        Description = "Set tile X+1 dari posisi pemain saat ini",
        Callback    = function()
            local px, py = playerTile()
            Options.FarmX:SetValue(tostring(px + 1))
            Options.FarmY:SetValue(tostring(py))
            Fluent:Notify({ Title = "Farm", Content = "Target: " .. (px+1) .. ", " .. py, Duration = 2 })
        end,
    })

    Tabs.PnB:AddToggle("AutoFarm", {
        Title   = "Start Auto Farm",
        Default = false,
        Callback = function(val)
            if val then
                local itemId = Options.FarmItem and Options.FarmItem.Value
                if not itemId or itemId == "" then
                    Fluent:Notify({ Title = "Error", Content = "Pilih item dulu! Tekan Refresh Items.", Duration = 2 })
                    Options.AutoFarm:SetValue(false)
                    return
                end

                local tx = tonumber(Options.FarmX.Value)
                local ty = tonumber(Options.FarmY.Value)
                if not tx or not ty then
                    Fluent:Notify({ Title = "Error", Content = "Masukkan koordinat tile!", Duration = 2 })
                    Options.AutoFarm:SetValue(false)
                    return
                end

                Fluent:Notify({ Title = "Auto Farm", Content = "Farming " .. itemId .. " di (" .. tx .. "," .. ty .. ")", Duration = 3 })
                startFarm(tx, ty, itemId)
            else
                stopFarm()
            end
        end,
    })
end

return init
