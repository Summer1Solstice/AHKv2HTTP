#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/08/07
 * @version 2.4.2
 ***********************************************************************/
#Include <thqby\Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk

;@region HTTP
class HTTP {
    static __New() {
        if not DirExist("logs") {
            DirCreate("logs")
        }
    }
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
    ; 解析mime类型文件
    static LoadMimes(file_path) {    ;考虑优化为JSON
        FileConent := FileRead(file_path, "`n")
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
    /**
     * 日志
     * @param {Integer} logLevel 日志等级 ["DEBUG", "INFO", "WARN", "ERROR"]
     * @param {String} Explain 日志文本
     */
    static log(logLevel := 1, Explain := "") {
        static logLevelDict := ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"]
        date := FormatTime(, "yyyy-MM-dd")
        time := FormatTime(, "HH:mm:ss")
        log := Format("{1} {2:-5} - {3}`n", time, logLevelDict[logLevel], Explain)
        FileAppend(log, "logs\" date ".log", "utf-8")
    }
    ; 2: 信息
    static INFO := HTTP.log.Bind(, 2)
    ; 3: 警告
    static WARN := HTTP.log.Bind(, 3)
    ; 4: 错误
    static ERROR := HTTP.log.Bind(, 4)
    ; 5: 致命错误
    static FATAL := HTTP.log.Bind(, 5)
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
        this.BodyCharset := "utf-8"
        this.GetQueryArgs := Map()  ; GET请求参数
        this.Block := [] ; 分块列表
        this.BlockSize := 0
    }
    ; 处理请求
    Parse(ReqMsg) {
        if this.Block.Length {
            this.Block.Push(ReqMsg)
            this.BlockSize += ReqMsg.size
            if this.BlockSize = this.Headers.Get("Content-Length", 0) {
                this.Body := Buffer(this.BlockSize)
                temp_size := 0
                for i in this.Block {    ; 合并分块
                    DllCall("Kernel32.dll\RtlCopyMemory", "Ptr", this.Body.ptr + temp_size, "Ptr", i.ptr, "UInt", i.size)
                    temp_size += i.size
                }
                if this.Body.size = this.Headers.Get("Content-Length", 0) {
                    this.Block := []
                    this.BlockSize := 0
                    return true
                }
                HTTP.ERROR(Format("[{1}] 合并失败", A_ThisFunc))
                return false
            } else {
                return false
            }
        }
        msg := StrGet(ReqMsg, "utf-8")
        LineEndPos := InStr(msg, "`r`n")    ; 获取消息行结束位置
        BodyStartPos := InStr(msg, "`r`n`r`n")  ; 获取消息体开始位置
        if not LineEndPos or not BodyStartPos {
            HTTP.ERROR(Format("[{1}] 疑似常规请求，不满足HTTP协议要求。{2}", A_ThisFunc, this.Request))
            return false
        }
        if not InStr(SubStr(msg, LineEndPos - 8, 8), "HTTP/") {
            HTTP.ERROR(Format("[{1}] 没有找到HTTP协议版本。", A_ThisFunc))
            return false
        }
        line := SubStr(msg, 1, LineEndPos - 1)
        this.ParseLine(line)
        headers := SubStr(msg, LineEndPos + 2, BodyStartPos - LineEndPos - 2)
        if not this.ParseHeaders(headers) {
            return false
        }
        if this.Method = "POST" and this.Block.Length = 0 {
            if this.Headers.Get("Content-Length", 0) > HTTP.GetBodySize(body) {
                temp := StrPut(SubStr(msg, 1, BodyStartPos + 2), "utf-8")
                if temp {
                    body := Buffer(ReqMsg.size - temp)
                    DllCall("Kernel32.dll\RtlCopyMemory", "Ptr", body, "Ptr", ReqMsg.ptr + temp, "UInt", ReqMsg.size - temp)
                    this.Block.Push(body)
                    this.BlockSize += body.size
                }
                return false
            }
        }
        body := SubStr(msg, BodyStartPos + 4)
        this.Body := body
        this.Request := msg
        return true
    }
    ; 解析请求行
    ParseLine(msg) {
        LineList := StrSplit(msg, A_Space)
        this.Method := LineList[1]
        this.Url := LineList[2]
        this.Protocol := LineList[3]
        if LineList[1] = "GET" and pos := InStr(this.Url, "?") {    ; 使用问号判断可能有点草率
            GetArgs := HTTP.UrlUnescape(SubStr(this.Url, pos + 1))
            ArgsList := StrSplit(GetArgs, ["&", "="])
            if Mod(ArgsList.Length, 2) {
                HTTP.WARN(Format("[{1}] GET请求参数错误。{2}", A_ThisFunc, this.Url))
                ArgsList.Push("")
            }
            this.Url := SubStr(this.Url, 1, pos - 1)
            this.GetQueryArgs := Map(ArgsList*)
        } else {
            this.GetQueryArgs := Map()
        }
        return true
    }
    ; 解析请求头
    ParseHeaders(msg) {
        HeadersList := StrSplit(msg, ["`r`n", ": "])
        if Mod(HeadersList.Length, 2) {
            HTTP.ERROR(Format("[{1}] 解析失败，请求头没有成对出现。", A_ThisFunc))
            return false
        }
        this.Headers := Map(HeadersList*)
        if this.Headers.Has("Content-Type") and Cpos := InStr(this.Headers["Content-Type"], "charset=") {
            this.BodyCharset := SubStr(this.Headers["Content-Type"], Cpos + 8)
        }
        return true
    }
}
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
    req := Request()    ; 请求类
    res := Response()   ; 响应类
    web := false    ; 是否开启web功能
    RejectExternalIP := true  ; 是否拒绝外部IP连接

    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(Socket, err) {
            if Socket.MsgSize() {
                if this.RejectExternalIP {
                    if not (InStr(Socket.addr, "127.0.0.1") or InStr(Socket.addr, "192.168.")) {
                        HTTP.WARN("[HttpServer] 已拒绝来自" Socket.addr "的请求")
                        Socket.__Delete()
                        return
                    }
                }
                this.Main(Socket)
            }
        }
        this.client.onClose := onclose
        onclose(Socket, err) {
            HTTP.INFO("[HttpServer] " Socket.addr " 已断开连接, 即将清理内存...")
            this.req.__New()
        }
    }
    ; 主函数
    Main(Socket) {
        if this.req.Parse(Socket.Recv()) {   ; 解析请求
            this.res.__New()    ; 初始化响应类的属性
            this.HandleRequest(Socket)  ; 处理请求
            this.GenerateResponse(Socket)   ; 发送响应
        }
    }
    ; 处理请求
    HandleRequest(Socket) {
        if this.HandleCallRequest(Socket) { ; 尝试处理调用请求
            return true
        } else if this.HandleWebRequest(Socket) {   ; 尝试处理Web请求
            return true
        } else {
            this.Not_Found()
            ; HTTP.INFO(Format("[NO] {1} 请求了 {2}", Socket.addr, this.req.Url))
        }
    }
    ; 处理调用请求
    HandleCallRequest(Socket) {
        if not this.Path.Has(this.req.Url) {    ; 路由表中没有此路径，返回
            return false
        }
        ; HTTP.INFO(Format("[OK] {1} 请求了 {2}", Socket.addr, this.req.Url))
        this.Path[this.req.Url](this.req, this.res) ; 执行请求
        return true
    }
    ; 处理Web请求
    HandleWebRequest(Socket) {
        if not (this.web and this.RejectExternalIP) {   ; web为真，拒绝外部IP连接为真，继续处理
            return false
        }
        path := "." this.req.Url
        SplitPath(this.req.Url, , , &ext)
        if not (FileExist(path) and this.MimeType.Has(ext)) {
            return false
        }
        this.SetBodyFile(path)
        ; HTTP.INFO(Format("[OK] {1} 访问了 {2}", Socket.addr, this.req.Url))
        return true
    }
    ; 生成响应
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
            this.DeBug()
        }
    }
    ; 设置mime类型
    SetMimeType(file_path) {
        if not FileExist(file_path) {
            log := file_path " 文件不存在或路径错误"
            HTTP.FATAL(Format("[{1}] 设置mime类型时出错, {2}", A_ThisFunc, log))
            throw TargetError(log)
        }
        this.MimeType := HTTP.LoadMimes(file_path)
    }
    ; 设置请求路径对应的处理函数
    SetPaths(paths) {
        if not Type(paths) = "Map" {
            log := "需要传入一个Map, 但传入的是 " Type(paths)
            HTTP.FATAL(Format("[{1}] {2}", A_ThisFunc, log))
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
            HTTP.ERROR(Format("[{1}] {2} 文件不存在或路径错误", A_ThisFunc, file_path))
            this.Not_Found()
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
            return StrGet(this.req.Body, this.req.Body.size, this.req.BodyCharset)
        }
    }
    ; DEBUG
    DeBug() {
        OutputDebug this.req.Request
        OutputDebug "`n----------------------------------`n"
        OutputDebug this.res.Response
        OutputDebug "`n=====================================================================`n"
    }
    ; 404
    Not_Found() {
        this.res.sCode := 404
        this.res.sMsg := "Not Found"
        this.res.Body := "404 Not Found"
    }
}