import uwsgi

def application(env, start_response): 
    path = env['REQUEST_URI']
    path_array = path.split('/')

    if len(path_array) < 3:
        start_response('200 OK', [('Content-Type','text/html')])
        return
    if path_array[1] != "hello":
        start_response('400 Bad Request', [('Content-Type','text/html')])
        return
    if path_array[2] == '':
        start_response('400 Bad Request', [('Content-Type','text/html')])
        return ["Please supply a name.\n"]
    else:
        start_response('200 OK', [('Content-Type','text/html')])
        return ["Hello, %s.\n" % (path_array[2])]
