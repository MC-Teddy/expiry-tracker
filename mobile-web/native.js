(()=>{
 const pending=new Map();
 window.nativeReply=(id,result,error)=>{const p=pending.get(id);if(!p)return;pending.delete(id);clearTimeout(p.timer);error?p.reject(Error(typeof error==='string'?error:JSON.stringify(error))):p.resolve(result);};
 window.Native={call(action,payload={}){return new Promise((resolve,reject)=>{
  const host=window.webkit?.messageHandlers?.native;if(!host){reject(Error('This action requires the iPhone app native bridge.'));return;}
  const id=crypto.randomUUID(),timer=setTimeout(()=>{pending.delete(id);reject(Error('Native '+action+' timed out. Please retry.'));},120000);
  pending.set(id,{resolve,reject,timer});try{host.postMessage({...payload,id,action});}catch(e){window.nativeReply(id,null,e.message);}
 });}};
})();
