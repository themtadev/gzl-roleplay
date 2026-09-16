-- Persistent social services shared by the converted NUI applications.
PhoneApps = {}
local cache, registering = {}, {}
local supported = { frogly=true, twitter=true, instagram=true, foffy=true, swiper=true, hacker=true }
local aliases = {
    sendTweet={'twitter','sendPost'}, deleteTweet={'twitter','deletePost'},
    likeTweet={'twitter','likePost'}, sendTweetComment={'twitter','sendPostComment'},
    deleteTweetComment={'twitter','deletePostComment'}, likeTweetComment={'twitter','likePostComment'}
}

local function decode(value)
    local result = type(value) == 'string' and fromJSON(value) or nil
    return type(result) == 'table' and result or {}
end
local function getState(app)
    if not cache[app] then
        local rows = dbPoll(dbQuery(getPhoneDB(), 'SELECT data FROM phone_app_state WHERE app = ?', app), -1)
        if not rows then return nil end
        local state = decode(rows[1] and rows[1].data)
        state.accounts = state.accounts or {}
        state.sessions = state.sessions or {}
        state.posts = state.posts or {}
        state.messages = state.messages or {}
        state.stories = state.stories or {}
        state.reports = state.reports or {}
        state.nextId = tonumber(state.nextId) or 0
        cache[app] = state
    end
    return cache[app]
end
local function save(app, state)
    return dbExec(getPhoneDB(), 'INSERT OR REPLACE INTO phone_app_state (app, data) VALUES (?, ?)', app, toJSON(state))
end
local function nextId(state)
    state.nextId = state.nextId + 1
    return state.nextId
end
local function notifyAccount(state, recipient, sender, kind, postId)
    local account=state.accounts[recipient or '']
    if not account or recipient==sender then return end
    account.notifications=account.notifications or {}
    table.insert(account.notifications,1,{id=nextId(state),tag=sender,type=kind,postId=postId,
        picture=(state.accounts[sender] or {}).picture or '',date=getRealTime().timestamp*1000,time=getRealTime().timestamp})
    while #account.notifications>100 do table.remove(account.notifications) end
end
local function fail(message) return {success=false, error=message} end
local function find(list, id)
    for index, item in ipairs(list) do
        if tostring(item.id) == tostring(id) then return item, index end
    end
end
local function toggle(list, value)
    for i, item in ipairs(list) do if item == value then table.remove(list,i) return false end end
    table.insert(list,value)
    return true
end
local function postHashtags(post)
    local tags = {}
    for value in tostring(post.text or post.content or ''):gmatch('#([%w_\128-\255]+)') do
        tags[string.lower(value)] = true
    end
    return tags
end
local function publicAccounts(state, viewer)
    local result = {}
    for tag, account in pairs(state.accounts) do
        result[tag] = {tag=tag, nickname=account.nickname, picture=account.picture or '',
            background=account.background or '', backgroundPhoto=account.background or '', bio=account.bio or '',
            verified=(tonumber(account.verifiedUntil) or 0)>getRealTime().timestamp,
            premium=(tonumber(account.premiumUntil) or 0)>getRealTime().timestamp,premium_expiry=account.premiumUntil or 0,
            daily_swipes=account.swipeDay==math.floor(getRealTime().timestamp/86400) and (account.dailySwipes or 0) or 0,
            following=account.following or {}, followers=account.followers or {},
            notifications=tag==viewer and account.notifications or {}, created=account.created, createdAt=account.created, time=account.created,
            photos=account.photos or {},age=account.age or 18,gender=account.gender or '',
            selected_preference=account.selected_preference or 'everyone',age_range=account.age_range or {min=18,max=100},
            interests=account.interests or {},likedUserTags=tag==viewer and account.likedUserTags or (viewer and account.likedUserTags and account.likedUserTags[viewer] and {[viewer]=account.likedUserTags[viewer]} or {}),rejectedUserTags=tag==viewer and account.rejectedUserTags or {}}
    end
    return result
end
local function chats(state, tag)
    local result = {}
    if not tag then return result end
    for _, message in ipairs(state.messages) do
        if message.sender == tag or message.receiver == tag then
            local target = message.sender == tag and message.receiver or message.sender
            if not result[target] then
                result[target] = {id=target, target=target, type='single', name=target, unread=0,
                    list={[tag]={tag=tag},[target]={tag=target}}, messages={}}
            end
            local chat = result[target]
            table.insert(chat.messages,message)
            chat.lastMessage = message
            if message.receiver == tag and not message.isRead then chat.unread = chat.unread + 1 end
        end
    end
    return result
