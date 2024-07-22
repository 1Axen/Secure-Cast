# Simulation

In this section we will explore setting up a basic simulation along side the different things we must account for in order to create a working simulation.

---

## Setting up your workspace

SecureCast requires a `Map` and `Characters` folder placed within workspace to function correctly.<br>
All parts of the map must be a descendant of the `Map` folder. <br>
All player characters must be paranted to the `Characters` folder.

We will also need an `Events` folder within ReplicatedStorage.
Add a RemoteEvent named `Simulation` under the `Events` folder.

---

## Setting up your client

Create a LocalScript and place it under StarterPlayerScripts.
Copy and paste the following code into the script you just created:
``` lua title="Example client simulation" linenums="1"
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SecureCast = require(ReplicatedStorage.SecureCast)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local Events = ReplicatedStorage.Events
local SimulateEvent = Events.Simulate

--> Only call once per context
SecureCast.Initialize()

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
	
    --> Replicate to the server
	SimulateEvent:FireServer(Origin, Direction, Time)

    --> Cast the projectile within our own simulation
	SecureCast.Cast(Player, "Bullet", Origin, Direction, Time)
end)

SimulateEvent.OnClientEvent:Connect(function(Caster: Player, Type: string, Origin: Vector3, Direction: Vector3, PVInstance: PVInstance?, Modifer)
	if Caster ~= Player then
		SecureCast.Cast(Caster, Type, Origin, Direction, workspace:GetServerTimeNow(), PVInstance, Modifer)
	end
end)
```

## Setting up your server

Create a Script and place it under ServerScriptService.
Copy and paste the following code into the script you just created:
``` lua title="Example server simulation" linenums="1"
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SecureCast = require(ReplicatedStorage.SecureCast)

local MAXIMUM_LATENCY = 0.8 -- 800 ms

local Events = ReplicatedStorage.Events
local SimulateEvent = Events.Simulate

--> Only call once per context
SecureCast.Initialize()

Players.PlayerAdded:Connect(function(Player: Player)
    --> We must parent all characters to the Characters folder within workspace
	Player.CharacterAdded:Connect(function(Character)
		RunService.PostSimulation:Wait()
		Character.Parent = workspace.Characters
	end)

    --> Disable raycast interactions with accessories
	Player.CharacterAppearanceLoaded:Connect(function(Character)
		for _, Child in Character:GetChildren() do
			if not Child:IsA("Accessory") then
				continue
			end

			local Handle: BasePart? = Child:FindFirstChild("Handle") :: BasePart
			if Handle then
				Handle.CanQuery = false
			end
		end
	end)
end)

ReplicatedStorage.Events.Simulate.OnServerEvent:Connect(function(Player: Player, Origin: Vector3, Direction: Vector3, Timestamp: number)
    --> It is best to have calculate these values at the top
    --> We can have the most accurate latency values this way
    --> Calculating them further down may result in skewed results

    --> We must take into account character interpolation
    --> The best estimate for this value available is (PLAYER_PING + 48 ms)
    --> If we do not factor in interpolation we will end up with inaccurate lag compensation

	local Latency = (workspace:GetServerTimeNow() - Timestamp)
	local Interpolation = (Player:GetNetworkPing() + SecureCast.Settings.Interpolation)

    --> Validate the latency and avoid players with very slow connections
	if (Latency < 0) or (Latency > MAXIMUM_LATENCY) then
		return
	end

    --> Validate the projectile origin
	local Character = Player.Character
	local Head: BasePart? = Character and Character:FindFirstChild("Head") :: BasePart
	if not Head then
		return
	end

	local Distance = (Origin - Head.Position).Magnitude
	if Distance > 5 then
		warn(`{Player} is too far from the projectile origin.`)
		return
	end
	
    --> Replicate the projectile to all other clients
	SimulateEvent:FireAllClients(Player, "Bullet", Origin, Direction)

    --> Cast the projectile within our own simulation
	SecureCast.Cast(Player, "Bullet", Origin, Direction, Timestamp - Interpolation)
end)
```

## Test your simulation

You can test if your simulation is working properly by going into a Local Test Server.
!!! note

    Make sure to create 2 seperate teams or the players will be ignored due to being on the same team.