<style>
    .type {
        color: rgb(115, 154, 226);
        font-size: large
    }
    .method {
        font-size: x-large
    }
</style>

# SecureCast

SecureCast is the top-level interface for interacting with the system. It is returned by `require(SecureCast)`.

## Members

<span class="type">Utility</span>
<span class="method"> Snapshots</span>

The snapshots utility used by the simulation, you can use this to retrieve player positions back in time for lag compensation.
!!! warning

    Snapshots can only be used on the server, calling any of the methods within the utility will throw an error when called from the client!

## Methods

<span class="type">void</span>
<span class="method"> Initialize &#40</span>
<span class="method">&#41</span>

Initialize the simulation for the current context.

!!! warning

    Initialize can only be called once per context, subsequent calls will result in an error.

---

<span class="type">void</span>
<span class="method"> Cast &#40</span>
    <br>&emsp;<span class="type">Player</span> <i>Caster</i>,
    <br>&emsp;<span class="type">string</span> <i>Type</i>,
    <br>&emsp;<span class="type">Vector3</span> <i>Origin</i>
    <br>&emsp;<span class="type">Vector3</span> <i>Direction</i>
    <br>&emsp;<span class="type">number</span> <i>Timestamp</i>
    <br>&emsp;<span class="type">PVInstance?</span> <i>PVInstance</i>
    <br>&emsp;<span class="type">Modifier?</span> <i>Modifier</i>
<br><span class="method">&#41</span>

Casts a new projectile. A <span class="type">Modifier</span> can be used to modify the behaviour of a projectile on a per cast basis. A <span class="type">PVInstance</span> must exist on the client in order for the projectile to be rendered.

!!! danger

    When using a Modifier make sure that all clients and the server use the same modifier, improper modifier usage can result in simulation desync.