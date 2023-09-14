--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

---- Imports ----

local SecureCast = script.Parent.Parent
local Utility = SecureCast.Utility

local Simulation = require(SecureCast.Simulation)
local DrawUtility = require(Utility.Draw)

---- Settings ----

local IS_CLIENT = RunService:IsClient()

---- Functions ----

local function OnImpact(Player: Player, Direction: Vector3, Instance: Instance, Normal: Vector3, Position: Vector3, Material: Enum.Material)
	DrawUtility.point(Position, nil, nil, 0.2)
end

local function OnDestroyed(Player: Player, Position: Vector3)
	
end

local function OnIntersection(Player: Player, Direction: Vector3, Part: string, Victim: Player, Position: Vector3)
	local Character = Victim.Character
	local Humanoid: Humanoid? = Character and Character:FindFirstChild("Humanoid") :: Humanoid
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end
	
	Humanoid:TakeDamage(10) 
	print(`Intersected {Victim}'s {Part}`)
end

---- Projectile ----

local Projectile: Simulation.Definition = {
	Loss = 0,
	Power = 50,
	Angle = 20,
	Collaterals = false,
	
	Gravity = -8,
	Velocity = 100,
	
	Lifetime = 5,
	
	OnImpact = OnImpact,
	OnDestroyed = OnDestroyed,
	OnIntersection = OnIntersection
}

return Projectile