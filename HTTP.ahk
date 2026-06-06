#RequiRes AutoHotkey v2.0
/************************************************************************
 * @date 2026/06/06
 * @version 3.3.5
 ***********************************************************************/
#Include <thqby\Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk

;@region 1.LogMsgText
BLOCK_MERGE_FAILED := "块合并失败"
NOT_A_STANDARD_HTTP_REQUEST := "不是标准的HTTP请求"
QUERY_PARAMETER_ERROR := "查询参数错误"
REQUEST_HEADER_ERROR := "请求头错误"
FILE_NOT_FOUND_OR_PATH_ERROR := "文件不存在或路径错误"
NVALID_VARIABLE_TYPE_ERROR_NEED_TO_PASS_ := "传入的变量类型错误，需要传入 {1}"
REQUEST_DENIED_FROM_ := "[HttpServer] 已拒绝来自 {1} 的请求"
PATH_FUNCTION_TYPE_ERROR := "路由函数类型错误，期望是 Func，实际传入{1}"
FUNCTION_AT_LEAST_TWO_PARAMETERS := "路由函数至少需要两个参数，第一个参数为请求对象，第二个参数为响应对象"
;@region 1.log
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
        global A_DebuggerName
        IsSet(A_DebuggerName) ? OutputDebug(Log) : ""
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
;@region 1.Http
class Http {
    ; 获取字符串字节长度
    static GetStrSize(str, encoding := "UTF-8") {
        return StrPut(str, encoding) - ((encoding = "UTF-16" or encoding = "CP1200") ? 2 : 1)
    }
    ; 获取body字节长度
    static GetBodySize(Body) {
        if Body is Buffer {
            return Body.size
        }
        if Body is Primitive {
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
    ; 标准化路径
    static NormalizePath(path) {
        cc := DllCall("GetFullPathName", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
        buf := Buffer(cc * 2)
        DllCall("GetFullPathName", "str", path, "uint", cc, "ptr", buf, "ptr", 0)
        return StrGet(buf)
    }
    ; 解析mime类型文件
    static ParseMimes(Mimes) {    ;考虑优化为JSON
        MimeType := Map()
        MimeType.CaseSense := false
        for i in StrSplit(Mimes, "`n") {
            if InStr(i, ":") {
                MimeType.Set(StrSplit(i, ":", A_Space "" A_Tab)*)
            } else if InStr(i, A_Tab) {
                MimeType.Set(StrSplit(i, A_Tab)*)
            }
        }
        return MimeType
    }
    static MimeType := Map()   ; Mime类型表
    ;@region 2.ResCode
    ; 响应预设
    static ResCode := Map(
        ; 3xx 重定向状态码
        301, { sCode: 301, sMsg: 'Moved Permanently', Body: "" }, ; 请求的资源已永久移动到新位置
        302, { sCode: 302, sMsg: 'Found', Body: "" }, ; 请求的资源临时从不同的URI响应请求
        ; 4xx 客户端错误状态码
        400, { sCode: 400, sMsg: 'Bad Request', Body: "400 Bad Request" }, ; 请求语法错误或参数有误，服务器无法理解
        403, { sCode: 403, sMsg: 'Forbidden', Body: "403 Forbidden" }, ; 服务器理解请求但拒绝执行，通常是因为权限不足
        404, { sCode: 404, sMsg: 'Not Found', Body: "404 Not Found" }, ; 请求的资源在服务器上未找到
        405, { sCode: 405, sMsg: 'Method Not Allowed', Body: "405 Method Not Allowed" }, ; 请求方法对指定资源不被允许
        406, { sCode: 406, sMsg: 'Not Acceptable', Body: "406 Not Acceptable" }, ; 服务器无法根据客户端的Accept头提供合适的响应内容
        408, { sCode: 408, sMsg: 'Request Timeout', Body: "408 Request Timeout" }, ; 服务器等待客户端发送请求的时间过长
        409, { sCode: 409, sMsg: 'Conflict', Body: "409 Conflict" }, ; 请求与服务器当前状态冲突，无法完成
        410, { sCode: 410, sMsg: 'Gone', Body: "410 Gone" }, ; 请求的资源已被永久删除
        ; 5xx 服务器错误状态码
        500, { sCode: 500, sMsg: 'Internal Server Error', Body: "500 Internal Server Error" }, ; 服务器遇到意外情况无法完成请求
        501, { sCode: 501, sMsg: 'Not Implemented', Body: "501 Not Implemented" }, ; 服务器不支持请求的功能
        502, { sCode: 502, sMsg: 'Bad Gateway', Body: "502 Bad Gateway" }, ; 作为网关或代理时收到无效响应
        503, { sCode: 503, sMsg: 'Service Unavailable', Body: "503 Service Unavailable" }, ; 服务器暂时无法处理请求，通常是过载或维护
        504, { sCode: 504, sMsg: 'Gateway Timeout', Body: "504 Gateway Timeout" }, ; 作为网关或代理时无法及时获得响应
        505, { sCode: 505, sMsg: 'HTTP Version Not Supported', Body: "505 HTTP Version Not Supported" } ; 服务器不支持请求使用的HTTP版本
    )
    static VisibleCRLF(str) => StrReplace(StrReplace(str, "`n", "\n"), "`r", "\r")
}
; 请求类
;@region 1.Request
class Request {
    __New() {
        this.Request := ""  ; 原始请求消息
        this.Method := ""   ; 请求方法
        this.Url := ""  ; 请求URL
        this.Protocol := "HTTP/1.1" ; 请求协议
        this.Headers := Map()   ; 请求头
        this.Headers.CaseSense := false
        this.BodyBuf := Buffer()  ; 请求体缓冲对象
        this.GetArgs := Map()  ; GET请求参数
        this.Block := [] ; 分块列表
        this.BlockSize := 0
        this.IP := ""
        this.DefineProp("Body", {
            Get: (this) => (this.BodyBuf),
            Set: (this, Value) => (this.BodyBuf := (Value is Buffer) ? Value : Buffer()),
            Call: (this, Encoding := this.Encoding) => (this.GetBodyText(Encoding))
        })
    }
    Encoding := "utf-8"
    ;@region 2.Parse
    ; 解析请求消息,一大坨代码.
    Parse(ReqMsg) {
        ; 如果存在分块数据，则继续接收分块数据
        if this.Block.Length {
            this.Block.Push(ReqMsg)
            this.BlockSize += ReqMsg.size
            ; OutputDebug this.BlockSize " " this.Headers.Get("Content-Length", 0) "`n"
            ; 检查是否已接收完整的请求体
            if this.BlockSize != this.Headers.Get("Content-Length", 0) {
                return
            }
            ; 合并所有分块数据为完整请求体
            this.BodyBuf := Buffer(this.BlockSize)
            Size := 0
            loop this.Block.Length {
                Data := this.Block.Pop()
                Size += Data.size
                Pos := this.BodyBuf.ptr + this.BodyBuf.size - Size
                DllCall("RtlCopyMemory", "Ptr", Pos, "Ptr", Data.ptr, "UInt", Data.size)
            }
            ; 验证合并后的数据大小是否正确
            if Size = this.Headers.Get("Content-Length", 0) {
                this.Block := []
                this.BlockSize := 0
                return 0
            }
            Log.Error(Block_MERGE_FAILED)
            return 500
        }
        ;@region 3.line&head
        msg := StrGet(ReqMsg, "utf-8")
        ; 以下pos不包含最末尾的\r\n
        LineEndPos := InStr(msg, "`r`n") - 1    ; 获取消息行结束位置
        HeadersPos := { start: LineEndPos + 3, end: InStr(msg, "`r`n`r`n") }
        BodyStartPos := HeadersPos.end + 3

        ; 检查HTTP请求格式是否正确
        if LineEndPos < 0 or HeadersPos.end = 0 {
            Log.Error(NOT_A_STANDARD_HTTP_REQUEST "Line")
            return 400
        }
        ; 检查协议标识是否正确
        if not InStr(SubStr(msg, LineEndPos - 9, 8), "HTTP/") {
            Log.Error(NOT_A_STANDARD_HTTP_REQUEST "Protocol")
            return 400
        }
        ; 解析请求行和请求头
        if Code := this.ParseLine(SubStr(msg, 1, LineEndPos)) {
            return Code
        } else if Code := this.ParseHeaders(SubStr(msg, HeadersPos.start, HeadersPos.end - HeadersPos.start)) {
            return Code
        }
        body := Buffer(ReqMsg.size - BodyStartPos)
        DllCall("RtlCopyMemory", "Ptr", body, "Ptr", ReqMsg.ptr + BodyStartPos, "UInt", body.Size)
        ; 处理POST请求的分块传输
        if this.Method = "POST" and this.Block.Length = 0 {
            if this.Headers.Get("Content-Length", 0) > body.Size {
                this.Block.Push(body)
                this.BlockSize += body.size
                return
            }
        }
        this.BodyBuf := body
        this.Request := msg
        return 0
    }
    ;@region 2.ParseLine
    ; 解析请求行
    ParseLine(Line) {
        LineList := StrSplit(Line, A_Space)
        this.Method := LineList[1]
        this.Url := LineList[2]
        this.Protocol := LineList[3]
        ; 检查URL中是否有查询参数
        if not Pos := InStr(this.Url, "?") {
            this.GetArgs := Map()
            return 0
        }
        ; 解析GET请求参数
        GetArgs := HTTP.UrlUnescape(SubStr(this.Url, pos + 1))
        ArgsList := StrSplit(GetArgs, ["&", "="])
        ; 检查参数格式是否正确（键值对应该成对出现）
        if ArgsList.Length & 1 {
            Log.Error(QUERY_PARAMETER_ERROR)
            return 400
        }
        this.Url := SubStr(this.Url, 1, pos - 1)
        this.GetArgs := Map(ArgsList*)
        return 0
    }
    ;@region 2.ParseHeaders
    ; 解析请求头
    ParseHeaders(Headers) {
        HeadersList := []
        loop parse Headers, "`n", "`r" {
            if not Pos := InStr(A_LoopField, ":") {
                Log.Error(REQUEST_HEADER_ERROR)
                return 400
            }
            HeadersList.Push(SubStr(A_LoopField, 1, Pos - 1))
            HeadersList.Push(LTrim(SubStr(A_LoopField, Pos + 1), A_Space))
        }
        ; 检查请求头格式是否正确（键值对应该成对出现）
        if HeadersList.Length & 1 {
            Log.Error(REQUEST_HEADER_ERROR)
            return 400
        }
        this.Headers := Map(HeadersList*)
        return 0
    }
    ;@region 2.GetBodyText
    ; 获取请求体
    GetBodyText(Encoding := this.Encoding) {
        return StrGet(this.Body, this.Body.size, Encoding)
    }
}
;@region 1.Response
class Response {
    __New() {
        this.Response := "" ; 原始响应消息
        this.Line := "HTTP/1.1" ; 响应协议
        this.sCode := 200   ; 响应状态码
        this.sMsg := "OK"   ; 响应状态信息
        this.Headers := Map()   ; 响应头
        this.Headers.CaseSense := false
        this.Body := "" ; 响应体
    }
    Encoding := "utf-8"
    ;@region 2.BuildLine
    ; 构建响应行
    BuildLine() {
        return Format("{1} {2} {3}", this.Line, this.sCode, this.sMsg)
    }
    ;@region 2.BuildHeaders
    ; 构建响应头
    BuildHeaders() {
        ; 响应头中添加Content-Length和Content-Type
        if not this.Headers.Has("Content-Length") {
            this.Headers["Content-Length"] := HTTP.GetBodySize(this.Body)
        }
        if not this.Headers.Has("Content-Type") {
            this.Headers["Content-Type"] := "text/plain"
        }
        ResHeaders := ""
        for k, v in this.Headers {
            ResHeaders .= Format("{1}: {2}`r`n", k, v)
        }
        return ResHeaders
    }
    ;@region 2.BuildResponse
    ; 生成响应
    BuildResponse() {
        ResLine := this.BuildLine()
        ResHeaders := this.BuildHeaders()
        ; 判断消息体类型, 是否在消息中包含消息体
        if Type(this.Body) = "Buffer" {
            Msg := Format("{1}`r`n{2}`r`n", ResLine, ResHeaders)
        } else {
            Msg := Format("{1}`r`n{2}`r`n{3}", ResLine, ResHeaders, this.Body)
        }
        return this.Response := Msg
    }
    ;@region 2.SetRedirect
    ; 设置重定向
    SetRedirect(URL, Code := 302) {
        this.SetErrorRes(Code)
        this.Headers["Location"] := URL
        this.Body := Format('<a href="{1}">{2}</a>.', URL, Http.ResCode[Code].sMsg)
    }
    ;@region 2.SetBodyText
    ; 设置响应体(文本)
    SetBodyText(Str, Encoding := this.Encoding) {
        this.Headers["Content-Length"] := HTTP.GetStrSize(Str)
        if not this.Headers.Has("Content-Type") {
            this.Headers["Content-Type"] := Encoding
                ? "text/plain; charset=" Encoding : "text/plain"
        }
        this.Body := Str
    }
    ;@region 2.SetBodyFile
    ; 设置响应体(文件)
    SetBodyFile(FilePath, Encoding := this.Encoding) {
        if !FileExist(FilePath) {
            Log.Error(Format("{1} {2}", FilePath, FILE_NOT_FOUND_OR_PATH_ERROR))
            this.SetErrorRes(404)
            return false
        }
        BuffObj := FileRead(FilePath, "Raw")
        this.Headers["Content-Length"] := BuffObj.size
        SplitPath(FilePath, , , &ext)
        CT := Http.MimeType.Has(ext) ? Http.MimeType[ext] : "text/plain"
        if InStr(CT, "text/") {
            CT .= Encoding ? "; charset=" Encoding : ""
        }
        this.Headers["Content-Type"] := CT
        this.Body := BuffObj
    }
    ;@region 2.SetErrorRes
    ; 设置错误响应
    SetErrorRes(code) {
        if not Http.ResCode.Has(code) {
            code := 500
        }
        this.sCode := Http.ResCode[code].sCode
        this.sMsg := Http.ResCode[code].sMsg
        this.Body := Http.ResCode[code].Body
    }
}

;@region 1.HttpServer
class HttpServer extends Socket.Server {
    Path := Map()   ; 路由表
    Req := Request()    ; 请求类
    Res := Response()   ; 响应类
    Web := false    ; 是否开启web功能
    onFunc := Map()
    onFunc.CaseSense := false
    ;@region 2.onACCEPT
    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(Socket, err) {
            if Socket.MsgSize() {
                ; IP访问控制检查
                this.Req.IP := SubStr(Socket.addr, 1, InStr(Socket.addr, ":") - 1)
                if this.onFunc.Has("isIPAllow") and not this.onFunc["isIPAllow"](this.Req.IP) {
                    Log.Warn(Format(REQUEST_DENIED_FROM_, Socket.addr), "")
                    Socket.__Delete()
                    return
                }
                this.Main(Socket)
            }
        }
        this.client.onClose := onclose
        onclose(Socket, err) {
            this.Req.__New()
        }
    }
    ;@region 2.Main
    Main(Socket) {
        ; 解析HTTP请求
        Code := this.Req.Parse(Socket.Recv())
        ; 根据解析结果处理请求
        if Code = 0 {
            this.Res.__New()
        } else if Code = "" {
            return
        } else {
            this.Res.SetErrorRes(Code)
            this.SendResponse(Socket)   ; 发送响应
            return Code
        }
        if this.onFunc.Has("PreHandleReq") and not this.onFunc["PreHandleReq"](this.Req, this.Res) {
            return Socket.__Delete()
        }
        ; 处理业务逻辑
        if Code := this.HandleRequest() {  ; 处理请求
            this.Res.SetErrorRes(Code)
            this.SendResponse(Socket)
            return Code
        }
        return this.SendResponse(Socket)
    }
    ;@region 2.HandleRequest
    ; 处理请求
    HandleRequest() {
        ; 尝试处理API调用请求
        if not Code := this.HandleAPIRequest() {
            return 0
        } else if this.Web and not Code := this.HandleWebRequest() { ; 如果启用Web功能，尝试处理Web请求
            return 0
        } else {
            return Code
        }
    }
    ;@region 2.HandleAPIRequest
    ; 处理调用请求
    HandleAPIRequest() {
        ; 检查路由表中是否存在该URL路径
        if not this.Path.Has(this.Req.Url) {    ; 路由表中没有此路径，返回
            return 404
        }
        this.Path[this.Req.Url](this.Req, this.Res) ; 执行请求
        return 0
    }
    ;@region 2.HandleWebRequest
    ; 处理Web请求
    HandleWebRequest() {
        ; Web访问IP控制检查
        Path := Http.NormalizePath(A_ScriptDir . this.Req.Url)
        ; 检查文件是否存在且有对应的MIME类型
        if not FileExist(Path) {
            return 404
        }
        this.Res.SetBodyFile(Path)
        return 0
    }
    ;@region 2.SendResponse
    ; 返回响应
    SendResponse(Socket) {
        this.DefResLine()    ; 设置响应行
        this.DefResHeader()    ; 设置响应头
        this.DefResBody()    ; 设置响应体
        if this.onFunc.Has("PreSendRes") and not this.onFunc["PreSendRes"](this.Req, this.Res) {
            return Socket.__Delete()
        }
        ; 根据body类型发送响应
        if Type(this.Res.Body) = "Buffer" {
            Socket.SendText(this.Res.BuildResponse())
            Socket.Send(this.Res.Body)
        } else {
            Socket.SendText(this.Res.BuildResponse())
        }
        ; 调试输出
        if this.Req.Url = "/debug" or this.Req.Method = "TRACE" {
            this.DeBug()
        }
        if this.Req.Headers.Get("Connection", 0) = "close" {
            Socket.__Delete()
        }
    }
    ;@region 1.DefResLine
    ; 设置默认响应行
    DefResLine() {
        return
    }
    ;@region 2.DefResHeader
    ; 设置默认响应头
    DefResHeader() {
        this.Res.Headers["Content-Location"] := this.Req.Url
        this.Res.Headers["Server"] := "AutoHotkey/" A_AhkVersion
        this.Res.Headers["Date"] := FormatTime(A_NowUTC " L0x0409", "ddd, d MMM yyyy HH:mm:ss 'GMT'")
        ; if this.Req.Method = "OPTIONS" {
        ;     this.Res.Headers["Allow"] := "GET,POST,HEAD,TRACE,OPTIONS"
        ; }
        ; this.Res.Headers["Connection"] := "close" ; 关闭长连接
    }
    ;@region 2.DefResBody
    ; 设置默认响应体
    DefResBody() {
        switch this.Req.Method {
            case "HEAD": this.Res.Body := ""
            case "TRACE": this.Res.SetBodyText(this.Req.Request)
        }
    }
    ;@region 2.LoadMimeType
    ; 设置mime类型
    LoadMimeType(FilePath) {
        if not FileExist(FilePath) {
            throw TargetError(FilePath " " FILE_NOT_FOUND_OR_PATH_ERROR)
        }
        Http.MimeType := HTTP.ParseMimes(FileRead(FilePath, "utf-8 `n"))
    }
    ;@region 2.SetPaths
    ; 设置请求路径对应的路由函数
    SetPaths(Paths) {
        if Type(Paths) != "Map" {
            throw TypeError(Format(NVALID_VARIABLE_TYPE_ERROR_NEED_TO_PASS_, Type(Paths)))
        }
        for _, F in Paths {
            if not F is Func {
                throw TypeError(Format(PATH_FUNCTION_TYPE_ERROR, Type(F)))
            }
            if F.MinParams < 2 {
                throw Error(Format(FUNCTION_AT_LEAST_TWO_PARAMETERS))
            }
        }
        this.Path := Paths
    }
    ;@region 2.DeBug
    DeBug() {
        OutputDebug this.Req.Request
        OutputDebug "`n----------------------------------`n"
        OutputDebug this.Res.Response
        OutputDebug "`n=====================================================================`n"
    }
}