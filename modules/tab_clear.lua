-- ================================================
--   Tab Clear — Clear World
-- ================================================

local function init(ctx)
    local Tabs         = ctx.Tabs
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options
    local RS           = ctx.RS
    local PM           = ctx.PM
    local WorldTiles   = ctx.WorldTiles
    local WorldManager = ctx.WorldManager
    local RemoteFist   = ctx.RemoteFist

    local playerTile      = ctx.playerTile
    local isTileWalkable  = ctx.isTileWalkable
    local findPath        = ctx.findPath

    local clearActive  = false
    local clearFlyConn = nil

    -- Fly khusus clear (tanpa notifikasi, tanpa FlyToggle)
    local function clearFlyTo(tx, ty)
        if clearFlyConn then clearFlyConn:Disconnect(); clearFlyConn = nil end

        local sx, sy = playerTile()
        if sx == tx and sy == ty then return end

        local path = findPath(sx, sy, tx, ty)
        if not path or #path == 0 then return end

        local pathIndex = 1
        local arrived = false
        local FLY_SPEED = ctx.getFlySpeed()

        clearFlyConn = RS.Heartbeat:Connect(function()
            if not clearActive or pathIndex > #path then
                PM.VelocityX = 0
                PM.VelocityY = 0
                arrived = true
                if clearFlyConn then clearFlyConn:Disconnect(); clearFlyConn = nil end
                return
            end

            local wp = path[pathIndex]
            local target = Vector3.new(wp.x * 4.5, wp.y * 4.5, 0)
            local pos = PM.Position
            local diff = target - pos
            local dist = diff.Magnitude

            if dist < 0.5 then
                PM.Position = target
                PM.OldPosition = target
                pathIndex = pathIndex + 1
            else
                local dir = diff.Unit
                local step = math.min(FLY_SPEED, dist)
                local newPos = pos + dir * step
                PM.Position = newPos
                PM.OldPosition = newPos
            end

            PM.VelocityX = 0
            PM.VelocityY = 0
            PM.Grounded = false
        end)

        while not arrived and clearActive do task.wait(0.1) end
    end

    -- Punch tile sampai foreground & background hancur
    local function clearPunchTile(x, y)
        local maxHits = 10
        local hits = 0
        while clearActive and WorldManager.GetTile(x, y, 1) do
            RemoteFist:FireServer(Vector2.new(x, y))
            task.wait(0.16)
            hits = hits + 1
            if hits >= maxHits then break end
        end
        hits = 0
        while clearActive and WorldManager.GetTile(x, y, 2) do
            RemoteFist:FireServer(Vector2.new(x, y))
            task.wait(0.16)
            hits = hits + 1
            if hits >= maxHits then break end
        end
    end

    local function startClear()
        clearActive = true

        task.spawn(function()
            local minX, maxX = math.huge, -math.huge
            local minY, maxY = math.huge, -math.huge
            for x, col in pairs(WorldTiles) do
                if type(col) == "table" then
                    for y in pairs(col) do
                        if type(y) == "number" then
                            local fg = WorldManager.GetTile(x, y, 1)
                            local bg = WorldManager.GetTile(x, y, 2)
                            if fg or bg then
                                if fg and type(fg) == "string" and fg:lower():find("bedrock") then
                                    continue
                                end
                                if x < minX then minX = x end
                                if x > maxX then maxX = x end
                                if y < minY then minY = y end
                                if y > maxY then maxY = y end
                            end
                        end
                    end
                end
            end

            if minX == math.huge then
                Fluent:Notify({ Title = "Clear World", Content = "Tidak ada tile di world!", Duration = 3 })
                clearActive = false
                if Options.ClearWorld then Options.ClearWorld:SetValue(false) end
                return
            end

            local totalCols = maxX - minX + 1
            local totalRows = maxY - minY + 1
            Fluent:Notify({ Title = "Clear World", Content = "Clearing " .. totalCols .. "x" .. totalRows .. " area\nY: " .. maxY .. "→" .. minY .. " | Start: (" .. minX .. ", " .. (maxY + 1) .. ")", Duration = 5 })

            clearFlyTo(minX, maxY + 1)
            if not clearActive then return end
            task.wait(0.2)

            local goingRight = true

            for y = maxY, minY, -1 do
                if not clearActive then break end

                local startX, endX, stepX
                if goingRight then
                    startX, endX, stepX = minX, maxX, 1
                else
                    startX, endX, stepX = maxX, minX, -1
                end

                for x = startX, endX, stepX do
                    if not clearActive then break end

                    local hasFg = WorldManager.GetTile(x, y, 1)
                    local hasBg = WorldManager.GetTile(x, y, 2)

                    if hasFg and type(hasFg) == "string" and hasFg:lower():find("bedrock") then
                        continue
                    end

                    if hasFg or hasBg then
                        local adjX, adjY
                        if x == startX then
                            adjX, adjY = x, y + 1
                        else
                            adjX, adjY = x - stepX, y
                        end

                        if not isTileWalkable(adjX, adjY) then
                            adjX, adjY = x, y + 1
                        end

                        clearFlyTo(adjX, adjY)
                        if not clearActive then break end
                        task.wait(0.05)

                        clearPunchTile(x, y)
                        if not clearActive then break end

                        if not WorldManager.GetTile(x, y, 1) then
                            clearFlyTo(x, y)
                            if not clearActive then break end
                            task.wait(0.05)
                        end
                    end
                end

                goingRight = not goingRight
            end

            clearActive = false
            if clearFlyConn then clearFlyConn:Disconnect(); clearFlyConn = nil end
            if Options.ClearWorld then Options.ClearWorld:SetValue(false) end
            Fluent:Notify({ Title = "Clear World", Content = "Selesai!", Duration = 3 })
        end)
    end

    local function stopClear()
        clearActive = false
        if clearFlyConn then clearFlyConn:Disconnect(); clearFlyConn = nil end
    end

    -- --------- Clear UI ---------

    Tabs.Clear:AddParagraph({
        Title   = "Clear World",
        Content = "Hancurkan semua block (foreground + background) di world.\nPola zigzag (snake) dari bawah ke atas.",
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
