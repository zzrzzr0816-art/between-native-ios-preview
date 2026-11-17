from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from functools import partial
from threading import Thread
from playwright.sync_api import sync_playwright
import json,time
root=Path(r'D:\天使与恶魔\Between原生iOS\design-reference')
fixture={'id':'design-reference','language':'en','category':'relationships','text':'My best friend is moving away. Do I tell them how much it hurts?','created':int(time.time()*1000),'answers':[{'id':'a1','author':'Example angel','side':'angel','text':'Tell them you will miss them, and make a plan to stay close.','likes':2,'replies':[]},{'id':'a2','author':'Example devil','side':'devil','text':'Say it now. Pretending you are fine will not make the goodbye easier.','likes':1,'replies':[]}],'mine':False,'best':{},'updates':[]}
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*a):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=r'D:\天使与恶魔\本地联调'));Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 b=p.chromium.launch(headless=True,executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe');page=b.new_page(viewport={'width':420,'height':912},is_mobile=True,has_touch=True)
 page.add_init_script("localStorage.setItem('between-swipe-lang','en');localStorage.setItem('between-guide-v1','1')")
 def api(route):
  name=route.request.url
  data={'stories':[fixture],'next_offset':None} if '/stories?' in name else {'snapshots':[]} if '/snapshots' in name else {'feedback':[]} if '/feedback' in name else {'ok':True}
  route.fulfill(status=200,content_type='application/json',body=json.dumps(data))
 page.route('**/api/**',api)
 page.goto('http://127.0.0.1:%d/'%server.server_port,wait_until='networkidle');page.wait_for_timeout(1000)
 page.screenshot(path=str(root/'h5-home.png'))
 selectors=['.app','.top','.logo','.demo','#gesture','.story','.story h1','.story-meta','.story-count','.nav','.nav button','.nav .nav-icon','.companions','.buddy-devil','.buddy-devil .buddy-face','.buddy-angel .buddy-face','.horn-left','.horn-right','.halo','.wing-left','.eye','.smile','.buddy-face::before']
 def metrics():
  return page.evaluate('''selectors=>Object.fromEntries(selectors.map(selector=>{let pseudo=selector.endsWith('::before');let el=document.querySelector(pseudo?selector.replace('::before',''):selector);if(!el)return[selector,null];let r=el.getBoundingClientRect(),s=getComputedStyle(el,pseudo?'::before':null),props=['width','height','top','left','right','bottom','padding','margin','borderRadius','fontSize','fontWeight','lineHeight','letterSpacing','color','background','boxShadow','transform','scale','translate','position','zIndex','gap','border','opacity'];return[selector,{rect:{x:r.x,y:r.y,width:r.width,height:r.height},styles:Object.fromEntries(props.map(p=>[p,s[p]]))}]}))''',selectors)
 out={'home':metrics()}
 page.evaluate("side='devil';sheet='comments';render()");page.wait_for_timeout(550);page.screenshot(path=str(root/'h5-devil.png'));selectors+=['.side-panel','.side-panel .sheet','.sheet-head','.tabs','.tab','.comment','.compose','.compose-row textarea','.compose-row .send'];out['devil']=metrics()
 (root/'computed-style.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf8')
 b.close()
server.shutdown();server.server_close();print('Saved H5 computed styles and home/comment references')
