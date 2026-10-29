// Never retarget an already initialized account's in-memory data/cache.
export function watchAccount(client,initialUserId,reload){
 return client.auth.onAuthStateChange((_event,session)=>{if((session?.user?.id||null)!==(initialUserId||null))reload();});
}
