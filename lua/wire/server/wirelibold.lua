-- Compatibility Global

-- Used because I have no time to fix this right now

OldWireLib = OldWireLib or {}

WireAddon = 1

local ents = ents
local timer = timer
local string = string
local math_clamp = math.Clamp
local table = table
local hook = hook
local concommand = concommand
local Msg = Msg
local MsgN = MsgN
local pairs = pairs
local ipairs = ipairs
local IsValid = IsValid
local tostring = tostring
local Vector = Vector
local Color = Color
local Material = Material



function OldWireLib.PortComparator(a,b)
	return a.Num < b.Num
end

-- Allow to specify the description and type, like "Name (Description) [TYPE]"
local function ParsePortName(namedesctype, fbtype, fbdesc)
	local namedesc, tp = namedesctype:match("^(.+) %[(.+)%]$")
	if not namedesc then
		namedesc = namedesctype
		tp = fbtype
	end

	local name, desc = namedesc:match("^(.+) %((.*)%)$")
	if not name then
		name = namedesc
		desc = fbdesc
	end
	return name, desc, tp
end

local Inputs = {}
local Outputs = {}
local CurLink = {}
local CurTime = CurTime


-- an array of data types
OldWireLib.DT = {
	NORMAL = {
		Zero = 0
	},	-- Numbers
	VECTOR = {
		Zero = Vector(0, 0, 0)
	},
	ANGLE = {
		Zero = Angle(0, 0, 0)
	},
	COLOR = {
		Zero = Color(0, 0, 0)
	},
	ENTITY = {
		Zero = NULL
	},
	STRING = {
		Zero = ""
	},
	TABLE = {
		Zero = {n={},ntypes={},s={},stypes={},size=0},
	},
	BIDIRTABLE = {
		Zero = {n={},ntypes={},s={},stypes={},size=0},
		BiDir = true
	},
	ANY = {
		Zero = 0
	},
	ARRAY = {
		Zero = {}
	},
	BIDIRARRAY = {
		Zero = {},
		BiDir = true
	},
}

function OldWireLib.CreateSpecialInputs(ent, names, types, descs)
	types = types or {}
	descs = descs or {}
	local ent_ports = {}
	ent.Inputs = ent_ports
	for n,v in pairs(names) do
		local name, desc, tp = ParsePortName(v, types[n] or "NORMAL", descs and descs[n])

		local port = {
			Entity = ent,
			Name = name,
			Desc = desc,
			Type = tp,
			Value = OldWireLib.DT[ tp ].Zero,
			Material = "tripmine_laser",
			Color = Color(255, 255, 255, 255),
			Width = 1,
			Num = n,
		}

		local idx = 1
		while (Inputs[idx]) do
			idx = idx+1
		end
		port.Idx = idx

		ent_ports[name] = port
		Inputs[idx] = port
	end

	OldWireLib._SetInputs(ent)

	return ent_ports
end

function OldWireLib.CreateSpecialOutputs(ent, names, types, descs)
	types = types or {}
	descs = descs or {}
	local ent_ports = {}
	ent.Outputs = ent_ports
	for n,v in pairs(names) do
		local name, desc, tp = ParsePortName(v, types[n] or "NORMAL", descs and descs[n])

		local port = {
			Entity = ent,
			Name = name,
			Desc = desc,
			Type = tp,
			Value = OldWireLib.DT[ tp ].Zero,
			Connected = {},
			TriggerLimit = 8,
			Num = n,
		}

		local idx = 1
		while (Outputs[idx]) do
			idx = idx+1
		end
		port.Idx = idx


		ent_ports[name] = port
		Outputs[idx] = port
	end

	OldWireLib._SetOutputs(ent)

	return ent_ports
end

