-- ================================================
--   Tab Movement — Fly UI & Auto Collect
-- ================================================

local function init(ctx)
    local Tabs      = ctx.Tabs
    local Fluent    = ctx.Fluent
    local Options   = ctx.Options
    local RS        = ctx.RS
    local Players   = ctx.Players
    local LocalPlayer = ctx.LocalPlayer

    local playerTile = ctx.playerTile
    local startFly   = ctx.startFly
    local stopFly    = ctx.stopFly

    -- --------- Fly UI ---------

    Tabs.Movement:AddParagraph({
        Title   = "Fly to Tile",
        Content = "Terbang langsung ke tile target. Noclip menembus dinding.",
    })

    Tabs.Movement:AddInput("TargetX", {
        Title       = "Target X",
        Default     = "50",
        Placeholder = "Tile X",
        Numeric     = true,
    })

    Tabs.Movement:AddInput("TargetY", {
        Title       = "Target Y",
        Default     = "10",
        Placeholder = "Tile Y",
        Numeric     = true,
    })

    Tabs.Movement:AddSlider("FlySpeed", {
        Title    = "Fly Speed",
        Default  = 1.2,
        Min      = 0.3,
        Max      = 5,
        Rounding = 1,
        Callback = function(val)
            ctx.setFlySpeed(val)
        end,
    })

    Tabs.Movement:AddToggle("FlyToggle", {
        Title   = "Fly to Target",
        Default = false,
        Callback = function(val)
            if val then
                local tx = tonumber(Options.TargetX.Value) or 50
                local ty = tonumber(Options.TargetY.Value) or 10
                local px, py = playerTile()
                Fluent:Notify({ Title = "Fly", Content = "Terbang dari ("..px..","..py..") ke ("..tx..","..ty..")", Duration = 2 })
                startFly(tx, ty)
            else
                stopFly()
            end
        end,
    })

    Tabs.Movement:AddButton({
        Title       = "Fly ke Player Terdekat",
        Description = "Terbang ke pemain terdekat",
        Callback    = function()
            local px, py = playerTile()
            local closest, closestDist = nil, math.huge

            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local root = plr.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local tx = math.floor(root.Position.X / 4.5 + 0.5)
                        local ty = math.floor(root.Position.Y / 4.5 + 0.5)
                        local dist = math.abs(tx - px) + math.abs(ty - py)
                        if dist < closestDist then
                            closestDist = dist
                            closest = { x = tx, y = ty, name = plr.Name }
                        end
                    end
                end
            end

            if not closest then
                Fluent:Notify({ Title = "Error", Content = "Tidak ada player lain!", Duration = 2 })
                return
            end

            Fluent:Notify({ Title = "Fly", Content = "Terbang ke " .. closest.name, Duration = 2 })
            Options.FlyToggle:SetValue(true)
            startFly(closest.x, closest.y)
        end,
    })

    -- --------- Auto Collect ---------

    local collectActive = false
    local collectQueue  = {}

    local function getUncollectedItems()
        local items = {}
        local gemsFolder = workspace:FindFirstChild("Gems")
        local dropsFolder = workspace:FindFirstChild("Drops")

        if gemsFolder then
            for _, part in ipairs(gemsFolder:GetChildren()) do
                if part:IsA("Part") and not part:GetAttribute("t") then
                    local wx, wy = part.Position.X, part.Position.Y
                    local tx = math.floor(wx / 4.5 + 0.5)
                    local ty = math.floor(wy / 4.5 + 0.5)
                    table.insert(items, { x = tx, y = ty, type = "Gem", part = part })
                end
            end
        end

        if dropsFolder then
            for _, part in ipairs(dropsFolder:GetChildren()) do
                if part:IsA("Part") and not part:GetAttribute("t") then
                    local wx, wy = part.Position.X, part.Position.Y
                    local tx = math.floor(wx / 4.5 + 0.5)
                    local ty = math.floor(wy / 4.5 + 0.5)
                    local id = part:GetAttribute("id") or "?"
                    local amount = part:GetAttribute("amount") or 1
                    table.insert(items, { x = tx, y = ty, type = id .. " x" .. amount, part = part })
                end
            end
        end

        local px, py = playerTile()
        table.sort(items, function(a, b)
            local da = math.abs(a.x - px) + math.abs(a.y - py)
            local db = math.abs(b.x - px) + math.abs(b.y - py)
            return da < db
        end)

        return items
    end

    -- Export getUncollectedItems ke ctx (dipakai PnB, Harvest)
    ctx.getUncollectedItems = getUncollectedItems

    local function collectNext()
        if not collectActive then return end

        while #collectQueue > 0 do
            local item = table.remove(collectQueue, 1)
            if item.part and item.part.Parent and not item.part:GetAttribute("t") then
                local wx, wy = item.part.Position.X, item.part.Position.Y
                local tx = math.floor(wx / 4.5 + 0.5)
                local ty = math.floor(wy / 4.5 + 0.5)

                startFly(tx, ty)

                local checkConn
                checkConn = RS.Heartbeat:Connect(function()
                    if not ctx.getFlyConn() then
                        checkConn:Disconnect()
                        task.wait(0.3)
                        if collectActive and #collectQueue == 0 then
                            local newItems = getUncollectedItems()
                            if #newItems > 0 then
                                collectQueue = newItems
                            end
                        end
                        collectNext()
                    end
                end)
                return
            end
        end

        collectActive = false
        Fluent:Notify({ Title = "Auto Collect", Content = "Selesai! Semua item sudah dicollect.", Duration = 3 })
        if Options.AutoCollect then Options.AutoCollect:SetValue(false) end
    end

    Tabs.Movement:AddToggle("AutoCollect", {
        Title   = "Auto Collect Items",
        Default = false,
        Callback = function(val)
            if val then
                local items = getUncollectedItems()
                if #items == 0 then
                    Fluent:Notify({ Title = "Auto Collect", Content = "Tidak ada item untuk dicollect!", Duration = 2 })
                    Options.AutoCollect:SetValue(false)
                    return
                end
                collectActive = true
                collectQueue  = items
                Fluent:Notify({ Title = "Auto Collect", Content = "Mengumpulkan " .. #items .. " item...", Duration = 2 })
                collectNext()
            else
                collectActive = false
                collectQueue  = {}
                stopFly()
            end
        end,
    })
end

return init
