-- ================================================
--   Tab Harvest — Auto Harvest Trees
-- ================================================

local function init(ctx)
    local Tabs         = ctx.Tabs
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options
    local RS           = ctx.RS
    local WorldTiles   = ctx.WorldTiles
    local WorldManager = ctx.WorldManager
    local ItemsManager = ctx.ItemsManager
    local RemoteFist   = ctx.RemoteFist

    local playerTile          = ctx.playerTile
    local startFly            = ctx.startFly
    local stopFly             = ctx.stopFly
    local getUncollectedItems = ctx.getUncollectedItems

    local harvestActive = false
    local harvestFilter = "All"

    -- Scan WorldTiles untuk semua sapling (ready atau belum)
    local function scanAllSaplings()
        local treeTypes = {}

        for x, col in pairs(WorldTiles) do
            if type(col) == "table" then
                for y, layers in pairs(col) do
                    if type(layers) == "table" then
                        local tileId = WorldManager.GetTile(x, y, 1)
                        if tileId and type(tileId) == "string" and tileId:sub(-8) == "_sapling" then
                            local baseName = tileId:gsub("_sapling$", "")
                            local itemData = ItemsManager.RequestItemData(baseName)
                            local name = itemData.Name or baseName
                            treeTypes[name] = true
                        end
                    end
                end
            end
        end

        local list = { "All" }
        for name in pairs(treeTypes) do
            table.insert(list, name)
        end
        table.sort(list, function(a, b)
            if a == "All" then return true end
            if b == "All" then return false end
            return a < b
        end)
        return list
    end

    -- Scan WorldTiles untuk sapling yang sudah ready (dengan filter)
    local function getReadySaplings()
        local saplings = {}
        local now = workspace:GetServerTimeNow()

        for x, col in pairs(WorldTiles) do
            if type(col) == "table" then
                for y, layers in pairs(col) do
                    if type(layers) == "table" then
                        local tileId, tileData = WorldManager.GetTile(x, y, 1)
                        if tileId and type(tileId) == "string" and tileId:sub(-8) == "_sapling" then
                            local baseName = tileId:gsub("_sapling$", "")
                            local itemData = ItemsManager.RequestItemData(baseName)
                            local name = itemData.Name or baseName
                            local rarity = itemData.Rarity or 1
                            local growTime = (rarity ^ 3) + (30 * rarity)
                            local elapsed = now - (tileData and tileData.at or 0)

                            if harvestFilter == "All" or name == harvestFilter then
                                if elapsed >= growTime then
                                    table.insert(saplings, { x = x, y = y, name = name, tileId = tileId })
                                end
                            end
                        end
                    end
                end
            end
        end

        local px, py = playerTile()
        table.sort(saplings, function(a, b)
            local da = math.abs(a.x - px) + math.abs(a.y - py)
            local db = math.abs(b.x - px) + math.abs(b.y - py)
            return da < db
        end)

        return saplings
    end

    local function startHarvest()
        harvestActive = true

        task.spawn(function()
            while harvestActive do
                local saplings = getReadySaplings()
                if #saplings == 0 then
                    Fluent:Notify({ Title = "Auto Harvest", Content = "Tidak ada tree ready. Menunggu...", Duration = 3 })
                    for _ = 1, 50 do
                        if not harvestActive then break end
                        task.wait(0.1)
                    end
                    continue
                end

                Fluent:Notify({ Title = "Auto Harvest", Content = #saplings .. " tree ready!", Duration = 2 })

                for _, sap in ipairs(saplings) do
                    if not harvestActive then break end

                    startFly(sap.x, sap.y)
                    while ctx.getFlyConn() and harvestActive do task.wait(0.1) end
                    if not harvestActive then break end
                    task.wait(0.2)

                    RemoteFist:FireServer(Vector2.new(sap.x, sap.y))
                    task.wait(0.2)

                    for _ = 1, 5 do
                        if not harvestActive then break end
                        if not WorldManager.GetTile(sap.x, sap.y, 1) then break end
                        RemoteFist:FireServer(Vector2.new(sap.x, sap.y))
                        task.wait(0.16)
                    end

                    task.wait(0.3)
                    local items = getUncollectedItems()
                    for _, item in ipairs(items) do
                        if not harvestActive then break end
                        if item.part and item.part.Parent and not item.part:GetAttribute("t") then
                            local ix = math.floor(item.part.Position.X / 4.5 + 0.5)
                            local iy = math.floor(item.part.Position.Y / 4.5 + 0.5)
                            if math.abs(ix - sap.x) <= 3 and math.abs(iy - sap.y) <= 3 then
                                startFly(ix, iy)
                                while ctx.getFlyConn() and harvestActive do task.wait(0.1) end
                                task.wait(0.3)
                            end
                        end
                    end
                end

                if not harvestActive then break end
                task.wait(1)
            end

            harvestActive = false
            if Options.AutoHarvest then Options.AutoHarvest:SetValue(false) end
            Fluent:Notify({ Title = "Auto Harvest", Content = "Harvest berhenti.", Duration = 2 })
        end)
    end

    local function stopHarvest()
        harvestActive = false
        stopFly()
    end

    -- --------- Harvest UI ---------

    Tabs.Harvest:AddParagraph({
        Title   = "Auto Harvest",
        Content = "Otomatis panen tree yang sudah ready. Fly langsung ke tile tree.",
    })

    local harvestDropdown = Tabs.Harvest:AddDropdown("HarvestTree", {
        Title   = "Tree to Harvest",
        Values  = { "All" },
        Multi   = false,
        Default = "All",
        Callback = function(val)
            harvestFilter = val
        end,
    })

    Tabs.Harvest:AddButton({
        Title       = "Refresh Trees",
        Description = "Scan world untuk jenis tree yang ada",
        Callback    = function()
            local list = scanAllSaplings()
            harvestDropdown:SetValues(list)
            harvestDropdown:SetValue("All")
            Fluent:Notify({ Title = "Harvest", Content = (#list - 1) .. " jenis tree ditemukan.", Duration = 2 })
        end,
    })

    Tabs.Harvest:AddToggle("AutoHarvest", {
        Title   = "Start Auto Harvest",
        Default = false,
        Callback = function(val)
            if val then
                local saplings = getReadySaplings()
                local filterText = harvestFilter == "All" and "semua tree" or harvestFilter
                Fluent:Notify({ Title = "Auto Harvest", Content = "Harvest " .. filterText .. " (" .. #saplings .. " ready)", Duration = 3 })
                startHarvest()
            else
                stopHarvest()
            end
        end,
    })
end

return init
