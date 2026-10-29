/* ═══ LUCIDE line icons (Modernist) ═══ */
const LUCIDE={
  package:'<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/><path d="M3.3 7 12 12l8.7-5"/><path d="M12 22V12"/>',
  camera:'<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>',
  zap:'<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>',
  'triangle-alert':'<path d="m10.29 3.86-8.4 14.55A2 2 0 0 0 3.6 21h16.8a2 2 0 0 0 1.71-3.03L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/>',
  clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>',
  'circle-check':'<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
  list:'<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
  'file-plus':'<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v5h5"/><path d="M12 12v6M9 15h6"/>',
  pencil:'<path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/>',
  trash:'<path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6z"/>',
  moon:'<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
  palette:'<circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.555C21.965 6.012 17.461 2 12 2z"/>',
  'scan-search':'<path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2"/><circle cx="12" cy="12" r="3"/><path d="m16 16-1.9-1.9"/>',
  tag:'<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/>',
  search:'<circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>',
  user:'<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  shield:'<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
  download:'<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="M7 10l5 5 5-5"/><path d="M12 15V3"/>',
  info:'<circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  'rotate-ccw':'<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
  'scan-line':'<path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 12h10"/>',
  plug:'<path d="M12 22v-5M9 8V2M15 8V2M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8Z"/>',
  x:'<path d="M18 6 6 18M6 6l12 12"/>',
  calendar:'<rect x="3" y="4" width="18" height="18" rx="0"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  check:'<path d="M20 6 9 17l-5-5"/>',
  bell:'<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>'
};
function ic(name,size){ const p=LUCIDE[name]; if(!p) return ''; const s=size||18; return `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:block;flex:none">${p}</svg>`; }
function renderIcons(root){ (root||document).querySelectorAll('[data-ic]').forEach(el=>{ el.innerHTML=ic(el.getAttribute('data-ic'), +(el.getAttribute('data-ic-size')||18)); }); }

/* ═══ VERSION ═══ (bumped on every edit — single source of truth) */
const APP_VERSION='6.5';
function renderVersion(){
  const t=document.getElementById('app-version-top');     if(t) t.textContent='v'+APP_VERSION;
  const s=document.getElementById('app-version-settings');if(s) s.textContent=APP_VERSION;
}
document.addEventListener('DOMContentLoaded',renderVersion);

/* ═══ THEME ═══ */
const THEMES=['dark','light'];
const THEME_META={ dark:{icon:'moon',color:'#201e1d'}, light:{icon:'sun',color:'#f3f2f2'} };
(function(){ let t=Mobile.settings.getItem('expiry_theme'); if(!THEME_META[t]) t='dark'; applyTheme(t); })();
/* Optional "Pro" desktop card design (opt-in, desktop-only visuals). */
(function(){ document.documentElement.setAttribute('data-cards', Mobile.settings.getItem('expiry_cards') || 'classic'); })();
function applyCardStyle(v){
  document.documentElement.setAttribute('data-cards', v);
  Mobile.settings.setItem('expiry_cards', v);
  renderCardStyleToggle();
  notify(v==='pro' ? '✨ Pro card design enabled (desktop)' : 'Classic card design');
}
function renderCardStyleToggle(){
  const cur=document.documentElement.getAttribute('data-cards')||'classic';
  ['classic','pro'].forEach(k=>{ const b=document.getElementById('cards-'+k); if(b) b.classList.toggle('on', cur===k); });
}
function applyTheme(t) {
  if(!THEME_META[t]) t='light';
  document.documentElement.setAttribute('data-theme', t);
  const btn=document.getElementById('theme-btn'), meta=document.getElementById('meta-theme-color');
  if(btn)btn.innerHTML=ic(THEME_META[t].icon,18); if(meta)meta.content=THEME_META[t].color;
  Mobile.settings.setItem('expiry_theme', t);
}
function toggleTheme(){
  const cur=document.documentElement.getAttribute('data-theme')||'light';
  applyTheme(THEMES[(THEMES.indexOf(cur)+1)%THEMES.length]);  // light → dark → glass → …
}

/* ═══ SETTINGS ═══ */
let SOON_DAYS     = parseInt(Mobile.settings.getItem('expiry_soon_days')     || '14');
let CRITICAL_DAYS = parseInt(Mobile.settings.getItem('expiry_critical_days') || '3');
function updateSoonDays(val) {
  SOON_DAYS = parseInt(val); Mobile.settings.setItem('expiry_soon_days', SOON_DAYS);
  document.getElementById('soon-val').textContent = SOON_DAYS+'d';
  if(CRITICAL_DAYS>SOON_DAYS){ CRITICAL_DAYS=SOON_DAYS; updateCriticalDays(CRITICAL_DAYS); }
}
function updateCriticalDays(val) {
  CRITICAL_DAYS = Math.min(parseInt(val), SOON_DAYS); Mobile.settings.setItem('expiry_critical_days', CRITICAL_DAYS);
  const el=document.getElementById('critical-val'); if(el) el.textContent=CRITICAL_DAYS+'d';
  const r=document.getElementById('critical-range'); if(r){ r.max=SOON_DAYS; r.value=CRITICAL_DAYS; }
}

/* ═══ PRODUCTS AUTOCOMPLETE ═══ */
const DEFAULT_PRODUCTS = [
  'Milk','Semi-Skimmed Milk','Whole Milk','Oat Milk','Almond Milk','Soy Milk',
  'Eggs','Butter','Cheese','Cheddar Cheese','Mozzarella','Cream Cheese','Parmesan','Feta Cheese','Brie',
  'Yogurt','Greek Yogurt','Cream','Heavy Cream','Sour Cream','Whipped Cream',
  'Chicken Breast','Chicken Thighs','Whole Chicken','Ground Beef','Beef Steak','Beef Mince',
  'Salmon Fillet','Tuna','Cod Fillet','Pork Chops','Bacon','Ham','Turkey','Shrimp','Prawns',
  'Bread','White Bread','Whole Wheat Bread','Sourdough Bread','Bagels','Tortillas','Pita Bread','Croissants','Rolls',
  'Orange Juice','Apple Juice','Grape Juice','Tomato Juice','Coconut Water','Sparkling Water',
  'Tomatoes','Lettuce','Spinach','Carrots','Broccoli','Cucumber','Bell Peppers','Mushrooms','Onions','Garlic','Kale','Celery',
  'Strawberries','Blueberries','Raspberries','Bananas','Apples','Avocado','Grapes','Mango','Pineapple',
  'Canned Tomatoes','Canned Beans','Canned Corn','Canned Tuna','Canned Salmon','Canned Soup',
  'Tomato Paste','Tomato Sauce','Pasta Sauce','Hummus','Salsa','Peanut Butter','Jam','Honey',
  'Mayonnaise','Mustard','Ketchup','Soy Sauce','Hot Sauce','Olive Oil','Vegetable Oil',
  'Aspirin','Ibuprofen','Paracetamol','Vitamin C','Vitamin D','Multivitamins','Fish Oil',
  'Antihistamine','Cough Syrup','Cold Medicine','Antacid','Probiotics',
  'Shampoo','Conditioner','Body Lotion','Sunscreen','Face Cream','Toothpaste',
  'Hand Sanitizer','Contact Lens Solution','Eye Drops','Hydrogen Peroxide',
  'Baby Formula','Baby Food','Baby Wipes','Infant Paracetamol','Nappy Cream',
  'Pasta','Rice','Oats','Cereal','Crackers','Biscuits','Chocolate','Ice Cream',
  'Frozen Pizza','Frozen Peas','Frozen Berries',
];
let PRODUCTS = JSON.parse(Mobile.settings.getItem('expiry_products') || 'null') || [...DEFAULT_PRODUCTS];

function saveProducts() { Mobile.settings.setItem('expiry_products', JSON.stringify(PRODUCTS)); }
function renderDatalist() {
  const dl = document.getElementById('products-list');
  dl.innerHTML = PRODUCTS.map(p => `<option value="${esc(p)}">`).join('');
}
function saveProductList() {
  const ta = document.getElementById('products-textarea');
  PRODUCTS = ta.value.split('\n').map(s=>s.trim()).filter(Boolean);
  saveProducts(); renderDatalist();
  document.getElementById('product-count-label').textContent = PRODUCTS.length + ' products in list';
  notify('✅ Product list saved — ' + PRODUCTS.length + ' items');
}
function resetProductList() {
  PRODUCTS = [...DEFAULT_PRODUCTS];
  saveProducts(); renderDatalist();
  const ta = document.getElementById('products-textarea');
  if(ta) ta.value = PRODUCTS.join('\n');
  document.getElementById('product-count-label').textContent = PRODUCTS.length + ' products in list';
  notify('↺ Reset to default list');
}

