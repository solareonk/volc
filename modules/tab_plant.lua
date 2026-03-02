-- ================================================
--   Tab Plant — Auto Plant Saplings
-- ================================================

local function init(ctx)
    local Tabs         = ctx.Tabs
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options
    local WorldTiles   = ctx.WorldTiles
    local WorldManager = ctx.WorldManager
    local Inventory    = ctx.Inventory
    local RemotePlace  = ctx.RemotePlace

    local startFly   = ctx.startFly
    local stopFly    = ctx.stopFly
    local findStack  = ctx.findStack

    local plantActive = false

    -- Scan inventory untuk sapling items
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

    -- Scan semua tile kosong di world, zigzag kiri↔kanan per row
    local function getPlantableTiles()
        local tiles = {}

        -- Hitung world bounds
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

        -- Zigzag: per row dari atas (maxY) ke bawah (minY)
        local goingRight = true
        for y = maxY, minY, -1 do
            if goingRight then
                for x = minX, maxX do
                    if not WorldManager.GetTile(x, y, 1) then
                        table.insert(tiles, { x = x, y = y })
                    end
                end
            else
                for x = maxX, minX, -1 do
                    if not WorldManager.GetTile(x, y, 1) then
                        table.insert(tiles, { x = x, y = y })
                    end
                end
            end
            goingRight = not goingRight
        end

        return tiles
    end

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

                for _, tile in ipairs(tiles) do
                    if not plantActive then break end

                    stackIdx = findStack(saplingId)
                    if not stackIdx then
                        Fluent:Notify({ Title = "Auto Plant", Content = "Sapling habis!", Duration = 3 })
                        plantActive = false
                        break
                    end

                    if WorldManager.GetTile(tile.x, tile.y, 1) then
                        continue
                    end

                    startFly(tile.x, tile.y)
                    while ctx.getFlyConn() and plantActive do task.wait(0.1) end
                    if not plantActive then break end
                    task.wait(0.2)

                    stackIdx = findStack(saplingId)
                    if stackIdx and not WorldManager.GetTile(tile.x, tile.y, 1) then
                        RemotePlace:FireServer(Vector2.new(tile.x, tile.y), stackIdx)
                        task.wait(0.2)
                    end
                end

                break
            end

            plantActive = false
            if Options.AutoPlant then Options.AutoPlant:SetValue(false) end
            Fluent:Notify({ Title = "Auto Plant", Content = "Selesai menanam.", Duration = 2 })
        end)
    end

    local function stopPlant()
        plantActive = false
        stopFly()
    end

    -- --------- Plant UI ---------

    Tabs.Plant:AddParagraph({
        Title   = "Auto Plant",
        Content = "Otomatis tanam sapling di semua tile kosong.\nPola zigzag: kiri→kanan, kanan→kiri per row.",
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
