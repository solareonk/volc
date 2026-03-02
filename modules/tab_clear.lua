-- ================================================
--   Tab Clear — Clear World (FIXED)
--
--   Fix: Uses startFly/stopFly from fly module
--   instead of separate clearFlyTo system.
-- ================================================

local function init(ctx)
    local Tabs         = ctx.Tabs
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options
    local RS           = ctx.RS
    local WorldTiles   = ctx.WorldTiles
    local WorldManager = ctx.WorldManager
    local RemoteFist   = ctx.RemoteFist

    local playerTile     = ctx.playerTile
    local isTileWalkable = ctx.isTileWalkable
    local startFly       = ctx.startFly
    local stopFly        = ctx.stopFly

    local clearActive = false

    -- ══════════════════════════════════════════════════════════════
    -- FLY TO TILE — reuses fly module (same pattern as Plant/Harvest)
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
        while not done and clearActive do
            task.wait(0.1)
            elapsed += 0.1
            if elapsed > 30 then
                if checkConn then checkConn:Disconnect() end
                stopFly()
                return false
            end
        end

        return done and clearActive
    end

    -- ══════════════════════════════════════════════════════════════
    -- PUNCH TILE — destroy foreground & background
    -- ══════════════════════════════════════════════════════════════

    local function clearPunchTile(x, y)
        local maxHits = 10

        -- Punch foreground (layer 1)
        local hits = 0
        while clearActive and WorldManager.GetTile(x, y, 1) do
            RemoteFist:FireServer(Vector2.new(x, y))
            task.wait(0.16)
            hits += 1
            if hits >= maxHits then break end
        end

        -- Punch background (layer 2)
        hits = 0
        while clearActive and WorldManager.GetTile(x, y, 2) do
            RemoteFist:FireServer(Vector2.new(x, y))
            task.wait(0.16)
            hits += 1
            if hits >= maxHits then break end
        end
    end

    -- ══════════════════════════════════════════════════════════════
    -- TILE SCAN — collect all clearable tiles in snake order
    -- ══════════════════════════════════════════════════════════════

    local function getClearableTiles()
        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge

        -- First pass: find bounds of clearable tiles
        for x, col in pairs(WorldTiles) do
            if type(col) == "table" then
                for y in pairs(col) do
                    if type(y) == "number" then
                        local fg = WorldManager.GetTile(x, y, 1)
                        local bg = WorldManager.GetTile(x, y, 2)

                        -- Skip bedrock
                        if fg and type(fg) == "string" and fg:lower():find("bedrock") then
                            continue
                        end

                        -- Skip walkable foreground tiles (doors, platforms, saplings)
                        if fg and ctx.isTileWalkable(x, y) and not bg then
                            continue
                        end

                        if fg or bg then
                            if x < minX then minX = x end
                            if x > maxX then maxX = x end
                            if y < minY then minY = y end
                            if y > maxY then maxY = y end
                        end
                    end
                end
            end
        end

        if minX == math.huge then return {}, nil end

        -- Second pass: collect tiles with content, grouped by row
        local rowTiles = {}
        for x = minX, maxX do
            for y = minY, maxY do
                local fg = WorldManager.GetTile(x, y, 1)
                local bg = WorldManager.GetTile(x, y, 2)

                if fg and type(fg) == "string" and fg:lower():find("bedrock") then
                    continue
                end

                -- Skip walkable tiles (doors, platforms, saplings)
                -- These are not solid blocks that need clearing
                if fg and ctx.isTileWalkable(x, y) then
                    -- Only skip if there's no background to clear either
                    if not bg then continue end
                end

                if fg or bg then
                    if not rowTiles[y] then
                        rowTiles[y] = {}
                    end
                    table.insert(rowTiles[y], { x = x, y = y })
                end
            end
        end

        -- Sort each row by X (left to right)
        for _, row in pairs(rowTiles) do
            table.sort(row, function(a, b) return a.x < b.x end)
        end

        -- Sort Y highest first (top to bottom)
        local sortedYs = {}
        for y in pairs(rowTiles) do
            table.insert(sortedYs, y)
        end
        table.sort(sortedYs, function(a, b) return a > b end)

        -- Snake zigzag
        local tiles = {}
        for i, y in ipairs(sortedYs) do
            local row = rowTiles[y]
            if i % 2 == 0 then
                for j = #row, 1, -1 do
                    table.insert(tiles, row[j])
                end
            else
                for _, tile in ipairs(row) do
                    table.insert(tiles, tile)
                end
            end
        end

        local bounds = { minX = minX, maxX = maxX, minY = minY, maxY = maxY }
        return tiles, bounds
    end

    -- ══════════════════════════════════════════════════════════════
    -- CLEAR LOOP
    -- ══════════════════════════════════════════════════════════════

    local function startClear()
        clearActive = true

        task.spawn(function()
            local tiles, bounds = getClearableTiles()

            if #tiles == 0 then
                Fluent:Notify({ Title = "Clear World", Content = "Tidak ada tile di world!", Duration = 3 })
                clearActive = false
                if Options.ClearWorld then Options.ClearWorld:SetValue(false) end
                return
            end

            local totalCols = bounds.maxX - bounds.minX + 1
            local totalRows = bounds.maxY - bounds.minY + 1
            Fluent:Notify({
                Title = "Clear World",
                Content = "Clearing " .. #tiles .. " tiles (" .. totalCols .. "x" .. totalRows .. " area)",
                Duration = 5,
            })

            -- Fly to starting position: above top-left corner
            local startX = bounds.minX
            local startY = bounds.maxY + 1
            Fluent:Notify({ Title = "Clear World", Content = "Fly ke posisi start (" .. startX .. ", " .. startY .. ")...", Duration = 2 })
            local reached = flyToAndWait(startX, startY)
            if not clearActive then return end
            if not reached then
                Fluent:Notify({ Title = "Clear World", Content = "Gagal ke posisi start!", Duration = 3 })
                clearActive = false
                if Options.ClearWorld then Options.ClearWorld:SetValue(false) end
                return
            end
            task.wait(0.2)

            local cleared = 0
            local lastTile = { x = startX, y = startY }

            for _, tile in ipairs(tiles) do
                if not clearActive then break end

                local fg = WorldManager.GetTile(tile.x, tile.y, 1)
                local bg = WorldManager.GetTile(tile.x, tile.y, 2)

                if fg and type(fg) == "string" and fg:lower():find("bedrock") then
                    continue
                end

                if not fg and not bg then continue end

                -- Find adjacent walkable tile based on context:
                -- Prefer: above first (cleared area), then direction we came from
                local adjTile = nil
                local candidates = {
                    { x = tile.x, y = tile.y + 1 },         -- above (already cleared)
                    { x = lastTile.x, y = lastTile.y },     -- where we just were
                    { x = tile.x - 1, y = tile.y },         -- left
                    { x = tile.x + 1, y = tile.y },         -- right
                    { x = tile.x, y = tile.y - 1 },         -- below
                }

                for _, c in ipairs(candidates) do
                    -- Don't stand on the tile we're about to punch
                    if c.x == tile.x and c.y == tile.y then continue end
                    if isTileWalkable(c.x, c.y) then
                        adjTile = c
                        break
                    end
                end

                if not adjTile then continue end

                reached = flyToAndWait(adjTile.x, adjTile.y)
                if not clearActive then break end
                if not reached then continue end

                task.wait(0.05)

                clearPunchTile(tile.x, tile.y)
                if not clearActive then break end

                -- Move into cleared tile
                if not WorldManager.GetTile(tile.x, tile.y, 1) then
                    flyToAndWait(tile.x, tile.y)
                    if not clearActive then break end
                    lastTile = { x = tile.x, y = tile.y }
                    task.wait(0.05)
                end

                cleared += 1
            end

            clearActive = false
            stopFly()
            if Options.ClearWorld then Options.ClearWorld:SetValue(false) end
            Fluent:Notify({ Title = "Clear World", Content = "Selesai! " .. cleared .. " tiles cleared.", Duration = 3 })
        end)
    end

    local function stopClear()
        clearActive = false
        stopFly()
    end

    -- ══════════════════════════════════════════════════════════════
    -- CLEAR UI
    -- ══════════════════════════════════════════════════════════════

    Tabs.Clear:AddParagraph({
        Title   = "Clear World",
        Content = "Hancurkan semua block (foreground + background) di world.\nPola snake zigzag dari atas ke bawah.\nBedrock di-skip otomatis.",
    })

    Tabs.Clear:AddToggle("ClearWorld", {
        Title   = "Start Clear World",
        Default = false,
        Callback = function(val)
            if val then
                Fluent:Notify({ Title = "Clear World", Content = "Memulai clear world...", Duration = 2 })
                startClear()
            else
                stopClear()
            end
        end,
    })
end

return init