import base64, json, pathlib, time, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/visual-evidence/c11f18'
OUT.mkdir(parents=True, exist_ok=True)
BASE = 'http://127.0.0.1:9521'


def wd(method, path, data=None):
    request = urllib.request.Request(
        BASE + path,
        data=None if data is None else json.dumps(data).encode(),
        method=method,
        headers={'Content-Type': 'application/json'},
    )
    with urllib.request.urlopen(request, timeout=28) as response:
        value = json.loads(response.read())['value']
    if isinstance(value, dict) and 'error' in value and 'message' in value:
        raise RuntimeError(value)
    return value


options = {'capabilities': {'alwaysMatch': {
    'browserName': 'chrome',
    'goog:chromeOptions': {'binary': '/data/data/com.termux/files/usr/bin/chromium-browser',
                           'args': ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
                                    '--disable-gpu', '--user-data-dir=/data/data/com.termux/files/home/.chrome-f18-audit']},
}}}
sid = wd('POST', '/session', options)['sessionId']


def js(source):
    return wd('POST', f'/session/{sid}/execute/sync', {'script': source, 'args': []})


def screenshot(name):
    (OUT / name).write_bytes(base64.b64decode(wd('GET', f'/session/{sid}/screenshot')))


def click_text(selector, text):
    return js("const el=Array.from(document.querySelectorAll(" + json.dumps(selector) + ")).find(e=>e.textContent.includes(" + json.dumps(text) + "));if(el){el.click();return true}return false;")


try:
    for width, height in ((320,740), (390,844), (412,915), (768,1024), (1280,800)):
        wd('POST', f'/session/{sid}/goog/cdp/execute', {
            'cmd':'Emulation.setDeviceMetricsOverride',
            'params':{'width':width, 'height':height, 'deviceScaleFactor':1, 'mobile':width<=412},
        })
        for view in ('laporan', 'riwayat'):
            wd('POST', f'/session/{sid}/url', {
                'url':f'http://127.0.0.1:4862/tests/browser-harness/f18/index.html?view={view}',
            })
            time.sleep(1.5)
            initial = js("return {main:!!document.querySelector('main.shell'),title:document.querySelector('main.shell h1')?.textContent,nav:!!document.querySelector('.app-bottom-nav'),note:!!document.querySelector('.fixture-notice'),width:innerWidth,doc:document.documentElement.scrollWidth,error:document.querySelector('[role=alert]')?.textContent?.slice(0,120)||''};")
            print('INITIAL',width,view,json.dumps(initial,ensure_ascii=False),flush=True)
            assert initial['main'] and initial['nav'] and initial['note'] and initial['doc']<=width and not initial['error'],initial
            if view == 'laporan':
                assert click_text('button', 'Tampilkan Laporan'), 'report load missing'
                time.sleep(0.4)
                report = js("return {summary:document.querySelectorAll('.report-summary-card').length,sections:document.querySelectorAll('.report-section-switcher button').length,rows:document.querySelectorAll('.report-compact-row').length,errors:document.querySelector('[role=alert]')?.textContent||'',width:document.documentElement.scrollWidth};")
                print('REPORT',width,json.dumps(report,ensure_ascii=False),flush=True)
                assert report['summary']==3 and report['sections']>=2 and not report['errors'] and report['width']<=width,report
                if width in (320,390,768,1280): screenshot(f'laporan-owner-{width}.png')
                assert click_text('.report-section-switcher button','Semua bagian')
                time.sleep(0.15)
                assert js("return document.querySelectorAll('.report-compact-row').length") > 20, 'second report section not displayed'
                assert click_text('button','Filter & Urutkan') or click_text('button','Filter aktif'), 'Filter control missing'
                time.sleep(0.1)
                assert js("return document.querySelector('.report-advanced-controls')!==null"), 'report filters absent'
                tracks = js("const a=document.querySelector('.report-section-switcher');return {overflow:a.scrollWidth>a.clientWidth,track:getComputedStyle(a).scrollbarWidth}")
                if width<=390: assert tracks['track']=='none',tracks
            else:
                history = js("return {records:document.querySelectorAll('.history-transaction-card').length,count:document.querySelector('.history-results-panel .muted')?.textContent,previous:document.querySelector('.history-pagination')?.textContent,width:document.documentElement.scrollWidth,errors:document.querySelector('[role=alert]')?.textContent||''};")
                print('HISTORY',width,json.dumps(history,ensure_ascii=False),flush=True)
                assert not history['errors'] and history['width']<=width and history['previous'],history
                if width in (320,390,768,1280): screenshot(f'riwayat-owner-{width}.png')
                assert click_text('.history-pagination button','Berikutnya')
                time.sleep(0.2)
                page2 = js("return document.querySelector('.history-pagination')?.textContent||''")
                print('HISTORY_PAGE2',width,page2.strip(),flush=True)
                assert '11' in page2,page2
                assert click_text('button','Filter Lanjutan')
                assert js("return document.querySelector('.history-advanced-grid')!==null")
                tracking = js("const a=document.querySelector('.history-period-presets');return {track:getComputedStyle(a).scrollbarWidth,wide:a.scrollWidth>a.clientWidth}")
                if width<=390: assert tracking['track']=='none',tracking
                js("const e=document.querySelector('input[placeholder=\"SJ-...\"]');const setter=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;setter.call(e,'CONTOH-0001');e.dispatchEvent(new Event('input',{bubbles:true}));")
                assert click_text('button','Cari Riwayat')
                time.sleep(0.25)
                one = js("return document.querySelector('.history-results-panel')?.textContent||''")
                assert '1 transaksi ditemukan' in one,one[:160]
    print('BROWSER_F18_PASS',flush=True)
finally:
    wd('DELETE', f'/session/{sid}')
    print('BROWSER_CLOSED',flush=True)
