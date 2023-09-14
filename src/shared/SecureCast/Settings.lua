local VoxelGridSize = Vector3.new(4096, 512, 4096)

return {
    --> Voxels
    VoxelSize = 32,
    VoxelGridSize = VoxelGridSize,
    VoxelGridCorner = CFrame.new(-VoxelGridSize / 2),

    --> Snapshots
    SnapshotLifetime = 1,

    --> Definitions
    Definitions = script.Parent.Simulation,

    --> Simulation (Do not touch these unless you know what you are doing!)
    Threads = 16, --> The maximum amount of CPU threads to allocate
    Interpolation = 0.048, --> The base amount of time in seconds it takes for ROBLOX characters to interpolate (this is a guess, no official numbers exist)
    ServerFrameRate = (1 / 60), --> The server frame rate (assume constant 60 FPS)
    RemianingFrameTimeRatio = 0.5, --> What percentage of the remaining frame time we can use to run the simulation.

    --> Penetration
    SurfaceHardness = {
        [Enum.Material.Wood] = 2,
        [Enum.Material.Concrete] = 10,
        Default = 10,
    },
    RicochetHardness = 10,

    --> Characters
    Parts = {
        "Head",
        "UpperTorso",
        "LowerTorso",
        "LeftUpperArm",
        "LeftLowerArm",
        "LeftHand",
        "RightUpperArm",
        "RightLowerArm",
        "RightHand",
        "LeftUpperLeg",
        "LeftLowerLeg",
        "LeftFoot",
        "RightUpperLeg",
        "RightLowerLeg",
        "RightFoot"
    },
    PartsSizes = {
        Vector3.new(1.161, 1.181, 1.161) / 2, -- Head
        Vector3.new(1.943, 1.698, 1.004) / 2, -- UpperTorso
        Vector3.new(1.991, 0.401, 1.004) / 2, -- LowerTorso
        Vector3.new(1.001, 1.242, 1.002) / 2, -- LeftUpperArm
        Vector3.new(1.001, 1.118, 1.002) / 2, -- LeftLowerArm
        Vector3.new(0.984, 0.316, 1.028) / 2, -- LeftHand
        Vector3.new(1.001, 1.242, 1.002) / 2, -- RightUpperArm
        Vector3.new(1.001, 1.118, 1.002) / 2, -- RightLowerArm
        Vector3.new(0.984, 0.316, 1.028) / 2, -- RightHand
        Vector3.new(0.993, 1.363, 0.973) / 2, -- LeftUpperLeg
        Vector3.new(0.993, 1.301, 0.973) / 2, -- LeftLowerLeg
        Vector3.new(1.009, 0.312, 1.001) / 2, -- LeftFoot
        Vector3.new(0.993, 1.363, 0.973) / 2, -- RightUpperLeg
        Vector3.new(0.993, 1.301, 0.973) / 2, -- RightLowerLeg
        Vector3.new(1.009, 0.312, 1.001) / 2, -- RightFoot
    },
    HitboxSize = Vector3.new(6, 6, 6) / 2,
}