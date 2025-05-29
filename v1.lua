---------------------------
-- Сервисы и переменные --
---------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Aimbot настройки
local aimbotEnabled = false
local visibilityCheck = true
local aimDistance = 100
local circleSize = 50
local silentAimEnabled = false

-- ESP настройки (общие и по компонентам)
local espEnabled = false
local espBoxesEnabled = false
local espTracersEnabled = false
local espHPBarEnabled = false
local espNameEnabled = true  -- включаем отображение ника
local espMaxDistance = 500   -- максимальное расстояние для ESP (в studs)

-- Таблица для хранения ESP объектов для каждого игрока
local playerESP = {}

---------------------------
-- Rayfield UI загрузка  --
---------------------------
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "d1xus bog",
    LoadingTitle = "Initializing...",
    LoadingSubtitle = "by d1xus",
    ConfigurationSaving = { Enabled = true, FileName = "AimbotConfig" },
    KeySystem = false
})

---------------------------
-- Aimbot вкладка        --
---------------------------
local AimbotTab = Window:CreateTab("Aimbot", "rewind")

local ToggleAimbot = AimbotTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Callback = function(state)
        aimbotEnabled = state
    end
})

local ToggleVisibility = AimbotTab:CreateToggle({
    Name = "Enable Visibility Check",
    CurrentValue = true,
    Callback = function(state)
        visibilityCheck = state
    end
})

local ToggleSilentAim = AimbotTab:CreateToggle({
    Name = "Enable Silent Aim",
    CurrentValue = false,
    Callback = function(state)
        silentAimEnabled = state
    end
})

local function getClosestTarget()
    local closestTarget = nil
    local closestDistance = aimDistance
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local head = player.Character:FindFirstChild("Head")
            if head and isVisible(head) then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local distToCircle = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude
                    local distanceFromLocal = (head.Position - Camera.CFrame.Position).Magnitude

                    if distToCircle < circleSize / 2 and distanceFromLocal < closestDistance then
                        closestDistance = distanceFromLocal
                        closestTarget = head
                    end
                end
            end
        end
    end
    return closestTarget
end

-- Круг аимбота (отображается всегда, если включён)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.IgnoreGuiInset = true -- убираем стандартные отступы Roblox
ScreenGui.Parent = game:GetService("CoreGui")
local Circle = Instance.new("Frame")
Circle.Size = UDim2.new(0, circleSize, 0, circleSize)
Circle.AnchorPoint = Vector2.new(0.5, 0.5)  -- центр фрейма
Circle.Position = UDim2.new(0.5, 0, 0.5, 0)   -- центр экрана
Circle.BackgroundTransparency = 1
Circle.Parent = ScreenGui
local UIStroke = Instance.new("UIStroke", Circle)
UIStroke.Thickness = 2
UIStroke.Color = Color3.fromRGB(255, 255, 255)
local UICorner = Instance.new("UICorner", Circle)
UICorner.CornerRadius = UDim.new(1, 0)

local ToggleCircle = AimbotTab:CreateToggle({
    Name = "Show Aimbot Circle",
    CurrentValue = true,
    Callback = function(state)
        Circle.Visible = state
    end
})

local CircleSizeSlider = AimbotTab:CreateSlider({
    Name = "Circle Size",
    Range = {20, 1000},
    Increment = 5,
    Suffix = "px",
    CurrentValue = circleSize,
    Callback = function(value)
        circleSize = value
        Circle.Size = UDim2.new(0, value, 0, value)
        -- благодаря AnchorPoint центр сохраняется автоматически
    end
})

local DistanceSlider = AimbotTab:CreateSlider({
    Name = "Aimbot Distance",
    Range = {10, 300},
    Increment = 10,
    Suffix = "m",
    CurrentValue = aimDistance,
    Callback = function(value)
        aimDistance = value
    end
})

local mt = getrawmetatable(game)
setreadonly(mt, false)

local oldNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if silentAimEnabled and method == "FireServer" and tostring(self):lower():find("shoot") then
        local target = getClosestTarget()
        if target then
            -- Заменяем позицию цели в аргументах на позицию головы цели
            for i, arg in pairs(args) do
                if typeof(arg) == "Vector3" then
                    args[i] = target.Position
                end
            end
            return oldNamecall(self, unpack(args))
        end
    end

    return oldNamecall(self, ...)
end)

setreadonly(mt, true)
---------------------------
-- ESP вкладка           --
---------------------------
local EspTab = Window:CreateTab("ESP", "eye")

-- Главный переключатель ESP
local ToggleESP = EspTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = false,
    Callback = function(state)
        espEnabled = state
        if not espEnabled then
            -- При отключении удаляем все ESP объекты
            for plr, drawings in pairs(playerESP) do
                for _, d in pairs(drawings) do
                    if d.Remove then d:Remove() end
                end
            end
            playerESP = {}
        else
            -- При включении создаём ESP для каждого игрока (кроме LocalPlayer)
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    createESPForPlayer(plr)
                end
            end
        end
    end
})

-- Переключатели для отдельных компонентов ESP
local ToggleESPBoxes = EspTab:CreateToggle({
    Name = "ESP Boxes",
    CurrentValue = false,
    Callback = function(state)
        espBoxesEnabled = state
    end
})

local ToggleESPLines = EspTab:CreateToggle({
    Name = "ESP Lines (Tracers)",
    CurrentValue = false,
    Callback = function(state)
        espTracersEnabled = state
    end
})

local ToggleESPHealth = EspTab:CreateToggle({
    Name = "ESP HP Bar",
    CurrentValue = false,
    Callback = function(state)
        espHPBarEnabled = state
    end
})

local ToggleESPName = EspTab:CreateToggle({
    Name = "ESP Name",
    CurrentValue = true,
    Callback = function(state)
        espNameEnabled = state
    end
})

-- Слайдер для максимальной дистанции ESP
local ESPDistanceSlider = EspTab:CreateSlider({
    Name = "ESP Max Distance",
    Range = {50, 1000},
    Increment = 50,
    Suffix = " studs",
    CurrentValue = espMaxDistance,
    Callback = function(value)
        espMaxDistance = value
    end
})

---------------------------
-- Функции Aimbot        --
---------------------------
-- Функция проверки видимости (Raycast)
local function isVisible(target)
    if not visibilityCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = (target.Position - origin).Unit * ((target.Position - origin).Magnitude)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(origin, direction, raycastParams)
    return result and result.Instance and result.Instance:IsDescendantOf(target.Parent)
end

-- Поиск ближайшей цели (сравнение с кругом аимбота)
local function getClosestTarget()
    local closestTarget = nil
    local closestDistance = aimDistance

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local head = player.Character:FindFirstChild("Head")
            if head and isVisible(head) then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                    local distToCircle = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude
                    if distToCircle < circleSize / 2 then
                        closestTarget = head
                        break
                    end
                end
            end
        end
    end
    return closestTarget
end

