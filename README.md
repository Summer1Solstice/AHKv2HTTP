# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
## 警告：这个脚本从设计到实现，都很简单。
## 可能存在一些意料之中和意料之外的问题，但只要还能满足基本需求，就不会进一步修改。
## 如果需要简单的HTTPserver建议尝试Python的http.server
# 注意事项与已知缺陷
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 只能发送文件，不能接收文件。
3. 没有刻意注意字符编码，在这方面可能有BUG。
4. 同时最好只有一个连接，没有针对多连接的处理。
5. 没有错误处理逻辑，出错时可能需要重启脚本。
6. 不支持复杂的HTTP协议机制，如：分块传输。

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
|配置项|默认值|说明|
| --- | --- | --- |
|web  |false|是否开启Web服务|
|RejectExternalIP|true|是否拒绝外部IP访问|
## 使用
- 调用类实例方法`SetBodyText`发送文本，传入字符串。  
- 调用类实例方法`SetBodyFile`发送文件，传入文件路径。  
- 当URL路径被访问时调用`paths`中相应的处理函数。  
- 调用处理函数时，传入两个参数`Request`和`Response`，处理函数必须有两个参数接受传入。    

**Request**包含以下属性：
| 属性 | 描述 | 类型 |
| --- | --- | --- |
| Request | 未解析的原始请求 | String |
| Method | 请求方法 | String |
| Url | 请求URL | String |
| Protocol | HTTP协议版本 | String |
| Headers | 请求头 | Map |
| Body | 请求体 | String | 
| GetQueryArgs | 查询参数 | Map |

**Response**包含以下属性：
| 属性 | 描述 | 类型 |
| --- | --- | --- |
| Response | 最终生成的HTTP响应 | String |
| Line | HTTP协议版本 | String |
| sCode | 响应代码 | Int |
| sMsg | 响应消息 | String |
| Headers | 响应头 | Map |
| Body | 响应体 | String |

`Line`、`sCode`、`sMsg`拥有默认值`HTTP/1.1`、`200`、`OK`
## 日志
预期内的错误会输出日志到`A_WorkingDir\logs\{date}.log`文件。