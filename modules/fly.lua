-- ================================================
--   Fly System with A* Pathfinding (FIXED)
-- ================================================

local function init(ctx)
    local RS           = ctx.RS
    local PM           = ctx.PM
    local WorldManager = ctx.WorldManager
    local ItemsManager = ctx.ItemsManager
    local Fluent       = ctx.Fluent
    local Options      = ctx.Options

    local flyConn    = nil
    local flyPath    = nil
    local flyIndex   = 0
    local FLY_SPEED  = 1.2

    -- ══════════════════════════════════════════════════════════════
    -- COORDINATE CONVERSION
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

    -- ══════════════════════════════════════════════════════════════
    -- TILE WALKABILITY
    --
    -- Collision types (from game engine):
    --   0 = no collision (walkable)
    --   1 = solid (blocked)
    --   2 = platform (blocks from below only, walkable for pathfinding)
    --   3 = door (depends on access: owner, public, color check)
    -- ══════════════════════════════════════════════════════════════

    local function isTileWalkable(x, y)
        local tileId, tileData = WorldManager.GetTile(x, y, 1)
        if not tileId then return true end

        -- Saplings are always walkable
        if type(tileId) == "string" and tileId:sub(-8) == "_sapling" then
            return true
        end

        -- Get item data for collision info
        local baseId = tileId
        if type(tileId) == "string" then
            baseId = tileId:gsub("_sapling$", "")
        end
        local itemData = ItemsManager.ItemsData[baseId] or ItemsManager.ItemsData[tileId]
        if not itemData or not itemData.Tile then return false end

        local collision = itemData.Tile.Collision or 1

        -- No collision
        if collision == 0 then return true end

        -- Platform (only blocks from below, walkable horizontally)
        if collision == 2 then return true end

        -- Door (check access)
        if collision == 3 then
            -- Door is open
            if tileData and tileData.open then return true end

            -- Check rendered tile color on layer 5 (lock_area overlay)
            local rendered = WorldManager.GetRenderedTile(x, y, 5)
            if rendered then
                -- Red = no access (blocked)
                if rendered.ImageColor3 == Color3.new(0.67451, 0, 0) then
                    return false
                end
                -- Green or Yellow = has access (walkable)
                return true
            end

            -- No render info — if WorldOwner exists, assume our world = walkable
            if workspace:GetAttribute("WorldOwner") then
                return true
            end

            return false
        end

        -- Collision 1 = solid (blocked)
        return false
    end

    -- ══════════════════════════════════════════════════════════════
    -- A* PATHFINDING
    -- ══════════════════════════════════════════════════════════════

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
    -- FLY MOVEMENT
    -- ══════════════════════════════════════════════════════════════

    local flyPosition: Vector3? = nil

    local function startFly(tx, ty)
        if flyConn then flyConn:Disconnect() end
        flyPath     = nil
        flyIndex    = 0
        flyPosition = nil

        local sx, sy = playerTile()

        local path = findPath(sx, sy, tx, ty)
        if not path or #path == 0 then
            Fluent:Notify({ Title = "Fly", Content = "Tidak ada jalur ke target!", Duration = 3 })
            if Options.FlyToggle then Options.FlyToggle:SetValue(false) end
            return
        end

        flyPath     = path
        flyIndex    = 1
        flyPosition = PM.Position

        Fluent:Notify({ Title = "Fly", Content = `Jalur ditemukan: {#path} tile`, Duration = 2 })

        flyConn = RS.Heartbeat:Connect(function(dt)
            if not flyPath or flyIndex > #flyPath then
                if flyPosition then
                    PM.Position    = flyPosition
                    PM.OldPosition = flyPosition
                end
                PM.VelocityX = 0
                PM.VelocityY = 0
                flyPath      = nil
                flyPosition  = nil
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
                flyPosition = target
                flyIndex   += 1
            else
                local step  = math.min(FLY_SPEED, dist)
                flyPosition = flyPosition + diff.Unit * step
            end

            PM.Position    = flyPosition
            PM.OldPosition = flyPosition
            PM.VelocityX   = 0
            PM.VelocityY   = 0
            PM.Grounded    = true
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