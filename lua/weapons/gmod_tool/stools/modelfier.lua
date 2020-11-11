if SERVER then
	util.AddNetworkString("Modelfier:NW:PoseParams")
end

TOOL.Category = "Poser"
TOOL.Name = "#tool.modelfier.name"
TOOL.Information = {
	{name = "left"},
	{name = "right"}
} 

--TOOL.ClientConVar["skin"] = 1
TOOL.ClientConVar["sequence"] = 0
--TOOL.ClientConVar["bodygroups"] = ""
TOOL.ClientConVar["poseparams"] = ""

TOOL.CurrentModel = NULL

if CLIENT then
	language.Add("tool.modelfier.name", "Modelfier")	
	language.Add("tool.modelfier.desc", "Manipulate a model's values")	
    language.Add("tool.modelfier.left", "Apply modifiers")
    language.Add("tool.modelfier.right", "Select a model to modify")


	language.Add("tool.modelfier.nomodel", "There is currently no valid model selected!")
	language.Add("tool.modelfier.noedits", "This model has nothing to modify!")
--	language.Add("tool.modelfier.skin", "Skin")
	language.Add("tool.modelfier.sequence", "Animations")
	--language.Add("tool.modelfier.bodygroup", "Bodygroups")
	language.Add("tool.modelfier.poseparams", "Pose Parameters")
end

function TOOL:BuildSettings()
	-- Sequence
	local sequence = self:GetClientInfo("sequence")

	-- Pose Parameter
	local poseParams = {}

	local values = self:GetClientInfo("poseparams")

	values = string.Explode("|", values)

	for k, v in ipairs(values) do
		local i = string.Split(v, ":")
		poseParams[i[1]] = i[2]
	end

	return sequence, poseParams
end

function TOOL:ApplySettings(target)
	if CLIENT then return end

	local entity = target or self.CurrentModel
	if not IsValid(entity) then return end -- Seems something went wrong.

	local sequence, poseParams = self:BuildSettings()

	if not entity.modelfierAnimated then
		entity.modelfierAnimated = true
	end

	if not (tonumber(sequence) == tonumber(entity:GetSequence())) then
		entity:SetSequence(sequence)
	end

	for k, v in pairs(poseParams) do
		local paramName = entity:GetPoseParameterName(k)
		if not paramName then continue end
		if tonumber(entity:GetPoseParameter(paramName)) == tonumber(v) then continue end
		entity:SetPoseParameter(paramName, tonumber(v))
	end

	net.Start("Modelfier:NW:PoseParams")
		net.WriteEntity(entity)
		net.WriteTable(poseParams)
	net.Broadcast()

	return entity
end

function TOOL:LeftClick(trace)
	local entity = trace.Entity
	if not IsValid(entity) then return end

	self:ApplySettings(entity)

	if CLIENT then
		entity:InvalidateBoneCache()
	end
	
	return true
end

function TOOL:RightClick(trace)
	local entity = trace.Entity
	if not IsValid(entity) then return end

	-- Set the active model
	self.CurrentModel = entity

	-- Refresh the toolgun UI
	if CLIENT then
		self:RebuildCPanel()
	end

	return true
end


-- The rest is client side UI
if SERVER then return end

function TOOL:RebuildCPanel()
	local panel = controlpanel.Get("modelfier")
	if (!spawnmenu.ActiveControlPanel()) then return end
	
	panel:ClearControls()
	self.BuildCPanel(panel, self.CurrentModel)
end

function TOOL:Think()
	-- To prevent spamming
	self.thinkCooldown = self.thinkCooldown or CurTime()

	-- Run every second
	if self.thinkCooldown > CurTime() then return end
	self.thinkCooldown = CurTime() + 1

	if not IsValid(self.CurrentModel) then
		local CPanel = controlpanel.Get( "modelfier" )
		if (!spawnmenu.ActiveControlPanel()) then return end
	
		CPanel:ClearControls()
		self.BuildCPanel(CPanel)
	end
end

function TOOL.BuildCPanel(panel, entity)
	-- Header
	panel:AddControl("Header", {Description = IsValid(entity) and "#tool.modelfier.desc" or "#tool.modelfier.nomodel"})

	-- No valid entity
	if not IsValid(entity) then return end

	if (entity:GetSequenceCount() <= 1) and (entity:GetNumPoseParameters() == 0) then
		panel:AddControl("Header", {Description = "#tool.modelfier.noedits"})
		return
	end

	-- Sequence
	if entity:GetSequenceCount() > 1 then
		-- Filter all the sequences and pull the valid animations 
		local validSeqs = {}
		for i=0, entity:GetSequenceCount()-1 do
			local info = entity:GetSequenceInfo(i)

			if info.numblends > 1 then continue end -- Is likely a pose param

			validSeqs[i] = string.lower(info.label) -- Lower it for consistency
		end

		if table.Count(validSeqs) > 1 then
			panel:AddControl("Header", {Description = "#tool.modelfier.sequence"})
			local listbox = panel:AddControl("ListBox", {Label = "#tool.modelfier.sequence", Height = 17 + table.Count(validSeqs) * 17})
	
			-- Loop all the sequences
			for i, v in pairs(validSeqs) do
				local line = listbox:AddLine(v)
				line.data = {modelfier_sequence = i}
	
				if entity:GetSequence() == i then line:SetSelected(true) end
			end
		end
	end

	if entity:GetNumPoseParameters() > 0 then
		panel:AddControl("Header", {Description = "#tool.modelfier.poseparams"})

		local allSliders = {}
		for i=0, entity:GetNumPoseParameters()-1 do
			local min, max = entity:GetPoseParameterRange(i)
			local slider = panel:AddControl("Slider", {Label = entity:GetPoseParameterName(i), Type = "Int", Min = min, Max = max})

			slider:SetValue(math.Remap(entity:GetPoseParameter(i), 0, 1, min, max))

			allSliders[i] = slider

			slider.OnValueChanged = function(self, value)
				local values = {}
				for k, v in pairs(allSliders) do
					table.insert(values, k..":"..math.Round(v:GetValue()))
				end

				local formatted = table.concat(values, "|")
				RunConsoleCommand("modelfier_poseparams", formatted)
			end
		end
	end
end

-- This will not network to users who join after the change, but this tool is not intended for some long term edit.
net.Receive("Modelfier:NW:PoseParams", function()
	local entity = net.ReadEntity(entity)
	local poseParams = net.ReadTable(poseParams)

	-- In b4 gmod PVS fucks this for some users
	if not IsValid(entity) then return end

	for k, v in pairs(poseParams) do
		local paramName = entity:GetPoseParameterName(k)
		if not paramName then continue end
		if tonumber(entity:GetPoseParameter(paramName)) == tonumber(v) then continue end
		entity:SetPoseParameter(paramName, tonumber(v))
	end

	entity:InvalidateBoneCache()
end)