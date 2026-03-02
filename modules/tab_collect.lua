-- ================================================
--   Tab Collect — Auto Collect Items
-- ================================================

local function init(ctx)
    local Tabs      = ctx.Tabs
    local Fluent    = ctx.Fluent
    local Options   = ctx.Options
    local RS        = ctx.RS

    local playerTile = ctx.playerTile
    local startFly   = ctx.startFly
    local stopFly    = ctx.stopFly

    local collectActive = false
    local collectQueue  = {}

    -- ══════════════════════════════════════════════════════════════
    -- SNAKE SORT — shared zigzag pattern (top to bottom, L↔R)
    -- ══════════════════════════════════════════════════════════════

    local function snakeSort(items)
        if #items == 0 then return items end

        local rows = {}
        for _, item in ipairs(items) do
            if not rows[item.y] then
                rows[item.y] = {}
            end
            table.insert(rows[item.y], item)
        end

        for _, row in pairs(rows) do
            table.sort(row, function(a, b) return a.x < b.x end)
        end

        local sortedYs = {}
        for y in pairs(rows) do
            table.insert(sortedYs, y)
        end
        table.sort(sortedYs, function(a, b) return a > b end)

        local sorted = {}
        for i, y in ipairs(sortedYs) do
            local row = rows[y]
            if i % 2 == 0 then
                for j = #row, 1, -1 do
                    table.insert(sorted, row[j])
                end
            else
                for _, item in ipairs(row) do
                    table.insert(sorted, item)
                end
            end
        end

        return sorted
    end

    -- ══════════════════════════════════════════════════════════════
    -- ITEM SCAN
    -- ══════════════════════════════════════════════════════════════

    local function getUncollectedItems()
        local items = {}
        local gemsFolder = workspace:FindFirstChild("Gems")
        local dropsFolder = workspace:FindFirstChild("Drops")

        if gemsFolder then
            for _, part in ipairs(gemsFolder:GetChildren()) do
                if part:IsA("Part") and not part:GetAttribute("t") then
                    local wx, wy = part.Position.X, part.Position.Y
                    local tx = math.round(wx / 4.5)
                    local ty = math.round(wy / 4.5)
                    table.insert(items, { x = tx, y = ty, type = "Gem", part = part })
                end
            end
        end

        if dropsFolder then
            for _, part in ipairs(dropsFolder:GetChildren()) do
                if part:IsA("Part") and not part:GetAttribute("t") then
                    local wx, wy = part.Position.X, part.Position.Y
                    local tx = math.round(wx / 4.5)
                    local ty = math.round(wy / 4.5)
                    local id = part:GetAttribute("id") or "?"
                    local amount = part:GetAttribute("amount") or 1
                    table.insert(items, { x = tx, y = ty, type = id .. " x" .. amount, part = part })
                end
            end
        end

        return snakeSort(items)
    end

    -- Export ke ctx
    ctx.getUncollectedItems = getUncollectedItems

    -- ══════════════════════════════════════════════════════════════
    -- COLLECT LOOP
    -- ══════════════════════════════════════════════════════════════

    local function collectNext()
        if not collectActive then return end

        while #collectQueue > 0 do
            local item = table.remove(collectQueue, 1)
            if item.part and item.part.Parent and not item.part:GetAttribute("t") then
                local wx, wy = item.part.Position.X, item.part.Position.Y
                local tx = math.round(wx / 4.5)
                local ty = math.round(wy / 4.5)

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

    -- ══════════════════════════════════════════════════════════════
    -- COLLECT UI
    -- ══════════════════════════════════════════════════════════════

    Tabs.Collect:AddParagraph({
        Title   = "Auto Collect",
        Content = "Otomatis kumpulkan semua item (gems & drops) di world.\nPola snake zigzag: atas ke bawah, kiri↔kanan per row.",
    })

    Tabs.Collect:AddToggle("AutoCollect", {
        Title   = "Start Auto Collect",
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