#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/01/05
 * @version 2.0
 ***********************************************************************/
#Include <Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
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
        if Type(Elements["line"]) != "Array" or Type(Elements["headers"]) != "Map"
            throw TypeError()
        msg := ""
        line := Format("{1} {2} {3}", Elements["line"]*)
        headers := ""

        for k, v in Elements["headers"] {
            headers .= Format("{1}: {2}`r`n", k, v)
        }
        if Type(Elements["body"]) = "Buffer" {
            msg := Format("{1}`r`n{2}`r`n", line, headers)
        } else {
            msg := Format("{1}`r`n{2}`r`n{3}", line, headers, Elements["body"])
        }
        return msg
    }
    static LoadMimes(File) {
        FileConent := FileRead(File)
        MimeType := Map()
        MimeType.CaseSense := false
        for i in StrSplit(FileConent, "`n") {
            Types := SubStr(i, 1, InStr(i, A_Space) - 1)
            i := StrReplace(i, Types)
            i := LTrim(i)
            for i in StrSplit(i, A_Space) {
                MimeType[i] := Types
            }
        }
        return MimeType
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
        this.GetQueryArgs := Map()
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
            this.Line.Url := SubStr(Url, 1, pos - 1)
            QueryArgs := StrSplit(QueryArgs, ["&", "="])
            for i in QueryArgs {
                if InStr(i, "%") {
                    QueryArgs[A_Index] := HTTP.UrlUnescape(i)
                }
            }
            this.GetQueryArgs := temp := Map(QueryArgs*)
        }
    }
    ; 生成请求
    Generate(Method := this.Line.Method, Url := this.Line.Url, Headers := this.Headers, Body := this.Body) {
        Method := StrUpper(Method)
        if Method = "GET" and this.GetQueryArgs.Count > 0 {
            Url .= "?"
            for k, v in this.GetQueryArgs {
                k := HTTP.UrlEncode(k)
                v := HTTP.UrlEncode(v)
                Url .= (A_Index < this.GetQueryArgs.Count) ? k "=" v "&" : k "=" v
            }
        }
        ReqMap := Map("line", [Method, Url, this.Line.Protocol], "headers", Headers, "body", Body)
        return this.Request := HTTP.GenerateMessage(ReqMap)
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

        if not Headers.Has("Content-Length") {
            if Type(Body) = "Buffer" {
                Headers["Content-Length"] := Body.size
            }
            if not IsObject(Body) {
                Headers["Content-Length"] := HTTP.GetStrSize(Body)
            }
        }
        Headers["Content-Length"] := Headers["Content-Length"]
        if not Headers.Has("Content-Type") {
            Headers["Content-Type"] := "text/plain"
        }
        Headers["Server"] := "AutoHotkey/" A_AhkVersion

        ResMap := Map("line", [Line, sCode, sMsg], "headers", Headers, "body", Body)
        return this.Response := HTTP.GenerateMessage(ResMap)
    }
}
class HttpServer extends Socket.Server {
    Path := Map()
    req := Request()
    res := Response()
    SetMimeType(file){
        if not FileExist(file) {
            throw TargetError
        }
        this.MimeType := HTTP.LoadMimes(file)
    }
    SetPaths(paths) {
        if not Type(paths) = "Map"
            throw TypeError()
        this.Path := paths
    }
    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(SocketServer, err) {
            this.ParseRequest(SocketServer.RecvText())
            this.GenerateResponse(SocketServer)
        }
    }
    ; 解析请求
    ParseRequest(msg) {
        this.req.Parse(msg)
        if this.Path.Has(this.req.Line.Url) {
            this.res.__New()
            this.Path[this.req.Line.Url](this.req, this.res)
        } else {
            this.res.sCode := 404
            this.res.sMsg := "Not Found"
            this.res.Body := "404 Not Found"
        }
    }
    SetBodyText(str) {
        this.res.Headers["Content-Length"] := HTTP.GetStrSize(str)
        this.res.Headers["Content-Type"] := "text/plain"
        this.res.Body := str
    }
    SetBodyFile(file) {
        if !FileExist(file)
            return false
        buffobj := FileRead(file, "Raw")
        this.res.Headers["Content-Length"] := buffobj.size
        SplitPath(file, , , &ext)
        this.MimeType.Has(ext)
            ? this.res.Headers["Content-Type"] := this.MimeType[ext]
            : this.res.Headers["Content-Type"] := "text/plain"
        this.res.Body := buffobj
    }
    ; 生成响应
    GenerateResponse(Socket) {
        if this.req.Line.Method = "HEAD" {
            this.res.Body := ""
        }
        if Type(this.res.Body) = "Buffer" {
            this.res.Headers["Content-Length"] := this.res.Body.size
            Socket.SendText(this.res.Generate())
            Socket.Send(this.res.Body)
        } else {
            Socket.SendText(this.res.Generate())
        }
        if this.req.Line.Url = "/debug"{
            OutputDebug this.req.Request
            OutputDebug this.res.Response
        }
    }
}
; class Client {

; }

#Include <print>