function OldWireLib.AdjustSpecialInputs(ent, names, types, descs)
	types = types or {}
	descs = descs or {}
	local ent_ports = ent.Inputs or {}
	for n,v in ipairs(names) do
		local name, desc, tp = ParsePortName(v, types[n] or "NORMAL", descs and descs[n])

		if (ent_ports[name]) then
			if tp ~= ent_ports[name].Type then
				timer.Simple(0, function() OldWireLib.Link_Clear(ent, name) end)
				ent_ports[name].Value = OldWireLib.DT[tp].Zero
				ent_ports[name].Type = tp
			end
			ent_ports[name].Keep = true
			ent_ports[name].Num = n
			ent_ports[name].Desc = desc
		else
			local port = {
				Entity = ent,
				Name = name,
				Desc = desc,
				Type = tp,
				Value = OldWireLib.DT[ tp ].Zero,
				Material = "tripmine_laser",
				Color = Color(255, 255, 255, 255),
				Width = 1,
				Keep = true,
				Num = n,
			}

			local idx = 1
			while (Inputs[idx]) do
				idx = idx+1
			end
			port.Idx = idx

			ent_ports[name] = port
			Inputs[idx] = port
		end
	end

	for portname,port in pairs(ent_ports) do
		if (port.Keep) then
			port.Keep = nil
		else
			OldWireLib.Link_Clear(ent, portname)

			ent_ports[portname] = nil
		end
	end

	OldWireLib._SetInputs(ent)

	return ent_ports
end


function OldWireLib.AdjustSpecialOutputs(ent, names, types, descs)
	types = types or {}
	descs = descs or {}

	local ent_ports = ent.Outputs or {}

	if ent_ports.wirelink then
		local n = #names+1

		names[n] = "wirelink"
		types[n] = "WIRELINK"
	end

	for n,v in ipairs(names) do
		local name, desc, tp = ParsePortName(v, types[n] or "NORMAL", descs and descs[n])

		if (ent_ports[name]) then
			if tp ~= ent_ports[name].Type then
				OldWireLib.DisconnectOutput(ent, name)
				ent_ports[name].Type = tp
			end
			ent_ports[name].Keep = true
			ent_ports[name].Num = n
			ent_ports[name].Desc = desc
		else
			local port = {
				Keep = true,
				Name = name,
				Desc = desc,
				Type = tp,
				Value = OldWireLib.DT[ tp ].Zero,
				Connected = {},
				TriggerLimit = 8,
				Num = n,
			}

			local idx = 1
			while (Outputs[idx]) do
				idx = idx+1
			end
			port.Idx = idx

			ent_ports[name] = port
			Outputs[idx] = port
		end
	end

	for portname,port in pairs(ent_ports) do
		if (port.Keep) then
			port.Keep = nil
		else
			OldWireLib.DisconnectOutput(ent, portname)
			ent_ports[portname] = nil
		end
	end

	OldWireLib._SetOutputs(ent)

	return ent_ports
end

--- Disconnects all wires from the given output.
function OldWireLib.DisconnectOutput(entity, output_name)
	local output = entity.Outputs[output_name]
	if output == nil then return end
	for _, input in pairs_consume(output.Connected) do
		if IsValid(input.Entity) then
			OldWireLib.Link_Clear(input.Entity, input.Name)
		end
	end
end





local function ClearPorts(ports, ConnectEnt, DontSendToCL, Removing)
	local Valid, EmergencyBreak = true, 0

	-- There is a strange bug, not all the links get removed at once.
	-- It works when you run it multiple times.
	while (Valid and (EmergencyBreak < 32)) do
		local newValid = nil

		for k,v in ipairs(ports) do
			local Ent, Name = v.Entity, v.Name
			if (IsValid(Ent) and (not ConnectEnt or (ConnectEnt == Ent))) then
				local ports = Ent.Inputs
				if (ports) then
					local port = ports[Name]
					if (port) then
						OldWireLib.Link_Clear(Ent, Name, DontSendToCL, Removing)
						newValid = true
					end
				end
			end
		end

		Valid = newValid
		EmergencyBreak = EmergencyBreak + 1 -- Prevents infinite loops if something goes wrong.
	end
end

