-- INSERT_MOCKS
-- INSERT_MODULES
local Core=factories.Infrastructure()
local before=liveConnections()
local runtime=Core.new({Players=Players,RunService=RunService,Input=Input,Task=task,Warn=warn})
local ui=factories.DiqUILib({Runtime=runtime})
local window=ui:CreateWindow({Title="Test"})
local tab=window:CreateTab("Controls")
local base=liveConnections()
local calls=0
local toggle=tab:CreateToggle("Toggle",false,function() calls+=1 end,{Keybind={Default=Enum.KeyCode.F}})
toggle:Set(true)
check(calls==1 and toggle:Get(),"UI setters publish synchronously")
Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.F},false)
check(calls==2 and not toggle:Get(),"Embedded hotkey controls the same state")
Input.textbox={}
Input.InputBegan:Fire({UserInputType=Enum.UserInputType.Keyboard,KeyCode=Enum.KeyCode.F},false)
check(calls==2,"Embedded hotkeys ignore text entry")
Input.textbox=nil
toggle:Destroy(); toggle:Destroy(); toggle:Set(true)
check(calls==2 and #window._elements==0,"Destroyed element leaves no reset registration and cannot publish")
check(liveConnections()==base,"Destroying a control releases its listeners immediately")
local sliderCalls=0
local sliders={}
for i=1,100 do sliders[i]=tab:CreateSlider("S"..i,0,100,0,function() sliderCalls+=1 end) end
check(Input.InputChanged:Count()==1 and Input.InputEnded:Count()==1,"One engine input channel supports 100 sliders")
sliders[1]:Set(10); sliders[1]:Set(10)
check(sliderCalls==1,"Repeated quantized slider value does not invoke callback")
for _,slider in sliders do slider:Destroy() end
check(liveConnections()==base and #window._elements==0,"Repeated slider creation/destruction does not retain service listeners")
local dropdown=tab:CreateDropdown("Options",{"A","B"},"A",function() end)
local dropdownBase=liveConnections()
for _=1,20 do dropdown:SetOptions({"A","B"}) end
check(liveConnections()==dropdownBase,"Rebuilding dropdown options releases old handlers")
dropdown:Destroy(); check(liveConnections()==base,"Dropdown cleanup is local")
local enabled=true
local reset=tab:CreateToggle("Reset",false,function(value) enabled=value end)
reset:Set(true); window:ResetAll()
check(not enabled and not reset:Get(),"ResetAll completes synchronously")
reset:Destroy()
local section=tab:CreateSection("Section")
local nested=section:CreateToggle("Nested",false,function() error("must not run") end,{Keybind={Default=Enum.KeyCode.F}})
section:Destroy(); nested:Set(true)
check(liveConnections()==base and #window._elements==0,"Destroying section cleans up descendants and reset registrations")
local resumed=false
local yielding=tab:CreateToggle("Yielding",false,function() task.wait(1); resumed=true end)
yielding:Set(true); advance(2)
check(resumed,"Yielding callback resumes while its control is alive")
resumed=false
yielding:Set(true); yielding:Destroy(); advance(2)
check(not resumed,"Destroyed control cannot resume a yielding callback")
ui:Notify("Test","Pending",10)
ui:Destroy(); runtime:Destroy()
advance(20); advance(0)
check(liveConnections()==before,"UI shutdown releases notifications, controls and shared input")
check(#warnings==0,"No swallowed callback failures in UI scenarios")
print("UI checks passed: "..checks)
