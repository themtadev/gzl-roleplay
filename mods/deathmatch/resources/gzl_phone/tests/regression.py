"""Run with Python and lupa (Lua 5.1); no live database is touched."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
for path in ROOT.rglob('*.lua'):
    ok, error = compile_lua(path.read_text(encoding='utf-8-sig'), str(path))
    assert ok, error

lua.execute('''
root = {}; resourceRoot = {}; handlers = {}; queries = {}; responses = {}
function addEvent() end
function addEventHandler(name, target, fn) handlers[name] = fn end
function isElement(p) return type(p) == 'table' end
function getElementData(p,k) return p[k] end
function setElementData(p,k,v) p[k] = v end
function getPhoneDB() return {} end
function dbQuery(fn, db, sql, ...) table.insert(queries, {fn=fn, sql=sql, args={...}}) end
function dbPoll(q) return q end
function dbExec() return true end
function fromJSON() return {} end
function toJSON() return '{}' end
function triggerClientEvent(p,event,r,id,value) table.insert(responses,value or {}) end
function getTickCount() return 100 end
function getRealTime() return {timestamp=100, hour=1, minute=1} end
function getResourceFromName() return nil end
exports = {gzl_characters={saveCharacter=function() end}}
''')
lua.execute((ROOT / 'server/main.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
guest = {}; loadPlayerPhoneData(guest); assert(#queries == 0, 'guest queried shared account')
p = {['char:id']=7, ['character:bank']=100}; loadPlayerPhoneData(p)
p['char:id']=8
queries[1].fn({{char_id=7,phone_number='555-0007',iban='GZL-0007'}})
assert(p['char:phone'] == nil, 'stale character data applied')
assert(#queries == 2, 'new character was not loaded')
queries[2].fn({{char_id=8,phone_number='555-0008',iban='GZL-0008'}})
assert(p['char:phone'] == '555-0008')
client=p; source=p
handlers['cylex_phone:serverCallback']('transferMoney',{iban='GZL-0009',amount=80},'a')
handlers['cylex_phone:serverCallback']('transferMoney',{iban='GZL-0009',amount=80},'b')
q = {['char:id']=9,['character:bank']=0}; loadPlayerPhoneData(q)
queries[5].fn({{char_id=9,phone_number='555-0009',iban='GZL-0009'}})
queries[3].fn({{char_id=9,phone_number='555-0009',iban='GZL-0009'}})
queries[4].fn({{char_id=9,phone_number='555-0009',iban='GZL-0009'}})
assert(p['character:bank'] == 20, 'sender balance race')
assert(q['character:bank'] == 80, 'recipient credited twice')
assert(responses[#responses].success == false)
handlers['cylex_phone:serverCallback']('transferMoney',{iban='GZL-0008',amount=10},'c')
queries[#queries].fn({{char_id=8,phone_number='555-0008',iban='GZL-0008'}})
assert(p['character:bank'] == 20, 'self transfer changed balance')
assert(responses[#responses].success == false)
p['char:id']=10
assert(getPlayerByPhoneNumber('555-0008') == nil, 'old phone still routed to new character')
''')
print('PASS: Lua 5.1 syntax, guest isolation, character load race, transfer race, self transfer, stale phone routing')
