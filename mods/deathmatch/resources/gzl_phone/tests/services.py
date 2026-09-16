"""Exercise the real Lua services against an isolated SQLite database."""
import json
import sqlite3
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime, lua_type

ROOT = Path(__file__).resolve().parents[1]
db = sqlite3.connect(':memory:')
db.execute('CREATE TABLE phone_app_state (app TEXT PRIMARY KEY, data TEXT NOT NULL)')
db.execute('CREATE TABLE phone_users (char_id INTEGER PRIMARY KEY,settings TEXT,photos TEXT,darkchat_user TEXT)')
db.execute("CREATE TABLE phone_darkgroups (id INTEGER PRIMARY KEY,name TEXT,photo TEXT,code TEXT UNIQUE,creator TEXT,members TEXT,bans TEXT)")
db.execute('CREATE TABLE phone_darkmessages (id INTEGER PRIMARY KEY,group_id INTEGER,sender TEXT,message TEXT,time INTEGER)')

def runtime():
    lua=LuaRuntime(unpack_returned_tuples=True)
    def to_python(value):
        if lua_type(value) != 'table': return value
        items=dict(value.items())
        if all(isinstance(k,(int,float)) for k in items) and set(items)==set(range(1,len(items)+1)):
            return [to_python(items[i]) for i in range(1,len(items)+1)]
        return {str(k):to_python(v) for k,v in items.items()}
    def table(value):
        if isinstance(value,(list,dict)): return lua.table_from(value,recursive=True)
        return value
    def query(_db,sql,*args):
        cursor=db.execute(sql,args)
        return table([dict(zip([d[0] for d in cursor.description],row)) for row in cursor.fetchall()])
    def execute(_db,sql,*args): db.execute(sql,args); return True
    lua.globals().dbQuery=query
    lua.globals().dbExec=execute
    lua.globals().toJSON=lambda value:json.dumps(to_python(value))
    lua.globals().fromJSON=lambda value:table(json.loads(value)) if value else lua.table()
    lua.execute('''
        root={};resourceRoot={};players={};result=nil
        function isElement(p) return type(p)=='table' end
        function getElementsByType() return players end
        function getElementData(p,k) return p[k] end
        function getPhoneNumber(p) return p.number end
        function getPhoneDB() return true end
        function dbPoll(q) return q end
        function triggerClientEvent() end
        function getRealTime() return {timestamp=100000} end
        function getTickCount() return 123 end
        -- Deterministic test double only; production uses MTA bcrypt.
        function passwordHash(value,algorithm,options,callback)
            if callback then callback('test-hash:'..value);return true end
            return 'test-hash:'..value
        end
        function passwordVerify(value,encoded,options,callback)
            local valid=encoded=='test-hash:'..value
            if callback then callback(valid);return true end
            return valid
        end
        function reply(value) result=value end
        alice={['char:id']=101,number='555-0101'};bob={['char:id']=102,number='555-0102'};eve={['char:id']=103,number='555-0103'}
        players={alice,bob,eve}
    ''')
    for name in ['apps','utilities','darkchat']:
        lua.execute((ROOT/f'server/{name}.lua').read_text(encoding='utf-8'))
    return lua

