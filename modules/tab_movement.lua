-- ================================================
--   Tab Movement — Fly UI
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

    -- ══════════════════════════════════════════════════════════════
    -- FLY UI
    -- ══════════════════════════════════════════════════════════════

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
                        local tx = math.round(root.Position.X / 4.5)
                        local ty = math.round(root.Position.Y / 4.5)
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
end

return init