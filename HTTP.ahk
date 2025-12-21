#RequiRes AutoHotkey v2.0
/************************************************************************
 * @date 2025/12/21
 * @version 3.0.0
 ***********************************************************************/
#Include <thqby\Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
aaaa(a) {
    return StrReplace(StrReplace(a, "`n", "\n"), "`r", "\r") "`n"
}
;@region LogMsgText
BLOCK_MERGE_FAILED := "块合并失败"
NOT_A_STANDARD_HTTP_REQUEST := "不是标准的HTTP请求"
QUERY_PARAMETER_ERROR := "查询参数错误"
REQUEST_HEADER_ERROR := "请求头错误"
;@region log
class Log {
    static __New() {
        if not DirExist("logs") {
            DirCreate("logs")
        }
    }
    ; 写入日志
    static Write(LogLevel, Text, Fn) {
        Date := FormatTime(, "yyyy-MM-dd")
        Time := FormatTime(, "HH:mm:ss")
        Text := Fn ? Format("[{1}] {2}", Fn, Text) : Text
        Log := Format("{1} {2:-5} - {3}`n", Time, logLevel, Text)
        FileAppend(Log, "logs\" Date ".log", "utf-8")
    }
    ; 调试
    static Debug(Text, Fn := A_ThisFunc) => this.Write("DEBUG", Text, Fn)
    ; 信息
    static Info(Text, Fn := A_ThisFunc) => this.Write("INFO", Text, Fn)
    ; 警告
    static Warn(Text, Fn := A_ThisFunc) => this.Write("WARN", Text, Fn)
    ; 错误
    static Error(Text, Fn := A_ThisFunc) => this.Write("ERROR", Text, Fn)
    ; 严重错误
    static Fatal(Text, Fn := A_ThisFunc) => this.Write("FATAL", Text, Fn)
}
;@region Http
class Http {
    ; 获取字符串字节长度
    static GetStrSize(str, encoding := "UTF-8") {
        return StrPut(str, encoding) - ((encoding = "UTF-16" or encoding = "CP1200") ? 2 : 1)
    }
    ; 获取body字节长度
    static GetBodySize(Body) {
        if Type(Body) = "Buffer" {
            return Body.size
        } else {
            return Http.GetStrSize(Body)
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
        ; https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/LogServer.ahk#L473-L484
        DllCall('shlwapi\UrlUnescape', 'str', i, 'ptr', 0, 'uint*', 0, 'uint', 0x140000)
        return i
    }
    ; 解析mime类型文件
    static LoadMimes(FilePath) {    ;考虑优化为JSON
        FileConent := FileRead(FilePath, "`n")
        MimeType := Map()
        MimeType.CaseSense := false
        for i in StrSplit(FileConent, "`n") {
            if InStr(i, ":") {
                MimeType.Set(StrSplit(i, ":", A_Space "" A_Tab)*)
            } else if InStr(i, A_Tab) {
                MimeType.Set(StrSplit(i, A_Tab)*)
            }
        }
        return MimeType
    }
}
; 请求类
;@region Request
class Request {
    __New() {
        this.Request := ""  ; 原始请求消息
        this.Method := ""   ; 请求方法
        this.Url := ""  ; 请求URL
        this.Protocol := "HTTP/1.1" ; 请求协议
        this.Headers := Map()   ; 请求头
        this.Body := "" ; 请求体
        this.GetQueryArgs := Map()  ; GET请求参数
        this.Block := [] ; 分块列表
        this.BlockSize := 0
    }
    ;@region Parse
    Parse(ReqMsg) {
        if this.Block.Length {
            this.Block.Push(ReqMsg)
            this.BlockSize += ReqMsg.size
            OutputDebug this.BlockSize " " this.Headers.Get("Content-Length", 0) "`n"
            if this.BlockSize != this.Headers.Get("Content-Length", 0) {
                return
            }
            this.Body := Buffer(this.BlockSize)
            Size := 0
            for i in this.Block {
                DllCall("Kernel32.dll\RtlCopyMemory", "Ptr", this.Body.ptr + Size, "Ptr", i.ptr, "UInt", i.size)
                Size += i.size
            }
            if Size = this.Headers.Get("Content-Length", 0) {
                this.Block := []
                this.BlockSize := 0
                return 0
            }
            Log.Error(Block_MERGE_FAILED)
            return 500
        }
        ;@region line&head
        msg := StrGet(ReqMsg, "utf-8")
        ; 以下pos不包含最末尾的\r\n
        LineEndPos := InStr(msg, "`r`n") - 1    ; 获取消息行结束位置
        HeadersPos := { start: LineEndPos + 3, end: InStr(msg, "`r`n`r`n") }
        BodyStartPos := HeadersPos.end + 4
        ; OutputDebug aaaa(SubStr(msg, 1, LineEndPos)) "`n"
        ; OutputDebug aaaa(SubStr(msg, HeadersPos.start, HeadersPos.end - HeadersPos.start)) "`n"
        ; OutputDebug aaaa(SubStr(msg, BodyStartPos)) "`n"
        ; OutputDebug aaaa(SubStr(msg, 1, BodyStartPos - 1))
        ; Pause()
        if LineEndPos < 0 or HeadersPos.end < 0 {
            Log.Error(NOT_A_STANDARD_HTTP_REQUEST)
            return 400
        }
        if not InStr(SubStr(msg, LineEndPos - 9, 8), "HTTP/") {
            Log.Error(NOT_A_STANDARD_HTTP_REQUEST)
            return 400
        }
        if Code := this.ParseLine(SubStr(msg, 1, LineEndPos)) {
            return Code
        } else if Code := this.ParseHeaders(SubStr(msg, HeadersPos.start, HeadersPos.end - HeadersPos.start)) {
            return Code
        }
        body := SubStr(msg, BodyStartPos)
        if this.Method = "POST" and this.Block.Length = 0 {
            if this.Headers.Get("Content-Length", 0) > HTTP.GetBodySize(body) {
                temp := StrPut(SubStr(msg, 1, HeadersPos.end + 2), "utf-8")    ;请求体的长度
                if temp {
                    body := Buffer(ReqMsg.size - temp)
                    DllCall("Kernel32.dll\RtlCopyMemory", "Ptr", body, "Ptr", ReqMsg.ptr + temp, "UInt", ReqMsg.size - temp)
                    this.Block.Push(body)
                    this.BlockSize += body.size
                    ; OutputDebug this.BlockSize "`n"
                }
                return
            }
        }
        this.Body := body
        this.Request := msg
        return 0
    }
    ;@region ParseLine
    ParseLine(Line) {
        LineList := StrSplit(Line, A_Space)
        this.Method := LineList[1]
        this.Url := LineList[2]
        this.Protocol := LineList[3]
        if not Pos := InStr(this.Url, "?") {
            this.GetQueryArgs := Map()
            return 0
        }
        GetArgs := HTTP.UrlUnescape(SubStr(this.Url, pos + 1))
        ArgsList := StrSplit(GetArgs, ["&", "="])
        if ArgsList.Length & 1 {
            Log.Error(QUERY_PARAMETER_ERROR)
            return 400
        }
        this.Url := SubStr(this.Url, 1, pos - 1)
        this.GetQueryArgs := Map(ArgsList*)
        return 0
    }
    ;@region ParseHeaders
    ParseHeaders(Headers) {
        HeadersList := StrSplit(Headers, ["`r`n", ": "])
        if HeadersList.Length & 1 {
            Log.Error(REQUEST_HEADER_ERROR)
            return 400
        }
        this.Headers := Map(HeadersList*)
        return 0
    }
}
;@region Response
class Response {
    __New() {
        this.Response := "" ; 原始响应消息
        this.Line := "HTTP/1.1" ; 响应协议
        this.sCode := 200   ; 响应状态码
        this.sMsg := "OK"   ; 响应状态信息
        this.Headers := Map()   ; 响应头
        this.Body := "" ; 响应体
    }
    ; 生成响应
    Generate() {
        ; 响应头中添加Content-Length和Content-Type
        if not this.Headers.Has("Content-Length") {
            this.Headers["Content-Length"] := HTTP.GetBodySize(this.Body)
        }
        if not this.Headers.Has("Content-Type") {
            this.Headers["Content-Type"] := "text/plain"
        }
        ResLine := Format("{1} {2} {3}", this.Line, this.sCode, this.sMsg)
        ResHeaders := ""
        for k, v in this.Headers {
            ResHeaders .= Format("{1}: {2}`r`n", k, v)
        }
        ; 判断消息体类型, 是否在消息中包含消息体
        if Type(this.Body) = "Buffer" {
            msg := Format("{1}`r`n{2}`r`n", ResLine, ResHeaders)
        } else {
            msg := Format("{1}`r`n{2}`r`n{3}", ResLine, ResHeaders, this.Body)
        }
        return this.Response := msg
    }
}

;@region HttpServer
class HttpServer extends Socket.Server {
    Path := Map()   ; 路由表
    MimeType := Map()   ; Mime类型表
    Req := Request()    ; 请求类
    Res := Response()   ; 响应类
    Web := false    ; 是否开启web功能
    IPRestrict := true  ; 是否开启IP限制
    CallbackFn := Map()
    ErrorResMsg := Map(
        400, { sCode: 400, sMsg: 'Bad Request', Body: "400 Bad Request" },
        403, { sCode: 403, sMsg: 'Forbidden', Body: "403 Forbidden" },
        404, { sCode: 404, sMsg: 'Not Found', Body: "404 Not Found" },
        500, { sCode: 500, sMsg: 'Internal Server Error', Body: "500 Internal Server Error" }
    )
    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(Socket, err) {
            if Socket.MsgSize() {
                if this.IPRestrict {
                    if this.CallbackFn.Has("IPAudit") and not this.CallbackFn["IPAudit"](Socket.addr, "Access") {
                        Log.Warn("[HttpServer] 已拒绝来自" Socket.addr "的请求")
                        Socket.__Delete()
                        return
                    }
                }
                ; OutputDebug 1 "`n"
                this.Main(Socket)
            }
        }
        this.client.onClose := onclose
        onclose(Socket, err) {
            ; this.Req.Body := Buffer(this.Req.BlockSize)
            ; Size := 0
            ; for i in this.Req.Block {
            ;     DllCall("Kernel32.dll\RtlCopyMemory", "Ptr", this.Req.Body.ptr + Size, "Ptr", i.ptr, "UInt", i.size)
            ;     Size += i.size
            ; }
            ; this.Path["/hash"](this.Req, this.Res)
            OutputDebug("[HttpServer] " Socket.addr "已关闭")
            this.Req.__New()
        }
    }
    Main(Socket) {
        Code := this.Req.Parse(Socket.Recv())
        if Code = 0 {
            this.Res.__New()
        } else if Code = "" {
            return
        } else {
            this.ErrorResponse(Code)
            this.SendResponse(Socket)   ; 发送响应
            return Code
        }
        if Code := this.HandleRequest(Socket) {  ; 处理请求
            this.ErrorResponse(Code)
            this.SendResponse(Socket)
            return Code
        }
        return this.SendResponse(Socket)
    }
    ; 处理请求
    HandleRequest(Socket) {
        if not Code := this.HandleCallRequest(Socket) { ; 尝试处理调用请求
            return 0
        } else if this.Web and not Code := this.HandleWebRequest(Socket) { ; 尝试处理文件请求
            return 0
        } else {
            return Code
        }
    }
    ; 处理调用请求
    HandleCallRequest(Socket) {
        if not this.Path.Has(this.req.Url) {    ; 路由表中没有此路径，返回
            return 404
        }
        this.Path[this.req.Url](this.req, this.res) ; 执行请求
        return 0
    }
    ; 处理Web请求
    HandleWebRequest(Socket) {
        if this.CallbackFn.Has("IPAudit") and not this.CallbackFn["IPAudit"](Socket.addr, "Web") {
            return 403
        }
        path := "." this.req.Url
        SplitPath(this.req.Url, , , &ext)
        if not (FileExist(path) and this.MimeType.Has(ext)) {
            return 404
        }
        this.SetBodyFile(path)
        return 0
    }
    ; 返回响应
    SendResponse(Socket) {
        ; 根据请求方法设置响应
        if this.Req.Method = "HEAD" {
            this.Res.Body := ""
        } else if this.Req.Method = "TRACE" {
            this.SetBodyText(this.Req.Request)
        } else if this.Req.Method = "OPTIONS" {
            this.Res.Headers["Allow"] := "GET,POST,HEAD,TRACE,OPTIONS"
        }
        ; 设置响应头
        this.Res.Headers["Content-Location"] := this.Req.Url
        this.Res.Headers["Server"] := "AutoHotkey/" A_AhkVersion
        this.Res.Headers["Date"] := FormatTime("L0x0409", "ddd, d MMM yyyy HH:mm:ss")
        ; 根据body类型发送响应
        if Type(this.Res.Body) = "Buffer" {
            Socket.SendText(this.Res.Generate())
            Socket.Send(this.Res.Body)
        } else {
            Socket.SendText(this.Res.Generate())
        }
        ; 调试输出
        if this.Req.Url = "/debug" or this.Req.Method = "TRACE" {
            this.DeBug()
        }
    }
    ; 设置mime类型
    SetMimeType(file_path) {
        if not FileExist(file_path) {
            log := file_path " 文件不存在或路径错误"
            throw TargetError(log)
        }
        this.MimeType := HTTP.LoadMimes(file_path)
    }
    ; 设置请求路径对应的处理函数
    SetPaths(paths) {
        if not Type(paths) = "Map" {
            log := "需要传入一个Map, 但传入的是 " Type(paths)
            throw TypeError(log)
        }
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
    SetBodyFile(file_path) {
        if !FileExist(file_path) {
            Log.Error(Format("{1} 文件不存在或路径错误", file_path))
            this.ErrorResponse(404)
            return false
        }
        buffobj := FileRead(file_path, "Raw")
        this.res.Headers["Content-Length"] := buffobj.size
        SplitPath(file_path, , , &ext)
        this.MimeType.Has(ext)
            ? this.res.Headers["Content-Type"] := this.MimeType[ext]
            : this.res.Headers["Content-Type"] := "text/plain"
        this.res.Body := buffobj
    }
    ; 获取请求体
    GetReqBody() {
        if this.req.Body is String {
            return this.req.Body
        } else {
            return StrGet(this.req.Body, this.req.Body.size, "UTF-8")
        }
    }
    ; DEBUG
    DeBug() {
        OutputDebug this.req.Request
        OutputDebug "`n----------------------------------`n"
        OutputDebug this.res.Response
        OutputDebug "`n=====================================================================`n"
    }
    ; 设置错误响应
    ErrorResponse(code) {
        this.Res.sCode := this.ErrorResMsg[code].sCode
        this.Res.sMsg := this.ErrorResMsg[code].sMsg
        this.Res.Body := this.ErrorResMsg[code].Body
    }
}