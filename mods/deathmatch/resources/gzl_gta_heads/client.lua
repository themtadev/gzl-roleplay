local registered=false
local function register()
 local creator=getResourceFromName('gzl_creator')
 if not creator or getResourceState(creator)~='running' then return end
 local prefix=':'..getResourceName(getThisResource())..'/'
 for _,variant in pairs(GZLOutfit.headVariants) do
  if variant.dff:sub(1,1)~=':' then variant.dff=prefix..variant.dff;variant.txd=prefix..variant.txd end
 end
 GZLOutfit.dff=GZLOutfit.headVariants[0].dff;GZLOutfit.txd=GZLOutfit.headVariants[0].txd
 for _,files in pairs(GZLOutfit.materials) do
  for i,path in ipairs(files) do if path:sub(1,1)~=':' then files[i]=prefix..path end end
 end
 registered=exports.gzl_creator:registerCreatorOutfit(GZLOutfit)
 if not registered then outputDebugString('[GZL Studio] Creator outfit kaydı başarısız: '..GZLOutfit.id,1) end
end
addEventHandler('onClientResourceStart',resourceRoot,register)
addEventHandler('onClientResourceStart',root,function(r)
 if r==getResourceFromName('gzl_creator') then register() end
end)
addEventHandler('onClientResourceStop',resourceRoot,function()
 if registered and getResourceState(getResourceFromName('gzl_creator'))=='running' then exports.gzl_creator:unregisterCreatorOutfit(GZLOutfit.id) end
end)