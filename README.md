# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
# 注意
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 只有文本消息传输的功能。
3. 没有刻意注意字符编码，在这方面可能有BUG。
4. 同时只能处理一个连接。
5. 没有考虑错误处理。  
6. 不适合复杂需求，如：分块传输等。
# TODO
- [x] 请求方法全部转大写
- [ ] 添加错误处理
- [ ] 类型验证
- [ ] URL编码调用DLL部分，需要优化。
# 使用方法
实例化类`HttpServer`，同时传入端口号。  
调用类实例方法`SetPaths`传入URL路径对应的处理函数，变量类型`Map`。  
调用类实例方法`SetMimeType`传入`mime.types`，应该传入文件路径。  
调用类实例方法`SetBodyText`发送文本，传入字符串。  
调用类实例方法`SetBodyFile`发送文件，传入文件路径。  
当URL路径被访问时调用`paths`中相应的处理函数。  
调用处理函数时，传入两个参数`Request`和`Response`，处理函数必须有两个参数接受传入。    
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
# 其他
旧版本，仅实现服务端功能，本体和示例在 old 文件夹中。
