#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/01/23
 * @version 2.14
 ***********************************************************************/
#Include <Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
;@region HTTP
class HTTP {
    ; 获取字符串字节长度
    static GetStrSize(str, encoding := "UTF-8") {
        return StrPut(str, encoding) - ((encoding = "UTF-16" or encoding = "CP1200") ? 2 : 1)
    }
    static GetBodySize(Body) {
        if Type(Body) = "Buffer" {
            return Body.size
        } else {
            return HTTP.GetStrSize(Body)
        }
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
    static LoadMimes(File) {    ;考虑优化为JSON
        FileConent := FileRead(File, "`n")
        MimeType := Map()
        MimeType.CaseSense := false
        if InStr(FileConent, ": ") {
            for i in StrSplit(FileConent, "`n") {
                i := StrSplit(i, ": ")
                MimeType.Set(i*)
            }
        } else {
            for i in StrSplit(FileConent, "`n") {
                Types := SubStr(i, 1, InStr(i, A_Space) - 1)
                i := StrReplace(i, Types)
                i := LTrim(i)
                for i in StrSplit(i, A_Space) {
                    MimeType[i] := Types
                }
            }
        }
        return MimeType
    }
}
; 请求类
;@region Request
class Request extends HTTP {
    __New() {
        this.Request := ""
        this.Method := ""
        this.Url := ""
        this.Protocol := "HTTP/1.1"
        this.Headers := Map()
        this.Body := ""
        this.GetQueryArgs := Map()
    }
    ; 解析请求
    Parse(ReqMsg) {
        this.Request := ReqMsg
        MessageMap := HTTP.ParseMessage(ReqMsg)
        this.Method := Method := MessageMap["line"][1]
        this.Url := Url := MessageMap["line"][2]
        this.Protocol := MessageMap["line"][3]
        this.Headers := MessageMap["headers"]
        this.Body := MessageMap.Get("body", "")
        if Method = "GET" and InStr(Url, "?") {
            pos := InStr(Url, "?")
            QueryArgs := SubStr(Url, pos + 1)
            this.Url := SubStr(Url, 1, pos - 1)
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
    Generate(Method := this.Method, Url := this.Url, Headers := this.Headers, Body := this.Body) {
        Method := StrUpper(Method)
        if Method = "GET" and this.GetQueryArgs.Count > 0 {
            Url .= "?"
            for k, v in this.GetQueryArgs {
                k := HTTP.UrlEncode(k)
                v := HTTP.UrlEncode(v)
                Url .= (A_Index < this.GetQueryArgs.Count) ? k "=" v "&" : k "=" v
            }
        }
        ReqMap := Map("line", [Method, Url, this.Protocol], "headers", Headers, "body", Body)
        return this.Request := HTTP.GenerateMessage(ReqMap)
    }
}
; 响应类
;@region Response
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
            Headers["Content-Length"] := HTTP.GetBodySize(Body)
        }
        if not Headers.Has("Content-Type") {
            Headers["Content-Type"] := "text/plain"
        }
        Headers["Server"] := "AutoHotkey/" A_AhkVersion
        Headers["Date"] := FormatTime("L0x0409", "ddd, d MMM yyyy HH:mm:ss")
        ResMap := Map("line", [Line, sCode, sMsg], "headers", Headers, "body", Body)
        return this.Response := HTTP.GenerateMessage(ResMap)
    }
}
;@region HttpServer
class HttpServer extends Socket.Server {
    Path := Map()
    MimeType := Map()
    req := Request()
    res := Response()
    SetMimeType(file) {
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
    SetBodyText(str) {
        this.res.Headers["Content-Length"] := HTTP.GetStrSize(str)
        if not this.res.Headers.Has("Content-Type")
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
    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(Socket, err) {
            if Socket.MsgSize() {
                this.ParseRequest(Socket)
            }
        }
        ; this.client.onCLOSE := onclose
        ; onclose(Socket, err) {
        ;     ; this.req.__New()
        ;     ; this.res.__New()
        ; }
    }
    ; 解析客户端请求
    ParseRequest(Socket) {
        this.req.Parse(Socket.RecvText())
        if this.Path.Has(this.req.Url) {
            this.res.__New()
            this.Path[this.req.Url](this.req, this.res)
        } else {
            this.res.sCode := 404
            this.res.sMsg := "Not Found"
            this.res.Body := "404 Not Found"
        }
        this.GenerateResponse(Socket)
    }

    ; 生成服务端响应
    GenerateResponse(Socket) {
        if this.req.Method = "HEAD" {
            this.res.Body := ""
        } else if this.req.Method = "TRACE" {
            this.SetBodyText(this.req.Request)
        } else if this.req.Method = "OPTIONS" {
            this.res.Headers["Allow"] := "GET,POST,HEAD,TRACE,OPTIONS"
        }
        if Type(this.res.Body) = "Buffer" {
            Socket.SendText(this.res.Generate())
            Socket.Send(this.res.Body)
        } else {
            Socket.SendText(this.res.Generate())
        }
        if this.req.Url = "/debug" or this.req.Method = "TRACE" {
            OutputDebug this.req.Request
            OutputDebug "`n"
            OutputDebug this.res.Response
        }
    }
}
; class Client {

; }

#Include <print>