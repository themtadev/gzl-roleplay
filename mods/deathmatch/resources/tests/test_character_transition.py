"""Run with python tests/test_character_transition.py (requires lupa).

Executes production Lua 5.1 against a small MTA event/DB mock. This checks
transition ordering, not GTA rendering or network packet delivery.
"""
from pathlib import Path
from itertools import permutations
import unittest
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''
root = {}; resourceRoot = {}; localPlayer = {}; client = localPlayer; source = localPlayer
handlers = {}; data = {}; queries = {}; events = {}; timers = {}; spawnOK = true
function addEvent() end
function addEventHandler(name, element, fn)
    handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn)
end
function removeEventHandler(name, element, fn)
    for i,v in ipairs(handlers[name] or {}) do if v == fn then table.remove(handlers[name],i); break end end
end
function fire(name, ...) for _,fn in ipairs(handlers[name] or {}) do fn(...) end end
function isElement(e) return type(e) == 'table' end
function getElementData(e,k) return data[k] end
function setElementData(e,k,v) data[k]=v end
function getElementInterior() return playerInterior or 0 end
function setElementInterior(e,v) playerInterior=v end
function setElementDimension(e,v) playerDimension=v end
function setCameraInterior(v,serverValue) cameraInterior=serverValue or v end
function setCameraTarget(...) cameraTarget=select(1,...); cameraArgs=select('#',...) end
function setCameraMatrix(...) cameraTarget=false end
function setElementFrozen(e,v) frozen=v end
function spawnPlayer(...) spawnCalls=(spawnCalls or 0)+1; return spawnOK end
function dbQuery(fn,...) table.insert(queries,fn) end
function dbPoll() return rows end
function reply(value) rows=value; table.remove(queries,1)(1) end
function getCharacterDB() return {} end
function triggerClientEvent(p,name,...) table.insert(events,name) end
function triggerEvent(name,...) table.insert(events,name) end
function setTimer(fn,...) table.insert(timers,fn); return {} end
function getThisResource() return resourceRoot end
function getResourceFromName() return nil end
function getElementsByType() return {} end
function getElementType() return 'player' end
function guiGetScreenSize() return 1920,1080 end
function fromJSON() return {} end
function toJSON() return '{}' end
function getTickCount() return 1 end
function hasEvent(name) for _,v in ipairs(events) do if v==name then return true end end return false end
function noop() end
for _,name in ipairs({'setPlayerHudComponentVisible','setTime','setWeather','setMinuteDuration',
 'fadeCamera','showCursor','showChat','setElementAlpha','setElementHealth','setPedArmor',
 'setPlayerMoney','dbExec','outputDebugString','outputChatBox','addCommandHandler','destroyElement',
 'setElementRotation'}) do _G[name]=noop end