-- Set DontUnList to true, if you want to call OldWireLib._RemoveWire(eid) manually.
function OldWireLib.Remove(ent, DontUnList)
	--Clear the inputs
	local ent_ports = ent.Inputs
	if (ent_ports) then
		for _,inport in pairs(ent_ports) do
			local Source = inport.Src
			if (IsValid(Source)) then
				local Outports = Source.Outputs
				if (Outports) then
					local outport = Outports[inport.SrcId]
					if (outport) then
						ClearPorts(outport.Connected, ent, true, true)
					end
				end
			end
			Inputs[inport.Idx] = nil
		end
	end

	--Clear the outputs
	local ent_ports = ent.Outputs
	if (ent_ports) then
		for _,outport in pairs(ent_ports) do
			ClearPorts(outport.Connected)
			Outputs[outport.Idx] = nil
		end
	end

	ent.Inputs = nil -- Remove the inputs
	ent.Outputs = nil -- Remove the outputs
	ent.IsWire = nil -- Remove the wire mark

	if (DontUnList) then return end -- Set DontUnList to true if you want to remove ent from the list manually.
	OldWireLib._RemoveWire(ent:EntIndex()) -- Remove entity from the list, so it doesn't count as a wire able entity anymore. Very important for IsWire checks!
end





function OldWireLib.Link_Node(idx, ent, pos)
	if not CurLink[idx] then return end
	if not IsValid(CurLink[idx].Dst) then return end
	if not IsValid(ent) then return end -- its the world, give up

	table.insert(CurLink[idx].Path, { Entity = ent, Pos = pos })
	OldWireLib.Paths.Add(CurLink[idx].Dst.Inputs[CurLink[idx].DstId])
end


function OldWireLib.Link_Cancel(idx)
	if not CurLink[idx] then return end
	if not IsValid(CurLink[idx].Dst) then return end

	if CurLink[idx].input then
		CurLink[idx].Path = CurLink[idx].input.Path
	else
		OldWireLib.Paths.Add({Entity = CurLink[idx].Dst, Name = CurLink[idx].DstId, Width = 0})
	end
	CurLink[idx] = nil
end


function OldWireLib.Link_Clear(ent, iname, DontSendToCL, Removing)
	OldWireLib.Paths.Add({Entity = ent, Name = iname, Width = 0})
	Wire_Unlink(ent, iname, DontSendToCL, Removing)
end

function OldWireLib.WireAll(ply, ient, oent, ipos, opos, material, color, width)
	if not IsValid(ient) or not IsValid(oent) or not ient.Inputs or not oent.Outputs then return false end

	for iname, _ in pairs(ient.Inputs) do
		if oent.Outputs[iname] then
			OldWireLib.Link_Start(ply:UniqueID(), ient, ipos, iname, material or "arrowire/arrowire2", color or Color(255,255,255), width or 0)
			OldWireLib.Link_End(ply:UniqueID(), oent, opos, iname, ply)
		end
	end
end

do -- class OutputIterator
	local OutputIterator = {}
	OutputIterator.__index = OutputIterator

	function OutputIterator:Add(ent, iname, value)
		table.insert(self, { Entity = ent, IName = iname, Value = value })
	end

	function OutputIterator:Process()
		if self.Processing then return end -- should not occur
		self.Processing = true

		while #self > 0 do
			local nextelement = self[1]
			table.remove(self, 1)

			OldWireLib.TriggerInput(nextelement.Entity, nextelement.IName, nextelement.Value, self)
		end

		self.Processing = nil
	end

	function OldWireLib.CreateOutputIterator()
		return setmetatable({}, OutputIterator)
	end
end -- class OutputIterator


duplicator.RegisterEntityModifier("WireDupeInfo", function(ply, Ent, DupeInfo)
	-- this does nothing for now, we need the blank function to get the duplicator to copy the WireDupeInfo into the pasted ent
end)


