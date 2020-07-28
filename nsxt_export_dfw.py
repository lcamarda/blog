import json
import requests

#prepare the http connection to NSX Manager
session = requests.Session()
session.verify = False
session.auth = ('admin', 'VMware1!VMware1!')
nsx_mgr = 'https://nsxmgr-01a.corp.local'

#collect Services Inventory
services_path = '/policy/api/v1/infra?filter=Type-Service'
services_json = session.get(nsx_mgr + services_path).json()

#filter the user defined services only and store them in the user_defined_services list
user_defined_services = []

while services_json["children"]:
    childservice = services_json["children"].pop()
    if childservice["Service"]["_system_owned"] == False:
        del childservice["Service"]["children"] #This looks to be needed because the retrived JSON have unexpected child objects for the Service Objects
        user_defined_services.append(childservice)

#collect Profiles Inventory
profiles_path = '/policy/api/v1/infra?filter=Type-PolicyContextProfile'
profiles_json = session.get(nsx_mgr + profiles_path).json()

#filter the user defined profiles only and store them in the user_defined_profiles list
user_defined_profiles = []

while profiles_json["children"]:
    childprofile = profiles_json["children"].pop()
    if childprofile["PolicyContextProfile"]["_system_owned"] == False:
        user_defined_profiles.append(childprofile)

#Collect DFW configuration
dfw_path = '/policy/api/v1/infra?filter=Type-Domain|Group|SecurityPolicy|Rule'
dfw_json = session.get(nsx_mgr + dfw_path).json()

#Add User-Defined Services and Profiles to the DFW Configuration
new_infra_children = dfw_json["children"] + user_defined_services + user_defined_profiles

dfw_json["children"] = new_infra_children

#Write the DFW Configuration to a JSON file that can be applied via a PATCH API call to the infra URI: '/policy/api/v1/infra'
with open("dfw.json", "w") as write_file:
    json.dump(dfw_json, write_file, indent = 4)
