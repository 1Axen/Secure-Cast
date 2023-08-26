--!strict
--!optimize 2

-- ******************************* --
-- 			AX3NX / AXEN		   --
-- ******************************* --

---- Services ----

---- Imports ----

---- Settings ----

---- Constants ----

local Utility = {}

---- Variables ----

---- Private Functions ----

local function Format(Time: number): string
	if Time < 1E-6 then
		return `{Time * 1E+9} ns`
	elseif Time < 0.001 then
		return `{Time * 1E+6} μs`
	elseif Time < 1 then
		return `{Time * 1000} ms`
	else
		return `{Time} s`
	end
end

---- Public Functions ----

function Utility.Benchmark(Label: string, Samples: number, Closure: (Begin: (Tag: string) -> (), End: (Tag: string) -> (), ...any) -> (...any), ...: any): (number, number, number, number)
	local Total = 0
	local Results = table.create(Samples)
	
	--> Prevent 'Script timeout: exhausted allowed execution time'
	local Tick = os.clock()
	local function Rest()
		if (os.clock() - Tick) > 5 then
			Tick = os.clock()
			task.wait()
		end
	end
	
	--> Tag system	
	local Tags = {}
	local Calls = {}
	local Recordings = {}
	
	local function Begin(Tag: string)
		if not Tags[Tag] then
			Tags[Tag] = {
				Times = {},
				Calls = {}
			}
			Calls[Tag] = 0
		end
		
		Calls[Tag] += 1
		Recordings[Tag] = os.clock()
	end
	
	local function End(Tag: string)
		local Now = os.clock()
		table.insert(Tags[Tag].Times, Now - Recordings[Tag])
	end
	
	for Index = 1, Samples do
		--> Execute closure
		local Start = os.clock()
		Closure(Begin, End, ...)
		local Time = (os.clock() - Start)
		
		--> Accumulate
		Total += Time
		table.insert(Results, Time)
		
		--> Record calls
		for Tag, Amount in Calls do
			Rest()
			Calls[Tag] = 0
			table.insert(Tags[Tag].Calls, Amount)
		end
		
		Rest()
	end
	
	task.wait()
	
	table.sort(Results, function(a, b)
		return b > a
	end)
	
	local Index50th = math.max(math.floor(Samples / 2), 1)	
	local Index95th = math.max(math.floor(Samples * 0.95), 1)
	local Index99th = math.max(math.floor(Samples * 0.99), 1)
	
	warn(`BENCHMARK: {Label} -- {debug.info(2, "s")}`)
	print(`Fastest Time: {Format(Results[1])}`)
	print(`Average Time: {Format(Total / Samples)}`)
	print(`50th Percentile: {Format(Results[Index50th])}`)
	print(`95th Percentile: {Format(Results[Index95th])}`)
	print(`99th Percentile: {Format(Results[Index99th])}`)
	
	for Tag, Information in Tags do
		local Calls = Information.Calls
		local Times = Information.Times
		
		local Total = 0
		local Samples = #Times
		for Index, Time in Times do
			Total += Time
			Rest()
		end
		
		task.wait()
		
		local TotalCalls = 0
		local CallsSamples = #Calls
		for Index, Amount in Calls do
			TotalCalls += Amount
			Rest()
		end
		
		task.wait()
		
		table.sort(Calls, function(a, b)
			return b > a
		end)
		
		task.wait()
		
		table.sort(Times, function(a, b)
			return b > a
		end)
		
		local TimeIndex50th = math.max(math.floor(Samples / 2), 1)	
		local TimeIndex95th = math.max(math.floor(Samples * 0.95), 1)
		local TimeIndex99th = math.max(math.floor(Samples * 0.99), 1)
		local CallsIndex50th = math.max(math.floor(CallsSamples / 2), 1)	
		
		warn(`TAG: {Tag}`)
		print(`	Sample Time: {Format(Times[TimeIndex50th] * Calls[CallsIndex50th])}`)
		--print(`	Fastest Time: {Format(Times[1])}`)
		print(`	Average Time: {Format(Total / Samples)}`)
		--print(`	Average Calls: {TotalCalls / CallsSamples}`)
		print(`	50th Percentile: {Format(Times[TimeIndex50th])}`)
		--print(`	95th Percentile: {Format(Times[TimeIndex95th])}`)
		--print(`	99th Percentile: {Format(Times[TimeIndex99th])}`)
		
		Rest()
	end
	
	return Results[1], Total / Samples, Results[Index95th], Results[Index99th]
end

---- Initialization ----

---- Connections ----

return Utility