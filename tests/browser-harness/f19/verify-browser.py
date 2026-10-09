import base64,json,pathlib,time,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=ROOT/'docs/visual-evidence/c11f19';OUT.mkdir(parents=True,exist_ok=True)
BASE='http://127.0.0.1:9522'
def wd(method,path,data=None):
 request=urllib.request.Request(BASE+path,data=None if data is None else json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(request,timeout=30) as response: value=json.loads(response.read())['value']
 if isinstance(value,dict) and 'error' in value and 'message' in value: raise RuntimeError(value)
 return value
opts={'capabilities':{'alwaysMatch':{'browserName':'chrome','goog:chromeOptions':{'binary':'/data/data/com.termux/files/usr/bin/chromium-browser','args':['--headless=new','--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--user-data-dir=/data/data/com.termux/files/home/.chrome-f19-audit']}}}}
sid=wd('POST','/session',opts)['sessionId']
def js(s):return wd('POST',f'/session/{sid}/execute/sync',{'script':s,'args':[]})
def screenshot(name):(OUT/name).write_bytes(base64.b64decode(wd('GET',f'/session/{sid}/screenshot')))
def click(selector,text):
 return js('const el=Array.from(document.querySelectorAll('+json.dumps(selector)+')).find(e=>e.textContent.includes('+json.dumps(text)+'));if(!el)return false;el.click();return true;')
try:
 for width,height in ((320,740),(390,844),(412,915),(768,1024),(1280,800)):
  wd('POST',f'/session/{sid}/goog/cdp/execute',{'cmd':'Emulation.setDeviceMetricsOverride','params':{'width':width,'height':height,'deviceScaleFactor':1,'mobile':width<=412}})
  for view in ('keuangan','shift'):
   wd('POST',f'/session/{sid}/url',{'url':f'http://127.0.0.1:4863/tests/browser-harness/f19/index.html?view={view}'})
   time.sleep(1.5)
   initial=js("return {main:!!document.querySelector('main.shell'),title:document.querySelector('main.shell h1')?.textContent,nav:!!document.querySelector('.app-bottom-nav'),note:!!document.querySelector('.fixture-notice'),width:innerWidth,doc:document.documentElement.scrollWidth,error:document.querySelector('.error-banner')?.textContent||'',status:document.querySelector('.shift-active-hero h2')?.textContent||''};")
   print('INITIAL',width,view,json.dumps(initial,ensure_ascii=False),flush=True)
   assert initial['main'] and initial['nav'] and initial['note'] and initial['doc']<=width and not initial['error'],initial
   if view=='keuangan':
    accounts=js("return {balance:document.querySelectorAll('.finance-summary-grid article').length,tabs:document.querySelectorAll('.finance-flow-tabs button').length,flow:document.querySelector('.finance-flow-tabs .active')?.textContent,sections:document.querySelectorAll('[id^=finance-]').length};")
    print('FINANCE',width,json.dumps(accounts,ensure_ascii=False),flush=True)
    assert accounts['tabs']==9 and accounts['flow']=='Saldo',accounts
    if width==320:
     columns=js("return getComputedStyle(document.querySelector('.finance-summary-grid')).gridTemplateColumns.split(' ').length")
     assert columns==2,columns
    if width in (320,390,768,1280):screenshot(f'keuangan-owner-{width}.png')
    assert click('.finance-flow-tabs button','Piutang')
    time.sleep(0.15)
    selected=js("return {selected:document.querySelector('.finance-flow-tabs .active')?.textContent,receivables:!!document.querySelector('#finance-receivables'),payables:!!document.querySelector('#finance-payables'),width:document.documentElement.scrollWidth};")
    assert selected['selected']=='Piutang' and selected['receivables'] and not selected['payables'] and selected['width']<=width,selected
    assert click('.finance-flow-tabs button','Pindah Uang')
    time.sleep(0.13)
    assert js("return !!document.querySelector('#finance-transfer') && !document.querySelector('#finance-receivables')")
    if width in (320,390,768,1280):screenshot(f'keuangan-transfer-owner-{width}.png')
   else:
    kpis=js("return {count:document.querySelectorAll('.shift-kpi-grid article').length,tabs:Array.from(document.querySelectorAll('.shift-flow-tabs button')).map(x=>x.textContent),status:document.querySelector('.shift-active-hero h2')?.textContent};")
    print('SHIFT',width,json.dumps(kpis,ensure_ascii=False),flush=True)
    assert kpis['count']==4 and 'Shift Aktif'==kpis['status'] and len(kpis['tabs'])==6,kpis
    if width in (320,390,768,1280):screenshot(f'shift-owner-{width}.png')
    assert click('.shift-flow-tabs button','Kas Shift')
    time.sleep(0.12)
    assert js("return document.querySelector('.shift-flow-tabs .active')?.textContent==='Kas Shift' && !!document.querySelector('.shift-reconciliation-panel')")
    assert click('.shift-flow-tabs button','Tutup Shift')
    time.sleep(0.15)
    close=js("return {active:document.querySelector('.shift-flow-tabs .active')?.textContent,button:!!document.querySelector('.shift-closing-card button'),width:document.documentElement.scrollWidth};")
    print('CLOSING_VIEW',width,json.dumps(close,ensure_ascii=False),flush=True)
    assert close['active']=='Tutup Shift' and close['width']<=width,close
    if width in (320,390,768,1280):screenshot(f'shift-closing-owner-{width}.png')
  if width==390:
   wd('POST',f'/session/{sid}/url',{'url':'http://127.0.0.1:4863/tests/browser-harness/f19/index.html?view=shift&role=kasir'})
   time.sleep(1.1)
   kasir=js("return {tabs:Array.from(document.querySelectorAll('.shift-flow-tabs button')).map(e=>e.textContent),doc:document.documentElement.scrollWidth}")
   assert len(kasir['tabs'])==5 and 'Pengeluaran' not in kasir['tabs'] and kasir['doc']<=390,kasir
   print('SHIFT_KASIR',json.dumps(kasir,ensure_ascii=False),flush=True)
   screenshot('shift-kasir-390.png')
 print('BROWSER_F19_PASS',flush=True)
finally:
 wd('DELETE',f'/session/{sid}')
 print('BROWSER_CLOSED',flush=True)
