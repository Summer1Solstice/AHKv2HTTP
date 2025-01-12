#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/01/05
 * @version 2.0
 ***********************************************************************/
class HTTP {
    ; 获取字符串字节长度
    static GetStrSize(str, encoding := "UTF-8") {
        ; https://github.com/zhamlin/AHKhttp/blob/c6267f67d4a3145c352c281bb58e610bcf9e9d77/AHKhttp.ahk#L323-L327
        encodingSize := ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
        return StrPut(str, encoding) * encodingSize - encodingSize
    }
    ; URL编码
    static UrlEncode(url, component := false) {
        ; https://github.com/thqby/ahk2_lib/blob/master/UrlEncode.ahk
        flag := component ? 0xc2000 : 0xc0000
        DllCall('shlwapi\UrlEscape', 'str', url, 'ptr*', 0, 'uint*', &len := 1, 'uint', flag)
        DllCall('shlwapi\UrlEscape', 'str', url, 'ptr', buf := Buffer(len << 1), 'uint*', &len, 'uint', flag)
        return StrGet(buf)
    }
    ; URL解码
    static UrlUnescape(i) {
        ; https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/HttpServer.ahk#L473-L484
        DllCall('shlwapi\UrlUnescape', 'str', i, 'ptr', 0, 'uint*', 0, 'uint', 0x140000)
        return i
    }
    ; 消息解析
    static ParseMessage(msg) {
        MessageMap := Map()
        LineEndPos := InStr(msg, "`r`n")
        BodyStartPos := InStr(msg, "`r`n`r`n")
        MessageMap["line"] := StrSplit(SubStr(msg, 1, LineEndPos - 1), A_Space)
        MessageMap["headers"] := Map()
        Headers := StrSplit(SubStr(msg, LineEndPos + 3, BodyStartPos - LineEndPos - 3), ["`r`n", ": "])
        MessageMap["headers"].Set(Headers*)
        MessageMap["body"] := SubStr(msg, BodyStartPos + 4)
        return MessageMap
    }
    ; 消息拼装
    static GenerateMessage(Elements) {
        if Type(Elements) != "Map"
            throw TypeError()
        if !Elements.Has("line") or !Elements.Has("headers") or !Elements.Has("body")
            throw UnsetError()
        if Type(Elements["line"]) != "Array" or Type(Elements["headers"]) != "Map" or Type(Elements["body"]) != "String"
            throw TypeError()
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
; 请求类
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
    ; 解析请求
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
        }
    }
    ; 生成请求
    Generate(Method := this.Line.Method, Url := this.Line.Url, Headers := this.Headers, Body := this.Body) {
        Method := StrUpper(Method)
        if Method = "GET" and this.GETQueryArgs.Count > 0 {
            Url .= "?"
            for k, v in this.GETQueryArgs {
                k := HTTP.UrlEncode(k)
                v := HTTP.UrlEncode(v)
                Url .= (A_Index < this.GETQueryArgs.Count) ? k "=" v "&" : k "=" v
            }
        }
        this.Request := ReqMap := Map("line", [Method, Url, this.Line.Protocol], "headers", Headers, "body", Body)
        return HTTP.GenerateMessage(ReqMap)
    }
}
; 响应类
class Response extends HTTP {
    __New() {
        this.Response := ""
        this.Line := "HTTP/1.1"
        this.sCode := 200
        this.sMsg := "OK"
        this.Headers := Map()
        this.Body := ""
    }
    ; 解析响应
    Parse(ResMsg) {
        this.Response := ResMsg
        MessageMap := HTTP.ParseMessage(ResMsg)
        this.Line := MessageMap["line"][1]
        this.sCode := MessageMap["line"][2]
        this.sMsg := MessageMap["line"][3]
        this.Headers := MessageMap["headers"]
        this.Body := MessageMap.Get("body", "")
    }
    ; 生成响应
    Generate(sCode := this.sCode, sMsg := this.sMsg, Headers := this.Headers, Body := this.Body) {
        Line := this.Line
        this.Response := ResMap := Map("line", [Line, sCode, sMsg], "headers", Headers, "body", Body)
        return HTTP.GenerateMessage(ResMap)
    }
}
class Server {
    __New(path) {
        this.path := path
    }
    req := Request()
    res := Response()
    ; 解析请求
    ParseRequest(msg) {
        this.req.Parse(msg)
        if this.path.Has(this.req.Line.Url) {
            this.path[this.req.Line.Url](this.req, this.res)
        }
    }
    ; 生成响应
    GenerateResponse() {
        if this.req.Line.Method = "HEAD" {
            this.res.Headers["Content-Length"] := HTTP.GetStrSize(this.res.Body)
            this.res.Body := ""
        }
        if this.path.Has(this.req.Line.Url) {
            return this.res.Generate()
        } else {
            return this.res.Generate(404, "Not Found", unset, "404 Not Found")
        }
    }
}
; class Client {

; }

#Include <print>