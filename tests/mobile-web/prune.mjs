import {parse} from 'acorn';
import {readFileSync,writeFileSync} from 'node:fs';
const file=new URL('../../mobile-web/app.js',import.meta.url);let source=readFileSync(file,'utf8');
const functions=parse(source,{ecmaVersion:'latest',sourceType:'script'}).body.filter(n=>n.type==='FunctionDeclaration');
const last=new Map(functions.map(n=>[n.id.name,n]));const obsolete=functions.filter(n=>last.get(n.id.name)!==n).sort((a,b)=>b.start-a.start);
for(const n of obsolete)source=source.slice(0,n.start)+source.slice(n.end);
source=source.replace('/* On-device OCR via the reused Tesseract worker. */','/* On-device OCR via Apple Vision. */');
writeFileSync(file,source);console.log('Removed '+obsolete.length+' replaced website functions from mobile bundle');
