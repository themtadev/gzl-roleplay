local ENABLE_FAILISH_ATTEMPT_AT_ANTI_ALIASING = false

local OVERLAY_WIDTH      = 256
local OVERLAY_HEIGHT     = 256
local OVERLAY_LINE_WIDTH = 5
local OVERLAY_LINE_COLOR = tocolor ( 0, 200, 0, 255 )
local OVERLAY_LINE_AA    = tocolor ( 0, 200, 0, 200 )

local linePoints  = { }
local renderStuff = { }

function removeLinePoints ( )
	if not next(linePoints) then
		return false
	end
	linePoints = { }
	for name, data in pairs ( renderStuff ) do
		unloadTile ( name )
	end
	return true
end

function addLinePoint ( posX, posY )
	if not tonumber(posX) and not tonumber(poxY) then
		return false
	end

	local row = 11 - math.floor  ( ( tonumber(posY) + 3000 ) / 500 )
	local col =      math.floor ( ( tonumber(posX) + 3000 ) / 500 )

	if row < 0 or row > 11 or col < 0 or col > 11 then
		return false
	end

	local startX = col * 500 - 3000
	local startY = 3000 - row * 500

	local tileX = ( tonumber(posX) - startX ) / 500 * OVERLAY_WIDTH
	local tileY = ( startY - tonumber(posY) ) / 500 * OVERLAY_HEIGHT

	local id   = col + row * 12
	local name = string.format ( "radar%02d", id )

	if not linePoints [ name ] then
		linePoints [ name ] = { }
	end

	table.insert ( linePoints[name], { posX = tileX, posY = tileY } )

	return true
end

function loadTile ( name )

	local shader = dxCreateShader ( "overlay.fx" )
	if not shader then
		return false
	end

	local rt = dxCreateRenderTarget ( OVERLAY_WIDTH, OVERLAY_HEIGHT, true )
	if not rt then
		destroyElement ( shader )
		return false
	end

	dxSetShaderValue ( shader, "gOverlay", rt )

	dxSetRenderTarget ( rt )

	local points = linePoints [ name ]
	local prevX, prevY = points [ 1 ].posX, points [ 1 ] .posY

	for index, point in ipairs ( points ) do
		local newX = point.posX
		local newY = point.posY

		if ENABLE_FAILISH_ATTEMPT_AT_ANTI_ALIASING then
			dxDrawLine ( prevX - 1, prevY - 1, newX - 1, newY - 1, OVERLAY_LINE_AA, OVERLAY_LINE_WIDTH )
			dxDrawLine ( prevX + 1, prevY - 1, newX + 1, newY - 1, OVERLAY_LINE_AA, OVERLAY_LINE_WIDTH )
			dxDrawLine ( prevX - 1, prevY + 1, newX - 1, newY + 1, OVERLAY_LINE_AA, OVERLAY_LINE_WIDTH )
			dxDrawLine ( prevX + 1, prevY + 1, newX + 1, newY + 1, OVERLAY_LINE_AA, OVERLAY_LINE_WIDTH )
		end

		dxDrawLine ( prevX, prevY, newX, newY, OVERLAY_LINE_COLOR, OVERLAY_LINE_WIDTH )

		prevX = newX
		prevY = newY
	end

	engineApplyShaderToWorldTexture ( shader, name )

	renderStuff [ name ] = { shader = shader, rt = rt }

	return true
end

function unloadTile ( name )
	destroyElement ( renderStuff[name].shader )
	destroyElement ( renderStuff[name].rt )
	renderStuff[name] = nil
	return true
end

addEventHandler ( "onClientHUDRender", root,
	function ( )
		local visibleTileNames = table.merge ( engineGetVisibleTextureNames ( "radar??" ), engineGetVisibleTextureNames ( "radar???" ) )

		for name, data in pairs ( renderStuff ) do
			if not table.find ( visibleTileNames, name ) then
				unloadTile ( name )
			end
		end

		for index, name in ipairs ( visibleTileNames ) do
			if linePoints [ name ] and not renderStuff [ name ] then
				loadTile ( name )
			end
		end
	end
)