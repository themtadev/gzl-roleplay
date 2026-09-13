
local outfits,loaded,wearing={},{},setmetatable({},{__mode='k'})
function getCreatorOutfits(gender)
 local result={{id='',name='GZL gardırop'}}
 for _,v in pairs(outfits) do if v.gender==gender then result[#result+1]={id=v.id,name=v.name} end end
 table.sort(result,function(a,b) if a.id=='' then return true elseif b.id=='' then return false else return a.id<b.id end end)
 return result
end
function getCreatorOutfit(data)
 local entry=type(data)=='table' and outfits[data.outfit]
 return entry and entry.gender==(data.gender or 'male') and entry or false
end
function resolveCreatorConfig(data)
 local base=data.gender=='female' and CreatorConfig.Female or CreatorConfig.Male
 local outfit=getCreatorOutfit(data)
 if not outfit then return base end
 local cfg={};for k,v in pairs(base) do cfg[k]=v end
 for k,v in pairs(outfit.config) do cfg[k]=v end
 cfg.accessories=outfit.config.accessories or {}
 return cfg
end
local function load(entry)
 if loaded[entry.id] then return loaded[entry.id] end
 local id=engineRequestModel('ped',entry.gender=='female' and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID)
 if not id then return false end
 local t=engineLoadTXD(entry.txd);local d=engineLoadDFF(entry.dff)
 if not t or not d or not engineImportTXD(t,id) or not engineReplaceModel(d,id,true) then
  if isElement(d) then destroyElement(d) end
  if isElement(t) then destroyElement(t) end
  engineFreeModel(id);return false
 end
 loaded[entry.id]={id=id,txd=t,dff=d};return loaded[entry.id]
end
function applyCreatorOutfitModel(ped,data)
 local outfit=getCreatorOutfit(data)
 if outfit then
  local model=load(outfit)
  if not model then outputDebugString('[Creator] Kombin modeli yüklenemedi: '..outfit.id,1);return false end
  wearing[ped]={key=outfit.id,gender=outfit.gender,data=data}
  if getElementModel(ped)~=model.id then setElementModel(ped,model.id) end
 elseif wearing[ped] then
  wearing[ped]=nil;setElementModel(ped,data.gender=='female' and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID)
 end
 return true
end
local function refresh()
 for _,kind in ipairs({'ped','player'}) do
  for _,ped in ipairs(getElementsByType(kind)) do
   local data=getElementData(ped,'char:customization')
   if type(data)=='table' then applyCharacterCustomization(ped,data) end
  end
 end
end
function registerCreatorOutfit(entry)
 if type(entry)~='table' or type(entry.id)~='string' or type(entry.config)~='table' or type(entry.materials)~='table' then return false end
 if entry.gender~='male' and entry.gender~='female' then return false end
 if outfits[entry.id] then return false end
 if not fileExists(entry.dff) or not fileExists(entry.txd) then return false end
 outfits[entry.id]=entry;refresh();return true
end
function unregisterCreatorOutfit(key)
 if not outfits[key] then return false end
 outfits[key]=nil
 for ped,state in pairs(wearing) do
  if state.key==key and isElement(ped) then
   wearing[ped]=nil;setElementModel(ped,state.gender=='female' and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID)
   applyCharacterCustomization(ped,state.data)
  end
 end
 local asset=loaded[key]
 if asset then engineFreeModel(asset.id);destroyElement(asset.dff);destroyElement(asset.txd);loaded[key]=nil end
 return true
end
addEventHandler('onClientResourceStop',resourceRoot,function()
 local keys={};for key in pairs(outfits) do keys[#keys+1]=key end
 for _,key in ipairs(keys) do unregisterCreatorOutfit(key) end
end)
addEventHandler('onClientElementDestroy',root,function() wearing[source]=nil end)