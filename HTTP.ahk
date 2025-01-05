#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/01/05
 * @version 2.0
 ***********************************************************************/
class HTTP {
    ; https://github.com/zhamlin/AHKhttp/blob/c6267f67d4a3145c352c281bb58e610bcf9e9d77/AHKhttp.ahk#L323-L327
    static GetStrSize(str, encoding := "UTF-8") {
        encodingSize := ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
        return StrPut(str, encoding) * encodingSize - encodingSize
    }
    ; https://github.com/thqby/ahk2_lib/blob/master/UrlEncode.ahk
    static UrlEncode(url, component := false) {
        flag := component ? 0xc2000 : 0xc0000
        DllCall('shlwapi\UrlEscape', 'str', url, 'ptr*', 0, 'uint*', &len := 1, 'uint', flag)
        DllCall('shlwapi\UrlEscape', 'str', url, 'ptr', buf := Buffer(len << 1), 'uint*', &len, 'uint', flag)
        return StrGet(buf)
    }
    ; https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/HttpServer.ahk#L473-L484
    static UrlUnescape(i) {
        DllCall('shlwapi\UrlUnescape', 'str', i, 'ptr', 0, 'uint*', 0, 'uint', 0x140000)
        return i
    }
    static ParseMessage(msg) {
        MessageMap := Map()
        LineEndPos := InStr(msg, "`r`n")
        BobyStartPos := InStr(msg, "`r`n`r`n")
        MessageMap["line"] := StrSplit(SubStr(msg, 1, LineEndPos - 1), A_Space)
        MessageMap["headers"] := Map()
        Headers := StrSplit(SubStr(msg, LineEndPos + 3, BobyStartPos - LineEndPos - 3), ["`r`n", ": "])
        MessageMap["headers"].Set(Headers*)
        MessageMap["boby"] := SubStr(msg, BobyStartPos + 4)
        return MessageMap
    }
    static GenerateMessage(Elements) {
        msg := ""
        line := Format("{1} {2} {3}", Elements["line"]*)
        headers := ""
        Elements["headers"].Has("Content-Length")
            ? Elements["headers"]["Content-Length"] := Elements["headers"]["Content-Length"]
            : Elements["headers"]["Content-Length"] := HTTP.GetStrSize(Elements["body"])
        Elements["headers"]["Server"] := "AutoHotkey/" A_AhkVersion
        for k, v in Elements["headers"] {
            headers .= Format("{1}: {2}`r`n", k, v)
        }
        return Format("{1}`r`n{2}`r`n{3}", line, headers, Elements["body"])
    }
}
class Request extends HTTP {
    __New() {
        this.Request := ""
        this.Line := {}
        this.Line.Method := ""
        this.Line.Url := ""
        this.Line.Protocol := "HTTP/1.1"
        this.Headers := Map()
        this.Body := ""
        this.GETQueryArgs := Map()
    }
    Parse(ReqMsg) {
        this.Request := ReqMsg
        MessageMap := HTTP.ParseMessage(ReqMsg)
        this.Line.Method := Method := MessageMap["line"][1]
        this.Line.Url := Url := MessageMap["line"][2]
        this.Line.Protocol := MessageMap["line"][3]
        this.Headers := MessageMap["headers"]
        this.Body := MessageMap.Get("body", "")
        if Method = "GET" and InStr(Url, "?") {
            pos := InStr(Url, "?")
            QueryArgs := SubStr(Url, pos + 1)
            this.Line.url := SubStr(Url, 1, pos - 1)
            QueryArgs := StrSplit(QueryArgs, ["&", "="])
            for i in QueryArgs {
                if InStr(i, "%") {
                    QueryArgs[A_Index] := HTTP.UrlUnescape(i)
                }
            }
            this.GETQueryArgs.Set(QueryArgs*)
            print this.GETQueryArgs
        }
    }
    Generate(Method := this.Line.Method, Url := this.Line.Url, Headers := this.Headers, Body := this.Body) {
        if Method = "GET" and this.GETQueryArgs.Count > 0 {
            Url .= "?"
            for k, v in this.GETQueryArgs {
                k := HTTP.UrlEncode(k)
                v := HTTP.UrlEncode(v)
                Url .= (A_Index < this.GETQueryArgs.Count) ? k "=" v "&" : k "=" v
            }
        }
        ReqMap := Map("line", [Method, Url, this.Line.Protocol], "headers", Headers, "body", Body)
        return HTTP.GenerateMessage(ReqMap)
    }
}
class Response extends HTTP {
    __New() {
        this.Request := ""
        this.Line := "HTTP/1.1"
        this.sCode := 200
        this.sMsg := "OK"
        this.Headers := Map()
        this.Body := ""
    }
    Parse(ResMsg) {
        this.Request := ResMsg
        MessageMap := HTTP.ParseMessage(ResMsg)
        this.Line := MessageMap["line"][1]
        this.sCode := MessageMap["line"][2]
        this.sMsg := MessageMap["line"][3]
        this.Headers := MessageMap["headers"]
        this.Body := MessageMap.Get("body", "")
    }
    Generate(sCode := this.sCode, sMsg := this.sMsg, Headers := this.Headers, Body := this.Body) {
        Line := this.Line
        ResMap := Map("line", [Line, sCode, sMsg], "headers", Headers, "body", Body)
        return HTTP.GenerateMessage(ResMap)
    }
}
class Server {
    __New(path) {
        this.path := path
    }
    req := Request()
    res := Response()

    ParseRequest(msg) {
        this.req.Parse(msg)
        if this.path.Has(this.req.Line.Url) {
            this.path[this.req.Line.Url](this.req, this.res)
        }
    }
    GenerateResponse() {
        if this.req.Line.Method = "HEAD" {
            this.res.Headers["Content-Length"] := HTTP.GetStrSize(this.res.Body)
            this.res.Body := ""
        }
        return this.res.Generate()
    }
}
; class Client {
    
; }

#Include <print>