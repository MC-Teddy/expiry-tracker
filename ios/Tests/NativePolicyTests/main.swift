import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    checks += 1
    if !condition() { fatalError("FAIL: \(label)") }
}
func rejects(_ label: String, _ block: () throws -> Void) {
    checks += 1
    do { try block(); fatalError("FAIL: \(label)") } catch {}
}
let host = "https://viupqrjyszvvcpnxrmsq.supabase.co"
check(NativePolicy.allowedURL(host + "/rest/v1/items"), "exact HTTPS endpoint")
for url in ["http://viupqrjyszvvcpnxrmsq.supabase.co/rest/v1/x", host + ".evil/rest/v1/x", host + ":444/rest/v1/x", host + "/anything", host + "/rest/v1/../private", host + "/rest/v1/%2e%2e/private", "https://x@viupqrjyszvvcpnxrmsq.supabase.co/rest/v1/x"] {
    check(!NativePolicy.allowedURL(url), "reject destination \(url)")
}
let bytes = Data([0, 255, 128, 13, 10])
let payload: [String: Any] = ["url":host + "/storage/v1/object/items/x", "method":"POST", "headers":["Authorization":"Bearer example", "Content-Type":"image/jpeg"], "body":bytes.base64EncodedString()]
let request = try NativePolicy.request(payload, cloud:true)
check(request.httpMethod == "POST" && request.httpBody == bytes, "binary request preserved")
check(request.value(forHTTPHeaderField:"Authorization") == "Bearer example", "auth preserved")
rejects("local blocks native network") { _ = try NativePolicy.request(payload, cloud:false) }
for update: [String: Any] in [["method":"TRACE"], ["headers":["Host":"evil"]], ["headers":["Authorization":"bad\r\nX-Evil: true"]], ["body":"%%%"], ["body":Data(repeating:0, count:NativePolicy.limit + 1).base64EncodedString()]] {
    rejects("invalid request") { _ = try NativePolicy.request(payload.merging(update) { _, new in new }, cloud:true) }
}
for name in ["expiry-backup_2026.json", "report.csv"] { check(NativePolicy.exportName(name), "safe export") }
for name in ["../a.json", "a/b.csv", ".json", "a.exe", "a.json.exe", "a\\b.csv", "a\n.csv", String(repeating:"a", count:121) + ".json"] { check(!NativePolicy.exportName(name), "unsafe export") }
let response = try NativePolicy.response(status:403, headers:["Content-Type":"application/octet-stream", "Set-Cookie":"secret"], data:bytes, error:nil)
check(response["status"] as? Int == 403 && response["body"] as? String == bytes.base64EncodedString(), "binary error HTTP response")
check((response["headers"] as? [String:String])?["Set-Cookie"] == nil, "no response cookies")
rejects("response plus transport error rejects") { _ = try NativePolicy.response(status:200, headers:[:], data:bytes, error:URLError(.networkConnectionLost)) }
rejects("oversized response rejects") { _ = try NativePolicy.response(status:200, headers:[:], data:Data(repeating:0, count:NativePolicy.limit + 1), error:nil) }
var calls = 0
var shot: OneShot<String?>!
shot = OneShot { value in calls += 1; check(value == "answer", "prompt value"); shot.finish("reentered") }
shot.finish("answer")
shot.finish(nil)
check(calls == 1, "prompt callback consumed exactly once including re-entry")
let entry = URL(fileURLWithPath:"/bundle/Web/index.html")
check(NativePolicy.trustedDocument(entry, entry:entry, mainFrame:true), "trusted bundle main document")
for (url, main) in [(entry,false), (URL(fileURLWithPath:"/other/index.html"),true), (URL(string:host + "/rest/v1/x")!,true)] {
    check(!NativePolicy.trustedDocument(url, entry:entry, mainFrame:main), "reject foreign caller or child frame")
}
check(NativePolicy.cameraPurpose("expiry"), "expiry native camera")
check(NativePolicy.cameraPurpose("barcode"), "barcode native camera")
check(!NativePolicy.cameraPurpose("microphone"), "unknown capture purpose denied")
var cancelCount = 0
let cancelled = OneShot<String?> { value in check(value == nil, "camera/prompt cancel value"); cancelCount += 1 }
cancelled.finish(nil); cancelled.finish("late photo")
check(cancelCount == 1, "capture cancel ignores late completion")
check(NativePolicy.cloudMode("cloud"), "trusted cloud storage value")
for value: Any? in [nil, NSNull(), "local", "CLOUD", true, 1, "", "cloud "] { check(!NativePolicy.cloudMode(value), "missing/invalid/local storage blocks network") }
print("PASS: \(checks) policy checks")
