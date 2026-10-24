import json

def application(environ,start_response):
 path=environ.get('PATH_INFO','/')
 status='200 OK' if path in ('/','/healthz') else '404 Not Found'
 body=json.dumps({'service':'azure-compute-app-service','healthy':status=='200 OK'}).encode()
 start_response(status,[('Content-Type','application/json'),('Content-Length',str(len(body)))])
 return [body]
