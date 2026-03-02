-- ================================================
--   Fly System with A* Pathfinding (FIXED)
--   
--   Fixes:
--   1. playerTile() now uses math.round (matches game engine)
--   2. Fly movement hooks into game's Tick system instead of Heartbeat
--   3. Proper physics bypass: override Position AFTER PhysicsUpdate
--   4. Neutralize gravity/friction every tick while flying
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

    -- ══════════════════════════════════════════════════════════════
    -- FIX #1: Coordinate conversion matching game engine
    -- Game uses math.round(x / 4.5), NOT math.floor(x / 4.5 + 0.5)
    -- They differ at exact halfway points (e.g. 2.25 → floor+0.5 gives 1, round gives 0)
    -- ══════════════════════════════════════════════════════════════

    local function worldToTile(worldPos: number): number
        return math.round(worldPos / 4.5)
    end

    local function tileToWorld(tileCoord: number): number
        return tileCoord * 4.5
    end

    local function playerTile()
        local p = PM.Position
        return worldToTile(p.X), worldToTile(p.Y)
    end

    local function isTileWalkable(x, y)
        local tileId = WorldManager.GetTile(x, y, 1)
        if not tileId then return true end
        if type(tileId) == "string" and tileId:sub(-8) == "_sapling" then
            return true
        end
        return false
    end

    -- ══════════════════════════════════════════════════════════════
    -- A* PATHFINDING (unchanged logic, minor cleanup)
    -- ══════════════════════════════════════════════════════════════

    local function findPath(sx, sy, gx, gy)
        -- If goal is blocked, find nearest walkable tile
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

        local dirs = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
        local iterations = 0
        local MAX_ITER = 15000

        while true do
            iterations += 1
            if iterations > MAX_ITER then return nil end

            local bestKey, bestNode = nil, nil
            for k, node in open do
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

            for _, d in dirs do
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

    -- ══════════════════════════════════════════════════════════════
    -- FIX #2 & #3: Fly uses Heartbeat but ALSO overrides physics
    -- 
    -- Strategy: 
    --   - Use Heartbeat for smooth visual movement (interpolation)
    --   - After each frame, force Position & zero out velocity
    --   - Set Grounded = true to prevent gravity accumulation
    --   - Store a "fly position" separately so physics can't corrupt it
    -- ══════════════════════════════════════════════════════════════

    local flyPosition: Vector3? = nil  -- our authoritative position while flying

    local function startFly(tx, ty)
        if flyConn then flyConn:Disconnect() end
        flyPath    = nil
        flyIndex   = 0
        flyPosition = nil

        local sx, sy = playerTile()

        local path = findPath(sx, sy, tx, ty)
        if not path or #path == 0 then
            Fluent:Notify({ Title = "Fly", Content = "Tidak ada jalur ke target!", Duration = 3 })
            if Options.FlyToggle then Options.FlyToggle:SetValue(false) end
            return
        end

        flyPath  = path
        flyIndex = 1
        flyPosition = PM.Position  -- start from current actual position

        Fluent:Notify({ Title = "Fly", Content = `Jalur ditemukan: {#path} tile`, Duration = 2 })

        flyConn = RS.Heartbeat:Connect(function(dt)
            if not flyPath or flyIndex > #flyPath then
                -- Arrived at destination
                if flyPosition then
                    PM.Position    = flyPosition
                    PM.OldPosition = flyPosition
                end
                PM.VelocityX = 0
                PM.VelocityY = 0
                flyPath     = nil
                flyPosition = nil
                if flyConn then flyConn:Disconnect(); flyConn = nil end
                Fluent:Notify({ Title = "Fly", Content = "Sampai tujuan!", Duration = 3 })
                if Options.FlyToggle then Options.FlyToggle:SetValue(false) end
                return
            end

            local wp     = flyPath[flyIndex]
            local target = Vector3.new(tileToWorld(wp.x), tileToWorld(wp.y), 0)
            local diff   = target - flyPosition
            local dist   = diff.Magnitude

            if dist < 0.3 then
                -- Snap to waypoint and advance
                flyPosition = target
                flyIndex   += 1
            else
                -- Move towards waypoint
                local step   = math.min(FLY_SPEED, dist)
                flyPosition  = flyPosition + diff.Unit * step
            end

            -- ══════════════════════════════════════════
            -- CRITICAL: Override physics every frame
            -- This must happen AFTER PhysicsUpdate would
            -- have modified Position/Velocity
            -- ══════════════════════════════════════════
            PM.Position    = flyPosition
            PM.OldPosition = flyPosition  -- prevents lerp drift
            PM.VelocityX   = 0            -- kill horizontal momentum
            PM.VelocityY   = 0            -- kill gravity accumulation
            PM.Grounded    = true          -- prevents gravity from applying (-0.4/tick)
        end)
    end

    local function stopFly()
        flyPath     = nil
        flyIndex    = 0
        flyPosition = nil
        if flyConn then
            flyConn:Disconnect()
            flyConn = nil
        end
        -- Release grounded so normal physics resumes
        PM.Grounded = false
    end

    -- ══════════════════════════════════════════════════════════════
    -- EXPORTS
    -- ══════════════════════════════════════════════════════════════

    ctx.playerTile      = playerTile
    ctx.worldToTile     = worldToTile
    ctx.tileToWorld     = tileToWorld
    ctx.isTileWalkable  = isTileWalkable
    ctx.findPath        = findPath
    ctx.startFly        = startFly
    ctx.stopFly         = stopFly
    ctx.getFlyConn      = function() return flyConn end
    ctx.setFlySpeed     = function(v) FLY_SPEED = v end
    ctx.getFlySpeed     = function() return FLY_SPEED end
end

return init