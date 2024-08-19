local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuickSetup = {}


function QuickSetup:Run()
    local Map = ReplicatedStorage:FindFirstChild("Map")
    local Characters = ReplicatedStorage:FindFirstChild("Characters")
    local Events = ReplicatedStorage:FindFirstChild("Events")
    local Simulate
    
    if Events == nil then
        Events = Instance.new("Folder")
        Events.Name = "Events"
        Events.Parent = ReplicatedStorage
    end

    if Events:FindFirstChild("Simulate") == nil then
        Simulate = Instance.new("RemoteEvent")
        Simulate.Name = "Simulate"
        Simulate.Parent = Events
    end

    if Map == nil then
        Map = Instance.new("Folder")
        Map.Name = "Map"
        Map.Parent = workspace
    end

    if Characters == nil then
        Characters = Instance.new("Folder")
        Characters.Name = "Characters"
        Characters.Parent = workspace
    end

    -- Avoid name instance clashing
    local ERR_MSG = "Instance with expected name was found, but was the incorrect class!"
    assert(workspace.Map:IsA("Folder"), ERR_MSG)
    assert(workspace.Characters:IsA("Folder"), ERR_MSG)
    assert(ReplicatedStorage.Events:IsA("Folder"), ERR_MSG)
    assert(ReplicatedStorage.Events.Simulate:IsA("RemoteEvent"), ERR_MSG)
end


return QuickSetup