/* ═══ CATEGORIES ═══ */
const DEFAULT_CATS = [
  {emoji:'🥛',name:'Dairy'},{emoji:'🥩',name:'Meat'},{emoji:'🧴',name:'Beauty'},
  {emoji:'💊',name:'Medicine'},{emoji:'🥫',name:'Canned'},{emoji:'🍞',name:'Bread'},
  {emoji:'🧀',name:'Cheese'},{emoji:'🥚',name:'Eggs'},{emoji:'🫙',name:'Pantry'},
  {emoji:'🧃',name:'Drinks'},{emoji:'🥦',name:'Veg'},{emoji:'🍓',name:'Fruit'},
  {emoji:'❄️',name:'Frozen'},{emoji:'🧹',name:'Cleaning'},
];
let CATEGORIES = JSON.parse(Mobile.settings.getItem('expiry_cats') || JSON.stringify(DEFAULT_CATS));
function catName(c){ return typeof c==='string' ? c : ((c&&c.name)||''); }   // supports old {emoji,name} + new {name}
let catScan = catName(CATEGORIES[0])||'Other', catManual = catName(CATEGORIES[0])||'Other';

function saveCategories() { Mobile.settings.setItem('expiry_cats', JSON.stringify(CATEGORIES)); }
function renderCatList() {
  const el=document.getElementById('cat-list'); if(!el) return;
  el.innerHTML=CATEGORIES.map((c,i)=>
    `<span class="cat-chip"><span class="cat-chip-name">${esc(catName(c))}</span><button class="cat-chip-del" onclick="removeCategory(${i})">×</button></span>`
  ).join('');
}
function addCategory() {
  const nEl=document.getElementById('new-cat-name');
  const name=nEl.value.trim();
  if(!name){ notify('⚠️ Enter a category name'); return; }
  if(CATEGORIES.some(c=>catName(c).toLowerCase()===name.toLowerCase())){ notify('⚠️ That category already exists'); return; }
  CATEGORIES.push({name}); saveCategories();
  renderCatList(); renderCategoryPicker('scan'); renderCategoryPicker('manual');
  nEl.value=''; notify('✅ Category "'+name+'" added');
}
function removeCategory(idx) {
  if(CATEGORIES.length<=1){ notify('⚠️ Keep at least one category'); return; }
  const removed=CATEGORIES.splice(idx,1)[0]; saveCategories();
  renderCatList(); renderCategoryPicker('scan'); renderCategoryPicker('manual');
  notify('Removed "'+catName(removed)+'"');
}
/* Category picker shows NAMES (no icons). Selected value stored on the item. */
function renderCategoryPicker(ctx) {
  const el=document.getElementById('emoji-picker-'+ctx); if(!el) return;
  el.innerHTML=CATEGORIES.map((c,i)=>
    `<button class="cat-opt${i===0?' on':''}" data-cat="${esc(catName(c))}" onclick="selectCat(this,'${ctx}')">${esc(catName(c))}</button>`
  ).join('');
  const first=catName(CATEGORIES[0])||'Other';
  if(ctx==='scan')   catScan  =first;
  if(ctx==='manual') catManual=first;
  if(ctx==='edit')   catEdit  =first;
}
function selectCat(btn, ctx) {
  document.getElementById('emoji-picker-'+ctx).querySelectorAll('.cat-opt').forEach(b=>b.classList.remove('on'));
  btn.classList.add('on');
  if(ctx==='scan')   catScan  =btn.dataset.cat;
  if(ctx==='manual') catManual=btn.dataset.cat;
  if(ctx==='edit')   catEdit  =btn.dataset.cat;
}
/* Highlight the option matching a category name (used when opening the edit form). */
function preselectCat(ctx,name){
  const el=document.getElementById('emoji-picker-'+ctx); if(!el) return;
  const opts=[...el.querySelectorAll('.cat-opt')];
  opts.forEach(b=>b.classList.remove('on'));
  const target=opts.find(b=>b.dataset.cat===name) || opts[0];
  if(target){ target.classList.add('on'); if(ctx==='edit') catEdit=target.dataset.cat; }
}

/* ═══ LOCAL IMAGE STORE ═══ */
let capturedThumb = null;
function getThumbnail(canvas) {
  // Store the date photo at a readable size (serves both the tiny list thumbnail
  // and the enlarged lightbox view), preserving aspect ratio.
  const maxDim=800, scale=Math.min(1, maxDim/Math.max(canvas.width,canvas.height));
  const w=Math.round(canvas.width*scale), h=Math.round(canvas.height*scale);
  const t=document.createElement('canvas'); t.width=w; t.height=h;
  t.getContext('2d').drawImage(canvas,0,0,w,h);
  return t.toDataURL('image/jpeg',.68);
}
/* Local cache (instant display + offline). Keyed by item id. */




/* ── Supabase Storage image sync ──
   Thumbnails live at  <user_id>/<item_id>.jpg  in the 'item-images' bucket, so
   any device signed into the same account can pull them. Local cache is kept as
   an instant/offline copy. */
const IMG_BUCKET='item-images';
/* Each item has a thumbnail (id.jpg) and an optional full "package" photo (id_full.jpg). */
function imagePath(id,full){ return CURRENT_USER ? `${CURRENT_USER.id}/${id}${full?'_full':''}.jpg` : null; }
function imgKey(id,full){ return full ? id+'_full' : String(id); }
function dataURLtoBlob(u){ const [h,b]=u.split(','); const mime=(h.match(/:(.*?);/)||[])[1]||'image/jpeg'; const bin=atob(b); const a=new Uint8Array(bin.length); for(let i=0;i<bin.length;i++)a[i]=bin.charCodeAt(i); return new Blob([a],{type:mime}); }
function blobToDataURL(blob){ return new Promise((res,rej)=>{ const r=new FileReader(); r.onload=()=>res(r.result); r.onerror=rej; r.readAsDataURL(blob); }); }
/* Save locally then push to Storage (upsert). Local copy stands in if upload fails. */
let _uploadWarned=false;

/* Return a displayable data URL: local cache first, else download from Storage
   (and cache it so it's instant/offline next time). null if there is no image. */


/* Fill an <img> once its thumbnail is available (used for cross-device pulls). */
async function hydrateImage(el,id){
  if(!el) return;
  let url=await fetchImage(id,false);          // date/scan photo first
  if(!url) url=await fetchImage(id,true);       // else fall back to the package photo
  if(url && el.isConnected){ el.style.backgroundImage=`url('${url}')`; el.classList.add('has-photo'); }
}


/* ═══ PACKAGE (2nd) PHOTO + IMAGE LIGHTBOX ═══ */
function setBtn(id,txt){ const b=document.getElementById(id); if(b) b.textContent=txt; }
/* Set a button's label with a leading Lucide icon (keeps flex row + gap from CSS). */
function setBtnIc(id,icon,txt){ const b=document.getElementById(id); if(b) b.innerHTML=ic(icon,14)+'<span>'+txt+'</span>'; }
let pendingFullPhoto=null;   // package photo attached to the item being scanned
function resetFullPhoto(){
  pendingFullPhoto=null;
  const b=document.getElementById('full-photo-btn');
  if(b){ b.classList.remove('added'); setBtnIc('full-photo-btn','package','Add package photo (optional)'); }
}
/* Trigger the camera / file picker for the scan flow's package photo. */
function pickFullPhoto(forId){
  const inp=document.getElementById('full-photo-input');
  inp.dataset.mode=''; inp.dataset.full='1'; inp.dataset.forId = forId==null?'':String(forId);
  inp.value=''; inp.click();
}
/* Optional photos on the manual "New Item" form (attached on save). */
let pendingManualThumb=null, pendingManualFull=null;
function manualPickPhoto(full){
  const inp=document.getElementById('full-photo-input');
  inp.dataset.mode='manual'; inp.dataset.full=full?'1':''; inp.dataset.forId='';
  inp.value=''; inp.click();
}
function resetManualPhotos(){
  pendingManualThumb=null; pendingManualFull=null;
  setBtnIc('manual-photo-btn','camera','Add photo (optional)');
  setBtnIc('manual-pkg-btn','package','Add package photo (optional)');
}
/* Load a chosen photo and downscale it for storage. */
function loadDownscaled(file,maxDim,q){
  return new Promise((res,rej)=>{
    const img=new Image();
    img.onload=()=>{
      const scale=Math.min(1, maxDim/Math.max(img.width,img.height));
      const cw=Math.round(img.width*scale), ch=Math.round(img.height*scale);
      const cv=document.createElement('canvas'); cv.width=cw; cv.height=ch;
      cv.getContext('2d').drawImage(img,0,0,cw,ch);
      URL.revokeObjectURL(img.src);
      res(cv.toDataURL('image/jpeg', q||.82));
    };
    img.onerror=e=>{ URL.revokeObjectURL(img.src); rej(e); };
    img.src=URL.createObjectURL(file);
  });
}
async function onFullPhotoSelected(inp){
  const file=inp.files&&inp.files[0]; if(!file) return;
  const full = inp.dataset.full==='1';
  let dataUrl;
  try{ dataUrl=await loadDownscaled(file, full?1100:900, .82); }
  catch(e){ notify('⚠️ Could not read that image'); return; }
  if(inp.dataset.mode==='edit'){       // editing an item → stage, upload on Save
    if(full){ editPendingFull=dataUrl;  setBtnIc('edit-pkgphoto-btn','check','Package photo set — tap to change'); }
    else    { editPendingThumb=dataUrl; setBtnIc('edit-datephoto-btn','check','Date photo set — tap to change'); }
    return;
  }
  if(inp.dataset.mode==='manual'){     // manual New Item form → attach on save
    if(full){ pendingManualFull=dataUrl;  setBtnIc('manual-pkg-btn','check','Package photo added — tap to change'); }
    else    { pendingManualThumb=dataUrl; setBtnIc('manual-photo-btn','check','Photo added — tap to change'); }
    return;
  }
  const forId=inp.dataset.forId;
  if(forId){ await uploadImage(forId,dataUrl,true); notify('📷 Package photo saved'); }
  else{                                // scan flow → attach on save
    pendingFullPhoto=dataUrl;
    const b=document.getElementById('full-photo-btn');
    if(b){ b.classList.add('added'); setBtnIc('full-photo-btn','check','Package photo added — tap to change'); }
  }
}

