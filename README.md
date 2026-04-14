# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
#### 警告：这个脚本从设计到实现，都很简单。
#### 可能存在一些意料之中和意料之外的问题，但只要还能满足基本需求，就不会进一步改进。
#### 如果需要简单的HTTPserver建议尝试Python的http.server
# 注意事项
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 没有刻意注意字符编码，在这方面可能有BUG。
3. 同时最好只有一个连接，没有针对多连接的处理。
4. 不支持复杂的HTTP协议机制，如：分块传输。
# 已知缺陷
输出错误日志待完善。  
请求体过长截断的问题已经解决，使用大小`9.76M`的UTF-8编码txt文件进行测试没有问题，但没有做更多测试。  
感觉在编码方面还是有隐患。~~也可能是我多虑了~~
# 使用方法
## 开始
1. 实例化类`HttpServer`，同时传入端口号。  
2. 调用类实例方法`SetPaths`传入URL路径对应的处理函数，变量类型`Map`。  
3. 调用类实例方法`SetMimeType`传入如下格式的文件的路径，用于设置文件的MIME类型。
    ```
    html: text/html
    jpg: image/jpeg
    ```
### 可选配置项
| 配置项        | 默认值 | 说明            |
| ------------- | ------ | --------------- |
| Web           | false  | 是否开启Web服务 |
| EnableIPCheck | true   | 开启IP限制      |
## 使用
- 当URL路径被访问时调用`paths`中相应的处理函数。  
- 调用处理函数时，传入两个参数，请求`Request`和响应`Response`，处理函数必须有两个参数接受传入。    
- `Request`类实例属性`BodyBuf`包含请求体，类型为`Buffer`。
    - 通过`Body`动态属性获取，或直接调用`Body()`并传入编码来提取文本。  
- 调用`Response`类实例方法`SetBodyText`发送文本，传入字符串，可选传入编码。  
- 调用`Response`类实例方法`SetBodyFile`发送文件，传入文件路径，可选传入编码。  
- 其他请求头、响应头等，可以直接访问传入处理函数的参数`Request`和`Response`的属性。
### 回调函数
`HttpServer`包含一个`Map`类型的属性`CallbackFunc`用于存放回调函数，其大小写不敏感。
- `isIPAllowed`  
    参数为访问的IP，需`EnableIPCheck`为`true`。  
    函数返回`true`则允许访问，返回`false`则拒绝访问。  
    获取到的访问者IP并不一定是准确的真实IP，也可能是其他转发路由的IP。
- 其他暂无，没什么需求。
## 请求 Request
### 可用 Request 属性
| 属性     | 描述             | 类型   | 默认值   |
| -------- | ---------------- | ------ | -------- |
| Request  | 未解析的原始请求 | String |          |
| Method   | 请求方法         | String |          |
| Url      | 请求URL          | String |          |
| Protocol | HTTP协议版本     | String | HTTP/1.1 |
| Headers  | 请求头           | Map    |          |
| BodyBuf  | 请求体           | Buffer |          |
| GetArgs  | 查询参数         | Map    |          |

### 可用 Request 方法
#### `GetBodyText(Encoding := "UTF-8")`
从`Req.BodyBuf`中以指定编码提取文本。
- **参数**
    - `encoding` (**String**, 可选): 请求体的文本编码，默认值：`UTF-8`。  
        可从`Content-Type`中提取客户端设置的编码。
- **返回**
    - `String`: 文本

## 响应 Response
### 可用 Response 属性
| 属性     | 描述               | 类型          | 默认值                                                           |
| -------- | ------------------ | ------------- | ---------------------------------------------------------------- |
| Response | 最终生成的HTTP响应 | String        |                                                                  |
| Line     | HTTP协议版本       | String        | HTTP/1.1                                                         |
| sCode    | 响应代码           | Int           | 200                                                              |
| sMsg     | 响应消息           | String        | OK                                                               |
| Headers  | 响应头             | Map           | 必要的`Content-Length`、`Content-Type`和`HttpServer`预设的响应头 |
| Body     | 响应体             | String/Buffer | 类型取决于响应体内容，默认为字符串。                             |

### 可用 Response 方法
#### `SetBodyText(Str, Encoding := "")`
将文本设置为响应体，包含响应头`Content-Length`、`Content-Type`的设置。无返回值。
- **参数**
    - `Str` (**String**, 必填): 文本。
    - `Encoding` (**String**, 可选): 传入编码，则响应头`Content-Type`将添加`"; charset=" Encoding `。
#### `SetBodyFile(FilePath, Encoding := "")`
将文件作为响应体，包含响应头`Content-Length`、`Content-Type`的设置。无返回值。
- **参数**
    - `FilePath` (**String**, 必填): 文件路径，不存在则抛出错误。
    - `Encoding` (**String**, 可选): 传入编码，则响应头`Content-Type`将添加`"; charset=" Encoding `。
#### `SetErrorRes(Code)`
设置错误响应，仅支持部分响应码。
无返回值。
- **参数**
    - `Code` (**Int**, 必填): 错误码。
#### `SetRedirect(Url, Code := 302)`
设置重定向。无返回值。
- **参数**
    - `Url` (**String**, 必填): 重定向的URL。
    - `Code` (**Int**, 可选): 状态码，默认为302。
## HttpServer的预设响应头
 - Content-Location: 请求的URL
 - Date: 本地时间
 - Server: AutoHotkey版本
## 日志
预期内的错误会输出日志到`A_WorkingDir\logs\{date}.log`文件。

# 更新日志
- 2026/02/16  
    现在服务端的大部分行为都可以通过派生类，重写方法来修改。  
- 2026/04/14
    请求类的属性`Body`改为动态属性，包含`call`属性，默认使用`UTF-8`调用`GetBodyText()`方法。
# 关于HTTPS
使用caddy反向代理来实现HTTPS，至少我是这么做的。  
觉得`http://ip:port`太长可以尝试使用`.localhost`域名，局域网尝试使用设备名称+`.lan`或`.local`域名。  
```Caddyfile
ahk.localhost {
	reverse_proxy :port
}
```
# 其他
### TODO
 - [x] 细化日志
 - [x] 优化`HTTP.log`  
 - [x] 优化`ParseRequest`的If结构。  
 - [x] 尝试优化请求体过长（极限大概是几KB）截断的问题，现有的处理逻辑会导致字符的字节丢失。  
 - [x] 将`MimeType`、`ErrorResMsg`移至`http`类
 - [x] `setbody`、`getbody`的方法移至相应类
 - [x] 重写请求类的body为动态属性
 - [ ] ~~向请求类传入响应类实例，发生错误时由请求类直接操作响应类，省去在函数调用间传递错误码。~~
### 优化方向
响应头默认初始设置`Content-Type`，能省下大概3个if语句。