--// === КОНФИГ ===
local CONFIG = {
	ENEMY_COLOR = Color3.fromRGB(255, 50, 50),
	TEAM_COLOR = Color3.fromRGB(50, 150, 255),
	TOGGLE_KEY = Enum.KeyCode.F,
	UPDATE_INTERVAL = 0.5,
	OUTLINE_THICKNESS = 2,
	MAX_DISTANCE = nil,
	SHOW_DISTANCE = true,
	DISTANCE_UPDATE_INTERVAL = 0.1,
}
local lastDistances = {}
--// === СЕРВИСЫ ===
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
--// === ОЧИСТКА ===
pcall(function()
	local old = CoreGui:FindFirstChild("PerfData")
	if old then old:Destroy() end
end)

--// === ПАПКА ===
local visualFolder = Instance.new("Folder")
visualFolder.Name = "PerfData"
visualFolder.Parent = CoreGui

--// === ПЕРЕМЕННЫЕ ===
local highlights = {}
local distanceLabels = {}
local vehicleCache = {}
local vehicleParts = {}
local isVisible = true
local lastUpdate = 0
local lastDistanceUpdate = 0

--// === УТИЛИТЫ ===
local function safeDestroy(obj)
	if obj and obj.Parent then obj:Destroy() end
end

-- 🔥 ОПОРНАЯ ЧАСТЬ ТАНКА (ФИКС)
local function getVehiclePart(vehicle)
	if vehicleParts[vehicle] and vehicleParts[vehicle].Parent then
		return vehicleParts[vehicle]
	end

	local part =
		vehicle:FindFirstChild("HullNode")
		or vehicle.PrimaryPart

	if not part then
		for _, d in ipairs(vehicle:GetDescendants()) do
			if d:IsA("BasePart") then
				part = d
				break
			end
		end
	end

	if part then
		vehicleParts[vehicle] = part
	end

	return part
end


local function getDistance(vehicle)
    local part = getVehiclePart(vehicle)
    if not part then return 0 end
    
    -- вектор от камеры к танку
    local dir = part.Position - Camera.CFrame.Position
    
    -- проекция на направление взгляда камеры (глубина)
    local depth = dir:Dot(Camera.CFrame.LookVector)
    
    local stud_distance = math.max(depth, 0)
    
    -- Переводим в "реальные" метры
    local real_meters = math.floor(stud_distance / 3.75 + 0.5)  -- +0.5 для нормального округления
    
    return real_meters
end

local function getPlayerFromVehicle(name)
	return Players:FindFirstChild(name:gsub("Chassis", ""))
end

--// === DISTANCE LABEL ===
local function createDistanceLabel(model)
	local part = getVehiclePart(model)
	if not part then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "DistanceLabel"
	gui.Adornee = part
	gui.Size = UDim2.new(0, 100, 0, 40)
	gui.StudsOffset = Vector3.new(0, 8, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = isVisible and CONFIG.SHOW_DISTANCE
	gui.Parent = visualFolder

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.BackgroundTransparency = 1
	txt.TextStrokeTransparency = 0
	txt.TextStrokeColor3 = Color3.new(0,0,0)
	txt.Font = Enum.Font.GothamBold
	txt.TextSize = 14
	txt.Text = getDistance(model) .. "m"
	txt.Parent = gui

	distanceLabels[model] = gui
end

local function updateDistanceLabel(model)
	local gui = distanceLabels[model]
	if not gui then return end

	local txt = gui:FindFirstChildOfClass("TextLabel")
	if not txt then return end

	local d = getDistance(model)
	txt.Text = d .. "m"

	if d < 200 then
		txt.TextColor3 = Color3.fromRGB(255,100,100)
	elseif d < 500 then
		txt.TextColor3 = Color3.fromRGB(255,255,100)
	else
		txt.TextColor3 = Color3.fromRGB(255,255,255)
	end
end

--// === HIGHLIGHT ===
local function getColor(vehicle)
	local p = getPlayerFromVehicle(vehicle.Name)
	if not p or p == LocalPlayer then return nil end
	if LocalPlayer.Team and p.Team then
		return (LocalPlayer.Team == p.Team) and CONFIG.TEAM_COLOR or CONFIG.ENEMY_COLOR
	end
	return CONFIG.ENEMY_COLOR
end

local function createHighlight(model, color)
	local h = Instance.new("Highlight")
	h.OutlineColor = color
	h.FillTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = model
	h.Enabled = isVisible
	h.Parent = visualFolder

	highlights[model] = h
	if CONFIG.SHOW_DISTANCE then
		createDistanceLabel(model)
	end
end

local function removeHighlight(model)
	safeDestroy(highlights[model])
	safeDestroy(distanceLabels[model])
	highlights[model] = nil
	distanceLabels[model] = nil
	vehicleParts[model] = nil
end

--// === UPDATE ===
local function updateAll()
	local folder = Workspace:FindFirstChild("Vehicles")
	if not folder then return end

	for _, v in ipairs(folder:GetChildren()) do
		if v:IsA("Actor") and v.Name:match("^Chassis") and not v.Name:match(LocalPlayer.Name) then
			local color = getColor(v)
			if color then
				if highlights[v] then
					highlights[v].OutlineColor = color
				else
					createHighlight(v, color)
				end
			else
				removeHighlight(v)
			end
		end
	end
end

--// === LOOP ===
RunService.Heartbeat:Connect(function()
	local t = tick()

	if t - lastUpdate >= CONFIG.UPDATE_INTERVAL then
		lastUpdate = t
		updateAll()
	end

	if CONFIG.SHOW_DISTANCE and t - lastDistanceUpdate >= CONFIG.DISTANCE_UPDATE_INTERVAL then
		lastDistanceUpdate = t
		for v in pairs(highlights) do
			updateDistanceLabel(v)
		end
	end
end)

--// === TOGGLE ===
UserInputService.InputBegan:Connect(function(i,g)
	if g then return end
	if i.KeyCode == CONFIG.TOGGLE_KEY then
		isVisible = not isVisible
		for _, h in pairs(highlights) do h.Enabled = isVisible end
		for _, d in pairs(distanceLabels) do d.Enabled = isVisible end
	end
end)

updateAll()