/* ═══ IMAGE LIGHTBOX (gallery: expiry-date photo → package photo) ═══ */
let lbPhotos=[], lbIndex=0, lbId=null;
async function openLightbox(id){
  lbId=id; lbIndex=0; lbPhotos=[];
  document.getElementById('lightbox').classList.add('show');
  const spin=document.getElementById('lightbox-loading'), stage=document.querySelector('.lb-stage'), empty=document.getElementById('lightbox-empty');
  spin.style.display='block'; stage.style.visibility='hidden'; empty.style.display='none';
  document.getElementById('lb-dots').innerHTML=''; document.getElementById('lb-caption').textContent='';
  const dateUrl=await fetchImage(id,false);   // expiry date photo first
  const pkgUrl =await fetchImage(id,true);     // package photo second
  if(lbId!==id) return;                        // user closed/opened another meanwhile
  spin.style.display='none';
  if(dateUrl) lbPhotos.push({url:dateUrl, cap:'Expiry date photo'});
  if(pkgUrl)  lbPhotos.push({url:pkgUrl,  cap:'Package photo'});
  if(!lbPhotos.length){ empty.style.display='block'; return; }
  renderLb();
}
function renderLb(){
  const stage=document.querySelector('.lb-stage'); stage.style.visibility='visible';
  document.getElementById('lightbox-img').src=lbPhotos[lbIndex].url;
  const multi=lbPhotos.length>1;
  document.getElementById('lb-caption').textContent=lbPhotos[lbIndex].cap+(multi?`  ·  ${lbIndex+1}/${lbPhotos.length}`:'');
  const prev=document.querySelector('.lb-prev'), next=document.querySelector('.lb-next');
  prev.style.display=next.style.display=multi?'flex':'none';
  prev.classList.toggle('disabled', lbIndex===0);
  next.classList.toggle('disabled', lbIndex===lbPhotos.length-1);
  document.getElementById('lb-dots').innerHTML = multi ? lbPhotos.map((_,i)=>`<span class="lb-dot${i===lbIndex?' on':''}"></span>`).join('') : '';
}
function lbGo(d){ const n=lbIndex+d; if(n>=0 && n<lbPhotos.length){ lbIndex=n; renderLb(); } }
function closeLightbox(){ document.getElementById('lightbox').classList.remove('show'); lbId=null; lbPhotos=[]; }
(function(){                                    // swipe + keyboard navigation
  const lb=document.getElementById('lightbox'); if(!lb) return;
  let x0=null;
  lb.addEventListener('touchstart',e=>{ x0=e.touches[0].clientX; },{passive:true});
  lb.addEventListener('touchend',e=>{ if(x0==null)return; const dx=e.changedTouches[0].clientX-x0; if(Math.abs(dx)>40) lbGo(dx<0?1:-1); x0=null; },{passive:true});
  document.addEventListener('keydown',e=>{ if(!lb.classList.contains('show'))return; if(e.key==='ArrowRight')lbGo(1); else if(e.key==='ArrowLeft')lbGo(-1); else if(e.key==='Escape')closeLightbox(); });
})();

/* ═══ EDIT ITEM ═══ */
let editingId=null, editPendingThumb=null, editPendingFull=null, catEdit='Other';
function openEdit(id){
  const item=itemMap[id]; if(!item){ notify('⚠️ Item not found'); return; }
  editingId=id; editPendingThumb=null; editPendingFull=null;
  document.getElementById('edit-name').value=item.name||'';
  document.getElementById('edit-date').value=item.expiry||'';
  renderCategoryPicker('edit'); preselectCat('edit', item.icon||'');
  setBtnIc('edit-datephoto-btn','calendar','Replace expiry date photo');
  setBtnIc('edit-pkgphoto-btn','package','Add / replace package photo');
  document.getElementById('edit-modal').classList.add('show');
}
function editPickPhoto(full){
  const inp=document.getElementById('full-photo-input');
  inp.dataset.mode='edit'; inp.dataset.full=full?'1':''; inp.dataset.forId='';
  inp.value=''; inp.click();
}
async function saveEdit(){
  if(!editingId) return;
  const name=document.getElementById('edit-name').value.trim();
  const date=document.getElementById('edit-date').value;
  if(!name){ notify('⚠️ Enter a product name'); return; }
  if(!date){ notify('⚠️ Enter the expiry date'); return; }
  const updated=await dbUpdate(editingId,{name,expiry:date,icon:catEdit});
  if(!updated) return;
  if(editPendingThumb) await uploadImage(editingId, editPendingThumb, false);
  if(editPendingFull)  await uploadImage(editingId, editPendingFull, true);
  editPendingThumb=null; editPendingFull=null;
  closeEdit(); notify('✅ Changes saved');
  renderDashboard(); renderAll();
}
function closeEdit(){ document.getElementById('edit-modal').classList.remove('show'); editingId=null; }

/* ═══ BARCODE SCANNER → OpenFoodFacts name lookup ═══
   Uses the native BarcodeDetector when available (Chrome/Android); everywhere
   else, the user types the number. Either way we look the product up and
   auto-fill the target name field. */
let bcTarget=null, bcStream=null, bcDetector=null, bcTimer=null, bcReader=null;
function setBcStatus(t){ const el=document.getElementById('bc-status'); if(el) el.textContent=t; }
/* Lazily load ZXing only when the native BarcodeDetector isn't available. */

async function scanBarcodeLoop(){
  const modal=document.getElementById('barcode-modal');
  if(!bcDetector || !bcStream || !modal.classList.contains('show')) return;
  try{
    const codes=await bcDetector.detect(document.getElementById('bc-video'));
    if(codes && codes.length && codes[0].rawValue){ lookupBarcode(codes[0].rawValue); return; }
  }catch(e){}
  bcTimer=setTimeout(scanBarcodeLoop,350);
}
function stopBcCamera(){
  if(bcStream){ bcStream.getTracks().forEach(t=>t.stop()); bcStream=null; }
  if(bcReader){ try{ bcReader.reset(); }catch(e){} bcReader=null; }
  clearTimeout(bcTimer);
  const v=document.getElementById('bc-video'); if(v) v.srcObject=null;
}
function closeBarcode(){ stopBcCamera(); document.getElementById('barcode-modal').classList.remove('show'); }
function lookupBarcode(){setBcStatus('Network barcode lookup is disabled. Enter the product name manually.');}
/* ═══ SUPABASE ═══ */
const SUPABASE_URL='https://viupqrjyszvvcpnxrmsq.supabase.co';
const SUPABASE_ANON_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpdXBxcmp5c3p2dmNwbnhybXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTY2ODgsImV4cCI6MjA5NDg3MjY4OH0.-j_X1M4_FBDuax4Gpd3tOHYdgs-fdWN2sPTbhYlG7qk';
const sb=Mobile.client;
function getDeviceId(){ let id=Mobile.settings.getItem('expiry_device_id'); if(!id){id=crypto.randomUUID();Mobile.settings.setItem('expiry_device_id',id);} return id; }
const DEVICE_ID=getDeviceId();

/* ═══ AUTH ═══ (Supabase email/password — scopes data to the logged-in account
   so items sync across every device that signs in, replacing per-device silos.
   Sign-in only: accounts are provisioned by the admin, never self-created.) */
let CURRENT_USER=null;
function isAdmin(){ return !!(CURRENT_USER && CURRENT_USER.app_metadata && CURRENT_USER.app_metadata.role==='admin'); }





/* Change my own password (any user). */
async function changeMyPassword(){
  const inp=document.getElementById('new-password'), status=document.getElementById('pw-status');
  const pw=(inp.value||'').trim();
  if(pw.length<6){ status.style.color='#dc2626'; status.textContent='Password must be at least 6 characters.'; return; }
  const{error}=await sb.auth.updateUser({password:pw});
  if(error){ status.style.color='#dc2626'; status.textContent=error.message; return; }
  inp.value=''; status.style.color='var(--green,#16a34a)'; status.textContent='✓ Password updated.'; notify('🔒 Password changed');
}

