const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert/strict');
const routes=['index','players','teams','match','sequences','search','insights','market-values','glossary','guide','methodology','validation','evidence-contracts','model-review','model-lab','match-review','writing-lab','quick-ingest'];
let scripts=0;for(const r of routes){const s=fs.readFileSync(path.join('dashboard',r+'.html'),'utf8');assert(s.includes('site-tools.js'),r+' shared navigation');for(const m of s.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)){if(!m[2].trim()||/application\/ld\+json|application\/json/.test(m[1]))continue;new vm.Script(m[2],{filename:r+'.html'});scripts++;}}
new vm.Script(fs.readFileSync('dashboard/site-tools.js','utf8'));
const glossary=fs.readFileSync('dashboard/glossary.html','utf8');assert(!glossary.includes('const bars=12'),'No invented frequency bars');
const review=fs.readFileSync('dashboard/model-review.html','utf8');assert(!review.includes('.slice(0,30)'),'Forecast records not capped');
const market=fs.readFileSync('dashboard/market-values.html','utf8');assert(!market.includes('.slice(0,220)')&&!market.includes('teams.slice(0,16)'),'Market records not capped');
const tools=fs.readFileSync('dashboard/site-tools.js','utf8');assert(!tools.includes('role="menu"'),'Native disclosure navigation');
console.log(JSON.stringify({routes:routes.length,inline_scripts_parsed:scripts,shared_script_parsed:true,contract_checks:4}));
