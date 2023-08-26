--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = ReplicatedStorage.SecureCast

local Dispatcher = require(SecureCast.Dispatcher)
local Simulation = require(SecureCast.Simulation)

---- Settings ----

local MAXIMUM_LATENCY = 0.8 -- 800 ms

---- Constants ----

local Events = ReplicatedStorage.Events
local SimulateEvent = Events.Simulate

local SimulationDispatcher = Dispatcher.new(4, SecureCast.Simulation, Simulation.Process)

---- Variables ----

---- Private Functions ----

---- Public Functions ----

---- Initialization ----

--> Only call once per context
Simulation.ImportDefentions()

---- Connections ----

Players.PlayerAdded:Connect(function(Player: Player)
	Player.CharacterAdded:Connect(function(Character)
		RunService.PostSimulation:Wait()
		Character.Parent = workspace.Characters
	end)
end)

ReplicatedStorage.Events.Simulate.OnServerEvent:Connect(function(Player: Player, Origin: Vector3, Direction: Vector3, Timestamp: number)
	local Latency = (workspace:GetServerTimeNow() - Timestamp)
	if (Latency < 0) or (Latency > MAXIMUM_LATENCY) then
		return
	end
	
	SimulateEvent:FireAllClients(Player, "Bullet", Origin, Direction)
	SimulationDispatcher:Dispatch(Player, "Bullet", Origin, Direction, os.clock() - Latency)
end)