/* ═══ USER MANAGEMENT ═══ (admin only; runs server-side via the admin-users
   Edge Function so the service-role key never touches the browser) */
async function callAdmin(action, payload){
  const{data,error}=await sb.functions.invoke('admin-users',{body:{action,...(payload||{})}});
  if(error) throw new Error(error.message||'Request failed');
  if(data&&data.ok===false) throw new Error(data.error||'Request failed');
  return data;
}
async function adminCreateUser(){
  const em=document.getElementById('nu-email'), pw=document.getElementById('nu-pass'), st=document.getElementById('nu-status');
  const email=(em.value||'').trim(), pass=(pw.value||'').trim();
  st.style.color='var(--text-2)'; st.textContent='';
  if(!email||pass.length<6){ st.style.color='#dc2626'; st.textContent='Enter an email and a password (6+ chars).'; return; }
  try{
    st.textContent='Creating…';
    await callAdmin('create',{email,password:pass});
    em.value=''; pw.value=''; st.style.color='var(--green,#16a34a)'; st.textContent='✓ User created.';
    notify('✅ User "'+email+'" created'); adminLoadUsers();
  }catch(e){ st.style.color='#dc2626'; st.textContent=e.message; }
}
async function adminDeleteUser(id,email){
  if(!confirm('Delete user '+email+'? This removes their login (their items remain in the database).')) return;
  try{ await callAdmin('delete',{id}); notify('🗑 User deleted'); adminLoadUsers(); }
  catch(e){ notify('⚠️ '+e.message); }
}
async function adminLoadUsers(){
  const wrap=document.getElementById('user-list'); if(!wrap) return;
  wrap.innerHTML='<div style="font-size:12px;color:var(--text-2);padding:6px 0;">Loading…</div>';
  try{
    const{users}=await callAdmin('list');
    if(!users||!users.length){ wrap.innerHTML='<div style="font-size:12px;color:var(--text-2);">No users.</div>'; return; }
    wrap.innerHTML=users.map(u=>`
      <div class="settings-row" style="gap:8px;">
        <span style="flex:1;min-width:0;">
          <span class="acct-email">${esc(u.email||'')}</span>
          <span style="font-size:10px;font-weight:700;padding:1px 6px;border-radius:6px;margin-left:6px;background:${u.role==='admin'?'var(--accent-lt)':'var(--muted-bg)'};color:${u.role==='admin'?'var(--accent)':'var(--text-2)'};">${u.role==='admin'?'ADMIN':'USER'}</span>
        </span>
        ${u.role==='admin'?'':`<button class="cat-chip-del" onclick="adminDeleteUser('${u.id}','${esc(u.email||'')}')">×</button>`}
      </div>`).join('');
  }catch(e){ wrap.innerHTML='<div style="font-size:12px;color:#dc2626;">'+esc(e.message)+'</div>'; }
}

/* ═══ SYNC UI ═══ */

async function refresh(){ await renderDashboard(); await renderAll(); }

/* ═══ DB ═══ */





/* ═══ HELPERS ═══ */
function daysUntil(s){ const t=new Date(); t.setHours(0,0,0,0); return Math.round((new Date(s+'T00:00:00')-t)/86400000); }
function getStatus(d){ return d<0?'s-red':d<=CRITICAL_DAYS?'s-orange':d<=SOON_DAYS?'s-yellow':'s-green'; }
function getTag(d)   { return d<0?'tag-red':d<=CRITICAL_DAYS?'tag-orange':d<=SOON_DAYS?'tag-yellow':'tag-green'; }
function daysLabel(d){ if(d<0)return 'Expired '+Math.abs(d)+'d ago'; if(d===0)return 'Today!'; if(d===1)return 'Tomorrow'; return d+' days'; }
function fmtDate(s)  { return new Date(s+'T00:00:00').toLocaleDateString('en-US',{year:'numeric',month:'short',day:'numeric'}); }
function esc(s)      { return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
function notify(msg) { const b=document.getElementById('notify-bar'); b.textContent=msg; b.classList.add('show'); setTimeout(()=>b.classList.remove('show'),3000); }

/* ═══ TABS ═══ */
const PAGE_TITLES={dashboard:'Expiry Tracker',camera:'Scan Item',manual:'New Item',list:'All Items',settings:'Settings'};
let stream=null;

/* Persistent, pre-warmed OCR worker — created once and reused across every scan
   instead of being rebuilt+torn down each capture (the old approach reloaded the
   ~10MB model every time). warmOCR() is idempotent; call it early to overlap the
   one-time init with the user aiming the camera. */
function warmOCR(){return Promise.resolve({recognize:async image=>{const result=await Native.call('ocr',{image:typeof image==='string'?image:image.toDataURL('image/jpeg',.9)});if(typeof result?.text!=='string')throw Error('Invalid native OCR response');return {data:{text:result.text}};}});}
function switchTab(tab){
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b=>b.classList.remove('active'));
  document.getElementById(tab+'-page').classList.add('active');
  const btn=document.getElementById('tab-'+tab); if(btn) btn.classList.add('active');
  document.title = tab==='dashboard' ? 'Expiry Tracker' : PAGE_TITLES[tab]+' · Expiry Tracker';
  if(tab==='camera') startCamera(); else stopCamera();
  if(tab==='dashboard') renderDashboard();
  if(tab==='list') renderAll();
  if(tab==='settings') renderSettingsPage();
}

/* ═══ CAMERA ═══ */





/* ═══ OCR ═══ */
/* Crop to the scan-frame region (a bit wider than the on-screen guide to tolerate
   aim error), upscale small crops so glyphs are tall enough to read, then greyscale
   + contrast-stretch. Far fewer pixels than the full frame and much cleaner input,
   so recognition is both faster and more accurate. */
function preprocessForOCR(src,full){
  const fw=full?0.98:0.74, fh=full?0.98:0.42;   // full-frame retry vs tight scan-box crop
  const cw=Math.round(src.width*fw), ch=Math.round(src.height*fh);
  const cx=Math.round((src.width-cw)/2), cy=Math.round((src.height-ch)/2);
  const scale=Math.max(1,Math.min(3,(full?1600:1100)/cw));
  const out=document.createElement('canvas');
  out.width=Math.round(cw*scale); out.height=Math.round(ch*scale);
  const ctx=out.getContext('2d');
  ctx.imageSmoothingEnabled=true; ctx.imageSmoothingQuality='high';
  ctx.drawImage(src,cx,cy,cw,ch,0,0,out.width,out.height);
  const img=ctx.getImageData(0,0,out.width,out.height),d=img.data;
  for(let i=0;i<d.length;i+=4){
    let g=0.299*d[i]+0.587*d[i+1]+0.114*d[i+2];
    g=(g-128)*1.6+128;                 // contrast stretch
    d[i]=d[i+1]=d[i+2]=g<0?0:g>255?255:g;
  }
  ctx.putImageData(img,0,0);
  return out;
}
function cloudOcrEnabled(){return false;}
async function cloudOCR(canvas,full){return localOCR(canvas,full);}
function renderVisionKeyStatus(){document.getElementById('vision-key-status').textContent='Apple Vision reads dates on this iPhone. Photos are never sent to cloud OCR.';}
/* On-device OCR via Apple Vision. */
async function localOCR(canvas,full){
  const w=await warmOCR();
  const{data:{text}}=await w.recognize(preprocessForOCR(canvas,full));
  return text;
}
/* One OCR pass: cloud-first when available, else on-device; cloud failures fall back. */
async function ocrPass(canvas,full){
  if(cloudOcrEnabled()){
    try{ return await cloudOCR(canvas,full); }
    catch(err){ return await localOCR(canvas,full); }
  }
  return await localOCR(canvas,full);
}
/* Two-pass hybrid: read the tight scan-box crop first; if no date is parsed,
   retry once on the full frame (covers the case where the date sat outside the box). */
let lastOCRText='';
async function runOCR(canvas){
  const st=document.getElementById('ocr-status'),ot=document.getElementById('ocr-text');
  st.classList.add('show'); ot.dataset.live='1';
  ot.textContent=cloudOcrEnabled()?'Reading (cloud)…':'Reading expiry date…';
  try{
    let text=await ocrPass(canvas,false);
    let cands=extractDates(text);
    if(!cands.length){               // aim may have been off — try the whole frame
      ot.textContent='Looking wider…';
      const wide=await ocrPass(canvas,true);
      const wc=extractDates(wide);
      if(wc.length){ cands=wc; text=wide; }
      else if((wide||'').length>(text||'').length){ text=wide; }
    }
    lastOCRText=text||'';
    const {primary,list}=pickExpiry(cands);
    console.log('[OCR] text:',JSON.stringify(lastOCRText),'candidates:',cands.map(c=>c.date+'/'+(c.label||'?')));
    ot.dataset.live='0';
    if(primary){
      const n=new Set(list.map(c=>c.date)).size;
      ot.textContent = n>1 ? (n+' dates found — expiry looks like '+fmtDate(primary.date)) : ('Date detected: '+fmtDate(primary.date));
    }else{
      const snip=lastOCRText.replace(/\s+/g,' ').trim().slice(0,70);
      ot.textContent=snip?('Read: "'+snip+'" — no date, enter manually'):'No text detected — enter manually';
    }
    showConfirm(primary?primary.date:null, list);
  }catch(e){ot.dataset.live='0';ot.textContent='OCR error — enter date manually';showConfirm(null);}
}
/* Find EVERY date in the text, each tagged exp/prod by nearby label keywords,
   so we can prefer the expiry rather than blindly taking the first date. */
