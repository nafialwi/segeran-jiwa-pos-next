"""Read-only UAT workbook smoke. Creates only dummy local-browser test progress."""
import base64
import json
import pathlib
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/visual-evidence/c11f21'
OUT.mkdir(parents=True, exist_ok=True)
BASE = 'http://127.0.0.1:9525'
UAT = 'http://127.0.0.1:4865/docs/uat/UAT_C11_F21_OPERATOR_WORKBOOK_2026-10-09.html'

def wd(method, path, data=None):
    request = urllib.request.Request(BASE + path,
        data=None if data is None else json.dumps(data).encode(),
        method=method, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=30) as response:
        value = json.loads(response.read())['value']
    if isinstance(value, dict) and 'error' in value and 'message' in value:
        raise RuntimeError(value)
    return value

options = {'capabilities': {'alwaysMatch': {'browserName': 'chrome', 'goog:chromeOptions': {
    'binary': '/data/data/com.termux/files/usr/bin/chromium-browser',
    'args': ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
             '--disable-gpu', '--user-data-dir=/data/data/com.termux/files/home/.chrome-f21-uat'],
}}}}
sid = wd('POST', '/session', options)['sessionId']
def js(code):
    return wd('POST', f'/session/{sid}/execute/sync', {'script': code, 'args': []})
def shot(width):
    (OUT / f'uat-workbook-pending-{width}.png').write_bytes(
        base64.b64decode(wd('GET', f'/session/{sid}/screenshot')))

try:
    for width, height in [(320,740), (390,844), (768,1024)]:
        wd('POST', f'/session/{sid}/goog/cdp/execute', {
            'cmd': 'Emulation.setDeviceMetricsOverride', 'params': {
                'width':width,'height':height,'deviceScaleFactor':1,'mobile':width<500}})
        wd('POST', f'/session/{sid}/url', {'url':UAT})
        time.sleep(.8)
        js("localStorage.removeItem('SJPOSNEXT_F21_UAT_0fafee4');location.reload()")
        time.sleep(.5)
        item = js("return {title:document.title,total:document.getElementById('total')?.textContent,passed:document.getElementById('passed')?.textContent,remaining:document.getElementById('remaining')?.textContent,bar:document.getElementById('bar')?.getAttribute('aria-valuenow'),width:document.documentElement.scrollWidth,viewport:innerWidth,all:document.querySelectorAll('.item').length,gate:document.getElementById('gate-text')?.textContent,errors:!!document.querySelector('error')};")
        print('INITIAL', width, json.dumps(item, ensure_ascii=False), flush=True)
        assert item['total']=='44' and item['passed']=='0' and item['remaining']=='44' and item['bar']=='0' and item['all']==44 and item['width']<=width and 'CUTOVER_READY=NO' in item['gate'], item
        shot(width)
        changed = js("const s=document.querySelector('[aria-label=\"Status A01\"]');s.value='PASS';s.dispatchEvent(new Event('change',{bubbles:true}));return document.getElementById('passed').textContent")
        assert changed=='1', changed
        wd('POST', f'/session/{sid}/refresh', {})
        time.sleep(.4)
        persisted=js("return {status:document.querySelector('[aria-label=\"Status A01\"]').value,passed:document.getElementById('passed').textContent}")
        assert persisted=={'status':'PASS','passed':'1'}, persisted
        p0=js("const s=document.querySelector('[aria-label=\"Status A02\"]');s.value='FAIL';s.dispatchEvent(new Event('change',{bubbles:true}));return document.getElementById('gate-text').textContent")
        assert 'STOP' in p0 and 'P0' in p0, p0
        filt=js("const f=document.getElementById('statusFilter');f.value='FAIL';f.dispatchEvent(new Event('change',{bubbles:true}));return Array.from(document.querySelectorAll('.item')).filter(x=>!x.hidden).map(x=>x.dataset.id)")
        assert filt==['A02'], filt
        print('INTERACTION_PASS', width, persisted, filt, flush=True)
    print('BROWSER_F21_PASS', flush=True)
finally:
    wd('DELETE', f'/session/{sid}')
    print('BROWSER_CLOSED', flush=True)
