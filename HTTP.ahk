#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/07/04
 * @version 2.3.2
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
    /**日志
     * @param Explain 日志说明
     * @param {Integer} LogLevel ["DEBUG", "INFO", "WARN", "ERROR"]
     * @param {String} FuncName 当前函数名，自动获取
     */
    static Log(Explain, LogLevel := 4) {
        static logLevelDict := ["DEBUG", "INFO", "WARN", "ERROR"]
        date := FormatTime(, "yyyy-MM-dd")
        time := FormatTime(, "HH:mm:ss")
        Log := Format("{1} {} - {}`n", time, logLevelDict[LogLevel], Explain)
        FileAppend(log, "logs\" date ".log", "utf-8")
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
        this.block := false ; 是否分块传输
    }
    ; 处理请求
    Parse(ReqMsg) {
        if this.block {
            this.Body .= ReqMsg
            if this.Headers.Get("Content-Length", 0) > HTTP.GetBodySize(this.Body) {
                this.block := true
                SetTimer(abc(*) => this.block = false, -3000)
                HTTP.log("请求体不完整，疑似分块传输。")
                return false
            }
            this.block := false
            return true
        }
        this.Request := ReqMsg
        LineEndPos := InStr(ReqMsg, "`r`n")    ; 获取消息行结束位置
        BodyStartPos := InStr(ReqMsg, "`r`n`r`n")  ; 获取消息体开始位置
        if not LineEndPos or not BodyStartPos {
            HTTP.log("疑似常规请求，不满足HTTP协议要求。 " this.Request)
            return false
        }
        if not InStr(SubStr(ReqMsg, LineEndPos - 8, 8), "HTTP/") {
            HTTP.log("没有找到HTTP协议版本。")
            return false
        }
        line := SubStr(ReqMsg, 1, LineEndPos - 1)
        this.ParseLine(line)
        headers := SubStr(ReqMsg, LineEndPos + 2, BodyStartPos - LineEndPos - 2)
        body := SubStr(ReqMsg, BodyStartPos + 4)
        if this.Method = "POST" and this.block = false {
            if this.ParseHeaders(headers) {
                if this.Headers.Get("Content-Length", 0) > HTTP.GetBodySize(body) {
                    this.block := true
                }
                this.Body := body
            }
        } else {
            this.ParseHeaders(headers)
            this.Body := body
        }
    }
    ; 解析请求行
    ParseLine(msg) {
        LineList := StrSplit(msg, A_Space)
        this.Method := LineList[1]
        this.Url := LineList[2]
        this.Protocol := LineList[3]
        if LineList[1] = "GET" and pos := InStr(this.Url, "?") {
            GetArgs := HTTP.UrlUnescape(SubStr(this.Url, pos + 1))
            this.Url := SubStr(this.Url, 1, pos - 1)
            this.GetQueryArgs.Set(StrSplit(GetArgs, ["&", "="])*)
        }
        return true
    }
    ; 解析请求头
    ParseHeaders(msg) {
        HeadersList := StrSplit(msg, ["`r`n", ": "])
        if Mod(HeadersList.Length, 2) {
            HTTP.log("解析失败，请求头没有成对出现。")
            return false
        }
        this.Headers.Set(HeadersList*)
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
                        HTTP.log("已拒绝来自" Socket.addr "的请求", 3)
                        Socket.__Delete()
                        return
                    }
                }
                this.ParseRequest(Socket)
            }
        }
    }
    ; 解析客户端请求
    ParseRequest(Socket) {
        this.req.Parse(Socket.RecvText())   ; 解析请求
        this.res.__New()    ; 初始化响应类的属性
        if this.Path.Has(this.req.Url) {
            this.Path[this.req.Url](this.req, this.res) ; 执行请求
        } else if this.web and not this.RejectExternalIP {
            path := "." this.req.Url
            SplitPath(this.req.Url, , , &ext)
            if FileExist(path) and this.MimeType.Has(ext) {
                this.SetBodyFile(path)
            } else {
                this.Not_Found()
            }
        } else {
            this.Not_Found()
        }
        this.GenerateResponse(Socket)   ; 发送响应
        ; this.DeBug()
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
            throw TargetError
        }
        this.MimeType := HTTP.LoadMimes(file_path)
    }
    ; 设置请求路径对应的处理函数
    SetPaths(paths) {
        if not Type(paths) = "Map" {
            throw TypeError()
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
            HTTP.log(file_path " 文件不存在或路径错误")
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
    ; DEBUG
    DeBug() {
        OutputDebug this.req.Request
        OutputDebug "`n------------------------------------`n"
        OutputDebug this.res.Response
        OutputDebug "`n************************************`n"
    }
    Not_Found() {
        this.res.sCode := 404
        this.res.sMsg := "Not Found"
        this.res.Body := "404 Not Found"
    }
}