function extractDates(raw){
  const t=(raw||'').toUpperCase();
  const M={JAN:1,FEB:2,MAR:3,APR:4,MAY:5,JUN:6,JUL:7,AUG:8,SEP:9,OCT:10,NOV:11,DEC:12};
  const MON='(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)';
  const S='[\\/\\-. ]';                                  // /  -  .  or space separator
  const mk=(y,m,d)=>{ let yy=+y,mm=+m,dd=+d; if(yy<100)yy+=2000; if(!yy||mm<1||mm>12||dd<1||dd>31||yy<2020||yy>2041)return null; return `${yy}-${String(mm).padStart(2,'0')}-${String(dd).padStart(2,'0')}`; };
  // Month/year only (e.g. 07/2026) → default to the LAST day of that month (expiry = good through end of month).
  const mkEOM=(y,m)=>{ let yy=+y; if(yy<100)yy+=2000; const mm=+m; if(mm<1||mm>12||yy<2020||yy>2041)return null; return mk(yy,mm,new Date(yy,mm,0).getDate()); };
  const two=(a,b,y)=>{ a=+a;b=+b; if(a>12&&b<=12)return mk(y,b,a); if(b>12&&a<=12)return mk(y,a,b); return mk(y,b,a); };
  const P=[
    {r:new RegExp(`(\\d{1,2})\\s*${MON}[A-Z]*\\s*(\\d{2,4})`),           f:m=>mk(m[3],M[m[2]],m[1])},  // 31 DEC 2026 / 31DEC26
    {r:new RegExp(`${MON}[A-Z]*\\s*(\\d{1,2})\\s*[, ]\\s*(\\d{2,4})`),   f:m=>mk(m[3],M[m[1]],m[2])},  // DEC 31, 2026
    {r:new RegExp(`${MON}[A-Z]*${S}*(20\\d{2}|\\d{2})\\b`),             f:m=>mkEOM(m[2],M[m[1]])},     // DEC 2026 / DEC26 → end of month
    {r:/(20\d{2})[\/\-.](\d{1,2})[\/\-.](\d{1,2})/,                     f:m=>mk(m[1],m[2],m[3])},      // 2026-07-21 (no space sep: avoids bridging two dates)
    {r:/\b(20\d{2})(\d{2})(\d{2})\b/,                                    f:m=>mk(m[1],m[2],m[3])},      // 20260721
    {r:new RegExp(`(\\d{1,2})${S}(\\d{1,2})${S}(20\\d{2})`),            f:m=>two(m[1],m[2],m[3])},     // 21/07/2026 or 07/21/2026
    {r:new RegExp(`\\b(\\d{1,2})${S}(\\d{1,2})${S}(\\d{2})\\b`),        f:m=>{const a=+m[1],b=+m[2],y=+m[3]; if(y<24||y>41)return null; if(a>12&&b<=12)return mk(y,b,a); if(b>12&&a<=12)return mk(y,a,b); return mk(y,b,a);}}, // 21/07/26
    {r:new RegExp(`\\b(\\d{1,2})${S}(20\\d{2})\\b`),                    f:m=>mkEOM(m[2],m[1])},        // 07/2026 → end of month
    {r:new RegExp(`\\b(\\d{2})${S}(\\d{2})\\b`),                        f:m=>{const mm=+m[1],yy=+m[2]; return(mm>=1&&mm<=12&&yy>=24&&yy<=41)?mkEOM(yy,mm):null;}}, // 07/26 → end of month
    {r:/\b(\d{2})(20\d{2})\b/,                                          f:m=>mkEOM(m[2],m[1])},        // 072026 → end of month
  ];
  const consumed=[], cands=[];
  for(const {r,f} of P){                    // patterns run most-specific first; consumed spans block weaker overlaps
    const g=new RegExp(r.source,'g'); let m;
    while((m=g.exec(t))){
      if(!m[0]){ g.lastIndex++; continue; }
      const s=m.index, e=s+m[0].length;
      if(consumed.some(c=> s<c.e && c.s<e)) continue;
      const d=f(m); if(!d) continue;
      consumed.push({s,e}); cands.push({date:d, pos:s});
    }
  }
  const EXP=/EXP|EXPIR|BEST\s?BEF|BEST\s?BY|\bBBE?\b|USE\s?BY|USE\s?BEF|SELL\s?BY|\bEND\b/;
  const PROD=/MFG|MFD|MANUF|PROD|PACK|PKD|\bMADE\b/;
  for(const c of cands){
    const before=t.slice(Math.max(0,c.pos-24), c.pos);   // label usually sits just before the date
    c.label = EXP.test(before) ? 'exp' : PROD.test(before) ? 'prod' : '';
  }
  return cands;
}
/* Choose the most likely expiry from the candidates + return the full list. */
function pickExpiry(cands){
  if(!cands||!cands.length) return {primary:null,list:[]};
  const rank=l=> l==='exp'?2 : l==='prod'?0 : 1;
  const byDate={};
  for(const c of cands){ const x=byDate[c.date]; if(!x||rank(c.label)>rank(x.label)) byDate[c.date]=c; }
  const uniq=Object.values(byDate);
  let primary=uniq.find(c=>c.label==='exp');
  if(!primary){                              // no explicit EXP label → latest non-prod date (expiry comes after production)
    const pool=uniq.filter(c=>c.label!=='prod'); const p=pool.length?pool:uniq;
    primary=p.reduce((a,b)=> a.date>=b.date?a:b);
  }
  const others=uniq.filter(c=>c.date!==primary.date).sort((a,b)=>b.date.localeCompare(a.date));
  return {primary, list:[primary,...others]};
}
function extractDate(raw){ const p=pickExpiry(extractDates(raw)).primary; return p?p.date:null; }  // back-compat
let dateCands=[];
function showConfirm(date, list){
  document.getElementById('add-form').classList.add('show');
  document.getElementById('scan-date').value=date||'';
  document.getElementById('scan-name').value='';
  resetFullPhoto();
  dateCands=list||[];
  renderDateChoices(date);
  const multi=new Set(dateCands.map(c=>c.date)).size>1;
  notify(date?(multi?'📅 Multiple dates — confirm the expiry below':'📅 Detected: '+fmtDate(date)):'No date detected — enter manually');
}
/* When several dates are found (e.g. PROD + EXP), let the user pick the expiry. */
function renderDateChoices(selected){
  const el=document.getElementById('date-choices'); if(!el) return;
  const seen={}, uniq=[];
  for(const c of dateCands){ if(!seen[c.date]){ seen[c.date]=1; uniq.push(c); } }
  if(uniq.length<2){ el.style.display='none'; el.innerHTML=''; return; }
  el.style.display='block';   // explicit — '' would revert to CSS display:none
  el.innerHTML='<div class="dc-hint">Multiple dates found — tap the expiry date:</div>'+
    uniq.map(c=>`<button type="button" class="dc-chip${c.date===selected?' on':''}" onclick="selectScanDate('${c.date}')">${fmtDate(c.date)}${c.label==='exp'?' · EXP':c.label==='prod'?' · PROD':''}</button>`).join('');
}
function selectScanDate(d){ document.getElementById('scan-date').value=d; renderDateChoices(d); }

/* ═══ SAVE ═══ */
async function saveScannedItem(){
  const name=document.getElementById('scan-name').value.trim();
  const date=document.getElementById('scan-date').value;
  if(!name){notify('⚠️ Enter a product name');return;}
  if(!date){notify('⚠️ Enter the expiry date');return;}
  const item=await dbAdd({name,expiry:date,icon:catScan,added:new Date().toISOString()});
  if(item){
    if(capturedThumb)await uploadImage(item.id,capturedThumb);
    if(pendingFullPhoto)await uploadImage(item.id,pendingFullPhoto,true);
    notify('✅ "'+name+'" saved!');
    document.getElementById('add-form').classList.remove('show'); document.getElementById('ocr-status').classList.remove('show');
    capturedThumb=null; resetFullPhoto(); startCamera();
  }
}
async function saveManualItem(){
  const name=document.getElementById('manual-name').value.trim();
  const date=document.getElementById('manual-date').value;
  if(!name){notify('⚠️ Enter a product name');return;}
  if(!date){notify('⚠️ Enter the expiry date');return;}
  const item=await dbAdd({name,expiry:date,icon:catManual,added:new Date().toISOString()});
  if(item){
    if(pendingManualThumb) await uploadImage(item.id, pendingManualThumb, false);
    if(pendingManualFull)  await uploadImage(item.id, pendingManualFull, true);
    notify('✅ "'+name+'" saved!');
    document.getElementById('manual-name').value=''; document.getElementById('manual-date').value=new Date().toISOString().split('T')[0];
    resetManualPhotos(); renderDashboard(); renderAll();
  }
}

