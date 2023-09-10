<style>
    .type {
        color: rgb(115, 154, 226);
        font-size: large
    }
    .method {
        font-size: x-large
    }
</style>

# Snapshots

The snapshots utility is used by the simulation to take "snapshots" of player positions in the past for lag compensation.

## Methods

<span class="type">{[string]: CFrame}?</span>
<span class="method"> GetPlayerAtTime &#40</span>
    <span class="type">Player</span> <i>Player</i>
    <span class="type">number</span> <i>Time</i>
<span class="method">&#41</span>

Returns an array containing the CFrame of each of the player's hitboxes in the past, returns nothing when no snapshots containing the player can be found.

---

<span class="type">{[Player]: {[string]: CFrame}}</span>
<span class="method"> GetPlayersAtTime &#40</span>
    <span class="type">number</span> <i>Time</i>
<span class="method">&#41</span>

Returns an array containing the CFrame of each of the hitboxes of every player in the past.

---

<span class="type">Snapshot?, Snapshot?, number?</span>
<span class="method"> GetSnapshotsAtTime &#40</span>
    <span class="type">number</span> <i>Time</i>
<span class="method">&#41</span>

Returns a tuple containing the previous snapshot, next snapshot and the fraction used for lerping between them, returns nothing if no snapshots can be found for the given time.

---

<span class="type">void</span>
<span class="method"> CreatePlayersSnapshot &#40</span>
    <span class="type">number</span> <i>Time</i>
<span class="method">&#41</span>

Creates a snapshot of every players hitbox at the given time.
!!! danger

    This method should not be called or it may result in undefined behaviour, this is already called by SecureCast internally.

---