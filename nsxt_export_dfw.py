import json
import requests

session = requests.Session()
session.verify = False
session.auth = ('admin', 'VMware1!VMware1!')
nsx_mgr = 'https://nsxmgr-01a.corp.local'

services_path = '/policy/api/v1/infra?filter=Type-Service'
services_json = session.get(nsx_mgr + services_path).json()

user_defined_services = []

while services_json["children"]:
    childservice = services_json["children"].pop()
    if childservice["Service"]["_system_owned"] == False:
        del childservice["Service"]["children"]
        user_defined_services.append(childservice)

dfw_path = '/policy/api/v1/infra?filter=Type-Domain|Group|SecurityPolicy|Rule'
dfw_json = session.get(nsx_mgr + dfw_path).json()

new_infra_children = dfw_json["children"] + user_defined_services

dfw_json["children"] = new_infra_children

with open("dfw.json", "w") as write_file:
    json.dump(dfw_json, write_file, indent = 4)