/* ═══ RENDER ═══ */
const itemMap={};
function buildItem(item,idx){
  itemMap[item.id]=item;
  const days=daysUntil(item.expiry);
  const local=getImageLocally(item.id) || getImageLocally(item.id+'_full');   // date photo, else package photo
  const div=document.createElement('div');
  div.className='bao-item '+getStatus(days);
  div.innerHTML=`
    <span class="item-num">${idx+1}.</span>
    <div class="item-thumb${local?' has-photo':''}" data-img="${item.id}" onclick="itemTap('${item.id}')" ${local?`style="background-image:url('${local}')"`:''}></div>
    <div class="item-body" onclick="itemTap('${item.id}')" style="cursor:pointer">
      <div class="item-name-text">${esc(item.name)}</div>
      <div class="item-sub">${fmtDate(item.expiry)}</div>
    </div>
    <span class="item-tag ${getTag(days)}">${daysLabel(days)}</span>
    <button class="item-edit-btn" onclick="openEdit('${item.id}')" title="Edit">${ic('pencil',15)}</button>
    <button class="item-del-btn" onclick="deleteItem('${item.id}')" title="Delete">${ic('trash',15)}</button>`;
  if(!local) hydrateImage(div.querySelector('.item-thumb'), item.id);  // pull from Storage
  attachSwipe(div, item.id);
  return div;
}
/* Swipe a row left to delete it (mobile); vertical drags fall through to scroll. */
function attachSwipe(el,id){
  let x0=0,y0=0,active=false,moved=0;
  el.addEventListener('touchstart',e=>{ x0=e.touches[0].clientX; y0=e.touches[0].clientY; active=true; moved=0; el.style.transition='none'; },{passive:true});
  el.addEventListener('touchmove',e=>{
    if(!active) return;
    const dx=e.touches[0].clientX-x0, dy=e.touches[0].clientY-y0;
    if(Math.abs(dy)>Math.abs(dx)+6){ active=false; el.style.transform=''; el.style.opacity=''; return; } // vertical → let it scroll
    moved=dx;
    if(dx<0){ el.style.transform='translateX('+Math.max(dx,-150)+'px)'; el.style.opacity=String(1+Math.max(dx,-150)/300); }
  },{passive:true});
  el.addEventListener('touchend',()=>{
    if(!active) return; active=false; el.style.transition='transform .2s, opacity .2s';
    if(Math.abs(moved)>8){ justSwiped=true; setTimeout(()=>justSwiped=false,400); }
    if(moved<-95){ el.style.transform='translateX(-110%)'; el.style.opacity='0'; setTimeout(()=>softDelete(id),160); }
    else { el.style.transform=''; el.style.opacity=''; }
  },{passive:true});
}

/* Tapping an Overview stat filters the list below; tapping the active one clears it. */
let dashFilter='all', dashItems={expired:[],soon:[],ok:[]};
function setDashFilter(f){ dashFilter = (dashFilter===f)?'all':f; renderDashList(); }
/* Tapping the top-bar count badge jumps to the dashboard's items-needing-attention. */
function showAttention(){ dashFilter='all'; switchTab('dashboard'); }
function renderDashList(){
  const list=document.getElementById('dashboard-list');
  const titleEl=document.getElementById('dash-list-title'); if(!list) return;
  const iconEl=document.getElementById('dash-list-icon');
  const cfg={
    expired:{arr:dashItems.expired, title:'Expired',       head:'triangle-alert', color:'var(--red)',    icon:'circle-check', empty:'Nothing expired'},
    soon:   {arr:dashItems.soon,    title:'Expiring Soon', head:'clock',          color:'var(--yellow)', icon:'circle-check', empty:'None due soon'},
    good:   {arr:dashItems.ok,      title:'Good',          head:'circle-check',   color:'var(--green)',  icon:'package',      empty:'No good items yet'},
    all:    {arr:[...dashItems.expired,...dashItems.soon], title:'Needs Attention', head:'triangle-alert', color:'var(--accent)', icon:'circle-check', empty:'All clear!<br/>Nothing expiring soon.'}
  }[dashFilter] || {arr:[],title:'Needs Attention',head:'triangle-alert',color:'var(--accent)',icon:'circle-check',empty:'—'};
  ['expired','soon','good'].forEach(k=>{ const el=document.getElementById('stat-'+k); if(el) el.classList.toggle('active', dashFilter===k); });
  if(titleEl) titleEl.textContent=cfg.title;
  if(iconEl){ iconEl.innerHTML=ic(cfg.head,18); iconEl.style.color=cfg.color; }
  const arr=cfg.arr.slice().sort((a,b)=>new Date(a.expiry)-new Date(b.expiry));
  const badge=document.getElementById('attention-badge');
  if(badge){ badge.textContent=arr.length; badge.style.display=arr.length>0?'inline':'none'; }
  list.innerHTML='';
  if(!arr.length){ list.innerHTML='<div class="empty"><div class="e-icon">'+ic(cfg.icon,26)+'</div><p>'+cfg.empty+'</p></div>'; }
  else arr.forEach((item,i)=>list.appendChild(buildItem(item,i)));
}
async function renderDashboard(){
  const dashList=document.getElementById('dashboard-list');
  const goodList=document.getElementById('good-list');
  dashList.innerHTML='<div class="empty"><div class="e-icon">⏳</div><p>Loading…</p></div>';
  if(goodList) goodList.innerHTML='<div class="empty"><div class="e-icon">⏳</div><p>Loading…</p></div>';

  // Today's date label
  const dateEl=document.getElementById('overview-date');
  if(dateEl) dateEl.textContent=new Date().toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'});

  const items=(await dbGetAll()).filter(i=>!pendingDeletes.has(i.id));
  const expired=items.filter(i=>daysUntil(i.expiry)<0);
  const soon   =items.filter(i=>{ const d=daysUntil(i.expiry); return d>=0&&d<=SOON_DAYS; });
  const ok     =items.filter(i=>daysUntil(i.expiry)>SOON_DAYS);

  document.getElementById('count-expired').textContent=expired.length;
  document.getElementById('count-soon').textContent=soon.length;
  document.getElementById('count-ok').textContent=ok.length;

  // Stat subtitles
  const subExp=document.getElementById('sub-expired');
  const subSoon=document.getElementById('sub-soon');
  const subOk=document.getElementById('sub-ok');
  if(subExp)  subExp.textContent  = expired.length===0?'Nothing expired':'Need disposal';
  if(subSoon) subSoon.textContent = soon.length===0?'None due soon':'Within '+SOON_DAYS+' days';
  if(subOk)   subOk.textContent   = ok.length===0?'Add items to track':'No action needed';

  // Alert badge
  const n=expired.length+soon.length;
  const badge=document.getElementById('alert-badge');
  badge.style.display=n>0?'inline':'none'; badge.textContent=n;

  // Attention badge
  const attBadge=document.getElementById('attention-badge');
  if(attBadge){ attBadge.style.display=n>0?'inline':'none'; attBadge.textContent=n; }

  // Good badge
  const goodBadge=document.getElementById('good-badge');
  if(goodBadge){ goodBadge.style.display=ok.length>0?'inline':'none'; goodBadge.textContent=ok.length; }

  // Needs Attention list (respects the tapped Overview filter)
  dashItems={expired,soon,ok};
  renderDashList();

  // All Good list
  if(goodList){
    goodList.innerHTML='';
    if(!ok.length){
      goodList.innerHTML='<div class="empty"><div class="e-icon">'+ic('package',26)+'</div><p>No items tracked yet.</p></div>';
    }else{
      ok.slice(0,8).forEach((item,i)=>goodList.appendChild(buildItem(item,i)));
    }
  }
}

