--[[ SETTINGS ]]--
getgenv().Settings = {
    SilentAim = true,
    ToggleKey = Enum.KeyCode.Q,
    UnlockKey = Enum.KeyCode.LeftAlt,
    TargetPart = "HumanoidRootPart",
    Prediction = 0.1,
    Offset = 0.6,
    Resolver = false,
    HealthThreshold = 1,
    TeamCheck = true,
    FOVRadius = 120,
    FOVThreshold = 0.5
}

--[[ SERVICES ]]--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--[[ VARIABLES ]]--
local Victim = nil
local LockedTarget = nil
local Velocity = Vector3.zero
local OldPosition = Vector3.zero

--[[ DRAW FOV ]]--
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = true
FOVCircle.Radius = Settings.FOVRadius
FOVCircle.Color = Color3.fromRGB(0, 255, 140)
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 0.6

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y)
    FOVCircle.Visible = Settings.SilentAim
end)

--[[ TOGGLES ]]--
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Settings.ToggleKey then
        Settings.SilentAim = not Settings.SilentAim
    elseif input.KeyCode == Settings.UnlockKey then
        LockedTarget = nil
    end
end)

--[[ VISIBILITY ]]--
local function IsVisible(part)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true

    local result = workspace:Raycast(
        Camera.CFrame.Position,
        part.Position - Camera.CFrame.Position,
        params
    )

    return result and result.Instance:IsDescendantOf(part.Parent)
end

--[[ FOV CHECK ]]--
local function IsInFOV(part)
    local dir = (part.Position - Camera.CFrame.Position).Unit
    return dir:Dot(Camera.CFrame.LookVector) > Settings.FOVThreshold
end

--[[ VALID TARGET CHECK ]]--
local function IsValidTarget(part)
    if not part or not part.Parent then return false end

    local humanoid = part.Parent:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= Settings.HealthThreshold then
        return false
    end

    local ok, screenPos = pcall(Camera.WorldToViewportPoint, Camera, part.Position)
    if not ok or screenPos.Z <= 0 then return false end

    local dist = (Vector2.new(Mouse.X, Mouse.Y) -
                  Vector2.new(screenPos.X, screenPos.Y)).Magnitude

    return dist <= Settings.FOVRadius
       and IsVisible(part)
       and IsInFOV(part)
end

--[[ TARGET SELECTION + LOCK ]]--
local function GetClosestTarget()
    if LockedTarget and IsValidTarget(LockedTarget) then
        return LockedTarget
    end

    LockedTarget = nil
    local closest, shortest = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer
        and player.Character
        and player.Character:FindFirstChild(Settings.TargetPart) then

            if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                continue
            end

            local part = player.Character[Settings.TargetPart]
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health > Settings.HealthThreshold then
                local ok, screenPos =
                    pcall(Camera.WorldToViewportPoint, Camera, part.Position)

                if ok and screenPos.Z > 0
                and IsVisible(part)
                and IsInFOV(part) then

                    local dist =
                        (Vector2.new(Mouse.X, Mouse.Y) -
                         Vector2.new(screenPos.X, screenPos.Y)).Magnitude

                    if dist < shortest and dist <= Settings.FOVRadius then
                        shortest = dist
                        closest = part
                    end
                end
            end
        end
    end

    LockedTarget = closest
    return closest
end

--[[ VELOCITY TRACKING ]]--
RunService.Heartbeat:Connect(function(dt)
    if LockedTarget and LockedTarget.Parent then
        local pos = LockedTarget.Position
        local delta = pos - OldPosition
        local est = delta / math.max(dt, 0.01)

        Velocity = Velocity:Lerp(Vector3.new(
            est.X,
            est.Y * 0.94 * Settings.Offset,
            est.Z
        ), 0.4)

        OldPosition = pos
    end
end)

--[[ SILENT AIM HOOK ]]--
if not getgenv().__silent_hooked then
    local mt = getrawmetatable(game)
    setreadonly(mt, false)

    local old = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()

        if Settings.SilentAim
        and (tostring(self):lower():find("hit")
        or tostring(self):lower():find("target")) then

            Victim = GetClosestTarget()

            if Victim and Victim.Parent then
                local predicted =
                    Settings.Resolver
                    and Victim.Position + (Velocity * Settings.Prediction)
                    or Victim.Position + (Victim.Velocity * Settings.Prediction)

                if method == "FireServer" or method == "InvokeServer" then
                    if typeof(args[1]) == "Vector3" then
                        args[1] = predicted
                    elseif typeof(args[1]) == "CFrame" then
                        args[1] = CFrame.new(predicted)
                    end
                end
            end
        end

        return old(self, unpack(args))
    end)

    setreadonly(mt, true)
    getgenv().__silent_hooked = true
end
