const ORIGIN='https://viupqrjyszvvcpnxrmsq.supabase.co';
export function makeNativeFetch(mode,call){return async(input,init)=>{
 if(mode!=='cloud')throw Error('Networking is disabled in local mode');
 const request=new Request(input,init);if(new URL(request.url).origin!==ORIGIN)throw Error('Network destination not permitted');request.signal.throwIfAborted();
 let body=null;if(!['GET','HEAD'].includes(request.method)){const bytes=new Uint8Array(await request.arrayBuffer());let binary='';for(let i=0;i<bytes.length;i+=32768)binary+=String.fromCharCode(...bytes.subarray(i,i+32768));body=btoa(binary);}
 const result=await call('request',{url:request.url,method:request.method,headers:Object.fromEntries(request.headers.entries()),body});request.signal.throwIfAborted();
 const bytes=Uint8Array.from(atob(result.body||''),c=>c.charCodeAt(0));return new Response([204,205,304].includes(result.status)?null:bytes,{status:result.status,headers:result.headers});
};}
