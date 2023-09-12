<style>
    .type {
        color: rgb(115, 154, 226);
        font-size: large
    }
    .method {
        font-size: x-large
    }
</style>

# Definitions

This page contains all types defined and used by SecureCast.

---

<span class="type">type</span>
<span class="method"> Modifier &#40</span>
    <br>&emsp;<span class="type">number</span> <i>Loss</i>,
    <br>&emsp;<span class="type">number</span> <i>Power</i>,
    <br>&emsp;<span class="type">number</span> <i>Angle</i>,
    <br>&emsp;<span class="type">number</span> <i>Gravity</i>,
    <br>&emsp;<span class="type">number</span> <i>Velocity</i>,
    <br>&emsp;<span class="type">number</span> <i>Lifetime</i>,
    <br>&emsp;<span class="type">BindableEvent?</span> <i>OnImpact</i>,
    <br>&emsp;<span class="type">BindableEvent?</span> <i>OnDestroyed</i>,
    <br>&emsp;<span class="type">BindableEvent?</span> <i>OnIntersection</i>,
    <br>&emsp;<span class="type">RaycastParams?</span> <i>RaycastFilter</i>,
<br><span class="method">&#41</span>

Modifiers are a powerful tool that allows you to define per cast functionality seperate from the base projectile definition.

``` lua title="Custom event handling" linenums="1"
local Bindable = Instance.new("BindableEvent")
Bindable.Event:Connect(function(Type: string, Event: string, ...)
    if Event == "OnDestroyed" then
        --> No need to keep a reference to the connection 
        --> since destroy will take care of it for us
        Bindable:Destroy()
    elseif Event == "OnImpact" then

    elseif Event == "OnIntersection" then

    end
end)

local Modifier = {
    OnImpact = Bindable,
    OnDestroyed = Bindable,
    OnIntersection = Bindable,
}

SecureCast.Cast(Player, "Bullet", Origin, Direction, os.clock() - Latency, nil, Modifier)
```

!!! danger

    When using Modifiers make sure that all clients and the server use the same modifier, improper modifier usage can result in simulation desync.

---

<span class="type">type</span>
<span class="method"> Definition &#40</span>
    <br>&emsp;<span class="type">number</span> <i>Loss</i>,
    <br>&emsp;<span class="type">number</span> <i>Power</i>,
    <br>&emsp;<span class="type">number</span> <i>Angle</i>,
    <br>&emsp;<span class="type">number</span> <i>Gravity</i>,
    <br>&emsp;<span class="type">number</span> <i>Velocity</i>,
    <br>&emsp;<span class="type">number</span> <i>Lifetime</i>,
    <br>&emsp;<span class="type">BindableEvent?</span> <i>Output</i>,
    <br>&emsp;<span class="type">RaycastParams?</span> <i>RaycastFilter</i>,
    <br>&emsp;<span class="type">void</span> <i>OnImpact</i> (
        <br>&emsp;&emsp;<span class="type">Player</span> <i>Caster</i>,
        <br>&emsp;&emsp;<span class="type">Vector3</span> <i>Direction</i>,
        <br>&emsp;&emsp;<span class="type">Instance</span> <i>Instance</i>,
        <br>&emsp;&emsp;<span class="type">Vector3</span> <i>Normal</i>,
        <br>&emsp;&emsp;<span class="type">Vector3</span> <i>Position</i>,
        <br>&emsp;&emsp;<span class="type">Enum.Material</span> <i>Material</i>
    <br>&emsp;),
    <br>&emsp;<span class="type">void</span> <i>OnDestroyed</i> (
        <br>&emsp;&emsp;<span class="type">Player</span> <i>Caster</i>,
        <br>&emsp;&emsp;<span class="type">Vector3</span> <i>Position</i>
    <br>&emsp;),
    <br>&emsp;<span class="type">void</span> <i>OnIntersection</i> (
        <br>&emsp;&emsp;<span class="type">Player</span> <i>Caster</i>,
        <br>&emsp;&emsp;<span class="type">Vector3</span> <i>Direction</i>,
        <br>&emsp;&emsp;<span class="type">string</span> <i>Part</i>,
        <br>&emsp;&emsp;<span class="type">Player</span> <i>Victim</i>,
        <br>&emsp;&emsp;<span class="type">Vector3</span> <i>Position</i>
    <br>&emsp;),
<br><span class="method">&#41</span>

This type represents the way that projectiles should be defined within the system.<br>
Refer to the template bullet included within the GitHub repository for an example.

---

<span class="type">type</span>
<span class="method"> Record &#40</span>
    <br>&emsp;<span class="type">{CFrame}</span> <i>Parts</i>,
    <br>&emsp;<span class="type">Vector3</span> <i>Position</i>,
<br><span class="method">&#41</span>

---

<span class="type">type</span>
<span class="method"> Snapshot &#40</span>
    <br>&emsp;<span class="type">number</span> <i>Time</i>,
    <br>&emsp;<span class="type">Voxels.Grid</span> <i>Grid</i>,
    <br>&emsp;<span class="type">{[Player]: Record}</span> <i>Records</i>,
<br><span class="method">&#41</span>

---

*[Loss]: Speed loss incured from a projectile ricocheting or bouncing off of a surface.
*[Power]: Penetrative power of the projectile.
*[Angle]: Ricochet angle of the projectile in degrees. (360 for grenades)
*[Output]: BindableEvent used to override per cast events. [DEPRECATED]
*[OnImpact]: A callback which is invoked whenever the projectile hits something in the world.
*[OnDestroyed]: A callback which is invoked whenever the projectile is destroyed.
*[OnIntersection]: A callback which is invoked whenever the projectile intersects a player hitbox. (SERVER SIDE ONLY)