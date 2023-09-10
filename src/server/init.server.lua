--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = require(ReplicatedStorage.SecureCast)

---- Settings ----

local MAXIMUM_LATENCY = 0.8 -- 800 ms

---- Constants ----

local Events = ReplicatedStorage.Events
local SimulateEvent = Events.Simulate

---- Variables ----

local Modifier = {
	Power = 1_000,
}

---- Private Functions ----

---- Public Functions ----

---- Initialization ----

--> Only call once per context
SecureCast.Initialize()

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

	--> Retrieve an array of the player's hitboxes lag compensated, this may be nil!
	local Orienations = SecureCast.Snapshots.GetPlayerAtTime(Latency)
	if not Orienations then
		warn(`Unable to do lag compensation for {Player}.`)
		return
	end

	--> We do distance checks with the lag compensated positions, this means we can do a much tighter distance check.
	local Distance = (Origin - Orienations[1].Position).Magnitude
	if Distance > 1 then
		warn(`{Player} is too far from the projectile origin.`)
		return
	end
	
	--> WARNING: Make sure to replicate your modifier to the client as well or the simulation will desync
	SimulateEvent:FireAllClients(Player, "Bullet", Origin, Direction, Modifier)
	SecureCast.Cast(Player, "Bullet", Origin, Direction, os.clock() - Latency, nil, Modifier)
end)
