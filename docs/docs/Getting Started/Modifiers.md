# Modifiers

Modifiers are a powerful tool that allows you to define per cast functionality seperate from the base projectile definition.  
They can be used to alter already existing projectile definitions for example: Giving a grenade extra velocity for jump/run throws.  

!!! danger
    When using Modifiers make sure that all clients and the server use the same modifier, improper modifier usage can result in simulation desync.

## Example 

I will be using the simulation setup from the [previous page](Simulation.md), if you haven't setup your simulaton yet refer to the [previous page](Simulation.md).  
In this example we will create a modifier that gives a bullet extra penetrative power, this modifier will be controlled by an attribute "ExtraPenetration" in the players character.
``` lua title="Example client simulation with modifiers"
...

UserInputService.InputBegan:Connect(function(Input, GPE)
	...

    local ProjectileModifier;
    if Character:GetAttribute("ExtraPenetration") then
        ProjectileModifier = {
            Power = 200
        }
    end
	
    --> Replicate to the server
	SimulateEvent:FireServer(Origin, Direction, workspace:GetServerTimeNow())

    --> Cast the projectile within our own simulation
	SecureCast.Cast(Player, "Bullet", Origin, Direction, os.clock(), nil, ProjectileModifier)
end)

...
```

``` lua title="Example server simulation with modifiers" linenums="1"
...

ReplicatedStorage.Events.Simulate.OnServerEvent:Connect(function(Player: Player, Origin: Vector3, Direction: Vector3, Timestamp: number)
    ...

    local ProjectileModifier;
    if Character:GetAttribute("ExtraPenetration") then
        ProjectileModifier = {
            Power = 200
        }
    end
	
    --> Replicate the projectile to all other clients
	SimulateEvent:FireAllClients(Player, "Bullet", Origin, Direction, nil, ProjectileModifier)

    --> Cast the projectile within our own simulation
	SecureCast.Cast(Player, "Bullet", Origin, Direction, Time - Latency - Interpolation, nil, ProjectileModifier)
end)
```