exports = setmetatable({}, {__index=function() return {} end})
'''


class TransitionTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK)

    def load(self, path):
        self.lua.execute((ROOT / path).read_text(encoding='utf-8-sig'))

    def server(self):
        self.load('gzl_characters/shared/config.lua')
        self.load('gzl_characters/server/main.lua')
        self.lua.execute("data['account:id']=7")

    def test_studio_restores_interior_and_target_even_on_repeat(self):
        self.load('gzl_characters/shared/config.lua')
        self.load('gzl_characters/client/studio.lua')
        self.lua.execute('''startCharacterStudio(); playerInterior=5; stopCharacterStudio()
            assert(cameraTarget==localPlayer and cameraInterior==5)
            cameraTarget=false; stopCharacterStudio(); assert(cameraTarget==localPlayer)''')

    def test_auth_render_loop_cannot_retake_spawn_camera(self):
        self.load('gzl_auth/client/camera.lua')
        self.lua.execute('''startAuthCamera(); fire('onClientRender'); assert(cameraTarget==false)
            fire('char:spawnSuccess'); fire('onClientRender')
            assert(cameraTarget==localPlayer and cameraArgs==1)''')

    def test_creator_render_loop_stops_on_spawn(self):
        self.load('gzl_creator/client/camera.lua')
        self.lua.execute('''startStudioCamera(nil); fire('char:spawnSuccess')
            assert(#handlers.onClientPreRender==0 and cameraTarget==localPlayer)''')

    def test_failed_spawn_does_not_publish_character_or_success(self):
        self.server()
        self.lua.execute('''spawnOK=false; fire('char:select',1); reply({{id=1}})
            assert(not data.loggedin_character and not data['character:id'])
            assert(not hasEvent('char:spawnSuccess') and hasEvent('char:response'))''')

    def test_new_custom_character_spawn_failure(self):
        self.server()
        self.lua.execute('''spawnOK=false
            fire('char:create','Test_Player',1,24,170,{gender='male'})
            reply({}); reply({}); reply({{id=1,name='Test_Player'}})
            assert(spawnCalls==1 and not data.loggedin_character)
            assert(not hasEvent('char:spawnSuccess') and hasEvent('char:response'))''')

    def test_optional_ui_error_cannot_leave_studio_camera(self):
        self.load('gzl_characters/shared/config.lua')
        self.load('gzl_characters/client/studio.lua')
        self.load('gzl_characters/client/gui.lua')
        self.lua.execute('''startCharacterStudio(); playerInterior=3
            exports.gzl_ui={setActiveEditBox=function() error('UI unavailable') end}
            local ok=pcall(fire,'char:spawnSuccess')
            assert(not ok and cameraTarget==localPlayer and cameraInterior==3)''')

    def test_client_ignores_late_character_list(self):
        self.load('gzl_characters/shared/config.lua')
        self.load('gzl_characters/client/studio.lua')
        self.load('gzl_characters/client/gui.lua')
        self.lua.execute('''data.loggedin_character=true; cameraTarget=localPlayer
            fire('char:receiveList',{}); assert(cameraTarget==localPlayer)''')

    def test_success_preserves_saved_interior_and_coma(self):
        self.server()
        self.lua.execute('''fire('char:select',1)
            reply({{id=1,name='Test_Player',interior=5,dimension=42,is_dead=1}})
            assert(data.loggedin_character and hasEvent('char:spawnSuccess'))
            assert(cameraInterior==5 and playerDimension==42 and frozen==true)''')

    def test_late_list_discarded_after_spawn(self):
        self.server()
        self.lua.execute('''fire('char:requestList'); data.loggedin_character=true; reply({{id=1}})
            assert(not hasEvent('char:receiveList'))''')

    def test_old_account_reply_cannot_spawn(self):
        self.server()
        self.lua.execute('''fire('char:select',1); data['account:id']=8; reply({{id=1}})
            assert(not spawnCalls and not hasEvent('char:spawnSuccess'))''')

    def creator(self):
        self.lua.execute('''
            function createPed() return {} end
            function getElementPosition() return 835,-2060,13 end
            function getElementRotation() return 0,0,180 end
            function processLineOfSight() return false end
            function triggerServerEvent(name) table.insert(events,name) end
            function applyCharacterCustomization() end
            function resetPedShaders() end
            function setPedAnimation() end
        ''')
        self.load('gzl_creator/shared/config.lua')
        self.load('gzl_creator/client/camera.lua')
        self.load('gzl_creator/client/gui.lua')

    def test_creator_notification_error_does_not_block_close(self):
        self.creator()
        self.lua.execute('''setCreatorVisible(true)
            exports.gzl_ui={showNotification=function() error('notification unavailable') end}
            data.loggedin_character=true
            local ok=pcall(fire,'gzl_creator:saveResponse',true,'saved')
            assert(not ok and cameraTarget==localPlayer)
            assert(#handlers.onClientPreRender==0 and hasEvent('gzl_creator:cancelSession'))''')

    def test_creator_shader_error_does_not_leave_session_frozen(self):
        self.creator()
        self.lua.execute('''setCreatorVisible(true)
            function resetPedShaders() error('shader unavailable') end
            local ok=pcall(setCreatorVisible,false)
            assert(not ok and cameraTarget==localPlayer)
            assert(#handlers.onClientPreRender==0 and hasEvent('gzl_creator:cancelSession'))''')

    def test_camera_event_order_permutations(self):
        for order in permutations(('auth','studio','creator')):
            with self.subTest(order=order):
                self.setUp()
                self.load('gzl_characters/shared/config.lua')
                for resource in order:
                    if resource=='auth':
                        self.load('gzl_auth/client/camera.lua')
                    elif resource=='studio':
                        self.load('gzl_characters/client/studio.lua')
                        self.load('gzl_characters/client/gui.lua')
                    else:
                        self.load('gzl_creator/client/camera.lua')
                self.lua.execute('''startAuthCamera(); startCharacterStudio(); startStudioCamera(nil)
                    playerInterior=6; data.loggedin_character=true
                    fire('char:spawnSuccess'); fire('onClientRender'); fire('onClientPreRender')
                    assert(cameraTarget==localPlayer and cameraInterior==6)''')

    def test_successful_creation_uses_configured_spawn(self):
        self.server()
        self.lua.execute('''CharConfig.DefaultSpawn.interior=5; CharConfig.DefaultSpawn.dimension=42
            fire('char:create','Test_Player',1,24,170,{gender='male'})
            reply({}); reply({}); reply({{id=1,name='Test_Player'}})
            assert(spawnCalls==1 and data.loggedin_character and hasEvent('char:spawnSuccess'))
            assert(cameraInterior==5 and playerDimension==42 and frozen==false)''')

    def test_failed_selection_can_retry(self):
        self.server()
        self.lua.execute('''spawnOK=false; fire('char:select',1); reply({{id=1}})
            spawnOK=true; fire('char:select',1); reply({{id=1}})
            assert(spawnCalls==2 and data.loggedin_character and hasEvent('char:spawnSuccess'))''')

    def test_all_modified_lua_compiles(self):
        for path in ['gzl_auth/client/camera.lua', 'gzl_characters/client/studio.lua',
                     'gzl_characters/client/gui.lua', 'gzl_characters/server/main.lua',
                     'gzl_creator/client/camera.lua', 'gzl_creator/client/gui.lua']:
            self.lua.execute('assert(loadstring(...))', (ROOT/path).read_text(encoding='utf-8-sig'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