-- used for welding wired stuff, if trace is world, the ent is not welded and is frozen instead
function OldWireLib.Weld(ent, traceEntity, tracePhysicsBone, DOR, collision, AllowWorldWeld)
	if (not ent or not traceEntity or traceEntity:IsNPC() or traceEntity:IsPlayer()) then return end
	local phys = ent:GetPhysicsObject()
	if ( traceEntity:IsValid() ) or ( traceEntity:IsWorld() and AllowWorldWeld ) then
		local const = constraint.Weld( ent, traceEntity, 0, tracePhysicsBone, 0, (not collision), DOR )
		-- Don't disable collision if it's not attached to anything
		if (not collision) then
			if phys:IsValid() then phys:EnableCollisions( false ) end
			ent.nocollide = true
		end
		return const
	else
		if phys:IsValid() then ent:GetPhysicsObject():EnableMotion( false ) end
		return nil
	end
end


function OldWireLib.BuildDupeInfo( Ent )
	if not Ent.Inputs then return {} end

	local info = { Wires = {} }
	for portname,input in pairs(Ent.Inputs) do
		if (IsValid(input.Src)) then
			info.Wires[portname] = {
				StartPos = input.StartPos,
				Material = input.Material,
				Color = input.Color,
				Width = input.Width,
				Src = input.Src:EntIndex(),
				SrcId = input.SrcId,
				SrcPos = Vector(0, 0, 0),
			}

			if (input.Path) then
				info.Wires[portname].Path = {}

				for _,v in ipairs(input.Path) do
					if (IsValid(v.Entity)) then
						table.insert(info.Wires[portname].Path, { Entity = v.Entity:EntIndex(), Pos = v.Pos })
					end
				end

				local n = #info.Wires[portname].Path
				if (n > 0) and (info.Wires[portname].Path[n].Entity == info.Wires[portname].Src) then
					info.Wires[portname].SrcPos = info.Wires[portname].Path[n].Pos
					table.remove(info.Wires[portname].Path, n)
				end
			end
		end
	end

	return info
end

function OldWireLib.ApplyDupeInfo( ply, ent, info, GetEntByID )
	if info.extended and not ent.extended then
		OldWireLib.CreateWirelinkOutput( ply, ent, {true} ) -- old dupe compatibility; use the new function
	end

	local idx = 0
	if IsValid(ply) then idx = ply:UniqueID() end -- Map Save loading does not have a ply
	if (info.Wires) then
		for k,input in pairs(info.Wires) do
			k=tostring(k) -- For some reason duplicator will parse strings containing numbers as numbers?
			local ent2 = GetEntByID(input.Src)

			-- Input alias
			if ent.Inputs and not ent.Inputs[k] then -- if the entity has any inputs and the input 'k' is not one of them...
				if ent.InputAliases and ent.InputAliases[k] then
					k = ent.InputAliases[k]
				else
					Msg("ApplyDupeInfo: Error, Could not find input '" .. k .. "' on entity type: '" .. ent:GetClass() .. "'\n")
					continue
				end
			end

			if IsValid( ent2 ) then
				-- Wirelink and entity outputs

				-- These are required if whichever duplicator you're using does not do entity modifiers before it runs PostEntityPaste
				-- because if so, the wirelink and entity outputs may not have been created yet

				if input.SrcId == "link" or input.SrcId == "wirelink" then -- If the target entity has no wirelink output, create one (& more old dupe compatibility)
					input.SrcId = "wirelink"
					if not ent2.extended then
						OldWireLib.CreateWirelinkOutput( ply, ent2, {true} )
					end
				elseif input.SrcId == "entity" and ((ent2.Outputs and not ent2.Outputs.entity) or not ent2.Outputs) then -- if the input name is 'entity', and the target entity doesn't have that output...
					OldWireLib.CreateEntityOutput( ply, ent2, {true} )
				end

				-- Output alias
				if ent2.Outputs and not ent2.Outputs[input.SrcId] then -- if the target entity has any outputs and the output 'input.SrcId' is not one of them...
					if ent2.OutputAliases and ent2.OutputAliases[input.SrcId] then
						input.SrcId = ent2.OutputAliases[input.SrcId]
					else
						Msg("ApplyDupeInfo: Error, Could not find output '" .. input.SrcId .. "' on entity type: '" .. ent2:GetClass() .. "'\n")
						continue
					end
				end
			end

			OldWireLib.Link_Start(idx, ent, input.StartPos, k, input.Material, input.Color, input.Width)

			if input.Path then
				for _,v in ipairs(input.Path) do
					local ent2 = GetEntByID(v.Entity)
					if IsValid(ent2) then
						OldWireLib.Link_Node(idx, ent2, v.Pos)
					else
						Msg("ApplyDupeInfo: Error, Could not find the entity for wire path\n")
					end
				end
			end

			if IsValid(ent2) then
				OldWireLib.Link_End(idx, ent2, input.SrcPos, input.SrcId)
			else
				Msg("ApplyDupeInfo: Error, Could not find the output entity\n")
			end
		end
	end
