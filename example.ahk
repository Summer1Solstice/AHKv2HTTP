#Requires AutoHotkey v2.0
Persistent
#Include HTTP.ahk
path := Map()
path["/"] := root
path["/logo"] := logo
path["/hi"] := HelloWorld
path["/echo"] := echo

Server := HttpServer(10000)
Server.SetPaths(path)
Server.LoadMimeType("mimetypes")
Server.Web := true	; 是否开启web服务
Server.onFunc["isIPAllow"] := IPAudit
IPAudit(ip) {
    static AllowIP := Map("127.0.0.1", true, "::1", true)   ; 允许的IP
    if AllowIP.Has(ip) {
        return true
    } else {
        ip := StrSplit(ip, ".")
        if ip[1] = 192 and ip[2] = 168 {
            return true
        }
        if ip[1] = 172 and (ip[2] > 15 and ip[2] < 32) {
            return true
        }
    }
}
Server.onFunc["PreHandleReq"] := (req, res) => (OutputDebug(req.Headers.Get("X-Real-Ip", "")), 0)
Server.onFunc["PreSendRes"] := (*) => (0)
root(req, res) {
    res.Body := "Hello World!(TestVersion)"
}
HelloWorld(req, res) {
    if Server.web and InStr(req.Headers.Get("User-Agent", 0), "Chrome") {
        res.SetBodyFile(".\index.html")
    } else {
        res.SetBodyText("Hello World!(TestVersion)")
    }
}
logo(req, res) {
    res.SetBodyFile("logo.png")
}
echo(req, res) {
    res.SetBodyText(req.Request)
}
#Include <XZ\GetHash>
Server.Path["/hash"] := hash
hash(req, res) {
    OutputDebug req.Headers["hash"] "`n"
    md5 := md5sum(req.Body)
    OutputDebug md5 "`n"
    if req.Headers["hash"] = md5 {
        OutputDebug "Yes`n"
        res.SetBodyText("Yes`n")
    } else {
        OutputDebug "No`n"
        res.SetBodyText("No`n")
    }
}