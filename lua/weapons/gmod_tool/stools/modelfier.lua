TOOL.Category = "Posing"
TOOL.Name = "#tool.modelfier.name"
TOOL.Information = {
	{name = "left"},
	{name = "right"}
} 

TOOL.ClientConVar["skin"] = 0
TOOL.ClientConVar["sequence"] = 0
TOOL.ClientConVar["bodygroups"] = {}
TOOL.ClientConVar["poseparams"] = {}

if CLIENT then
	language.Add("tool.modelfier.name", "Modelfier")	
	language.Add("tool.modelfier.desc", "Manipulate a model's values")	
    language.Add("tool.modelfier.left", "Apply modifiers")
    language.Add("tool.modelfier.right", "Select a model to modify")
end

function TOOL:LeftClick(trace)
end
function TOOL:RightClick(trace)
end

-- The rest is client side UI
if SERVER then return end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {Text = "#tool.modelfier.name", Description = "#tool.modelfier.desc"})
end