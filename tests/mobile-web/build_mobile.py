from pathlib import Path
import re
root=Path(__file__).resolve().parents[2]
s=(root/'index.html').read_text(encoding='utf-8')
script=s.split('<script>\n/* ═══ LUCIDE',1)[1].split('</script>',1)[0]
script='/* ═══ LUCIDE'+script
script=script.replace('capturedThumb=null; resetFullPhoto(); retakePhoto();','capturedThumb=null; resetFullPhoto(); startCamera();')
script=script.replace('downloadBlob(blob, \'expiry-tracker-\'','await downloadBlob(blob, \'expiry-tracker-\'')
script=script.replace('async function exportToExcel(){','async function exportToExcel(){\n try{')
script=script.replace("notify('📥 Exported '+items.length+' items');\n}","notify('📥 Exported '+items.length+' items');\n }catch(e){const status=document.getElementById('export-status');if(status)status.textContent=e.message;notify(e.message);}\n}")
# The iPhone bridge supports CSV/JSON, not XLSX. Generate CSV bytes, not a renamed ZIP.
script=script.replace("new Blob([buildXlsx(rows,'Expiry Items')],{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'})", "buildCsv(rows)")
script=script.replace("+'.xlsx'", "+'.csv'")
script=script.replace('localStorage','Mobile.settings')
script=script.replace("const sb=supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);","const sb=Mobile.client;")
# Native worker-compatible OCR. No worker/CDN or cloud OCR code is bundled.
a=script.index('let ocrWorkerPromise=');b=script.index('function switchTab',a)
script=script[:a]+'''function warmOCR(){return Promise.resolve({recognize:async image=>{const result=await Native.call('ocr',{image:typeof image==='string'?image:image.toDataURL('image/jpeg',.9)});if(typeof result?.text!=='string')throw Error('Invalid native OCR response');return {data:{text:result.text}};}});}
'''+script[b:]
a=script.index('/* ── Cloud OCR (Google Vision)');b=script.index('/* On-device OCR via',a)
script=script[:a]+'''function cloudOcrEnabled(){return false;}
async function cloudOCR(canvas,full){return localOCR(canvas,full);}
function renderVisionKeyStatus(){document.getElementById('vision-key-status').textContent='Apple Vision reads dates on this iPhone. Photos are never sent to cloud OCR.';}
'''+script[b:]
a=script.index('let _zxingP=');b=script.index('async function scanBarcodeLoop',a)
script=script[:a]+'''function openBarcodeScanner(){notify('Barcode product lookup is not available in the iPhone app. Enter the product name manually.');}
'''+script[b:]
a=script.index('async function lookupBarcode(');b=script.index('/* ═══ SUPABASE',a)
script=script[:a]+'''function lookupBarcode(){setBcStatus('Network barcode lookup is disabled. Enter the product name manually.');}
'''+script[b:]
script=script.replace("if('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(()=>{});",'')
script=script.replace('initAuth();          // decides: show login page or the app (+ loads this account\'s data)','Mobile.start();')
# Integration overrides execute before initialization.
pos=script.index('/* ═══ INIT ═══ */')
script=script[:pos]+(root/'mobile-web/integration.js').read_text(encoding='utf-8')+'\n'+script[pos:]
(root/'mobile-web/app.js').write_text(script,encoding='utf-8')
html=s[:s.index('<script src="https://cdn.jsdelivr.net/npm/@supabase')]
html=re.sub(r'<link[^>]+(?:fonts.googleapis|fonts.gstatic)[^>]*>','',html)
html=html.replace('<style>',"<style>\n    @font-face {font-family:'Archivo';font-style:normal;font-weight:100 900;font-display:swap;src:url('assets/Archivo.ttf') format('truetype');}")
html=html.replace('  <link rel="manifest" href="manifest.json" />','')
html=html.replace('<meta charset="UTF-8" />','''<meta charset="UTF-8" />
  <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'none'; worker-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'" />''')
html=html.replace('<body>','''<body>
<div class="login-wrap" id="mode-picker" style="display:flex;z-index:3000"><div class="login-card"><div class="login-title">Expiry Tracker</div><p class="login-sub">Choose where your items live. You can switch in Settings. Data is never copied automatically.</p><button class="login-btn" id="choose-local" onclick="Mobile.selectMode('local')">On this iPhone — no account</button><button class="logout-btn" id="choose-cloud" onclick="Mobile.selectMode('cloud')">Online — sign in</button><p id="mode-error" class="login-error" role="alert"></p></div></div>''')
html=html.replace('<div class="page" id="settings-page">','''<div class="page" id="settings-page">
<div class="bao-card"><div class="bao-card-head"><span class="head-title">Storage &amp; Backup</span></div><div class="settings-section"><p id="storage-mode"></p><p style="font-size:12px;color:var(--text-2);margin:12px 0">Local and each online account have separate data, photos and settings. Switching reloads the app; unsaved form changes are discarded. Export a JSON backup to transfer cloud data to local explicitly. Cloud imports are not supported.</p><button class="ghost-btn" id="change-mode" onclick="Mobile.pickMode()">Change storage mode</button><button class="cat-add-btn" id="backup-export" onclick="Mobile.exportBackup()">Export JSON with photos</button><button class="ghost-btn" id="backup-import" onclick="document.getElementById('backup-file').click()">Import JSON to local (replace)</button><input hidden type="file" id="backup-file" accept="application/json,.json" onchange="Mobile.importBackup(this)"/><p id="backup-status" role="status"></p></div></div>''')
a=html.index('      <!-- Scanning / OCR -->');b=html.index('      <!-- Categories -->',a)
html=html[:a]+'''<div class="bao-card"><div class="bao-card-head"><span class="head-title">On-device OCR</span></div><div class="settings-section" id="vision-key-status">Apple Vision reads dates on this iPhone; no cloud OCR.</div></div>\n'''+html[b:]
html=html.replace('Export all items to Excel','Export all items to CSV').replace('>Excel</button>','>CSV</button>').replace('Excel spreadsheet (.xlsx)','CSV file (.csv)').replace('Export to Excel','Export to CSV')
html=html.replace('Save to cloud','Save item').replace('Clear Cached Photos','Clear Cloud Photo Cache')
html=html.replace('<div class="login-toggle">Accounts are created by the administrator.</div>','<div class="login-toggle">Accounts are created by the administrator.</div><button class="ghost-btn" onclick="Mobile.pickMode()">Change storage mode</button>')
html+='''<script src="native.js"></script><script src="config.js"></script><script type="module" src="boot.mjs"></script></body></html>'''
(root/'mobile-web/index.html').write_text(html,encoding='utf-8')