end

function OldWireLib.RefreshSpecialOutputs(ent)
	local names = {}
	local types = {}
	local descs = {}

	if ent.Outputs then
		for _,output in pairs(ent.Outputs) do
			local index = output.Num
			names[index] = output.Name
			types[index] = output.Type
			descs[index] = output.Desc
		end

		ent.Outputs = OldWireLib.AdjustSpecialOutputs(ent, names, types, descs)
	else
		ent.Outputs = OldWireLib.CreateSpecialOutputs(ent, names, types, descs)
	end

	OldWireLib.TriggerOutput(ent, "link", ent)
end

function OldWireLib.CreateInputs(ent, names, descs)
	return OldWireLib.CreateSpecialInputs(ent, names, {}, descs)
end


function OldWireLib.CreateOutputs(ent, names, descs)
	return OldWireLib.CreateSpecialOutputs(ent, names, {}, descs)
end


function OldWireLib.AdjustInputs(ent, names, descs)
	return OldWireLib.AdjustSpecialInputs(ent, names, {}, descs)
end


function OldWireLib.AdjustOutputs(ent, names, descs)
	return OldWireLib.AdjustSpecialOutputs(ent, names, {}, descs)
end

-- Backwards compatibility
Wire_CreateInputs				= OldWireLib.CreateInputs
Wire_CreateOutputs				= OldWireLib.CreateOutputs
Wire_AdjustInputs				= OldWireLib.AdjustInputs
Wire_AdjustOutputs				= OldWireLib.AdjustOutputs
Wire_Restored					= OldWireLib.Restored
Wire_Remove						= OldWireLib.Remove
Wire_TriggerOutput				= OldWireLib.TriggerOutput
Wire_Link_Start					= OldWireLib.Link_Start
Wire_Link_Node					= OldWireLib.Link_Node
Wire_Link_End					= OldWireLib.Link_End
Wire_Link_Cancel				= OldWireLib.Link_Cancel
Wire_Link_Clear					= OldWireLib.Link_Clear
Wire_CreateOutputIterator		= OldWireLib.CreateOutputIterator
Wire_BuildDupeInfo				= OldWireLib.BuildDupeInfo
Wire_ApplyDupeInfo				= OldWireLib.ApplyDupeInfo

function OldWireLib.GetOwner(ent)
	return E2Lib.getOwner({}, ent)
end

function OldWireLib.NumModelSkins(model)
	if NumModelSkins then
		return NumModelSkins(model)
	end
	local info = util.GetModelInfo(model)
	return info and info.SkinCount
end

--- @return whether the given player can spawn an object with the given model and skin
function OldWireLib.CanModel(player, model, skin)
	if not util.IsValidModel(model) then return false end
	if skin ~= nil then
		local count = OldWireLib.NumModelSkins(model)
		if skin < 0 or (count and skin >= count) then return false end
	end
	if IsValid(player) and player:IsPlayer() and not hook.Run("PlayerSpawnObject", player, model, skin) then return false end
	return true
end

