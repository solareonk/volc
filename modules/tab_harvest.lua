-- ================================================
--   Tab Harvest — Auto Harvest Trees (DEBUG)
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

    local playerTile = ctx.playerTile
    local startFly   = ctx.startFly
    local stopFly    = ctx.stopFly

    local harvestActive = false
    local harvestFilter = "All"

    -- ══════════════════════════════════════════════════════════════
    -- DEBUG LOG
    -- ══════════════════════════════════════════════════════════════

    local debugLog = {}

    local function log(msg)
        print(msg)
        table.insert(debugLog, msg)
    end

    local function flushLog(filename)
        if #debugLog > 0 then
            pcall(function()
                writefile(filename or "harvest_debug.txt", table.concat(debugLog, "\n"))
            end)
        end
    end

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

    -- Scan WorldTiles untuk sapling yang sudah ready
    -- Sorted snake zigzag: atas ke bawah, kiri↔kanan per row
    local function getReadySaplings()
        debugLog = {}
        local now = workspace:GetServerTimeNow()

        -- Step 1: Collect ALL ready saplings into a flat list first
        local allReady = {}

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
                                    table.insert(allReady, {
                                        x = x, y = y, name = name, tileId = tileId
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end

        log("[Harvest DEBUG] Total ready saplings found: " .. #allReady)

        if #allReady == 0 then
            flushLog("harvest_debug.txt")
            return {}
        end

        -- Step 2: Group by Y
        local rowSaplings = {}
        for _, sap in ipairs(allReady) do
            if not rowSaplings[sap.y] then
                rowSaplings[sap.y] = {}
            end
            table.insert(rowSaplings[sap.y], sap)
        end

        -- Step 3: Sort each row by X (left to right)
        for y, row in pairs(rowSaplings) do
            table.sort(row, function(a, b) return a.x < b.x end)
            log("[Harvest DEBUG] Row Y=" .. y .. ": " .. #row .. " saplings, X range=" .. row[1].x .. ".." .. row[#row].x)
        end

        -- Step 4: Get sorted Y values (highest first = top to bottom)
        local sortedYs = {}
        for y in pairs(rowSaplings) do
            table.insert(sortedYs, y)
        end
        table.sort(sortedYs, function(a, b) return a > b end)

        log("[Harvest DEBUG] Sorted rows (top to bottom): " .. table.concat(sortedYs, ", "))

        -- Step 5: Snake zigzag
        local saplings = {}
        for i, y in ipairs(sortedYs) do
            local row = rowSaplings[y]
            local direction = (i % 2 == 1) and "L->R" or "R->L"
            log("[Harvest DEBUG] Row #" .. i .. " Y=" .. y .. " direction=" .. direction)

            if i % 2 == 0 then
                -- Even row: right → left
                for j = #row, 1, -1 do
                    table.insert(saplings, row[j])
                end
            else
                -- Odd row: left → right
                for _, sap in ipairs(row) do
                    table.insert(saplings, sap)
                end
            end
        end

        -- Debug: print final order
        log("[Harvest DEBUG] === FINAL ORDER ===")
        for i, sap in ipairs(saplings) do
            log("[Harvest DEBUG] #" .. i .. ": (" .. sap.x .. ", " .. sap.y .. ") " .. sap.name)
        end

        flushLog("harvest_debug.txt")
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

                for idx, sap in ipairs(saplings) do
                    if not harvestActive then break end

                    print("[Harvest] #" .. idx .. " Flying to (" .. sap.x .. ", " .. sap.y .. ") " .. sap.name)

                    -- Fly to tree
                    startFly(sap.x, sap.y)
                    while ctx.getFlyConn() and harvestActive do task.wait(0.1) end
                    if not harvestActive then break end
                    task.wait(0.2)

                    -- Punch tree until broken
                    RemoteFist:FireServer(Vector2.new(sap.x, sap.y))
                    task.wait(0.2)

                    for _ = 1, 5 do
                        if not harvestActive then break end
                        if not WorldManager.GetTile(sap.x, sap.y, 1) then break end
                        RemoteFist:FireServer(Vector2.new(sap.x, sap.y))
                        task.wait(0.16)
                    end

                    task.wait(0.15)
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
        Content = "Otomatis panen tree yang sudah ready.\nPola snake zigzag: atas ke bawah, kiri↔kanan per row.\nGunakan Auto Collect untuk mengambil drop.",
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

    -- DEBUG: button to test sorting without harvesting
    Tabs.Harvest:AddButton({
        Title       = "DEBUG: Scan Order",
        Description = "Print harvest order ke file (workspace/harvest_debug.txt)",
        Callback    = function()
            local saplings = getReadySaplings()
            Fluent:Notify({ Title = "Debug", Content = #saplings .. " saplings. Check harvest_debug.txt", Duration = 5 })
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