import json, urllib.request, time, base64, pathlib
BASE='http://127.0.0.1:9520'
OUT=pathlib.Path('docs/visual-evidence/c11f17');OUT.mkdir(parents=True,exist_ok=True)
def wd(method,path,data=None):
 req=urllib.request.Request(BASE+path,data=None if data is None else json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=30) as resp: val=json.loads(resp.read().decode())['value']
 if isinstance(val,dict) and 'error' in val and 'message' in val: raise Exception(val)
 return val
opts={'capabilities':{'alwaysMatch':{'browserName':'chrome','goog:chromeOptions':{'binary':'/data/data/com.termux/files/usr/bin/chromium-browser','args':['--headless=new','--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--user-data-dir=/data/data/com.termux/files/home/.chrome-f17-audit']}}}}
sid=wd('POST','/session',opts)['sessionId']
def js(code):return wd('POST',f'/session/{sid}/execute/sync',{'script':code,'args':[]})
def screenshot(name):
 raw=base64.b64decode(wd('GET',f'/session/{sid}/screenshot')); (OUT/name).write_bytes(raw)
 return len(raw)
def wait():time.sleep(1.5)
try:
 for width,height in [(320,740),(390,844),(412,915),(768,1024),(1280,800)]:
  wd('POST',f'/session/{sid}/goog/cdp/execute',{'cmd':'Emulation.setDeviceMetricsOverride','params':{'width':width,'height':height,'deviceScaleFactor':1,'mobile':width<=412}})
  for view in ('menu','produksi'):
   wd('POST',f'/session/{sid}/url',{'url':f'http://127.0.0.1:4861/tests/browser-harness/f17/index.html?view={view}&role=owner'});wait()
   snap=js('''const m=document.querySelector('main.shell'); return {main:!!m,title:m?.querySelector('h1')?.textContent||'', doc:document.documentElement.scrollWidth, inner:innerWidth, nav:!!document.querySelector('.app-bottom-nav'), notice:!!document.querySelector('.fixture-notice'), error:document.querySelector('[role="alert"]')?.textContent?.slice(0,180)||'', forms:document.querySelectorAll('form').length, buttons:document.querySelectorAll('button').length};''')
   print(json.dumps({'width':width,'view':view,**snap},ensure_ascii=False),flush=True)
   assert snap['main'] and snap['nav'] and snap['notice'] and snap['doc']<=snap['inner'],snap
   if width in (320,390,768,1280): screenshot(f'{view}-owner-{width}.png')
   if view=='menu':
    js("Array.from(document.querySelectorAll('.menu-category-tabs button')).find(b=>b.textContent.includes('Bisnis')).click();")
    time.sleep(0.15)
    business=js("return Array.from(document.querySelectorAll('.menu-card strong')).map(el=>el.textContent)")
    assert 'Produksi' in business and 'Keuangan' in business,business
    # React fires synthetic onChange for inputType text; use native setter if needed
    js("const el=document.querySelector('input[type=search]');const set=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;set.call(el,'Produksi');el.dispatchEvent(new Event('input',{bubbles:true}));")
    time.sleep(0.4)
    searched=js("return {cards:Array.from(document.querySelectorAll('.menu-card strong')).map(e=>e.textContent),count:document.querySelector('.menu-search-count')?.textContent||''};")
    print('SEARCH',width,json.dumps(searched,ensure_ascii=False),flush=True)
    assert 'Produksi' in searched['cards'],searched
   else:
    js("Array.from(document.querySelectorAll('.production-flow-tabs button')).find(b=>b.textContent.startsWith('Batch')).click();")
    time.sleep(0.25)
    batches=js("return {cards:document.querySelectorAll('.production-batch-card').length,pagination:document.querySelector('.production-batch-pagination')?.textContent?.trim(),width:document.documentElement.scrollWidth};")
    print('BATCH',width,json.dumps(batches,ensure_ascii=False),flush=True)
    assert batches['cards']==10 and batches['width']<=width,batches
    if width in (320,390,768,1280):screenshot(f'produksi-batch-owner-{width}.png')
    js("Array.from(document.querySelectorAll('.production-batch-pagination button')).find(b=>b.textContent.includes('Berikutnya')).click()")
    time.sleep(0.16)
    second=js("return {cards:document.querySelectorAll('.production-batch-card').length, text:document.querySelector('.production-batch-pagination span')?.textContent}")
    assert second['cards']==6 and '11' in second['text'],second
    js("Array.from(document.querySelectorAll('.production-batch-filters button')).find(b=>b.textContent.includes('Selesai')).click()")
    time.sleep(0.16)
    complete=js("return {cards:document.querySelectorAll('.production-batch-card.posted').length, scroll:document.documentElement.scrollWidth}")
    assert complete['cards']==8 and complete['scroll']<=width,complete
    js("Array.from(document.querySelectorAll('.production-flow-tabs button')).find(b=>b.textContent.startsWith('Resep Aktif')).click()")
    time.sleep(0.16)
    recipes=js("return document.querySelectorAll('.production-bom-list article').length")
    assert recipes==1,recipes

  if width==390:
   wd('POST',f'/session/{sid}/url',{'url':'http://127.0.0.1:4861/tests/browser-harness/f17/index.html?view=menu&role=kasir'});wait()
   js("Array.from(document.querySelectorAll('.menu-category-tabs button')).find(b=>b.textContent.includes('Bisnis')).click()")
   time.sleep(0.16)
   x=js("return {role:document.querySelector('.role-badge')?.textContent, cards:Array.from(document.querySelectorAll('.menu-card strong')).map(e=>e.textContent),doc:document.documentElement.scrollWidth};")
   print('CASHIER',json.dumps(x,ensure_ascii=False),flush=True)
   assert x['role']=='CASHIER' and 'Keuangan' not in x['cards'] and x['doc']<=390,x
   screenshot('menu-kasir-390.png')
 print('BROWSER_F17_PASS',flush=True)
finally:
 wd('DELETE',f'/session/{sid}')
 print('BROWSER_CLOSED',flush=True)
