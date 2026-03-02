-- ================================================
--   Tab Plant — Auto Plant Saplings (FIXED)
--
--   Changes:
--   1. plantFlyTo() uses flyPosition pattern (authoritative pos)
--   2. Uses ctx.tileToWorld / ctx.worldToTile for coordinate consistency
--   3. Grounded = true during fly to prevent gravity
--   4. Snap threshold 0.3 (matches fly module)
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

    local plantActive  = false
    local plantFlyConn = nil
    local findPath     = ctx.findPath
    local playerTile   = ctx.playerTile
    local tileToWorld  = ctx.tileToWorld

    -- ══════════════════════════════════════════════════════════════
    -- PLANT FLY — uses flyPosition pattern (matches fly module)
    -- ══════════════════════════════════════════════════════════════

    local function plantFlyTo(tx, ty)
        if plantFlyConn then plantFlyConn:Disconnect(); plantFlyConn = nil end

        local sx, sy = playerTile()

        -- Already at target tile
        if sx == tx and sy == ty then return true end

        local path = findPath(sx, sy, tx, ty)
        if not path or #path == 0 then return false end

        local pathIndex   = 1
        local arrived     = false
        local timeout     = 0
        local flyPosition = PM.Position  -- authoritative position during fly

        plantFlyConn = RS.Heartbeat:Connect(function(dt)
            -- Cancel check
            if not plantActive then
                PM.VelocityX = 0
                PM.VelocityY = 0
                PM.Grounded  = false
                arrived = true
                if plantFlyConn then plantFlyConn:Disconnect(); plantFlyConn = nil end
                return
            end

            -- Timeout safety
            timeout += dt
            if timeout > 30 then
                PM.VelocityX = 0
                PM.VelocityY = 0
                PM.Grounded  = false
                arrived = true
                if plantFlyConn then plantFlyConn:Disconnect(); plantFlyConn = nil end
                return
            end

            -- Path complete
            if pathIndex > #path then
                PM.Position    = flyPosition
                PM.OldPosition = flyPosition
                PM.VelocityX   = 0
                PM.VelocityY   = 0
                PM.Grounded    = false
                arrived = true
                if plantFlyConn then plantFlyConn:Disconnect(); plantFlyConn = nil end
                return
            end

            local wp     = path[pathIndex]
            local target = Vector3.new(tileToWorld(wp.x), tileToWorld(wp.y), 0)
            local diff   = target - flyPosition
            local dist   = diff.Magnitude

            if dist < 0.3 then
                flyPosition = target
                pathIndex  += 1
            else
                local speed = ctx.getFlySpeed()
                local step  = math.min(speed, dist)
                flyPosition = flyPosition + diff.Unit * step
            end

            -- Override physics every frame
            PM.Position    = flyPosition
            PM.OldPosition = flyPosition
            PM.VelocityX   = 0
            PM.VelocityY   = 0
            PM.Grounded    = true  -- prevent gravity accumulation
        end)

        while not arrived and plantActive do task.wait(0.1) end
        return arrived and plantActive
    end

    local function stopPlantFly()
        if plantFlyConn then plantFlyConn:Disconnect(); plantFlyConn = nil end
        PM.Grounded = false
    end

    -- ══════════════════════════════════════════════════════════════
    -- INVENTORY SCAN — find sapling items
    -- ══════════════════════════════════════════════════════════════

    local function getSaplingItems()
        local seen = {}
        local list = {}
        for _, stack in Inventory.Stacks do
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
    -- TILE SCAN — zigzag pattern for plantable tiles
    -- ══════════════════════════════════════════════════════════════

    local function getPlantableTiles()
        local tiles = {}

        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        for x, col in WorldTiles do
            if type(col) == "table" then
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                for y in col do
                    if type(y) == "number" then
                        if y < minY then minY = y end
                        if y > maxY then maxY = y end
                    end
                end
            end
        end

        if minX == math.huge then return tiles end

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

    -- ══════════════════════════════════════════════════════════════
    -- AUTO PLANT LOOP
    -- ══════════════════════════════════════════════════════════════

    local function startPlant(saplingId)
        plantActive = true

        task.spawn(function()
            while plantActive do
                local stackIdx = findStack(saplingId)
                if not stackIdx then
                    Fluent:Notify({ Title = "Auto Plant", Content = `Sapling habis! ({saplingId})`, Duration = 3 })
                    break
                end

                local tiles = getPlantableTiles()
                if #tiles == 0 then
                    Fluent:Notify({ Title = "Auto Plant", Content = "Tidak ada tile kosong untuk ditanami.", Duration = 3 })
                    break
                end

                Fluent:Notify({ Title = "Auto Plant", Content = `Menanam di {#tiles} tile...`, Duration = 2 })

                local planted = 0
                local skipped = 0

                for _, tile in tiles do
                    if not plantActive then break end

                    stackIdx = findStack(saplingId)
                    if not stackIdx then
                        Fluent:Notify({ Title = "Auto Plant", Content = "Sapling habis!", Duration = 3 })
                        plantActive = false
                        break
                    end

                    -- Skip if tile got filled while we were moving
                    if WorldManager.GetTile(tile.x, tile.y, 1) then
                        continue
                    end

                    local reached = plantFlyTo(tile.x, tile.y)
                    if not plantActive then break end

                    if not reached then
                        skipped += 1
                        continue
                    end

                    -- Re-check after arriving
                    stackIdx = findStack(saplingId)
                    if stackIdx and not WorldManager.GetTile(tile.x, tile.y, 1) then
                        RemotePlace:FireServer(Vector2.new(tile.x, tile.y), stackIdx)
                        planted += 1
                        task.wait(0.15)
                    end
                end

                if skipped > 0 then
                    Fluent:Notify({ Title = "Auto Plant", Content = `{skipped} tile dilewati (tidak terjangkau).`, Duration = 3 })
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
        stopPlantFly()
    end

    -- ══════════════════════════════════════════════════════════════
    -- PLANT UI
    -- ══════════════════════════════════════════════════════════════

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
                Fluent:Notify({ Title = "Plant", Content = `{#list} jenis sapling ditemukan.`, Duration = 2 })
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
                Fluent:Notify({ Title = "Auto Plant", Content = `Menanam {saplingId} ({#tiles} tile kosong)`, Duration = 3 })
                startPlant(saplingId)
            else
                stopPlant()
            end
        end,
    })
end

return init