function OldWireLib.MakeWireEnt( pl, Data, ... )
	Data.Class = scripted_ents.Get(Data.Class).ClassName
	if IsValid(pl) and not pl:CheckLimit(Data.Class:sub(6).."s") then return false end
	if Data.Model and not OldWireLib.CanModel(pl, Data.Model, Data.Skin) then return false end

	local ent = ents.Create( Data.Class )
	if not IsValid(ent) then return false end

	duplicator.DoGeneric( ent, Data )
	ent:Spawn()
	ent:Activate()
	duplicator.DoGenericPhysics( ent, pl, Data ) -- Is deprecated, but is the only way to access duplicator.EntityPhysics.Load (its local)

	ent:SetPlayer(pl)
	if ent.Setup then ent:Setup(...) end

	if IsValid(pl) then pl:AddCount( Data.Class:sub(6).."s", ent ) end

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		if Data.frozen then phys:EnableMotion(false) end
		if Data.nocollide then phys:EnableCollisions(false) end
	end

	return ent
end

-- Adds an input alias so that we can rename inputs on entities without breaking old dupes
-- Usage: OldWireLib.AddInputAlias( old, new ) works if used in the entity's file
-- or OldWireLib.AddInputAlias( class, old, new ) if used elsewhere
-- or OldWireLib.AddInputAlias( entity, old, new ) for a specific entity
function OldWireLib.AddInputAlias( class, old, new )
	if not new then
		new = old
		old = class
		class = nil
	end

	local ENT_table

	if not class and ENT then
		ENT_table = ENT
	elseif isstring( class ) then
		ENT_table = scripted_ents.GetStored( class )
	elseif isentity( class ) and IsValid( class ) then
		ENT_table = class
	else
		error( "Invalid class or entity specified" )
		return
	end

	if not ENT_table.InputAliases then ENT_table.InputAliases = {} end
	ENT_table.InputAliases[old] = new
end

-- Adds an output alias so that we can rename outputs on entities without breaking old dupes
-- Usage: OldWireLib.AddOutputAlias( old, new ) works if used in the entity's file
-- or OldWireLib.AddOutputAlias( class, old, new ) if used elsewhere
-- or OldWireLib.AddOutputAlias( entity, old, new ) for a specific entity
function OldWireLib.AddOutputAlias( class, old, new )
	if not new then
		new = old
		old = class
		class = nil
	end

	local ENT_table

	if not class and ENT then
		ENT_table = ENT
	elseif isstring( class ) then
		ENT_table = scripted_ents.GetStored( class )
	elseif isentity( class ) and IsValid( class ) then
		ENT_table = class
	else
		error( "Invalid class or entity specified" )
		return
	end

	if not ENT_table.OutputAliases then ENT_table.OutputAliases = {} end
	ENT_table.OutputAliases[old] = new
end

local function effectiveMass(ent)
	if not isentity(ent) then return 1 end
	if ent:IsWorld() then return 99999 end
	if not IsValid(ent) or not IsValid(ent:GetPhysicsObject()) then return 1 end
	return ent:GetPhysicsObject():GetMass()
end

function OldWireLib.CalcElasticConsts(Ent1, Ent2)
	local minMass = math.min(effectiveMass(Ent1), effectiveMass(Ent2))
	local const = minMass * 100
	local damp = minMass * 20

	return const, damp
end


-- Returns a string like "Git f3a4ac3" or "SVN 2703" or "Workshop" or "Extracted"
-- The partial git hash can be plugged into https://github.com/wiremod/wire/commit/f3a4ac3 to show the actual commit
local cachedversion
function OldWireLib.GetVersion()
	-- If we've already found our version just return that again
	if cachedversion then return cachedversion end

	-- Find what our legacy folder is called
	local wirefolder = "addons/wire"
	if not file.Exists(wirefolder, "GAME") then
		for k, folder in pairs(({file.Find("addons/*", "GAME")})[2]) do
			if folder:find("wire") and not folder:find("extra") then
				wirefolder = "addons/"..folder
				break
			end
		end
	end

	if file.Exists(wirefolder, "GAME") then
		if file.Exists(wirefolder.."/.git", "GAME") then
			cachedversion = "Git "..(file.Read(wirefolder.."/.git/refs/heads/master", "GAME") or "Unknown"):sub(1,7)
		elseif file.Exists(wirefolder.."/.svn", "GAME") then
			-- Note: This method will likely only detect TortoiseSVN installs
			local wcdb = file.Read(wirefolder.."/.svn/wc.db", "GAME") or ""
			local start = wcdb:find("/wiremod/wire/!svn/ver/%d+/branches%)")
			if start then
				cachedversion = "SVN "..wcdb:sub(start+23, start+26)
			else
				cachedversion = "SVN Unknown"
			end
		else
			cachedversion = "Extracted"
		end
	end

	-- Check if we're Workshop version first
	for k, addon in pairs(engine.GetAddons()) do
		if addon.wsid == "160250458" then
			cachedversion = "Workshop"
			return cachedversion
		end
	end

	if not cachedversion then cachedversion = "Unknown" end

	return cachedversion
