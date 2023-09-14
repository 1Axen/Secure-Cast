<style>
    .type {
        color: rgb(115, 154, 226);
        font-size: large
    }
    .method {
        font-size: x-large
    }
</style>

# Settings

This page contains all settings used by SecureCast. These can be found in the Settings module under the SecureCast module.

---

<span class="type">number</span>
<span class="method"> VoxelSize</span>

The size of each voxel in studs.

---

<span class="type">Vector3</span>
<span class="method"> VoxelGridSize</span>

The size of the voxel grid in studs.

!!! danger

    Be careful when editing this value, anything smaller than the playable area will result in players being missed by the server raycasts.

---

<span class="type">number</span>
<span class="method"> SnapshotLifetime</span>

The lifetime of snapshots in seconds.

!!! danger

    Be careful when editing this value, very small values will result in players with high ping not being able to land shots but high values may result in players being hit behind cover long after they have gone behind it.

---

<span class="type">Instance</span>
<span class="method"> Definitions</span>

The container for projectile definitions modules.

---

<span class="type">{[Enum.Material]: number}</span>
<span class="method"> SurfaceHardness</span>

An array of each materials hardness.<br>
The needed penetration power can be calculate with the following formula:<br>
`Power = SurfaceDepth * SurfaceHardness`

---

<span class="type">number</span>
<span class="method"> RicochetHardness</span>

The minimum surface hardness needed for a projectile to ricochet off of something.<br>
This is ignored when a projectile has a ricochet angle set to `math.pi * 2`.

---

<span class="type">{string}</span>
<span class="method"> Parts</span>

An array containing the names of every hitbox in a players character, ordered from most to least damage.

---

<span class="type">{Vector3}</span>
<span class="method"> PartsSizes</span>

An array containing the halved sizes of every hitbox in a players character, in the same order as the `Parts` array.

---

<span class="type">Vector3</span>
<span class="method"> HitboxSize</span>

The maximum halved size of a players character, it needs to contain the character at it's maximum arm span.

---