let allItemsCache=[];
async function renderAll(){
  const list=document.getElementById('all-list');
  list.innerHTML='<div class="empty"><div class="e-icon">⏳</div><p>Loading…</p></div>';
  allItemsCache=await dbGetAll();
  filterAll();
}
/* All-Items sort mode, driven by the segmented control. */
let sortMode='expiry';
function setSort(m){
  sortMode=m;
  document.querySelectorAll('#sort-seg .sort-seg-btn').forEach(b=>b.classList.toggle('on', b.getAttribute('data-sort')===m));
  filterAll();
}
/* Render the All-Items list from cache, applying the search box + sort (no refetch). */
function filterAll(){
  const list=document.getElementById('all-list'); if(!list) return;
  let items=allItemsCache.filter(i=>!pendingDeletes.has(i.id));
  const q=(document.getElementById('search-input')?.value||'').trim().toLowerCase();
  if(q) items=items.filter(i=>(i.name||'').toLowerCase().includes(q));
  const sort=sortMode;
  items.sort((a,b)=>sort==='expiry'?new Date(a.expiry)-new Date(b.expiry):sort==='name'?a.name.localeCompare(b.name):new Date(b.added)-new Date(a.added));
  list.innerHTML='';
  if(!items.length){ list.innerHTML = q
    ? '<div class="empty"><div class="e-icon">'+ic('search',26)+'</div><p>No matches for “'+esc(q)+'”.</p></div>'
    : '<div class="empty"><div class="e-icon">'+ic('package',26)+'</div><p>No items yet.<br/>Use Scan or Add to begin.</p></div>'; }
  else items.forEach((item,i)=>list.appendChild(buildItem(item,i)));
}

/* Reusable styled confirmation dialog. */
let _confirmCb=null;
function confirmDialog(message, onConfirm, opts){
  opts=opts||{}; _confirmCb=onConfirm;
  document.getElementById('confirm-title').textContent=opts.title||'Are you sure?';
  document.getElementById('confirm-msg').textContent=message;
  const ok=document.getElementById('confirm-ok');
  ok.textContent=opts.confirmText||'Delete';
  ok.classList.toggle('danger', opts.danger!==false);
  document.getElementById('confirm-modal').classList.add('show');
}
function confirmYes(){ document.getElementById('confirm-modal').classList.remove('show'); const cb=_confirmCb; _confirmCb=null; if(cb)cb(); }
function confirmNo(){ document.getElementById('confirm-modal').classList.remove('show'); _confirmCb=null; }

function deleteItem(id){
  const item=itemMap[id]; const name=item?item.name:'this item';
  confirmDialog(`Delete "${name}"? This also removes its photos and can't be undone.`, async ()=>{
    await removeImage(id); await dbDelete(id); notify('🗑 Deleted'); renderDashboard(); renderAll();
  }, {title:'Delete item', confirmText:'Delete', danger:true});
}

/* ═══ SWIPE-TO-DELETE + UNDO ═══ (swipe = quick delete with a 5s undo window;
   the actual delete is deferred until the window closes, so Undo is instant) */
const pendingDeletes=new Set();
let undoItem=null, undoTimer=null, justSwiped=false;
function itemTap(id){ if(justSwiped) return; openLightbox(id); }
function refreshLists(){ renderDashboard(); if(typeof filterAll==='function') filterAll(); }
function softDelete(id){
  const item=itemMap[id]; if(!item) return;
  if(undoItem && undoItem.id!==id) commitDelete(undoItem.id);   // flush any previous pending delete
  clearTimeout(undoTimer);
  pendingDeletes.add(id); undoItem=item;
  refreshLists();
  document.getElementById('undo-text').textContent='Deleted "'+item.name+'"';
  document.getElementById('undo-bar').classList.add('show');
  undoTimer=setTimeout(()=>commitDelete(id),5000);
}
function undoDelete(){
  clearTimeout(undoTimer);
  document.getElementById('undo-bar').classList.remove('show');
  if(undoItem){ const id=undoItem.id; undoItem=null; pendingDeletes.delete(id); refreshLists(); }
}
async function commitDelete(id){
  clearTimeout(undoTimer);
  if(undoItem && undoItem.id===id){ undoItem=null; document.getElementById('undo-bar').classList.remove('show'); }
  if(!pendingDeletes.has(id)) return;
  await removeImage(id); await dbDelete(id);
  pendingDeletes.delete(id);
}
/* Wipe every product (and its photos) for the current account. */


/* ═══ SETTINGS PAGE ═══ */
function renderSettingsPage(){
  renderCardStyleToggle();
  const sr=document.getElementById('soon-range'), cr=document.getElementById('critical-range');
  if(sr){sr.value=SOON_DAYS;document.getElementById('soon-val').textContent=SOON_DAYS+'d';}
  if(cr){cr.max=SOON_DAYS;cr.value=CRITICAL_DAYS;document.getElementById('critical-val').textContent=CRITICAL_DAYS+'d';}
  const dev=document.getElementById('device-id-display'); if(dev) dev.textContent=DEVICE_ID;
  const em=document.getElementById('account-email'); if(em&&CURRENT_USER) em.textContent=CURRENT_USER.email||'';
  const rl=document.getElementById('account-role'); if(rl) rl.textContent=isAdmin()?'Administrator':'User';
  const umc=document.getElementById('user-mgmt-card');
  if(umc){ umc.style.display=isAdmin()?'':'none'; if(isAdmin()) adminLoadUsers(); }
  renderVisionKeyStatus();
  renderCatList();
  // Populate products textarea
  const ta=document.getElementById('products-textarea');
  if(ta){
    ta.value=PRODUCTS.join('\n');
    document.getElementById('product-count-label').textContent=PRODUCTS.length+' products in list';
  }
}

