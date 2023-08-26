--!strict

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

---- Constants ----

local Actor = script.Parent

---- Variables ----

---- Private Functions ----

---- Public Functions ----

---- Initialization ----

---- Connections ----

Actor:BindToMessage("Initialize", function(Module: ModuleScript, ...)
	(require(Module) :: any).Initialize(Actor, ...)
end)