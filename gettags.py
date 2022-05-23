#!/usr/bin/env python3
# -*- coding:utf-8 -*-
import time
import requests
from requests.auth import HTTPBasicAuth
import json
import argparse



class Harbor_get_artifacts(object):
    def __init__(self,schema, harbor_domain, username, password,project_name,output_name):
        self.rep_name = None
        self.tags = None
        self.reps = None
        self.handle = None
        self.schema = schema
        self.harbor_domain = harbor_domain
        self.username = username
        
        self.password = password
        self.project_name = project_name
        self.output_name = output_name
        self.harbor_api_url = self.schema+'://'+self.harbor_domain+'/api/v2.0'
        self.harbor_rep_url = self.harbor_api_url+'/projects/'+self.project_name+'/repositories'
        self.harbor_rep_url_page = self.harbor_rep_url+ "?page=1&page_size=100"

        self.auth = HTTPBasicAuth(self.username,self.password)
        print(self.harbor_rep_url_page,self.username)
        self.result()

    def write_file(self,content):
        self.handle = open(self.output_name, "w")
        for c in content:
            self.handle.write(c + '\n')
        self.handle.close()

    def result(self):
        self.reps = self.get_reps()
        self.tags = self.get_artifacts(self.reps)
        self.write_file(self.tags)

    def get_reps(self):
        self.reps = requests.get(self.harbor_rep_url_page,auth=self.auth).json()
        print(self.reps)
        reps=[]
        for rep in self.reps:
            rep = rep['name'].replace(self.project_name,'')
            reps.append(rep)
        return reps


    def get_artifacts(self,rep_name):
        self.rep_name = rep_name
        tags=[]
        for rep in rep_name:
            self.harbor_tags_url = self.harbor_rep_url + rep + '/artifacts?page=1&page_size=100' \
                                                                         '&with_tag=true&with_label=false' \
                                                                         '&with_scan_overview=false' \
                                                                         '&with_signature=false' \
                                                                         '&with_immutable_status=false'
            #print(self.harbor_tags_url)
            self.tags = requests.get(self.harbor_tags_url, auth=self.auth).json()
            rep = rep.replace("/","")
            for tag_list in self.tags:
                for tag in tag_list['tags']:
                    tag = rep+":"+tag['name']
                    print(tag)
                    tags.append(tag)
            #time.sleep(0.1)
        return tags

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--domain", help="domain", required=True)
    parser.add_argument("-u", "--username", help="username", required=True)
    parser.add_argument("-p", "--password", help="password", required=True)
    parser.add_argument("-project", "--project", help="harbor project name", required=True)
    parser.add_argument("-o", "--output", help="output logs",default='./output.log')
    args = parser.parse_args()
    try:
        result = Harbor_get_artifacts(schema="https",harbor_domain=args.domain,username=args.username,password=args.password,project_name=args.project,output_name=args.output)
    except Exception as e:
        print(e)