/* ═══ EXPORT (native .xlsx — no dependency, works offline) ═══ */
function crc32(bytes){
  let table=crc32.table;
  if(!table){ table=crc32.table=[]; for(let n=0;n<256;n++){ let c=n; for(let k=0;k<8;k++) c=c&1?0xEDB88320^(c>>>1):c>>>1; table[n]=c>>>0; } }
  let crc=0xFFFFFFFF;
  for(let i=0;i<bytes.length;i++) crc=(crc>>>8)^table[(crc^bytes[i])&0xFF];
  return (crc^0xFFFFFFFF)>>>0;
}
function zipStore(files){                       // uncompressed (stored) ZIP
  const enc=new TextEncoder(), chunks=[], central=[]; let offset=0;
  const u16=n=>[n&0xFF,(n>>>8)&0xFF];
  const u32=n=>[n&0xFF,(n>>>8)&0xFF,(n>>>16)&0xFF,(n>>>24)&0xFF];
  for(const f of files){
    const name=enc.encode(f.name), data=f.data, crc=crc32(data);
    const lfh=[].concat(u32(0x04034b50),u16(20),u16(0),u16(0),u16(0),u16(0),u32(crc),u32(data.length),u32(data.length),u16(name.length),u16(0));
    chunks.push(new Uint8Array(lfh),name,data);
    const local=offset; offset+=lfh.length+name.length+data.length;
    const cdh=[].concat(u32(0x02014b50),u16(20),u16(20),u16(0),u16(0),u16(0),u16(0),u32(crc),u32(data.length),u32(data.length),u16(name.length),u16(0),u16(0),u16(0),u16(0),u32(0),u32(local));
    central.push({header:new Uint8Array(cdh),name});
  }
  const cdStart=offset; let cdSize=0;
  for(const c of central){ chunks.push(c.header,c.name); cdSize+=c.header.length+c.name.length; }
  chunks.push(new Uint8Array([].concat(u32(0x06054b50),u16(0),u16(0),u16(central.length),u16(central.length),u32(cdSize),u32(cdStart),u16(0))));
  let total=0; for(const c of chunks) total+=c.length;
  const out=new Uint8Array(total); let p=0; for(const c of chunks){ out.set(c,p); p+=c.length; }
  return out;
}
function buildXlsx(rows, sheetName){
  const enc=new TextEncoder();
  const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  const col=n=>{ let s=''; n++; while(n>0){ const m=(n-1)%26; s=String.fromCharCode(65+m)+s; n=(n-m-1)/26; } return s; };
  let body='';
  rows.forEach((row,ri)=>{
    let cells='';
    row.forEach((val,ci)=>{
      const ref=col(ci)+(ri+1);
      if(typeof val==='number' && isFinite(val)) cells+=`<c r="${ref}"><v>${val}</v></c>`;
      else cells+=`<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${esc(val==null?'':val)}</t></is></c>`;
    });
    body+=`<row r="${ri+1}">${cells}</row>`;
  });
  const sheet=`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${body}</sheetData></worksheet>`;
  const safe=esc((sheetName||'Sheet1').replace(/[\\\/\?\*\[\]:]/g,' ').slice(0,31));
  const files=[
    {name:'[Content_Types].xml', data:enc.encode(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>`)},
    {name:'_rels/.rels', data:enc.encode(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`)},
    {name:'xl/workbook.xml', data:enc.encode(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${safe}" sheetId="1" r:id="rId1"/></sheets></workbook>`)},
    {name:'xl/_rels/workbook.xml.rels', data:enc.encode(`<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`)},
    {name:'xl/worksheets/sheet1.xml', data:enc.encode(sheet)},
  ];
  return zipStore(files);
}

async function exportToExcel(){
 try{
  const st=document.getElementById('export-status');
  if(st){ st.style.color='var(--text-2)'; st.textContent='Preparing…'; }
  const items=await dbGetAll();
  if(!items.length){ if(st){st.style.color='#dc2626';st.textContent='No items to export.';} notify('Nothing to export'); return; }
  const rows=[['#','Product','Expiry Date','Days Left','Status','Added On']];
  items.forEach((it,i)=>{
    const d=daysUntil(it.expiry);
    const status=d<0?'Expired':(d<=SOON_DAYS?'Expiring Soon':'Good');
    rows.push([ i+1, it.name||'', it.expiry||'', d, status, (it.added||'').split('T')[0] ]);
  });
  const blob=buildCsv(rows);
  await downloadBlob(blob, 'expiry-tracker-'+new Date().toISOString().split('T')[0]+'.csv');
  if(st){ st.style.color='var(--green)'; st.textContent='✓ Exported '+items.length+' items.'; }
  notify('📥 Exported '+items.length+' items');
 }catch(e){const status=document.getElementById('export-status');if(status)status.textContent=e.message;notify(e.message);}
}

function startCamera(){
 document.getElementById('video').style.display='none';document.getElementById('scan-overlay').style.display='none';document.getElementById('scan-hint').textContent='Tap Capture to open the iPhone camera. Enter dates manually if needed.';document.getElementById('capture-btn').style.display='flex';document.getElementById('retake-btn').style.display='none';
}
function stopCamera(){}
let nativeCameraBusy=false;
async function capturePhoto(){
 if(nativeCameraBusy)return;nativeCameraBusy=true;capturedThumb=null;resetFullPhoto();document.getElementById('scan-name').value='';document.getElementById('scan-date').value='';dateCands=[];renderDateChoices('');document.getElementById('preview-img').style.display='none';const btn=document.getElementById('capture-btn');btn.disabled=true;
 try{const result=await Native.call('camera',{purpose:'expiry'});if(!/^data:image\/jpeg;base64,/.test(result?.image||''))throw Error('Native camera returned no JPEG image.');
 const img=new Image();await new Promise((resolve,reject)=>{img.onload=resolve;img.onerror=()=>reject(Error('Unable to read camera photo'));img.src=result.image;});
 const c=document.getElementById('canvas');c.width=img.width;c.height=img.height;c.getContext('2d').drawImage(img,0,0);capturedThumb=getThumbnail(c);const preview=document.getElementById('preview-img');preview.src=result.image;preview.style.display='block';btn.style.display='none';document.getElementById('retake-btn').style.display='flex';await runOCR(c);
 }catch(e){notify(e.message);document.getElementById('add-form').classList.add('show');document.getElementById('ocr-text').textContent=e.message+' — enter details manually.';}finally{nativeCameraBusy=false;btn.disabled=false;}
}
function retakePhoto(){capturedThumb=null;document.getElementById('add-form').classList.remove('show');document.getElementById('ocr-status').classList.remove('show');capturePhoto();}
async function openBarcodeScanner(targetInputId){
 try{const result=await Native.call('camera',{purpose:'barcode'});if(typeof result?.barcode!=='string'||!result.barcode)throw Error('No barcode returned. Enter the product name manually.');const input=document.getElementById(targetInputId||'manual-name');if(input&&!input.value)input.value=result.barcode;notify('Barcode '+result.barcode+' — enter the product name (online lookup is disabled).');}catch(e){notify(e.message);}
}
/* Mobile adapters: original screen/render logic above stays intact. */
function saveImageLocally(id,data){Mobile.photos[id]=data;return Mobile.write(()=>Mobile.store.put('photos',id,data));}
function getImageLocally(id){return Mobile.photos[id]||null;}
function deleteImageLocally(id){delete Mobile.photos[id];return Mobile.write(()=>Mobile.store.remove('photos',id));}
async function uploadImage(id,data,full){
 await saveImageLocally(imgKey(id,full),data);
 if(Mobile.mode==='local')return;
 const {error}=await sb.storage.from(IMG_BUCKET).upload(imagePath(id,full),dataURLtoBlob(data),{upsert:true,contentType:'image/jpeg'});
 if(error)throw Error('Photo kept on this device; cloud upload failed: '+error.message);
}
async function fetchImage(id,full){
 const key=imgKey(id,full);if(Mobile.photos[key])return Mobile.photos[key];if(Mobile.mode==='local')return null;
 const {data,error}=await sb.storage.from(IMG_BUCKET).download(imagePath(id,full));
 if(error){if(String(error.statusCode)==='404')return null;throw Error('Cloud photo download failed: '+error.message);}
 if(!data)return null;const url=await blobToDataURL(data);await saveImageLocally(key,url);return url;
}
async function removeImage(id){
 if(Mobile.mode==='cloud'){const {error}=await sb.storage.from(IMG_BUCKET).remove([imagePath(id,false),imagePath(id,true)]);if(error)throw error;}
 await deleteImageLocally(String(id));await deleteImageLocally(id+'_full');
}
async function clearLocalImages(){
 if(Mobile.mode==='local'){notify('Local photos are originals, not a cache. Delete an item to remove its photos.');return;}
 for(const id of Object.keys(Mobile.photos))await deleteImageLocally(id);notify('Cloud photo cache cleared for this account');
}
async function dbGetAll(){
 if(Mobile.mode==='local')return (await Mobile.store.all('items')).sort((a,b)=>a.expiry.localeCompare(b.expiry));
 if(!CURRENT_USER)throw Error('Sign in to your cloud account first.');
 const {data,error}=await sb.from('items').select('*').eq('user_id',CURRENT_USER.id).order('expiry',{ascending:true});if(error)throw Error('Cloud read failed: '+error.message);setSyncing(false);return data||[];
}
async function dbAdd(item){
 try{if(Mobile.mode==='local'){const data={...item,id:crypto.randomUUID()};await Mobile.store.put('items',data.id,data);return data;}
 const {data,error}=await sb.from('items').insert([{...item,user_id:CURRENT_USER.id,device_id:DEVICE_ID}]).select().single();if(error)throw error;return data;
 }catch(e){notify('Item was not saved: '+e.message);return null;}
}
async function dbUpdate(id,fields){
 try{if(Mobile.mode==='local'){const old=await Mobile.store.get('items',id);if(!old)throw Error('Item not found');const data={...old,...fields};await Mobile.store.put('items',id,data);return data;}
 const {data,error}=await sb.from('items').update(fields).eq('id',id).eq('user_id',CURRENT_USER.id).select().single();if(error)throw error;return data;
 }catch(e){notify('Changes were not saved: '+e.message);return null;}
}
async function dbDelete(id){
 if(Mobile.mode==='local'){await Mobile.store.remove('items',id);return;}
 const {error}=await sb.from('items').delete().eq('id',id).eq('user_id',CURRENT_USER.id);if(error)throw Error('Delete failed: '+error.message);
}
function setSyncing(on){const el=document.getElementById('sync-label');el.textContent=Mobile.mode==='local'?'On this iPhone · offline storage':on?'Syncing…':'Cloud account · refreshed';}
async function clearAllItems(){
 const items=await dbGetAll();confirmDialog('Permanently delete all items and photos in this storage mode?',async()=>{for(const i of items){await removeImage(i.id);await dbDelete(i.id);}await refresh();notify('Items deleted');},{title:'Clear products',confirmText:'Delete all'});
}
async function initAuth(){if(Mobile.mode==='local'){document.getElementById('app').style.display='flex';setSyncing(false);await refresh();return;}applySession(Mobile.session);}
function applySession(session){
 const user=session?.user;if((user?.id||null)!==(Mobile.session?.user?.id||null)){location.reload();return;}
 CURRENT_USER=user||null;document.getElementById('login-page').style.display=user?'none':'flex';document.getElementById('app').style.display=user?'flex':'none';if(user)refresh();
}
async function doLogin(){
 const el=document.getElementById('login-error'),btn=document.getElementById('login-btn');btn.disabled=true;el.textContent='';
 try{const {error}=await sb.auth.signInWithPassword({email:document.getElementById('login-email').value.trim(),password:document.getElementById('login-pass').value});if(error)throw error;location.reload();}catch(e){el.textContent='Sign-in failed: '+e.message;}finally{btn.disabled=false;}
}
async function doLogout(){const {error}=await sb.auth.signOut();if(error)throw error;location.reload();}
function buildCsv(rows){
 // Quote every cell (commas, quotes and embedded newlines); neutralize spreadsheet formulas.
 const cell=value=>{let text=String(value??'');if(typeof value==='string'&&/^[\s\u0000-\u001f]*[=+@-]|^[\t\r\n]/.test(text))text="'"+text;return '"'+text.replaceAll('"','""')+'"';};
 return new Blob(['\ufeff'+rows.map(row=>row.map(cell).join(',')).join('\r\n')+'\r\n'],{type:'text/csv;charset=utf-8'});
}
async function downloadBlob(blob,name){const data=await Mobile.base64(blob);const r=await Native.call('export',{name,data});if(!r?.completed)throw Error('Export cancelled — no file was saved.');}

/* ═══ INIT ═══ */

renderDatalist();
renderCategoryPicker('scan');
renderCategoryPicker('manual');
document.getElementById('manual-date').value=new Date().toISOString().split('T')[0];
renderIcons();       // fill static [data-ic] elements with Lucide line icons
Mobile.start();
