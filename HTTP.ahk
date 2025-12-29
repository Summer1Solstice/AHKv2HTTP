#RequiRes AutoHotkey v2.0
/************************************************************************
 * @date 2025/12/21
 * @version 3.0.0
 ***********************************************************************/
#Include <thqby\Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk

;@region LogMsgText
BLOCK_MERGE_FAILED := "块合并失败"
NOT_A_STANDARD_HTTP_REQUEST := "不是标准的HTTP请求"
QUERY_PARAMETER_ERROR := "查询参数错误"
REQUEST_HEADER_ERROR := "请求头错误"
FILE_NOT_FOUND_OR_PATH_ERROR := "文件不存在或路径错误"
NVALID_VARIABLE_TYPE_ERROR_NEED_TO_PASS_ := "传入的变量类型错误，需要传入{1}"
REQUEST_DENIED_FROM_ := "[HttpServer] 已拒绝来自{1}的请求"
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
    ; 可视化换行符
    static VisibleBr(v) {
        return StrReplace(StrReplace(v, "`n", "\n"), "`r", "\r") "`n"
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
        ; 如果存在分块数据，则继续接收分块数据
        if this.Block.Length {
            this.Block.Push(ReqMsg)
            this.BlockSize += ReqMsg.size
            OutputDebug this.BlockSize " " this.Headers.Get("Content-Length", 0) "`n"
            ; 检查是否已接收完整的请求体
            if this.BlockSize != this.Headers.Get("Content-Length", 0) {
                return
            }
            ; 合并所有分块数据为完整请求体
            this.Body := Buffer(this.BlockSize)
            Size := 0
            for i in this.Block {
                DllCall("Kernel32.dll\RtlCopyMemory", "Ptr", this.Body.ptr + Size, "Ptr", i.ptr, "UInt", i.size)
                Size += i.size
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
        ;@region line&head
        msg := StrGet(ReqMsg, "utf-8")
        ; 以下pos不包含最末尾的\r\n
        LineEndPos := InStr(msg, "`r`n") - 1    ; 获取消息行结束位置
        HeadersPos := { start: LineEndPos + 3, end: InStr(msg, "`r`n`r`n") }
        BodyStartPos := HeadersPos.end + 4

        ; 检查HTTP请求格式是否正确
        if LineEndPos < 0 or HeadersPos.end = 0 {
            Log.Error(NOT_A_STANDARD_HTTP_REQUEST)
            return 400
        }
        ; 检查协议标识是否正确
        if not InStr(SubStr(msg, LineEndPos - 9, 8), "HTTP/") {
            Log.Error(NOT_A_STANDARD_HTTP_REQUEST)
            return 400
        }
        ; 解析请求行和请求头
        if Code := this.ParseLine(SubStr(msg, 1, LineEndPos)) {
            return Code
        } else if Code := this.ParseHeaders(SubStr(msg, HeadersPos.start, HeadersPos.end - HeadersPos.start)) {
            return Code
        }
        body := SubStr(msg, BodyStartPos)
        ; 处理POST请求的分块传输
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
        ; 检查URL中是否有查询参数
        if not Pos := InStr(this.Url, "?") {
            this.GetQueryArgs := Map()
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
        this.GetQueryArgs := Map(ArgsList*)
        return 0
    }
    ;@region ParseHeaders
    ParseHeaders(Headers) {
        HeadersList := StrSplit(Headers, ["`r`n", ": "])
        ; 检查请求头格式是否正确（键值对应该成对出现）
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
            Msg := Format("{1}`r`n{2}`r`n", ResLine, ResHeaders)
        } else {
            Msg := Format("{1}`r`n{2}`r`n{3}", ResLine, ResHeaders, this.Body)
        }
        return this.Response := Msg
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
    CallbackFunc := Map()
    ErrorResMsg := Map(
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
    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(Socket, err) {
            if Socket.MsgSize() {
                ; IP访问控制检查
                if this.IPRestrict {
                    if this.CallbackFunc.Has("IPAudit") and not this.CallbackFunc["IPAudit"](Socket.addr, "Access") {
                        Log.Warn(Format("REQUEST_DENIED_FROM_", Socket.addr), "")
                        Socket.__Delete()
                        return
                    }
                }
                this.Main(Socket)
            }
        }
        this.client.onClose := onclose
        onclose(Socket, err) {
            this.Req.__New()
        }
    }
    Main(Socket) {
        ; 解析HTTP请求
        Code := this.Req.Parse(Socket.Recv())
        ; 根据解析结果处理请求
        if Code = 0 {
            this.Res.__New()
        } else if Code = "" {
            return
        } else {
            this.SetErrorResponse(Code)
            this.SendResponse(Socket)   ; 发送响应
            return Code
        }
        ; 处理业务逻辑
        if Code := this.HandleRequest(Socket) {  ; 处理请求
            this.SetErrorResponse(Code)
            this.SendResponse(Socket)
            return Code
        }
        return this.SendResponse(Socket)
    }
    ; 处理请求
    HandleRequest(Socket) {
        ; 尝试处理API调用请求
        if not Code := this.HandleCallRequest(Socket) {
            return 0
        } else if this.Web and not Code := this.HandleWebRequest(Socket) { ; 如果启用Web功能，尝试处理文件请求
            return 0
        } else {
            return Code
        }
    }
    ; 处理调用请求
    HandleCallRequest(Socket) {
        ; 检查路由表中是否存在该URL路径
        if not this.Path.Has(this.Req.Url) {    ; 路由表中没有此路径，返回
            return 404
        }
        this.Path[this.Req.Url](this.Req, this.Res) ; 执行请求
        return 0
    }
    ; 处理Web请求
    HandleWebRequest(Socket) {
        ; Web访问IP控制检查
        if this.CallbackFunc.Has("IPAudit") and not this.CallbackFunc["IPAudit"](Socket.addr, "Web") {
            return 403
        }
        Path := "." this.Req.Url
        SplitPath(this.Req.Url, , , &Ext)
        ; 检查文件是否存在且有对应的MIME类型
        if not (FileExist(Path) and this.MimeType.Has(Ext)) {
            return 404
        }
        this.SetBodyFile(Path)
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
    SetMimeType(FilePath) {
        if not FileExist(FilePath) {
            throw TargetError(FilePath " " FILE_NOT_FOUND_OR_PATH_ERROR)
        }
        this.MimeType := HTTP.LoadMimes(FilePath)
    }
    ; 设置请求路径对应的处理函数
    SetPaths(Paths) {
        if not Type(Paths) = "Map" {
            throw TypeError(Format(NVALID_VARIABLE_TYPE_ERROR_NEED_TO_PASS_, Type(Paths)))
        }
        this.Path := Paths
    }
    ; 设置响应体(文本)
    SetBodyText(Str) {
        this.Res.Headers["Content-Length"] := HTTP.GetStrSize(Str)
        if not this.Res.Headers.Has("Content-Type")
            this.Res.Headers["Content-Type"] := "text/plain"
        this.Res.Body := Str
    }
    ; 设置响应体(文件)
    SetBodyFile(FilePath) {
        if !FileExist(FilePath) {
            Log.Error(Format("{1} {2}", FilePath, FILE_NOT_FOUND_OR_PATH_ERROR))
            this.SetErrorResponse(404)
            return false
        }
        BuffObj := FileRead(FilePath, "Raw")
        this.Res.Headers["Content-Length"] := BuffObj.size
        SplitPath(FilePath, , , &ext)
        this.MimeType.Has(ext)
            ? this.Res.Headers["Content-Type"] := this.MimeType[ext]
            : this.Res.Headers["Content-Type"] := "text/plain"
        this.Res.Body := BuffObj
    }
    ; 获取请求体
    GetReqBodyText(encoding:="UTF-8") {
        if this.Req.Body is String {
            return this.Req.Body
        } else {
            return StrGet(this.Req.Body, this.Req.Body.size, encoding)
        }
    }
    ; DEBUG
    DeBug() {
        OutputDebug this.Req.Request
        OutputDebug "`n----------------------------------`n"
        OutputDebug this.Res.Response
        OutputDebug "`n=====================================================================`n"
    }
    ; 设置错误响应
    SetErrorResponse(code) {
        if this.ErrorResMsg.HasOwnProp(code) {
            code := 500
        }
        this.Res.sCode := this.ErrorResMsg[code].sCode
        this.Res.sMsg := this.ErrorResMsg[code].sMsg
        this.Res.Body := this.ErrorResMsg[code].Body
    }
}