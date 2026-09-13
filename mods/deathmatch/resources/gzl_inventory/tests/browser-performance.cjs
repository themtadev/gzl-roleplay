// Run with CODEX_NODE_MODULES set to a directory containing playwright.
const { chromium } = require(require('path').join(process.env.CODEX_NODE_MODULES, 'playwright'));
const fs = require('fs');
const path = require('path');
const http = require('http');
const assert = require('assert/strict');
const root = path.resolve(__dirname, '../web/build');
const server = http.createServer((req, res) => {
  const file = path.resolve(root, '.' + decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
  fs.readFile(file, (error, data) => {
    if (error) { res.writeHead(404).end(); return; }
    res.setHeader('Content-Type', ({ '.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.png':'image/png', '.ttf':'font/ttf' })[path.extname(file)] || 'application/octet-stream');
    res.end(data);
  });
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true, channel: 'chrome' });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(() => {
      window.callbacks = [];
      window.mta = { triggerEvent: (...args) => window.callbacks.push(args) };
    });
    await page.goto(`http://127.0.0.1:${server.address().port}/index.html`);
    await page.waitForFunction(() => window.callbacks.some(c => c[1] === 'uiLoaded'));
    await page.evaluate(() => {
      const items = Array.from({length: 40}, (_, i) => ({ slot: i+1, name:'water', count:10, weight:100, metadata:{label:'Water '+(i+1)} }));
      window.snapshot = {leftInventory:{id:'player',type:'player',label:'Player',slots:40,maxWeight:30000,items},rightInventory:{id:'drop',type:'drop',label:'World',slots:40,maxWeight:100000,items:[]}};
      window.sendNuiMessage({action:'init',data:{items:{water:{name:'water',label:'Water',stack:true,count:400}},locale:{},imagepath:'images'}});
      window.sendNuiMessage({action:'setupInventory',data:window.snapshot});
      window.sendNuiMessage({action:'setInventoryVisible',data:true});
    });
    const slots = page.locator('.inventory-grid-container').first().locator('.inventory-slot');
    await slots.first().waitFor();
    assert.equal(await slots.count(), 30);
    await slots.first().hover();
    await page.locator('.tooltip-wrapper').waitFor();
    const tooltipBox = await page.locator('.tooltip-wrapper').boundingBox();
    const first = await slots.first().boundingBox();
    await page.mouse.move(first.x + first.width/2 + 5, first.y + first.height/2 + 5);
    await page.waitForTimeout(250);
    const movedBox = await page.locator('.tooltip-wrapper').boundingBox();
    assert.equal(Math.round(tooltipBox.x), Math.round(movedBox.x), 'tooltip stays anchored during mouse movement');
    const second = await slots.nth(1).boundingBox();
    await page.mouse.move(first.x + 20, first.y + 20);
    await page.mouse.down();
    await page.mouse.move(second.x+20, second.y+20, {steps:12});
    await page.locator('.item-drag-preview').waitFor();
    const transform = await page.locator('.item-drag-preview').evaluate(e => e.style.transform);
    assert.match(transform, /translate3d/);
    await page.mouse.up();
    await page.waitForTimeout(250);
    const calls = await page.evaluate(() => window.callbacks);
    assert(calls.some(c => c[1] === 'swapItems'), 'slot drop sends swap');
    assert(!calls.some(c => c[1] === 'dropItem'), 'slot drop must not also drop to floor');
    await page.evaluate(() => window.sendNuiMessage({action:'closeInventory'}));
    await page.locator('.inventory-wrapper').waitFor({state:'detached'});
    assert.equal(await page.locator('.tooltip-wrapper').count(),0);
    assert.equal(await page.locator('.item-drag-preview').count(),0);
    for (const visible of [true, false, true, false]) {
      await page.evaluate(state => window.sendNuiMessage({action:'toggleHotbar', data:state}), visible);
      await page.locator('.hotbar-container').waitFor({state: visible ? 'visible' : 'detached'});
    }
    // Explicit MTA visibility must not race a second frontend timeout.
    await page.evaluate(() => window.sendNuiMessage({action:'toggleHotbar', data:true}));
    await page.locator('.hotbar-container').waitFor();
    await page.waitForTimeout(3100);
    assert(await page.locator('.hotbar-container').isVisible(), 'MTA owns the hotbar timeout');
    await page.evaluate(() => window.sendNuiMessage({action:'toggleHotbar', data:false}));
    await page.locator('.hotbar-container').waitFor({state:'detached'});
    await page.evaluate(() => window.sendNuiMessage({action:'setInventoryVisible',data:true}));
    await page.locator('.inventory-wrapper').waitFor();
    const exitsBefore = await page.evaluate(() => window.callbacks.filter(c=>c[1]==='exit').length);
    await page.keyboard.press('Escape');
    await page.locator('.inventory-wrapper').waitFor({state:'detached'});
    assert.equal(await page.evaluate(() => window.callbacks.filter(c=>c[1]==='exit').length), exitsBefore+1, 'one Escape sends one exit');
    for(let i=0;i<5;i++) {
      await page.evaluate(() => window.sendNuiMessage({action:'setInventoryVisible',data:true}));
      await page.locator('.inventory-wrapper').waitFor();
      await page.evaluate(() => window.sendNuiMessage({action:'closeInventory'}));
      await page.locator('.inventory-wrapper').waitFor({state:'detached'});
    }
    assert.equal((await page.evaluate(() => window.callbacks)).filter(c=>c[1]==='uiLoaded').length,1);
    assert.deepEqual(errors, []);
    console.log('PASS: 40-slot inventories, anchored tooltip, drag preview, single slot-drop action, close cleanup, 5 reopen cycles, no browser exceptions.');
  } finally { await browser.close(); server.close(); }
})().catch(error => { console.error(error); server.close(); process.exitCode=1; });
