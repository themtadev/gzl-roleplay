const fs = require('fs'), path = require('path'), http = require('http'), assert = require('assert/strict');
const { chromium } = require(path.join(process.env.CODEX_NODE_MODULES, 'playwright'));
const active=path.resolve('web/build'), baseline=path.resolve('performance-backup/web/build');
const server=http.createServer((req,res)=>{
  const url=decodeURIComponent(req.url.split('?')[0]), old=url.startsWith('/baseline/');
  const relative=url.replace(/^\/(baseline|active)\//,'');
  let file=path.resolve(old?baseline:active,relative);
  if(!file.startsWith((old?baseline:active)+path.sep)){res.writeHead(403).end();return;}
  if(old&&!fs.existsSync(file))file=path.resolve(active,relative);
  fs.readFile(file,(err,data)=>{if(err){res.writeHead(404).end();return;}
    res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.png':'image/png','.ttf':'font/ttf'})[path.extname(file)]||'application/octet-stream');res.end(data);});
});
(async()=>{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const browser=await chromium.launch({headless:true,channel:'chrome'});
  try{
    fs.mkdirSync('tests/screenshots',{recursive:true});
    for(const width of [1920,1366,2560]){
      const results=[];
      for(const version of ['baseline','active']){
        const page=await browser.newPage({viewport:{width,height:width===1366?768:width===2560?1440:1080}});
        await page.addInitScript(()=>{window.callbacks=[];window.mta={triggerEvent:(...a)=>window.callbacks.push(a)};});
        await page.goto(`http://127.0.0.1:${server.address().port}/${version}/index.html`);
        await page.waitForFunction(()=>window.callbacks.some(c=>c[1]==='uiLoaded'));
        await page.evaluate(()=>{
          const items=[{slot:1,name:'water',count:2,weight:350,metadata:{label:'Su'}},{slot:3,name:'water',count:9,weight:330,metadata:{label:'Soğuk Çay'}}];
          window.sendNuiMessage({action:'init',data:{items:{water:{name:'water',label:'Water',stack:true,count:11}},locale:{},imagepath:'images'}});
          window.sendNuiMessage({action:'setupInventory',data:{leftInventory:{id:'player',type:'player',label:'Thommy_Souverain',slots:40,maxWeight:30000,items},rightInventory:{id:'drop',type:'drop',label:'Dünya',slots:40,maxWeight:100000,items:[]}}});
          window.sendNuiMessage({action:'setInventoryVisible',data:true});
        });
        await page.locator('.inventory-slot').first().waitFor();
        await page.waitForTimeout(450);
        results.push(await page.evaluate(()=>{
          const style=e=>{const c=getComputedStyle(e),r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,background:c.backgroundColor,color:c.color,font:c.fontSize,display:c.display};};
          return {grids:[...document.querySelectorAll('.inventory-grid-container')].map(style),input:style(document.querySelector('input')),buttons:[...document.querySelectorAll('.inventory-control__button')].map(style),slots:[...document.querySelectorAll('.inventory-slot')].slice(0,4).map(style),labels:[...document.querySelectorAll('.inventory-slot-label-box')].map(style),backdrop:style(document.querySelector('.bg-dark.bg-opacity-80.absolute'))};
        }));
        await page.screenshot({path:`tests/screenshots/${version}-${width}.png`});
        await page.close();
      }
      fs.writeFileSync(`tests/screenshots/geometry-${width}.json`,JSON.stringify(results,null,2));
      assert.deepEqual(results[1],results[0],`${width}px: shipped layout and appearance must match`);
      assert(fs.readFileSync(`tests/screenshots/baseline-${width}.png`).equals(fs.readFileSync(`tests/screenshots/active-${width}.png`)), `${width}px: screenshots must match pixel-for-pixel`);
      console.log(`PASS: original and repaired layout/styles match at ${width}px`);
    }
  }finally{await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
