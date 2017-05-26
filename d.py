#coding=utf8
#参数一：domain
#参数二：serviceEntityName
#参数三：tag
#参数四：配置文件（file map）
#参数五：flag
import httplib
import urllib
import json
import ConfigParser
import os
import sys

#ag = "10.0.1.1"
ag = "dev.agplat"
port = "80"

class HttpClient():
    def get(self, server, port, location, value={}):
        self.server = server
        self.port = port
        self.location = location
        self.value = value
        data = urllib.urlencode(self.value)
        if data: url = self.location + '?' + data
        else: url = self.location
        try:
            httpclient = httplib.HTTPConnection(self.server, self.port,timeout=5)
            httpclient.request('GET', url)
            response = httpclient.getresponse()
            if int(response.status) == 200:
                return response.read()
        except Exception as e:
            return e
        finally:
            if httpclient:
                httpclient.close()

    def post(self, server, port, location, value):
        self.server = server
        self.port = port
        self.location = location
        self.value = value
        headers = {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"}
        params = urllib.urlencode(self.value)
        try:
            httpclient = httplib.HTTPConnection(self.server, self.port, timeout=5)
            httpclient.request('POST', self.location, params, headers=headers)
            response = httpclient.getresponse()
            if int(response.status) == 200:
                return response.read()
        except Exception as e:
            print e
        finally:
            if httpclient:
                httpclient.close()

def getInstanceFromdomain(domain,serviceEntityName=''):
    value = {}
    value['domain'] = domain
    if serviceEntityName: value['serviceEntityName'] = serviceEntityName
    httpclient = HttpClient()
    res_json = httpclient.get(ag,port,"/serviceinstance/serviceentity/list/get",value)
    instance = json.loads(res_json)
    if instance['status'] == 'ok':
    #return instance
        if serviceEntityName: return instance['content'][serviceEntityName]
        else: return instance['content']
    elif instance['status'] == 'error':
        return "参数错误！域名？"

def setInstancnDownOrUp(domain,serviceEntityName,instance, status):
    params = {}
    params['domain'] = domain
    params['serviceEntityName'] = serviceEntityName
    params['server'] = instance
    params['upOrDown'] = status
    httpclient = HttpClient()
    res_json = httpclient.post(ag, port, "/serviceinstance/serviceentity/server/put", params)
    if json.loads(res_json)['status'] == 'ok':
        return 0
    else:
        return 1

def getRunConfig(serviceEntityName):
    #返回json
    httpclient = HttpClient()
    location = '/' + serviceEntityName
    release_host = 'dev.release.56qq.cn'
    release_port = '80'
    try:
        runconf = httpclient.get(release_host,release_port, location)
        runconf_dict = eval(runconf)
        return runconf_dict
    except Exception as e:
        return

print getInstanceFromdomain('dev.shieldin', 'shield-manager')
print setInstancnDownOrUp('dev.shieldin', 'shield-manager', '10.0.2.7:405', 'down')
print getInstanceFromdomain('dev.shieldin')

print getRunConfig('shield-manager')

class DockerClient():
    def __init__(self, ip, port):
        self.ip = ip
        self.port = port
        _url = "tcp://" + self.ip + ":" + self.port

    def dockerRun(self):
        pass
    def dockerStop(self, containerName):
        pass
        
    def dockerPs(self):
        pass
    def dockerPull(self, imageName):
        pass
    def dockerRm(self, containerName):
        pass

def preRelease():
    pass

def Release(tag, runConf):
    pass

def aftRelease():
    pass

