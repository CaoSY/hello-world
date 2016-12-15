var http = require('http');

var hostname = 'localhost';
var port = 3000;

var server = http.createServer(function(req, res) {
	console.log(req.headers);
	res.writeHead(200, {'Content-Type':'text/html'});
	res.end(`<!doctype html><html><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Hello World</title></head><body><h1>Hello, world!</h1></body></html>`);
});

server.listen(port, hostname, function() {
	console.log(`Server running at http://${hostname}:${port}`);
});