---------------------------
-- Функции ESP         --
---------------------------
-- Функция создания ESP объектов для игрока
function createESPForPlayer(plr)
    if plr == LocalPlayer then return end
    playerESP[plr] = {}
    local drawings = playerESP[plr]
    
    -- ESP Box (две линии: окантовка и основной бокс)
    drawings.boxBorder = Drawing.new("Quad")
    drawings.boxBorder.Visible = false
    drawings.boxBorder.Filled = false
    drawings.boxBorder.Thickness = 2
    drawings.boxBorder.Color = Color3.new(0, 0, 0)
    
    drawings.box = Drawing.new("Quad")
    drawings.box.Visible = false
    drawings.box.Filled = false
    drawings.box.Thickness = 1
    drawings.box.Color = Color3.new(1, 1, 1)
    
    -- ESP Tracers (линии)
    drawings.tracerBorder = Drawing.new("Line")
    drawings.tracerBorder.Visible = false
    drawings.tracerBorder.Thickness = 2
    drawings.tracerBorder.Color = Color3.new(0, 0, 0)
    
    drawings.tracer = Drawing.new("Line")
    drawings.tracer.Visible = false
    drawings.tracer.Thickness = 1
    drawings.tracer.Color = Color3.new(1, 1, 1)
    
    -- ESP HP Bar
    drawings.healthBarBorder = Drawing.new("Line")
    drawings.healthBarBorder.Visible = false
    drawings.healthBarBorder.Thickness = 3
    drawings.healthBarBorder.Color = Color3.new(0, 0, 0)
    
    drawings.healthBar = Drawing.new("Line")
    drawings.healthBar.Visible = false
    drawings.healthBar.Thickness = 1.5
    
    -- ESP Name (ник)
    drawings.name = Drawing.new("Text")
    drawings.name.Visible = false
    drawings.name.Color = Color3.new(1, 1, 1)
    drawings.name.Size = 14
    drawings.name.Font = 2  -- можно менять (например, 2 = Plex, если поддерживается)
    drawings.name.Center = true
    drawings.name.Outline = true
    drawings.name.OutlineColor = Color3.new(0, 0, 0)
    
    -- ESP Distance (расстояние до игрока) – текст будет размещён под боксом
    drawings.distance = Drawing.new("Text")
    drawings.distance.Visible = false
    drawings.distance.Color = Color3.new(1, 1, 1)
    drawings.distance.Size = 12
    drawings.distance.Font = 2
    drawings.distance.Center = true
    drawings.distance.Outline = true
    drawings.distance.OutlineColor = Color3.new(0, 0, 0)
end

-- При добавлении нового игрока – создать для него ESP (если включено)
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer and espEnabled then
        createESPForPlayer(plr)
    end
end)

-- При выходе игрока – удалить его ESP объекты
Players.PlayerRemoving:Connect(function(plr)
    if playerESP[plr] then
        for _, d in pairs(playerESP[plr]) do
            if d.Remove then d:Remove() end
        end
        playerESP[plr] = nil
    end
end)