end
concommand.Add("wireversion", function(ply,cmd,args)
	local text = "Wiremod's version: '"..OldWireLib.GetVersion().."'"
	if IsValid(ply) then
		ply:ChatPrint(text)
	else
		print(text)
	end
end, nil, "Prints the server's Wiremod version")

function OldWireLib.CheckRegex(data, pattern)
	local limits = {[0] = 50000000, 15000, 500, 150, 70, 40} -- Worst case is about 200ms
	local stripped, nrepl, nrepl2
	-- strip escaped things
	stripped, nrepl = string.gsub(pattern, "%%.", "")
	-- strip bracketed things
	stripped, nrepl2 = string.gsub(stripped, "%[.-%]", "")
	-- strip captures
	stripped = string.gsub(stripped, "[()]", "")
	-- Find extenders
	local n = 0 for i in string.gmatch(stripped, "[%+%-%*]") do n = n + 1 end
	local msg
	if n<=#limits then
		if #data*(#stripped + nrepl - n + nrepl2)>limits[n] then msg = n.." ext search length too long ("..limits[n].." max)" else return end
	else
		msg = "too many extenders"
	end
	error("Regex is too complex! " .. msg)
end

local material_blacklist = {
	["engine/writez"] = true,
	["pp/copy"] = true,
	["effects/ar2_altfire1"] = true
}
function OldWireLib.IsValidMaterial(material)
	material = string.sub(material, 1, 260)
	local path = string.StripExtension(string.GetNormalizedFilepath(string.lower(material)))
	if material_blacklist[path] then return "" end
	return material
end

function OldWireLib.SetColor(ent, color)
	color.r = math_clamp(color.r, 0, 255)
	color.g = math_clamp(color.g, 0, 255)
	color.b = math_clamp(color.b, 0, 255)
	color.a = ent:IsPlayer() and ent:GetColor().a or math_clamp(color.a, 0, 255)

	local rendermode = ent:GetRenderMode()
	if rendermode == RENDERMODE_NORMAL or rendermode == RENDERMODE_TRANSALPHA then
		rendermode = color.a == 255 and RENDERMODE_NORMAL or RENDERMODE_TRANSALPHA
		ent:SetRenderMode(rendermode)
	else
		rendermode = nil -- Don't modify the current stored modifier
	end

	ent:SetColor(color)
	duplicator.StoreEntityModifier(ent, "colour", { Color = color, RenderMode = rendermode })
end

if not OldWireLib.PatchedDuplicator then
	OldWireLib.PatchedDuplicator = true

	local localPos

	local oldSetLocalPos = duplicator.SetLocalPos
	function duplicator.SetLocalPos(pos, ...)
		localPos = pos
		return oldSetLocalPos(pos, ...)
	end

	local oldPaste = duplicator.Paste
	function duplicator.Paste(player, entityList, constraintList, ...)
		local result = { oldPaste(player, entityList, constraintList, ...) }
		local createdEntities, createdConstraints = result[1], result[2]
		local data = {
			EntityList = entityList, ConstraintList = constraintList,
			CreatedEntities = createdEntities, CreatedConstraints = createdConstraints,
			Player = player, HitPos = localPos,
		}
		hook.Run("AdvDupe_FinishPasting", {data}, 1)
		return unpack(result)
	end
end
