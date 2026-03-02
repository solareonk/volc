-- ================================================
--   Fly System with A* Pathfinding
-- ================================================

local function init(ctx)
    local RS           = ctx.RS
    local PM           = ctx.PM
    local WorldManager = ctx.WorldManager
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options

    local flyConn    = nil
    local flyPath    = nil
    local flyIndex   = 0
    local FLY_SPEED  = 1.2

    local function playerTile()
        local p = PM.Position
        return math.floor(p.X / 4.5 + 0.5), math.floor(p.Y / 4.5 + 0.5)
    end

    local function isTileWalkable(x, y)
        local tileId = WorldManager.GetTile(x, y, 1)
        if not tileId then return true end
        if type(tileId) == "string" and tileId:sub(-8) == "_sapling" then
            return true
        end
        return false
    end

    -- A* Pathfinding
    local function findPath(sx, sy, gx, gy)
        if not isTileWalkable(gx, gy) then
            local found = false
            for r = 1, 10 do
                for dx = -r, r do
                    for dy = -r, r do
                        if math.abs(dx) == r or math.abs(dy) == r then
                            if isTileWalkable(gx + dx, gy + dy) then
                                gx, gy = gx + dx, gy + dy
                                found = true
                                break
                            end
                        end
                    end
                    if found then break end
                end
                if found then break end
            end
            if not found then return nil end
        end

        local open    = {}
        local closed  = {}
        local cameFrom = {}

        local function heuristic(ax, ay)
            return math.abs(ax - gx) + math.abs(ay - gy)
        end

        local function key(x, y)
            return x * 100000 + y
        end

        local startKey = key(sx, sy)
        open[startKey] = { x = sx, y = sy, g = 0, f = heuristic(sx, sy) }

        local dirs = { {1,0}, {-1,0}, {0,1}, {0,-1} }
        local iterations = 0
        local MAX_ITER = 15000

        while true do
            iterations = iterations + 1
            if iterations > MAX_ITER then return nil end

            local bestKey, bestNode = nil, nil
            for k, node in pairs(open) do
                if not bestNode or node.f < bestNode.f then
                    bestKey  = k
                    bestNode = node
                end
            end

            if not bestNode then return nil end

            local cx, cy = bestNode.x, bestNode.y

            if cx == gx and cy == gy then
                local path = {}
                local ck = key(cx, cy)
                while ck do
                    local n = cameFrom[ck]
                    if n then
                        table.insert(path, 1, { x = n.toX, y = n.toY })
                        ck = key(n.fromX, n.fromY)
                    else
                        break
                    end
                end
                return path
            end

            open[bestKey] = nil
            closed[bestKey] = true

            for _, d in ipairs(dirs) do
                local nx, ny = cx + d[1], cy + d[2]
                local nk = key(nx, ny)

                if not closed[nk] and isTileWalkable(nx, ny) then
                    local ng = bestNode.g + 1
                    local existing = open[nk]

                    if not existing or ng < existing.g then
                        open[nk] = { x = nx, y = ny, g = ng, f = ng + heuristic(nx, ny) }
                        cameFrom[nk] = { fromX = cx, fromY = cy, toX = nx, toY = ny }
                    end
                end
            end
        end
    end

    local function startFly(tx, ty)
        if flyConn then flyConn:Disconnect() end
        flyPath  = nil
        flyIndex = 0

        local sx, sy = playerTile()

        local path = findPath(sx, sy, tx, ty)
        if not path or #path == 0 then
            Fluent:Notify({ Title = "Fly", Content = "Tidak ada jalur ke target!", Duration = 3 })
            if Options.FlyToggle then Options.FlyToggle:SetValue(false) end
            return
        end

        flyPath  = path
        flyIndex = 1
        Fluent:Notify({ Title = "Fly", Content = "Jalur ditemukan: " .. #path .. " tile", Duration = 2 })

        flyConn = RS.Heartbeat:Connect(function()
            if not flyPath or flyIndex > #flyPath then
                PM.VelocityX = 0
                PM.VelocityY = 0
                flyPath = nil
                if flyConn then flyConn:Disconnect(); flyConn = nil end
                Fluent:Notify({ Title = "Fly", Content = "Sampai tujuan!", Duration = 3 })
                if Options.FlyToggle then Options.FlyToggle:SetValue(false) end
                return
            end

            local wp     = flyPath[flyIndex]
            local target = Vector3.new(wp.x * 4.5, wp.y * 4.5, 0)
            local pos    = PM.Position
            local diff   = target - pos
            local dist   = diff.Magnitude

            if dist < 0.5 then
                PM.Position    = target
                PM.OldPosition = target
                flyIndex = flyIndex + 1
            else
                local dir    = diff.Unit
                local step   = math.min(FLY_SPEED, dist)
                local newPos = pos + dir * step

                PM.Position    = newPos
                PM.OldPosition = newPos
            end

            PM.VelocityX = 0
            PM.VelocityY = 0
            PM.Grounded  = false
        end)
    end

    local function stopFly()
        flyPath  = nil
        flyIndex = 0
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
    end

    -- Export ke ctx
    ctx.playerTile      = playerTile
    ctx.isTileWalkable  = isTileWalkable
    ctx.findPath        = findPath
    ctx.startFly        = startFly
    ctx.stopFly         = stopFly
    ctx.getFlyConn      = function() return flyConn end
    ctx.setFlySpeed     = function(v) FLY_SPEED = v end
    ctx.getFlySpeed     = function() return FLY_SPEED end
end

return init
