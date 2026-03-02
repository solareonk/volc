-- ================================================
--   Tab Plant — Auto Plant Saplings (DEBUG VERSION)
--
--   TEMPORARY: Has debug prints to diagnose tile selection.
--   Remove prints after confirming fix works.
-- ================================================

local function init(ctx)
    local Tabs         = ctx.Tabs
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options
    local WorldTiles   = ctx.WorldTiles
    local WorldManager = ctx.WorldManager
    local Inventory    = ctx.Inventory
    local RemotePlace  = ctx.RemotePlace

    local RS         = ctx.RS
    local PM         = ctx.PM
    local findStack  = ctx.findStack
    local playerTile = ctx.playerTile
    local startFly   = ctx.startFly
    local stopFly    = ctx.stopFly

    local plantActive = false

    -- ══════════════════════════════════════════════════════════════
    -- FLY TO TILE — reuses fly module (same as Auto Collect)
    -- ══════════════════════════════════════════════════════════════

    local function flyToAndWait(tx, ty)
        local sx, sy = playerTile()
        if sx == tx and sy == ty then return true end

        startFly(tx, ty)

        local done = false
        local checkConn
        checkConn = RS.Heartbeat:Connect(function()
            if not ctx.getFlyConn() then
                checkConn:Disconnect()
                done = true
            end
        end)

        local elapsed = 0
        while not done and plantActive do
            task.wait(0.1)
            elapsed += 0.1
            if elapsed > 30 then
                if checkConn then checkConn:Disconnect() end
                stopFly()
                return false
            end
        end

        return done and plantActive
    end

    -- ══════════════════════════════════════════════════════════════
    -- INVENTORY SCAN
    -- ══════════════════════════════════════════════════════════════

    local function getSaplingItems()
        local seen = {}
        local list = {}
        for _, stack in pairs(Inventory.Stacks) do
            if stack and stack.Id and not seen[stack.Id] then
                if type(stack.Id) == "string" and stack.Id:sub(-8) == "_sapling" then
                    seen[stack.Id] = true
                    table.insert(list, stack.Id)
                end
            end
        end
        table.sort(list)
        return list
    end

    -- ══════════════════════════════════════════════════════════════
    -- TILE SCAN — with DEBUG PRINTS
    -- ══════════════════════════════════════════════════════════════

    local function isSolidTile(x, y)
        local tileId = WorldManager.GetTile(x, y, 1)
        if not tileId then return false end
        if type(tileId) == "string" and tileId:sub(-8) == "_sapling" then
            return false
        end
        return true
    end

    local function getPlantableTiles()
        local tiles = {}

        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        for x, col in pairs(WorldTiles) do
            if type(col) == "table" then
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                for y in pairs(col) do
                    if type(y) == "number" then
                        if y < minY then minY = y end
                        if y > maxY then maxY = y end
                    end
                end
            end
        end

        if minX == math.huge then return tiles end

        -- DEBUG: print world bounds
        print("[Plant DEBUG] World bounds: X=" .. minX .. ".." .. maxX .. " Y=" .. minY .. ".." .. maxY)

        local plantMaxY = maxY + 1

        local goingRight = true
        for y = plantMaxY, minY, -1 do
            if goingRight then
                for x = minX, maxX do
                    local isEmpty = not WorldManager.GetTile(x, y, 1)
                    local hasSolidBelow = isSolidTile(x, y - 1)
                    if isEmpty and hasSolidBelow then
                        table.insert(tiles, { x = x, y = y })
                    end
                end
            else
                for x = maxX, minX, -1 do
                    local isEmpty = not WorldManager.GetTile(x, y, 1)
                    local hasSolidBelow = isSolidTile(x, y - 1)
                    if isEmpty and hasSolidBelow then
                        table.insert(tiles, { x = x, y = y })
                    end
                end
            end
            goingRight = not goingRight
        end

        -- DEBUG: print first 10 tiles selected
        print("[Plant DEBUG] Found " .. #tiles .. " plantable tiles")
        for i = 1, math.min(10, #tiles) do
            local t = tiles[i]
            local below = WorldManager.GetTile(t.x, t.y - 1, 1)
            print("[Plant DEBUG] Tile #" .. i .. ": (" .. t.x .. ", " .. t.y .. ") below=" .. tostring(below))
        end

        return tiles
    end

    -- ══════════════════════════════════════════════════════════════
    -- AUTO PLANT LOOP
    -- ══════════════════════════════════════════════════════════════

    local function startPlant(saplingId)
        plantActive = true

        task.spawn(function()
            while plantActive do
                local stackIdx = findStack(saplingId)
                if not stackIdx then
                    Fluent:Notify({ Title = "Auto Plant", Content = "Sapling habis! (" .. saplingId .. ")", Duration = 3 })
                    break
                end

                local tiles = getPlantableTiles()
                if #tiles == 0 then
                    Fluent:Notify({ Title = "Auto Plant", Content = "Tidak ada tile kosong untuk ditanami.", Duration = 3 })
                    break
                end

                Fluent:Notify({ Title = "Auto Plant", Content = "Menanam di " .. #tiles .. " tile...", Duration = 2 })

                local planted = 0
                local skipped = 0

                for _, tile in ipairs(tiles) do
                    if not plantActive then break end

                    -- DEBUG: print which tile we're flying to
                    print("[Plant DEBUG] Flying to (" .. tile.x .. ", " .. tile.y .. ")")

                    stackIdx = findStack(saplingId)
                    if not stackIdx then
                        Fluent:Notify({ Title = "Auto Plant", Content = "Sapling habis!", Duration = 3 })
                        plantActive = false
                        break
                    end

                    if WorldManager.GetTile(tile.x, tile.y, 1) then
                        continue
                    end

                    local reached = flyToAndWait(tile.x, tile.y)
                    if not plantActive then break end

                    if not reached then
                        skipped = skipped + 1
                        continue
                    end

                    stackIdx = findStack(saplingId)
                    if stackIdx and not WorldManager.GetTile(tile.x, tile.y, 1) then
                        RemotePlace:FireServer(Vector2.new(tile.x, tile.y), stackIdx)
                        planted = planted + 1
                        task.wait(0.15)
                    end
                end

                if skipped > 0 then
                    Fluent:Notify({ Title = "Auto Plant", Content = skipped .. " tile dilewati (tidak terjangkau).", Duration = 3 })
                end

                break
            end

            plantActive = false
            stopFly()
            if Options.AutoPlant then Options.AutoPlant:SetValue(false) end
            Fluent:Notify({ Title = "Auto Plant", Content = "Selesai menanam.", Duration = 2 })
        end)
    end

    local function stopPlant()
        plantActive = false
        stopFly()
    end

    -- ══════════════════════════════════════════════════════════════
    -- PLANT UI
    -- ══════════════════════════════════════════════════════════════

    Tabs.Plant:AddParagraph({
        Title   = "Auto Plant",
        Content = "Otomatis tanam sapling di semua tile kosong di atas permukaan.\nPola zigzag: kiri→kanan, kanan→kiri per row.",
    })

    local plantDropdown = Tabs.Plant:AddDropdown("PlantSapling", {
        Title   = "Sapling to Plant",
        Values  = {},
        Multi   = false,
        Default = nil,
    })

    Tabs.Plant:AddButton({
        Title       = "Refresh Saplings",
        Description = "Scan inventory untuk sapling",
        Callback    = function()
            local list = getSaplingItems()
            plantDropdown:SetValues(list)
            if #list > 0 then
                Fluent:Notify({ Title = "Plant", Content = #list .. " jenis sapling ditemukan.", Duration = 2 })
            else
                Fluent:Notify({ Title = "Plant", Content = "Tidak ada sapling di inventory!", Duration = 2 })
            end
        end,
    })

    -- DEBUG: button to test tile scan without planting
    Tabs.Plant:AddButton({
        Title       = "DEBUG: Scan Tiles",
        Description = "Print plantable tiles ke console (F9)",
        Callback    = function()
            local tiles = getPlantableTiles()
            Fluent:Notify({ Title = "Debug", Content = #tiles .. " tiles found. Check F9 console.", Duration = 5 })
        end,
    })

    Tabs.Plant:AddToggle("AutoPlant", {
        Title   = "Start Auto Plant",
        Default = false,
        Callback = function(val)
            if val then
                local saplingId = Options.PlantSapling and Options.PlantSapling.Value
                if not saplingId or saplingId == "" then
                    Fluent:Notify({ Title = "Error", Content = "Pilih sapling dulu! Tekan Refresh Saplings.", Duration = 2 })
                    Options.AutoPlant:SetValue(false)
                    return
                end
                local tiles = getPlantableTiles()
                Fluent:Notify({ Title = "Auto Plant", Content = "Menanam " .. saplingId .. " (" .. #tiles .. " tile kosong)", Duration = 3 })
                startPlant(saplingId)
            else
                stopPlant()
            end
        end,
    })
end

return init