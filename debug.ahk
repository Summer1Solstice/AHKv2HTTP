#Requires AutoHotkey v2.0
#Include <print>
DeBug(req, res) {
	if req.Headers.Get["Host", 0] {
		if InStr(req.Headers["Host"], "127.0.0.1") {
			print "HTTPRequest:"
			print req.Request
			print "line:"
			print req.Line
			print "headers:"
			print req.Headers
			print "body:"
			print req.Body
			print "GETQueryArgs:"
			print req.GETQueryArgs
			print "`n"
			print "HttpResponse:"
			print res.Response
			print "line:"
			print res.Line
			print "headers:"
			print res.Headers
			print "body:"
			print res.Body
		}
	}
}
