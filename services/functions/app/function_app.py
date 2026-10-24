import json
import azure.functions as func
app=func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
@app.route(route='hello')
def hello(req:func.HttpRequest)->func.HttpResponse:
 return func.HttpResponse(json.dumps({'service':'azure-compute-functions','status':'ready'}),mimetype='application/json')