end
function PhoneApps.snapshot(app, charId)
    local state = getState(app)
    if not state then return nil end
    local tag = state.sessions[tostring(charId)]
    if not state.accounts[tag or ''] then tag = nil end
    local posts = {}
    local stories = {}
    for _,story in ipairs(state.stories) do
        if getRealTime().timestamp-story.time<86400 then
            stories[story.tag]=stories[story.tag] or {}
            table.insert(stories[story.tag],story)
        end
    end
    for i=1,math.min(#state.posts,100) do posts[i]=state.posts[i] end
    return {app=app, accounts=publicAccounts(state,tag), selected={tag=tag or '', password=tag and 'session' or '', logged=tag ~= nil},
        posts=posts, stories=stories, messages=chats(state,tag),prices={verified=Config and Config.PhoneVerifiedPrice or 10000,gold=Config and Config.SwiperGoldPrice or 1000}}
end
function PhoneApps.bootstrap(charId)
    local result = {}
    for app in pairs(supported) do result[app] = PhoneApps.snapshot(app,charId) end
    return result
end
function PhoneApps.route(endpoint, data)
    if aliases[endpoint] then return unpack(aliases[endpoint]) end
    local app, action = endpoint:match('^([^:]+):(.+)$')
    if app == 'app' or app == 'appAccounts' then app = tostring(data.app or '') end
    if supported[app] then return app, action end
end

function PhoneApps.handle(player, charId, endpoint, data, reply)
    local app, action = PhoneApps.route(endpoint,data)
    if not app then reply(fail('Unsupported social application')) return end
    local state = getState(app)
    if not state then reply(fail('Application database unavailable')) return end
    local owner = tostring(charId)
    local tag = state.sessions[owner]
    local account = state.accounts[tag or '']
    local function finish(value, changed)
        if changed then save(app,state) end
        reply({mtaSocial=PhoneApps.snapshot(app,charId), value=value == nil and {success=true} or value})
        if changed then
            for _, other in ipairs(getElementsByType('player')) do
                local id = tonumber(getElementData(other,'char:id') or getElementData(other,'character:id'))
                if id and other ~= player then
                    triggerClientEvent(other,'cylex_phone:socialUpdate',resourceRoot,PhoneApps.snapshot(app,id))
                end
            end
        end
    end
    local function stillCurrent()
        return isElement(player) and tonumber(getElementData(player,'char:id') or getElementData(player,'character:id')) == tonumber(charId)
    end
    if action == 'createAccount' or action == 'loginAccount' then
        local requested = tostring(data.tag or ''):lower()
        local password = tostring(data.password or '')
        if #requested < 3 or #requested > 18 or not requested:match('^[a-z0-9_-]+$') or #password < 3 or #password > 72 then
            reply(fail('Use a 3-18 character username and a 3-72 character password.')) return
        end
        if action == 'createAccount' then
            local key = app .. ':' .. requested
            if state.accounts[requested] or registering[key] then reply(fail('Username already exists.')) return end
            registering[key] = true
            local started = passwordHash(password, 'bcrypt', {cost=10}, function(encoded)
                registering[key] = nil
                if not stillCurrent() then return end
                if not encoded then reply(fail('Unable to secure account password.')) return end
                state.accounts[requested] = {nickname=tostring(data.nickname or requested):sub(1,48), password=encoded,
                    owner=owner, created=getRealTime().timestamp, followers={},following={}}
                state.sessions[owner] = requested
                finish({success=true, logged=true},true)
            end)
            if not started then registering[key]=nil reply(fail('Account creation unavailable.')) end
        else
            local target = state.accounts[requested]
            if not target then reply(fail('Incorrect username or password.')) return end
            if password == 'session' and state.sessions[owner] == requested then finish({success=true,logged=true}) return end
            passwordVerify(password,target.password,{},function(valid)
                if not stillCurrent() then return end
                if not valid then reply(fail('Incorrect username or password.')) return end
                state.sessions[owner] = requested
                finish({success=true,logged=true},true)
            end)
        end
        return
    end
    if not account then reply(fail('Sign in to use this application.')) return end
    if action == 'logout' then state.sessions[owner]=nil finish(nil,true) return end
    if action=='purchaseVerifiedAccount' or (app=='swiper' and (action=='purchaseVerified' or action=='purchaseGold')) then
        local gold=action=='purchaseGold'
        local field=gold and 'premiumUntil' or 'verifiedUntil'
        local price=tonumber(gold and Config.SwiperGoldPrice or Config.PhoneVerifiedPrice)
        if not price or price<=0 or price~=math.floor(price) then reply(fail('Invalid subscription price.')) return end
        if (tonumber(account[field]) or 0)>getRealTime().timestamp then reply(fail('Subscription is already active.')) return end
        local resource=getResourceFromName('gzl_characters')
        if not resource or getResourceState(resource)~='running' then reply(fail('Bank service is offline.')) return end
        local balance=exports.gzl_characters:getPlayerBank(player)
        if balance<price then reply(fail('Insufficient bank balance.')) return end
        if not exports.gzl_characters:setPlayerBank(player,balance-price) then reply(fail('Payment failed.')) return end
        local old=account[field]
        account[field]=getRealTime().timestamp+math.max(1,tonumber(Config.PhoneSubscriptionDays) or 30)*86400
        if not save(app,state) then account[field]=old;exports.gzl_characters:setPlayerBank(player,balance);reply(fail('Subscription save failed. Payment refunded.')) return end
        finish({success=true,balance=balance-price},true) return
    end
    if action == 'changePassword' then
        local password=tostring(data.newPassword or data.password or '')
        if #password<3 or #password>72 then reply(fail('Password must contain 3-72 characters.')) return end
        if data.newPasswordRepeat and data.newPasswordRepeat~=password then reply(fail('Passwords do not match.')) return end
        passwordVerify(tostring(data.oldPassword or ''),account.password,{},function(valid)
            if not stillCurrent() or state.sessions[owner] ~= tag then return end
            if not valid then reply(fail('Current password is incorrect.')) return end
            passwordHash(password,'bcrypt',{cost=10},function(encoded)
                if not stillCurrent() or state.sessions[owner] ~= tag then return end
                if not encoded then reply(fail('Password change failed.')) return end
                account.password=encoded
                for id, session in pairs(state.sessions) do if session==tag and id~=owner then state.sessions[id]=nil end end
                finish(nil,true)
            end)
        end)
        return
    end
    local profileKeys={changePhoto='picture',changeBackgroundPhoto='background',changeBio='bio',changeNickname='nickname'}
    if profileKeys[action] then
        account[profileKeys[action]]=tostring(data.url or data.bio or data.nickname or data.value or data.input or ''):sub(1,2048)
        finish(nil,true) return
    end
    if action=='followButton' then
        local target=state.accounts[tostring(data.tag)]
        if not target or data.tag==tag then reply(fail('Invalid account.')) return end
        account.following=account.following or {}; target.followers=target.followers or {}
        local following=toggle(account.following,data.tag)
        local found=false
        for i,v in ipairs(target.followers) do if v==tag then found=true if not following then table.remove(target.followers,i) end break end end
        if following and not found then table.insert(target.followers,tag) end
        if following then notifyAccount(state,data.tag,tag,'follow') end
        finish(nil,true) return
    end
    if action=='getFollowData' then
        local target=state.accounts[tostring(data.tag)] or account
        finish({following=target.following or {},followers=target.followers or {}}) return
    end
    if action=='getNotifications' then finish(account.notifications or {}) return end
    if action=='reportPost' or action=='reportUser' then
        local target=tostring(data.targetTag or '')
        local postId=tonumber(data.postId or data.id)
        if action=='reportPost' then
            local post=find(state.posts,postId)
            if not post then reply(fail('Post not found.')) return end
            target=post.tag
        elseif not state.accounts[target] then reply(fail('Profile not found.')) return end
        if target==tag then reply(fail('You cannot report yourself.')) return end
        for _,report in ipairs(state.reports) do
            if report.reporter==tag and report.target==target and report.postId==postId and not report.resolved then finish({success=true,reportId=report.id}) return end
        end
        local report={id=nextId(state),reporter=tag,target=target,postId=postId,
            reason=tostring(data.reason or 'Reported by user'):sub(1,1000),time=getRealTime().timestamp,resolved=false}
        table.insert(state.reports,report)
        finish({success=true,reportId=report.id},true) return
    end
    if action=='clearNotifications' then account.notifications={} finish({},true) return end
    if action=='getAllHashtags' or action=='getHashtagCounts' then
        local counts, result = {}, {}
        for _, post in ipairs(state.posts) do
            for hashtag in pairs(postHashtags(post)) do counts[hashtag]=(counts[hashtag] or 0)+1 end
        end
        for hashtag, count in pairs(counts) do table.insert(result,{tag=hashtag,count=count}) end
        table.sort(result,function(a,b) if a.count==b.count then return a.tag<b.tag end return a.count>b.count end)
        if action=='getAllHashtags' then
            local names={};for _,item in ipairs(result) do table.insert(names,item.tag) end
            finish(names)
        else finish(result) end
        return
    end
    if action=='search:getTweetByHashtag' then
        local target=string.lower(tostring(data.searchTag or ''):gsub('^#',''))
        local posts={}
        local limit=math.max(1,math.min(tonumber(data.limit) or 30,100))
        local before=tonumber(data.cursor or data.lastId)
        for _,post in ipairs(state.posts) do
            if postHashtags(post)[target] and (not before or post.id<before) then table.insert(posts,post) end
        end
        local more=#posts>limit
        while #posts>limit do table.remove(posts) end
        finish({success=true,tweets=posts,posts=posts,hasMore=more}) return
    end
    if app=='instagram' and action=='fetchStories' then finish(PhoneApps.snapshot(app,charId).stories) return end
    if app=='instagram' and action=='newStory' then
        local url=tostring(data.image or '')
        if url=='' or #url>2048 then reply(fail('Select an uploaded image for your story.')) return end
        table.insert(state.stories,{id=nextId(state),tag=tag,image=url,url=url,time=getRealTime().timestamp,watchers={},watched={}})
        finish(nil,true) return
    end
    if app=='instagram' and (action=='deleteStory' or action=='setStoryWatched') then
        local story,index=find(state.stories,data.id)
        if not story then reply(fail('Story not found.')) return end
        if action=='deleteStory' then
            if story.tag~=tag then reply(fail('You can only delete your own stories.')) return end
            table.remove(state.stories,index)
        else
            story.watchers=story.watchers or {}
            story.watchers[tag]=getRealTime().timestamp
        end
        finish(nil,true) return
    end
    if app=='swiper' then
        if action=='unmatch' then
            local target=tostring(data.targetTag or '')
            if not state.accounts[target] or target==tag then reply(fail('Profile not found.')) return end
            account.likedUserTags=account.likedUserTags or {};account.likedUserTags[target]=nil
            local other=state.accounts[target];other.likedUserTags=other.likedUserTags or {};other.likedUserTags[tag]=nil
            account.rejectedUserTags=account.rejectedUserTags or {};account.rejectedUserTags[target]=getRealTime().timestamp
            for i=#state.messages,1,-1 do local m=state.messages[i]
                if (m.sender==tag and m.receiver==target) or (m.sender==target and m.receiver==tag) then table.remove(state.messages,i) end
            end
            finish(nil,true) return
        end
        if action=='getSelfProfile' then finish(publicAccounts(state,tag)[tag]) return end
        if action=='updateProfile' then
            local allowed={photos=true,age=true,gender=true,bio=true,nickname=true,selected_preference=true,age_range=true,interests=true}
            if not allowed[data.field] then reply(fail('Invalid profile field.')) return end
            if data.field=='age' then
                local age=tonumber(data.value)
                if not age or age<18 or age>100 then reply(fail('Age must be between 18 and 100.')) return end
                account.age=math.floor(age)
            elseif data.field=='photos' or data.field=='interests' or data.field=='age_range' then
                if type(data.value)~='table' then reply(fail('Invalid profile value.')) return end
                account[data.field]=data.value
            else account[data.field]=tostring(data.value or ''):sub(1,1024) end
            finish(nil,true) return
        end
        if action=='getDiscoverUsers' then
            local users={}
            for other,profile in pairs(publicAccounts(state)) do
                local age=tonumber(profile.age) or 18
                local range=type(data.ageRange)=='table' and data.ageRange or {}
                if other~=tag and not (account.likedUserTags or {})[other] and not (account.rejectedUserTags or {})[other]
                    and age>=(tonumber(range.min) or 18) and age<=(tonumber(range.max) or 100)
                    and (not data.preference or data.preference=='everyone' or profile.gender==data.preference) then table.insert(users,profile) end
            end
            finish(users) return
        end
        if action=='likeUser' or action=='superLikeUser' or action=='rejectUser' then
            local target=tostring(data.targetTag or '')
            if not state.accounts[target] or target==tag then reply(fail('Profile not found.')) return end
            local day=math.floor(getRealTime().timestamp/86400)
            if account.swipeDay~=day then account.swipeDay=day;account.dailySwipes=0;account.dailySuperLikes=0 end
            local premium=(tonumber(account.premiumUntil) or 0)>getRealTime().timestamp
            local previous=(account.likedUserTags or {})[target] or (account.rejectedUserTags or {})[target]
            if previous then finish() return end
            if not premium and (account.dailySwipes or 0)>=10 then reply(fail('Daily swipe limit reached.')) return end
            if action=='superLikeUser' and (account.dailySuperLikes or 0)>=(premium and 5 or 1) then reply(fail('Daily super-like limit reached.')) return end
            account.dailySwipes=(account.dailySwipes or 0)+1
            if action=='superLikeUser' then account.dailySuperLikes=(account.dailySuperLikes or 0)+1 end
            local key=action=='rejectUser' and 'rejectedUserTags' or 'likedUserTags'
            account[key]=account[key] or {};account[key][target]=getRealTime().timestamp
            if action~='rejectUser' and (state.accounts[target].likedUserTags or {})[tag] then
                notifyAccount(state,target,tag,'match')
                notifyAccount(state,tag,target,'match')
            end
            finish(nil,true) return
        end
    end
    if action:find('^messages:') then
        local requested=tostring(data.toTag or data.selectedMessageId or data.messageId or data.matchId or '')
        if not state.accounts[requested] then
            for other in pairs(state.accounts) do
                local pair={tag,other};table.sort(pair)
                if requested==table.concat(pair,'_') then requested=other break end
            end
        end
        if requested=='' and type(data.list)=='table' and type(data.list[1])=='table' then requested=tostring(data.list[1].tag or '') end
        data.selectedMessageId=requested
        data.messageId=requested
        if app=='swiper' and action~='messages:getConversations' and action~='messages:setMessageId' then
            local other=state.accounts[requested]
            if not other or not (account.likedUserTags or {})[requested] or not (other.likedUserTags or {})[tag] then
                reply(fail('Match with this person before messaging.')) return
            end
        end
    end
    if action=='onAppClose' or action=='messages:setMessageId' then finish() return end
    if action=='messages:getConversations' then finish(chats(state,tag)) return end
    if action=='messages:getSpecificMessage' then
        local id=tostring(data.messageId or data.selectedMessageId or '')
        local chat=chats(state,tag)[id]
        finish({found=chat~=nil,messageId=id,messageData=chat}) return
    end
    if action=='messages:fetchChatMessages' then
        local id=tostring(data.selectedMessageId or data.messageId or '')
        for _, message in ipairs(state.messages) do if message.sender==id and message.receiver==tag then message.isRead=true end end
        finish({success=true,hasMore=false,messages=(chats(state,tag)[id] or {}).messages or {}},true) return
    end
    if action=='messages:sendMessage' then
        local target=tostring(data.selectedMessageId or data.messageId or '')
        if not state.accounts[target] or target==tag then reply(fail('Account not found.')) return end
        local text=tostring(data.message or ''):sub(1,4000)
        if text=='' and not data.image and not data.video and not data.audio and data.type~='location' and not data.location then reply(fail('Message is empty.')) return end
        local message={id=nextId(state),sender=tag,receiver=target,message=text,text=text,time=getRealTime().timestamp,
            image=data.image,video=data.video,audio=data.audio,isRead=false}
        if data.type=='location' or data.location then local x,y,z=getElementPosition(player) message.coords={x=x,y=y,z=z};message.location=message.coords end
        table.insert(state.messages,message)
        finish({success=true,message=message},true) return
    end
    if action=='messages:removeSingleMessage' or action=='messages:clearChatMessages' or action=='messages:removeAllMessage' then
        local target=tostring(data.selectedMessageId or data.messageId or '')
        for i=#state.messages,1,-1 do
            local m=state.messages[i]
            local own=m.sender==tag and m.receiver==target
            local exact=type(data.msgData)=='table' and (tostring(m.id)==tostring(data.msgData.id) or m.time==data.msgData.time)
            if own and (action~='messages:removeSingleMessage' or exact) then table.remove(state.messages,i) end
        end
        finish(nil,true) return
    end
    if action=='sendPost' then
        if tonumber(data.price or 0) ~= 0 then reply(fail('Paid posts are not configured on this server.')) return end
        local text=tostring(data.text or data.content or data.description or ''):sub(1,4000)
        local images=type(data.images)=='table' and data.images or (data.image and {data.image} or {})
        if text=='' and #images==0 and not data.video then reply(fail('Post is empty.')) return end
        local post={id=nextId(state),tag=tag,author=tag,text=text,content=text,images=images,image=images[1],video=data.video,
            time=getRealTime().timestamp,price=0,likes={},comments={},purchased={},retweets={}}
        table.insert(state.posts,1,post)
        finish({success=true,post=post,tweet=post},true) return
    end
    if action=='getPostById' or action=='getTweetById' then
        finish(find(state.posts,data.postId or data.tweetId or data.id) or false) return
    end
    if action=='deletePost' or action=='likePost' or action=='sendPostComment' or action=='sendComment' or action=='deletePostComment' or action=='likePostComment' or action=='likeComment' then
        local post,index=find(state.posts,data.id or data.postId or data.tweetId)
        if not post then reply(fail('Post not found.')) return end
        if action=='deletePost' then
            if post.tag~=tag then reply(fail('You can only delete your own posts.')) return end
            table.remove(state.posts,index)
        elseif action=='likePost' then
            if toggle(post.likes,tag) then notifyAccount(state,post.tag,tag,'like',post.id) end
        elseif action=='sendPostComment' or action=='sendComment' then
            local text=tostring(data.text or data.comment or ''):sub(1,2000)
            if text=='' then reply(fail('Comment is empty.')) return end
            table.insert(post.comments,{id=nextId(state),tag=tag,text=text,time=getRealTime().timestamp,likes={}})
            notifyAccount(state,post.tag,tag,'comment',post.id)
        else
            local comment,ci=find(post.comments,data.commentId)
            if not comment then reply(fail('Comment not found.')) return end
            if action=='deletePostComment' then
                if comment.tag~=tag and post.tag~=tag then reply(fail('You cannot delete this comment.')) return end
                table.remove(post.comments,ci)
            elseif toggle(comment.likes,tag) then notifyAccount(state,comment.tag,tag,'comment_like',post.id) end
        end
        finish(nil,true) return
    end
    if action=='fetchTimeline' or action=='fetchExplorePosts' or action=='fetchMore' or action=='getPosts' or action=='profile:getPosts' or action=='profile:getTweets' or action=='fetchFollowingFeed' or action=='getDiscoverPosts' then
        local posts={}
        local limit=math.max(1,math.min(tonumber(data.limit) or 30,100))
        local before=tonumber(data.lastId or data.lastPostId or data.beforeId or data.cursor)
        for _,post in ipairs(state.posts) do
            local following=data.filter~='following' and action~='fetchFollowingFeed'
            if not following then for _,followed in ipairs(account.following or {}) do if followed==post.tag then following=true break end end end
            if following and (not action:find('profile:') or post.tag==data.tag) and (not before or post.id<before) then table.insert(posts,post) end
        end
        local hasMore=#posts>limit
        while #posts>limit do table.remove(posts) end
        finish({success=true,posts=posts,tweets=posts,hasMore=hasMore,nextCursor=posts[#posts] and posts[#posts].id,append=action=='fetchMore'}) return
    end
    reply(fail('This feature needs a server integration: '..endpoint))
end

-- ACL-controlled moderation commands; console is also supported.
if addCommandHandler then
    addCommandHandler('phonereports',function(player,_,app,id)
        if not supported[app or ''] then
            local usage='Usage: phonereports <app> [report-id-to-resolve]'
            if isElement(player) then outputChatBox(usage,player) else outputServerLog(usage) end
            return
        end
        local state=getState(app)
        if not state then return end
        local function write(text)
            if isElement(player) then outputChatBox(text,player,255,255,255,false) else outputServerLog(text) end
        end
        if id then
            local report=find(state.reports,id)
            if not report then write('Report not found.') return end
            report.resolved=true;save(app,state);write('Report resolved: '..report.id);return
        end
        local count=0
        for _,report in ipairs(state.reports) do
            if not report.resolved then
                write('#'..report.id..' '..report.reporter..' -> '..report.target..' post='..tostring(report.postId or '-')..': '..report.reason)
                count=count+1;if count>=30 then break end
            end
        end
        write(tostring(count)..' open reports shown.')
    end,true,false)
end
