const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const timers = [];
const requests = [];
const storage = new Map();
const window = {
    fetch() {}, addEventListener() {}, dispatchEvent() {},
    mta: { triggerEvent(...args) { requests.push(args); } }
};
const context = {
    window, TextDecoder, Uint8Array, Blob, console,
    localStorage: {getItem:key=>storage.get(key)||null,setItem:(key,value)=>storage.set(key,value)},
    CustomEvent: function() {},
    HTMLIFrameElement: class { setAttribute() {} },
    MutationObserver: class { observe() {} },
    document: { addEventListener() {}, documentElement: { dataset: {} }, querySelectorAll: () => [] },
    setTimeout(fn) { timers.push(fn); return timers.length; }, clearTimeout() {},
};
let source = fs.readFileSync(path.join(__dirname, '../html/bridge.js'), 'utf8');
source = source.replace(/window\.__mtaPhoneSetActive\(false\)\s*\}\)\(\)/,
    'window.__test = { normalize, conversations }; window.__mtaPhoneSetActive(false)\n})()');
vm.runInNewContext(source, context);
vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../html/locales.js'),'utf8'),context);
const api = window.__test;
api.normalize('callapp:getContacts', [{id: 1, number: '555-0009', name: 'Test Person'}]);
const result = api.normalize('messages:fetchChatMessages', [
    {id: 42, from_number: '555-0009', to_number: '555-0008', message: 'fresh', time: 100}
], {selectedMessageId: '555-0009'});
assert.equal(result.messages[0].message, 'fresh');
assert.equal(api.conversations()['555-0009'].name, 'Test Person');
assert.equal(api.normalize('messages:fetchChatMessages', {success: false, error: 'blocked'}, {}).success, false);
assert.equal(api.normalize('bank:refreshBank', {bankBalance: 275, transactions: []}, {}).balance, 275);
window.$store = {state:{data:{AppAccounts:{}},self_userdata:{selectedAccounts:{}},appdata:{bank:{},twitter:{}}}};
api.normalize('bank:refreshBank', {bankBalance: 310, transactions: []}, {});
assert.equal(window.$store.state.data.bank,310);
const tweets=api.normalize('twitter:fetchTimeline',{mtaSocial:{app:'twitter',accounts:{},posts:[{id:1,text:'post'}]},value:{tweets:[{id:1,text:'post'}],hasMore:false}},{});
assert.equal(tweets.hasMore,false);
assert.equal(tweets.tweets[0].retweets.length,0);
assert.equal(window.$store.state.appdata.twitter.tweets[0].retweets.length,0);
(async () => {
    window.$store.state.Config={locales:{settings:{header:'Settings'},main:{cancel:'Cancel'}}};
    let lang=await (await window.fetch('https://cylex_phone/phone:changeLanguage',{body:JSON.stringify({data:{language:'tr'}})})).json();
    assert.equal(lang.success,true);
    assert.equal(window.$store.state.Config.locales.settings.header,'Ayarlar');
    assert.equal(storage.get('cylex_phone:language'),'tr');
    await window.fetch('https://cylex_phone/phone:changeLanguage',{body:JSON.stringify({data:{language:'en'}})});
    assert.equal(window.$store.state.Config.locales.main.cancel,'Cancel');
    assert.equal(window.$store.state.Config.language,'en');
    const pending = window.fetch('https://cylex_phone/notes:saveText', {body: '{}'});
    timers.at(-1)();
    assert.equal((await (await pending).json()).error, 'request_timeout');
    console.log('PASS: current message results, contact cache, server errors, request timeout');
})().catch(error => { console.error(error); process.exitCode = 1; });