lua=runtime()
lua.execute('''
function request(p,endpoint,data) result=nil;PhoneApps.handle(p,p['char:id'],endpoint,data,reply);assert(result,'Missing response');return result end
for _,app in ipairs({'frogly','twitter','instagram','foffy','swiper','hacker'}) do
    assert(request(alice,'app:createAccount',{app=app,tag='alice',password='secret',nickname='Alice'}).value.success)
end
assert(request(bob,'app:createAccount',{app='frogly',tag='alice',password='wrong'}).success==false)
assert(request(bob,'app:loginAccount',{app='frogly',tag='alice',password='wrong'}).success==false)
assert(request(bob,'app:createAccount',{app='frogly',tag='bobby',password='secret'}).value.success)
local posted=request(alice,'frogly:sendPost',{text='hello',tag='bobby'}).value.post
assert(posted.tag=='alice','caller controlled post author')
assert(request(bob,'frogly:deletePost',{id=posted.id}).success==false,'non-owner deleted post')
assert(request(bob,'frogly:likePost',{id=posted.id}).value.success)
assert(request(bob,'frogly:sendPostComment',{id=posted.id,text='reply'}).value.success)
local timeline=request(alice,'frogly:fetchTimeline',{}).value.posts
assert(#timeline==1 and #timeline[1].likes==1 and #timeline[1].comments==1)
assert(request(alice,'frogly:messages:sendMessage',{selectedMessageId='bobby',message='private'}).value.success)
assert(PhoneApps.snapshot('frogly',102).messages.alice.messages[1].message=='private')
assert(next(PhoneApps.snapshot('frogly',103).messages)==nil,'DM leaked to unrelated character')
local public=PhoneApps.snapshot('frogly',102).accounts.alice
assert(public.password==nil and public.owner==nil,'private account fields leaked')
assert(request(alice,'app:logout',{app='frogly'}).value.success)
assert(request(alice,'frogly:sendPost',{text='logged out'}).success==false)
assert(request(alice,'app:loginAccount',{app='frogly',tag='alice',password='secret'}).value.success)
''')
lua=runtime()  # A fresh service instance must load its state from SQLite.
lua.execute('''
assert(PhoneApps.snapshot('frogly',101).selected.tag=='alice','session not persisted')
assert(PhoneApps.snapshot('frogly',101).posts[1].text=='hello','posts not persisted')
pa={charId=101,number='555-0101',settings={},photos={}}
pb={charId=102,number='555-0102',settings={},photos={}}
function dark(p,d,endpoint,data) result=nil;PhoneDark.handle(p,d,'darkchat:'..endpoint,data,reply);assert(result);return result end
assert(dark(alice,pa,'createNewChat',{name='Private group',password='secret'}).value.success)
assert(dark(bob,pb,'joinChat',{id=1,password='wrong'}).success==false)
assert(next(PhoneDark.snapshot(pb.number))==nil)
assert(dark(bob,pb,'sendMessage',{messageId=1,message='outsider'}).success==false)
assert(dark(bob,pb,'joinChat',{id=1,password='secret'}).value.success)
assert(dark(bob,pb,'sendMessage',{messageId=1,message='member'}).value.success)
assert(PhoneDark.snapshot(pa.number)['1'].messages[1].message=='member')
assert(dark(bob,pb,'changeGroupName',{messageId=1,name='stolen'}).success==false)
assert(dark(alice,pa,'removeGroupMember',{messageId=1,targetNumber=pb.number}).value.success)
assert(next(PhoneDark.snapshot(pb.number))==nil)
PhoneUtilities.handle(alice,pa,'gallery:createAlbum',{name='Album'},reply)
local id=result.albums[1].id
PhoneUtilities.handle(alice,pa,'gallery:addPhotoToAlbum',{albumId=id,photoId='local-photo'},reply)
assert(result.albums[1].photos[1]=='local-photo')
PhoneUtilities.handle(alice,pa,'gallery:removePhotosFromAlbum',{albumId=id,photoIds={'local-photo'}},reply)
assert(#result.albums[1].photos==0)
for _,app in ipairs({'twitter','instagram','foffy'}) do
    PhoneApps.handle(alice,101,app..':sendPost',{text='Test post',images={'../images/background/b1.png'}},reply)
    assert(result.value.success)
end
PhoneApps.handle(alice,101,'app:changeBio',{app='frogly',input='Updated bio'},reply)
assert(result.mtaSocial.accounts.alice.bio=='Updated bio')
PhoneApps.handle(alice,101,'app:changePassword',{app='frogly',oldPassword='wrong',newPassword='newsecret'},reply)
assert(result.success==false)
PhoneApps.handle(alice,101,'instagram:newStory',{image='https://example.test/image.jpg'},reply)
assert(result.value.success)
assert(#PhoneApps.snapshot('instagram',101).stories.alice==1)
PhoneApps.handle(alice,101,'twitter:sendPost',{text='#GZL #gzl #phone'},reply)
local hashtagPost=result.value.post.id
PhoneApps.handle(alice,101,'twitter:getHashtagCounts',{},reply)
assert(result.value[1].tag=='gzl' and result.value[1].count==1,'duplicate hashtag inflated count')
PhoneApps.handle(alice,101,'twitter:getAllHashtags',{},reply)
assert(result.value[1]=='gzl' and result.value[2]=='phone')
PhoneApps.handle(alice,101,'twitter:search:getTweetByHashtag',{searchTag='#GZL'},reply)
assert(#result.value.tweets==1 and result.value.tweets[1].id==hashtagPost)
PhoneApps.handle(alice,101,'twitter:search:getTweetByHashtag',{searchTag='gz'},reply)
assert(#result.value.tweets==0,'hashtag search matched a partial tag')
PhoneApps.handle(alice,101,'app:getNotifications',{app='frogly'},reply)
assert(#result.value>=2,'social interactions did not produce notifications')
assert(#PhoneApps.snapshot('frogly',102).accounts.alice.notifications==0,'private notifications leaked')
PhoneApps.handle(alice,101,'appAccounts:clearNotifications',{app='frogly'},reply)
PhoneApps.handle(alice,101,'app:getNotifications',{app='frogly'},reply)
assert(#result.value==0,'notifications were not cleared')
PhoneApps.handle(bob,102,'app:createAccount',{app='swiper',tag='bobby',password='secret'},reply)
PhoneApps.handle(alice,101,'swiper:messages:sendMessage',{toTag='bobby',message='before match'},reply)
assert(result.success==false,'unmatched user could send a message')
PhoneApps.handle(alice,101,'swiper:likeUser',{targetTag='bobby'},reply)
PhoneApps.handle(bob,102,'swiper:likeUser',{targetTag='alice'},reply)
assert(PhoneApps.snapshot('swiper',101).accounts.bobby.likedUserTags.alice)
PhoneApps.handle(alice,101,'swiper:messages:sendMessage',{matchId='alice_bobby',toTag='bobby',message='matched'},reply)
assert(result.value.success)
PhoneApps.handle(bob,102,'swiper:messages:fetchChatMessages',{matchId='alice_bobby'},reply)
assert(result.value.messages[1].message=='matched')
PhoneApps.handle(alice,101,'swiper:reportUser',{targetTag='bobby',reason='test report'},reply)
local reportId=result.value.reportId
PhoneApps.handle(alice,101,'swiper:reportUser',{targetTag='bobby',reason='duplicate'},reply)
assert(result.value.reportId==reportId,'duplicate open report created')
PhoneApps.handle(alice,101,'swiper:unmatch',{targetTag='bobby'},reply)
assert(next(PhoneApps.snapshot('swiper',101).messages)==nil)
PhoneApps.handle(bob,102,'swiper:messages:sendMessage',{toTag='alice',message='after unmatch'},reply)
assert(result.success==false)
Config={PhoneVerifiedPrice=10000,SwiperGoldPrice=1000,PhoneSubscriptionDays=30}
function getResourceFromName() return true end
function getResourceState() return 'running' end
exports={gzl_characters={getPlayerBank=function(_,p)return p.bank end,setPlayerBank=function(_,p,value)p.bank=value;return true end}}
alice.bank=10500
PhoneApps.handle(alice,101,'app:purchaseVerifiedAccount',{app='twitter',price=1},reply)
assert(result.value.success and alice.bank==500,'client supplied subscription price accepted')
assert(PhoneApps.snapshot('twitter',101).accounts.alice.verified)
PhoneApps.handle(alice,101,'app:purchaseVerifiedAccount',{app='twitter',price=1},reply)
assert(result.success==false and alice.bank==500,'duplicate subscription charged')
PhoneApps.handle(alice,101,'swiper:purchaseGold',{},reply)
assert(result.success==false and alice.bank==500,'insufficient balance accepted')
alice.bank=2000
PhoneApps.handle(alice,101,'swiper:purchaseGold',{},reply)
assert(result.value.success and alice.bank==1000 and PhoneApps.snapshot('swiper',101).accounts.alice.premium)
''')
if '--fixture' in sys.argv:
    (ROOT/'tests/fixtures.json').write_text(lua.eval('toJSON(PhoneApps.bootstrap(101))'),encoding='utf-8')
print('PASS: six-app signup, password validation, duplicate accounts, author ownership, likes/comments, DM privacy, logout, SQLite reload, darkchat membership/ownership, gallery albums')
