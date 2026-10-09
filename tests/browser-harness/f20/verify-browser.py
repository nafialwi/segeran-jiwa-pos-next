import base64,json,pathlib,time,urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=ROOT/'docs/visual-evidence/c11f20';OUT.mkdir(parents=True,exist_ok=True)
BASE='http://127.0.0.1:9523'
def wd(method,path,data=None):
 req=urllib.request.Request(BASE+path,data=None if data is None else json.dumps(data).encode(),method=method,headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=30) as resp:v=json.loads(resp.read())['value']
 if isinstance(v,dict) and 'error' in v and 'message' in v:raise RuntimeError(v)
 return v
cap={'capabilities':{'alwaysMatch':{'browserName':'chrome','goog:chromeOptions':{'binary':'/data/data/com.termux/files/usr/bin/chromium-browser','args':['--headless=new','--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--user-data-dir=/data/data/com.termux/files/home/.chrome-f20-visual']}}}}
sid=wd('POST','/session',cap)['sessionId']
def js(script):return wd('POST',f'/session/{sid}/execute/sync',{'script':script,'args':[]})
def screenshot(name):(OUT/name).write_bytes(base64.b64decode(wd('GET',f'/session/{sid}/screenshot')))
def click(selector,fragment):
 return js('const el=Array.from(document.querySelectorAll('+json.dumps(selector)+')).find(e=>e.textContent.includes('+json.dumps(fragment)+'));if(!el)return false;el.click();return true;')
try:
 for width,height in [(320,740),(360,800),(390,844),(412,915),(768,1024),(1280,800)]:
  wd('POST',f'/session/{sid}/goog/cdp/execute',{'cmd':'Emulation.setDeviceMetricsOverride','params':{'width':width,'height':height,'deviceScaleFactor':1,'mobile':width<=412}})
  wd('POST',f'/session/{sid}/url',{'url':'http://127.0.0.1:4864/tests/browser-harness/f20/index.html'})
  time.sleep(1.35)
  initial=js("return {title:document.querySelector('.sales-v2-header h1')?.textContent,items:document.querySelectorAll('.sales-v2-product-card').length,disabled:document.querySelectorAll('.sales-v2-product-card:disabled').length,doc:document.documentElement.scrollWidth,viewport:innerWidth,header:!!document.querySelector('.app-bottom-nav'),fixture:!!document.querySelector('.fixture-notice'),error:document.querySelector('.error-banner')?.textContent||'',shift:document.querySelector('.sales-v2-header-meta')?.textContent||''};")
  print('CATALOG',width,json.dumps(initial,ensure_ascii=False),flush=True)
  assert initial['title']=='Jual' and initial['items']==5 and initial['disabled']==1 and initial['doc']<=width and initial['header'] and initial['fixture'] and not initial['error'] and 'aktif' in initial['shift'],initial
  if width in (320,390,768,1280):screenshot(f'jual-katalog-{width}.png')
  assert click('.sales-v2-product-card','BAKARAN 1K')
  time.sleep(.16)
  assert click('.sales-v2-product-card','CIRENG ISI')
  time.sleep(.16)
  assert click('.sales-v2-cart-bar','Lihat & Bayar')
  time.sleep(.2)
  cart=js("return {dialog:!!document.querySelector('[role=dialog][aria-label=\"Keranjang dan pembayaran\"]'),lines:document.querySelectorAll('.sales-v2-cart-line').length,total:document.querySelector('.sales-v2-cart-total strong')?.textContent,methods:Array.from(document.querySelectorAll('.sales-v2-payment-methods button')).map(x=>x.textContent.trim()),doc:document.documentElement.scrollWidth,foot:!!document.querySelector('.sales-v2-pay-button')};")
  print('CART',width,json.dumps(cart,ensure_ascii=False),flush=True)
  assert cart['dialog'] and cart['lines']==2 and cart['doc']<=width and cart['foot'] and cart['total'] and 'Tunai' in cart['methods'],cart
  if width in (320,390,768,1280):screenshot(f'jual-keranjang-{width}.png')
  pay=js("return {enabled:!document.querySelector('.sales-v2-pay-button').disabled,label:document.querySelector('.sales-v2-pay-button').textContent.trim()};")
  print('CHECKOUT_GUARD',width,json.dumps(pay,ensure_ascii=False),flush=True)
  assert pay['label'] and pay['label'].startswith('Bayar') and not pay['enabled'],pay
  assert click('.sales-v2-quick-cash button','Uang Pas')
  time.sleep(.13)
  ready=js("return {enabled:!document.querySelector('.sales-v2-pay-button').disabled,received:document.querySelector('.sales-v2-payment-panel input')?.value||'',width:document.documentElement.scrollWidth};")
  print('CASH_UI_READY',width,json.dumps(ready,ensure_ascii=False),flush=True)
  assert ready['enabled'] and ready['width']<=width,ready
  # Never click the payment button: UI fixture deliberately blocks checkout on the API boundary.
  assert click('.sales-v2-sheet-header button','Tutup')
  assert click('.sales-v2-product-card','JUS BUAH')
  time.sleep(.12)
  variant=js("return {dialog:!!document.querySelector('[role=dialog][aria-label=\"Pilih Varian\"]'),options:document.querySelectorAll('.sales-v2-variant-options button').length};")
  print('VARIANT',width,json.dumps(variant,ensure_ascii=False),flush=True)
  assert variant['dialog'] and variant['options']==2,variant
  if width in (320,390,768,1280):screenshot(f'jual-varian-{width}.png')
 print('BROWSER_F20_PASS',flush=True)
finally:
 wd('DELETE',f'/session/{sid}')
 print('BROWSER_CLOSED',flush=True)
