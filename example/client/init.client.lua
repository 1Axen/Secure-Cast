--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

---- Imports ----

local SecureCast = require(ReplicatedStorage.SecureCast)

---- Settings ----

---- Constants ----

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local Events = ReplicatedStorage.Events
local SimulateEvent = Events.Simulate

---- Variables ----

---- Private Functions ----

---- Public Functions ----

---- Initialization ----

--> Only call once per context
SecureCast.Initialize()

---- Connections ----

UserInputService.InputBegan:Connect(function(Input, GPE)
	if GPE or Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local Character = Player.Character
	local Head = Character and Character:FindFirstChild("Head")
	if not Head then
		return
	end
	
	local Origin = Head.Position
	local Direction = (Mouse.Hit.Position - Origin).Unit
	
	local Time = workspace:GetServerTimeNow()
	SimulateEvent:FireServer(Origin, Direction, Time)
	SecureCast.Cast(Player, "Bullet", Origin, Direction, Time)
end)

SimulateEvent.OnClientEvent:Connect(function(Caster: Player, Type: string, Origin: Vector3, Direction: Vector3, PVInstance: PVInstance?, Modifer)
	if Caster ~= Player then
		SecureCast.Cast(Caster, Type, Origin, Direction, workspace:GetServerTimeNow(), PVInstance, Modifer)
	end
end)