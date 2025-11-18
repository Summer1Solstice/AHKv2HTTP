#Requires AutoHotkey v2.0
; Socket.Ahk 的最小工作示例 
#Include <thqby\Socket>
class TestServer extends Socket.Server {
	onACCEPT(err) {
		this.client := this.AcceptAsClient()
		this.client.onREAD := onread
		onread(this, err) {
			MsgBox("receive from client`n" this.RecvText())
			this.SendText('hello')
		}
	}
}

server := TestServer(, "\\.\pipe\testPipe")

class TestClient extends Socket.Client {
	onREAD(err) {
		MsgBox("receive from server`n" this.RecvText())
	}
}
Persistent
tClient := TestClient("\\.\pipe\testPipe")
tClient.SendText("hi")