// Exercise lifecycle handling without a GPU. Real Safari stability needs a device.
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = readFileSync(join(__dirname, '../web/shell.html'), 'utf8');
const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1]
  .replace('$GODOT_CONFIG', JSON.stringify({serviceWorker:'index.service.worker.js'}));
class Target {
  constructor(){this.listeners={};this.hidden=false;this.textContent='';}
  addEventListener(type, fn){(this.listeners[type] ||= []).push(fn);}
  dispatchEvent(event){for(const fn of this.listeners[event.type]||[])fn(event);}
  click(){this.dispatchEvent({type:'click'});this.onclick?.();}
  focus(){}
}
async function fixture({blockedStorage=false, registrationFails=false}={}){
  const nodes=new Map();
  for(const id of ['canvas','game','status','progress','play','notice','offline','update','help','diagnostics','diagnostic-text','close-help'])nodes.set(id,new Target());
  const canvas=nodes.get('canvas'), dimensions={width:0,height:0};let assignments=0;
  for(const key of ['width','height'])Object.defineProperty(canvas,key,{get:()=>dimensions[key],set:value=>{dimensions[key]=value;assignments++;}});
  let bounds={width:390,height:716},observer,starts=0,reloads=0,registrations=0,engineConfig;
  nodes.get('game').getBoundingClientRect=()=>bounds;
  const document=new Target();document.getElementById=id=>nodes.get(id);
  const window=new Target();window.devicePixelRatio=3;window.matchMedia=()=>({matches:true});
  const serviceWorker=new Target(),registration=new Target();registration.active={};
  serviceWorker.getRegistration=async()=>undefined;
  serviceWorker.register=async()=>{registrations++;if(registrationFails)throw Error('storage denied');return registration;};
  serviceWorker.ready=registrationFails?new Promise(()=>{}):Promise.resolve(registration);
  const saved=new Map(),timers=new Map();let nextTimer=0;
  const context={document,window,URL,Date,Math,Event,performance:{getEntriesByType:()=>[{type:'navigate'}]},
    location:{href:'https://example.test/Snakegame/',reload:()=>reloads++},navigator:{serviceWorker,userAgent:'Test browser'},
    matchMedia:window.matchMedia,localStorage:{getItem:key=>{if(blockedStorage)throw Error('denied');return saved.get(key);},setItem:(key,value)=>{if(blockedStorage)throw Error('denied');saved.set(key,value);}},
    ResizeObserver:class{constructor(fn){observer=fn;}observe(){}},
    setTimeout:fn=>{timers.set(++nextTimer,fn);return nextTimer;},clearTimeout:id=>timers.delete(id),
    console:{warn(){},error(){}},
    Engine:class{static getMissingFeatures(){return [];}constructor(options){engineConfig=options;}startGame(options){this.options=options;starts++;return Promise.resolve();}}
  };
  vm.runInNewContext(code,context);
  await new Promise(setImmediate);
  return {nodes,document,window,serviceWorker,registration,saved,canvas,
    resize:()=>observer(),bounds:value=>{bounds=value;},flush:()=>{const pending=[...timers.values()];timers.clear();pending.forEach(fn=>fn());},
    counts:()=>({assignments,starts,reloads,registrations,timers:timers.size}),engineConfig};
}
(async()=>{
  const f=await fixture();
  assert.equal(f.canvas.width,585);assert.equal(f.canvas.height,1074);
  const initial=f.counts().assignments;
  for(let i=0;i<100;i++)f.resize();
  assert.equal(f.counts().timers,1,'resize burst is coalesced');
  f.flush();assert.equal(f.counts().assignments,initial,'unchanged dimensions do not reset buffers');
  f.bounds({width:391,height:716});f.resize();f.flush();
  assert.equal(f.counts().assignments,initial+1,'only changed dimension is assigned');
  f.document.hidden=true;f.bounds({width:0,height:0});f.resize();f.flush();
  assert.equal(f.canvas.width,587,'background zero-size viewport does not discard buffers');
  assert.equal(f.engineConfig.serviceWorker,'','only shell registers the worker');
  assert.equal(f.counts().registrations,1);
  assert.match(f.nodes.get('offline').textContent,/Offline ready/);
  f.serviceWorker.dispatchEvent({type:'controllerchange'});
  assert.equal(f.counts().reloads,0,'worker activation never reloads a running game');
  let pauses=0;f.document.addEventListener('snake-pause',()=>pauses++);
  f.nodes.get('help').click();assert.equal(pauses,1);assert.equal(f.nodes.get('diagnostics').hidden,false);
  assert.match(f.nodes.get('diagnostic-text').textContent,/stability-1/);
  f.nodes.get('close-help').click();assert.equal(f.nodes.get('diagnostics').hidden,true);
  let prevented=false,stopped=false;
  f.canvas.dispatchEvent({type:'webglcontextlost',preventDefault:()=>{prevented=true;},stopImmediatePropagation:()=>{stopped=true;}});
  assert.ok(prevented&&stopped);assert.equal(pauses,2);
  assert.equal(f.nodes.get('status').hidden,false);assert.equal(f.nodes.get('play').textContent,'Reload game');
  assert.equal(f.counts().reloads,0,'context loss offers explicit recovery instead of a reload loop');
  f.nodes.get('play').click();assert.equal(f.counts().reloads,1);
  for(let i=0;i<30;i++)f.window.dispatchEvent({type:'error',message:'test '+i});
  assert.equal(JSON.parse([...f.saved.values()][0]).length,6,'diagnostics storage is bounded');
  const unavailable=await fixture({blockedStorage:true,registrationFails:true});
  assert.equal(unavailable.counts().starts,1,'storage denial does not stop the engine');
  assert.equal(unavailable.nodes.get('play').disabled,false);
  assert.match(unavailable.nodes.get('offline').textContent,/unavailable/);
  console.log('WEB SHELL CHECKS: passed (resize bursts, storage denial, recovery, diagnostics, explicit updates).');
})().catch(error=>{console.error(error);process.exitCode=1;});
