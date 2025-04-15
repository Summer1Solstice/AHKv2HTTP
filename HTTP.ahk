#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/04/15
 * @version 2.1.6
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
        MessageMap := Map() ; 初始化变量
        LineEndPos := InStr(msg, "`r`n")    ; 获取消息行结束位置
        BodyStartPos := InStr(msg, "`r`n`r`n")  ; 获取消息体开始位置
        MessageMap["line"] := StrSplit(SubStr(msg, 1, LineEndPos - 1), A_Space) ; 获取消息行
        ; 解析消息头
        Headers := StrSplit(SubStr(msg, LineEndPos + 3, BodyStartPos - LineEndPos - 3), ["`r`n", ": "])
        MessageMap["headers"] := Map()  ; 初始化变量
        MessageMap["headers"].Set(Headers*) ; 使用可变参数,将Array转至Map
        MessageMap["body"] := SubStr(msg, BodyStartPos + 4) ; 获取消息体
        return MessageMap
    }
    ; 消息拼装
    static GenerateMessage(Elements) {
        ; 传入参数的验证
        if Type(Elements) != "Map"
            throw TypeError()
        if !Elements.Has("line") or !Elements.Has("headers") or !Elements.Has("body")
            throw UnsetError()
        if Type(Elements["line"]) != "Array" or Type(Elements["headers"]) != "Map"
            throw TypeError()

        line := Format("{1} {2} {3}", Elements["line"]*)    ; 拼装消息行
        ; 拼装消息头
        headers := ""
        for k, v in Elements["headers"] {
            headers .= Format("{1}: {2}`r`n", k, v)
        }
        msg := ""
        ; 判断消息体类型, 是否在消息中包含消息体
        if Type(Elements["body"]) = "Buffer" {
            msg := Format("{1}`r`n{2}`r`n", line, headers)
        } else {
            msg := Format("{1}`r`n{2}`r`n{3}", line, headers, Elements["body"])
        }
        return msg
    }
    ; 解析mime类型文件
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
        this.Request := ""  ; 原始请求消息
        this.Method := ""   ; 请求方法
        this.Url := ""  ; 请求URL
        this.Protocol := "HTTP/1.1" ; 请求协议
        this.Headers := Map()   ; 请求头
        this.Body := "" ; 请求体
        this.GetQueryArgs := Map()  ; GET请求参数
    }
    ; 解析请求
    Parse(ReqMsg) {
        ; 修复小体积请求分段的问题
        if HTTP.GetStrSize(ReqMsg) = this.Headers.Get("Content-Length", 0) {
            ReqMsg := this.Request . ReqMsg
        }
        this.Request := ReqMsg  ; 保存原始消息
        MessageMap := HTTP.ParseMessage(ReqMsg) ; 解析消息
        try {
            this.Method := Method := MessageMap["line"][1]  ; 请求方法
            this.Url := Url := MessageMap["line"][2]    ; 请求URL
            this.Protocol := MessageMap["line"][3]  ; 请求协议
            this.Headers := MessageMap["headers"]   ; 请求头
            this.Body := MessageMap.Get("body", "") ; 请求体
            if Method = "GET" and InStr(Url, "?") { ; 解析GET请求参数
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
        } catch Error as err {
            ; 错误处理
            temp := [A_Now, ReqMsg, err.Message, err.File, err.Line]
            FileAppend(Format("{1}: {2}`n`t{3}`t{4}`t{5}`n", temp*), "log.txt", "`n")
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
        this.Response := "" ; 原始响应消息
        this.Line := "HTTP/1.1" ; 响应协议
        this.sCode := 200   ; 响应状态码
        this.sMsg := "OK"   ; 响应状态信息
        this.Headers := Map()   ; 响应头
        this.Body := "" ; 响应体
    }
    ; 解析响应
    Parse(ResMsg) {
        this.Response := ResMsg ; 保存原始消息
        MessageMap := HTTP.ParseMessage(ResMsg) ; 解析消息
        this.Line := MessageMap["line"][1]  ; 响应协议
        this.sCode := MessageMap["line"][2] ; 响应状态码
        this.sMsg := MessageMap["line"][3]  ; 响应状态信息
        this.Headers := MessageMap["headers"]   ; 响应头
        this.Body := MessageMap.Get("body", "") ; 响应体
    }
    ; 生成响应
    Generate(sCode := this.sCode, sMsg := this.sMsg, Headers := this.Headers, Body := this.Body) {
        Line := this.Line
        ; 响应头中添加Content-Length和Content-Type
        if not Headers.Has("Content-Length") {
            Headers["Content-Length"] := HTTP.GetBodySize(Body)
        }
        if not Headers.Has("Content-Type") {
            Headers["Content-Type"] := "text/plain"
        }
        ResMap := Map("line", [Line, sCode, sMsg], "headers", Headers, "body", Body)
        return this.Response := HTTP.GenerateMessage(ResMap)    ; 生成响应消息
    }
}
;@region HttpServer
class HttpServer extends Socket.Server {
    Path := Map()   ; 路由表
    MimeType := Map()   ; Mime类型表
    req := Request()    ; 请求类
    res := Response()   ; 响应类
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
        this.req.Parse(Socket.RecvText())   ; 获取请求
        if this.Path.Has(this.req.Url) {
            this.res.__New()    ; 初始化响应类的属性
            this.Path[this.req.Url](this.req, this.res) ; 执行请求
        } else {    ; 404
            this.res.sCode := 404
            this.res.sMsg := "Not Found"
            this.res.Body := "404 Not Found"
        }
        this.GenerateResponse(Socket)   ; 发送响应
    }

    ; 生成服务端响应
    GenerateResponse(Socket) {
        ; 根据请求方法设置响应
        if this.req.Method = "HEAD" {
            this.res.Body := ""
        } else if this.req.Method = "TRACE" {
            this.SetBodyText(this.req.Request)
        } else if this.req.Method = "OPTIONS" {
            this.res.Headers["Allow"] := "GET,POST,HEAD,TRACE,OPTIONS"
        }
        ; 设置响应头
        this.res.Headers["Content-Location"] := this.req.Url
        this.res.Headers["Server"] := "AutoHotkey/" A_AhkVersion
        this.res.Headers["Date"] := FormatTime("L0x0409", "ddd, d MMM yyyy HH:mm:ss")
        ; 根据body类型发送响应
        if Type(this.res.Body) = "Buffer" {
            Socket.SendText(this.res.Generate())
            Socket.Send(this.res.Body)
        } else {
            Socket.SendText(this.res.Generate())
        }
        ; 调试输出
        if this.req.Url = "/debug" or this.req.Method = "TRACE" {
            OutputDebug this.req.Request
            OutputDebug "`n"
            OutputDebug this.res.Response
        }
    }
    ; 设置mime类型
    SetMimeType(file) {
        if not FileExist(file) {
            throw TargetError
        }
        this.MimeType := HTTP.LoadMimes(file)
    }
    ; 设置请求路径对应的处理函数
    SetPaths(paths) {
        if not Type(paths) = "Map"
            throw TypeError()
        this.Path := paths
    }
    ; 设置响应体(文本)
    SetBodyText(str) {
        this.res.Headers["Content-Length"] := HTTP.GetStrSize(str)
        if not this.res.Headers.Has("Content-Type")
            this.res.Headers["Content-Type"] := "text/plain"
        this.res.Body := str
    }
    ; 设置响应体(文件)
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
}
; class Client {

; }

#Include <print>