--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = ReplicatedStorage.SecureCast
local Utility = SecureCast.Utility

local DrawUtility = require(Utility.Draw)

---- Settings ----

---- Constants ----

local A = workspace:WaitForChild("A")
local B = workspace:WaitForChild("B")
local Player = Players.LocalPlayer

---- Variables ----

local Goal = A
local Active = false

---- Private Functions ----

---- Public Functions ----

---- Initialization ----

task.spawn(function()
    while true do
        if not Active then
            RunService.PostSimulation:Wait()
            continue
        end

        local Character = Player.Character
        local Humanoid: Humanoid? = Character and Character:FindFirstChild("Humanoid")

        if Humanoid then
            Humanoid:MoveTo(Goal.Position)
            Humanoid.MoveToFinished:Wait()
            Goal = (Goal == A and B or A)
        end

        RunService.Heartbeat:Wait()
    end
end)

---- Connections ----

UserInputService.InputBegan:Connect(function(Input, GameProcessedEvent)
    if GameProcessedEvent then
        return
    end

    if Input.KeyCode == Enum.KeyCode.X then
        Active = not Active
        print(`Auto movement: {Active}`)
    elseif Input.KeyCode == Enum.KeyCode.Delete then
        DrawUtility.getDefaultParent():ClearAllChildren()
    end
end)
