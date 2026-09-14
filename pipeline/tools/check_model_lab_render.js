#!/usr/bin/env node
/* Rendered smoke test for the local, password-gated Model Lab. */
'use strict';
const fs=require('fs'),path=require('path'),http=require('http');
const {chromium}=require('playwright');
const ROOT=path.resolve(__dirname,'../..'),DASH=path.join(ROOT,'dashboard'),OUT=path.join(ROOT,'artifacts');
const server=http.createServer((req,res)=>{
  const clean=decodeURIComponent((req.url||'/').split('?')[0]).replace(/^\/+/, '')||'model-lab.html';
  const file=path.resolve(DASH,clean);
  if(!file.startsWith(DASH)||!fs.existsSync(file)){res.writeHead(404);return res.end('not found')}
  res.writeHead(200,{'Content-Type':path.extname(file)==='.js'?'text/javascript':'text/html'});
  fs.createReadStream(file).pipe(res);
});
(async()=>{
  await new Promise(ok=>server.listen(0,'127.0.0.1',ok));
  const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'});
  try{
    for(const [name,width,height] of [['desktop',1440,1000],['mobile',390,844]]){
      const page=await browser.newPage({viewport:{width,height}}),errors=[];
      page.on('pageerror',error=>errors.push(error.message));
      await page.addInitScript(()=>localStorage.setItem('siteAccess','granted-v1'));
      await page.goto(`http://127.0.0.1:${server.address().port}/model-lab.html?tab=legitimacy`,{waitUntil:'networkidle'});
      await page.locator('#legitimacy .panel').first().waitFor({state:'visible'});
      const text=await page.locator('#legitimacy').innerText();
      if(!text.includes('Shots and territory are tied')||!text.includes('Historical table backtests'))throw new Error(`${name}: legitimacy evidence missing`);
      if(errors.length)throw new Error(`${name}: ${errors.join('; ')}`);
      await page.screenshot({path:path.join(OUT,`model-lab-legitimacy-${name}.png`),fullPage:true,animations:'disabled'});
      console.log(`PASS ${name}: ${text.length} rendered characters`);
      await page.close();
    }
  }finally{await browser.close();await new Promise(ok=>server.close(ok))}
})().catch(error=>{console.error(error.stack||error);process.exit(1)});