---------------------------
-- RenderStepped цикл    --
---------------------------
RunService.RenderStepped:Connect(function()
    -- Обновляем позицию круга аимбота – всегда по центру экрана
    Circle.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    -- Aimbot: нацеливаем камеру на ближайшую цель внутри круга
    if aimbotEnabled then
        local target = getClosestTarget()
        if target then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        end
    end

    -- Обновляем ESP (если включено)
    if espEnabled then
        local localHRP = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
        for plr, drawings in pairs(playerESP) do
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and 
               plr.Character:FindFirstChild("Head") and plr.Character:FindFirstChild("Humanoid") then
               
                local hrp = plr.Character.HumanoidRootPart
                local head = plr.Character.Head
                local humanoid = plr.Character.Humanoid

                -- Если дистанция до игрока превышает espMaxDistance, скрываем все ESP элементы
                if localHRP and (localHRP.Position - hrp.Position).Magnitude > espMaxDistance then
                    drawings.boxBorder.Visible = false
                    drawings.box.Visible = false
                    drawings.tracerBorder.Visible = false
                    drawings.tracer.Visible = false
                    drawings.healthBar.Visible = false
                    drawings.healthBarBorder.Visible = false
                    drawings.name.Visible = false
                    drawings.distance.Visible = false
                else
                    local hrpPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen and humanoid.Health > 0 then
                        -- Получаем координаты головы для расчёта размера бокса
                        local headPos = Camera:WorldToViewportPoint(head.Position)
                        local distY = (Vector2.new(headPos.X, headPos.Y) - Vector2.new(hrpPos.X, hrpPos.Y)).Magnitude
                        distY = math.clamp(distY, 2, 1000)
                        
                        -- Вычисляем координаты углов бокса
                        local topLeft = Vector2.new(hrpPos.X - distY, hrpPos.Y - 2 * distY)
                        local topRight = Vector2.new(hrpPos.X + distY, hrpPos.Y - 2 * distY)
                        local bottomLeft = Vector2.new(hrpPos.X - distY, hrpPos.Y + 2 * distY)
                        local bottomRight = Vector2.new(hrpPos.X + distY, hrpPos.Y + 2 * distY)
                        
                        -- ESP Boxes
                        if espBoxesEnabled then
                            drawings.boxBorder.Visible = true
                            drawings.boxBorder.PointA = bottomRight
                            drawings.boxBorder.PointB = bottomLeft
                            drawings.boxBorder.PointC = topLeft
                            drawings.boxBorder.PointD = topRight

                            drawings.box.Visible = true
                            drawings.box.PointA = bottomRight
                            drawings.box.PointB = bottomLeft
                            drawings.box.PointC = topLeft
                            drawings.box.PointD = topRight
                        else
                            drawings.boxBorder.Visible = false
                            drawings.box.Visible = false
                        end
                        
                        -- ESP Tracers (линии)
                        if espTracersEnabled then
                            local origin = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                            local tracerEnd = Vector2.new((bottomLeft.X + bottomRight.X)/2, (bottomLeft.Y + bottomRight.Y)/2)
                            drawings.tracerBorder.Visible = true
                            drawings.tracerBorder.From = origin
                            drawings.tracerBorder.To = tracerEnd
                            drawings.tracer.Visible = true
                            drawings.tracer.From = origin
                            drawings.tracer.To = tracerEnd
                        else
                            drawings.tracerBorder.Visible = false
                            drawings.tracer.Visible = false
                        end
                        
                        -- ESP HP Bar с градиентом (от зелёного к красному)
                        if espHPBarEnabled then
                            local barHeight = (bottomLeft - topLeft).Magnitude
                            local healthRatio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            local healthOffset = barHeight * healthRatio
                            drawings.healthBarBorder.Visible = true
                            drawings.healthBarBorder.From = topLeft
                            drawings.healthBarBorder.To = bottomLeft
                            drawings.healthBar.Visible = true
                            drawings.healthBar.From = topLeft
                            drawings.healthBar.To = Vector2.new(topLeft.X, topLeft.Y + healthOffset)
                            drawings.healthBar.Color = Color3.new((1 - healthRatio), healthRatio, 0)
                        else
                            drawings.healthBarBorder.Visible = false
                            drawings.healthBar.Visible = false
                        end
                        
                        -- ESP Name (ник) – размещаем над боксом
                        if espNameEnabled then
                            drawings.name.Visible = true
                            drawings.name.Text = plr.DisplayName or plr.Name
                            local nameOffset = 5
                            drawings.name.Position = Vector2.new((topLeft.X + topRight.X) / 2, topLeft.Y - nameOffset)
                        else
                            drawings.name.Visible = false
                        end
                        
                        -- Отображение дистанции под боксом
                        if localHRP then
                            local distance = (localHRP.Position - hrp.Position).Magnitude
                            drawings.distance.Visible = true
                            drawings.distance.Text = string.format("%.0f studs", distance)
                            -- Размещаем дистанцию под боксом (на основе нижней точки бокса)
                            local distOffset = 5
                            drawings.distance.Position = Vector2.new((bottomLeft.X + bottomRight.X)/2, bottomRight.Y + distOffset)
                        else
                            drawings.distance.Visible = false
                        end
                    else
                        -- Если игрок не на экране или его нет, скрываем все ESP элементы
                        drawings.boxBorder.Visible = false
                        drawings.box.Visible = false
                        drawings.tracerBorder.Visible = false
                        drawings.tracer.Visible = false
                        drawings.healthBar.Visible = false
                        drawings.healthBarBorder.Visible = false
                        drawings.name.Visible = false
                        drawings.distance.Visible = false
                    end
                end
            else
                -- Если у игрока отсутствует персонаж, скрываем ESP
                drawings.boxBorder.Visible = false
                drawings.box.Visible = false
                drawings.tracerBorder.Visible = false
                drawings.tracer.Visible = false
                drawings.healthBar.Visible = false
                drawings.healthBarBorder.Visible = false
                drawings.name.Visible = false
                drawings.distance.Visible = false
            end
        end
    end
end)

---------------------------
-- Конфигурация UI       --
---------------------------
Rayfield:LoadConfiguration()
