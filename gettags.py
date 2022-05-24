#!/usr/bin/env python3
# -*- coding:utf-8 -*-
import time
import requests
from requests.auth import HTTPBasicAuth
import json
import argparse


class HarborGetArtifacts(object):
    def __init__(self,schema, harbor_domain, username, password,project_name,output_name):
        self.schema = schema
        self.harbor_domain = harbor_domain
        self.username = username
        self.password = password
        self.project_name = project_name
        self.output_name = output_name
        self.harbor_api_url = self.schema+'://'+self.harbor_domain+'/api/v2.0'
        self.harbor_rep_url = self.harbor_api_url+'/projects/'+self.project_name+'/repositories'
        self.harbor_rep_url_page = self.harbor_rep_url+ "?page_size=100&page="

        self.auth = HTTPBasicAuth(self.username,self.password)
        self.result()

    def write_file(self,content):

        handle = open(self.output_name, "w")
        for c in content:
            handle.write(c + '\n')
        handle.close()

    def result(self):
        reps = self.get_reps()
        tags = self.get_artifacts(reps)
        self.write_file(tags)

    def get_reps(self):
        page = 1
        flag = True
        reps = []
        while flag:
            r_reps = requests.get(self.harbor_rep_url_page+str(page),auth=self.auth).json()
            #print(r_reps)
            if len(r_reps) != 0:
                for rep in r_reps:
                    rep = rep['name'].replace(self.project_name,'')
                    reps.append(rep)
                page += 1
            else:
                flag = False
        #print(reps)
        return reps


    def get_artifacts(self,rep_name):
        #rep_name=['/neo4j']
        tags=[]
        for rep in rep_name:
            page = 1
            flag = True
            self.harbor_tags_url = self.harbor_rep_url + rep + '/artifacts?page_size=100' \
                                                                         '&with_tag=true&with_label=false' \
                                                                         '&with_scan_overview=false' \
                                                                         '&with_signature=false' \
                                                                         '&with_immutable_status=false&page='
            #print(self.harbor_tags_url)
            rep = rep.replace("/", "")
            while flag:
                all_tags = requests.get(self.harbor_tags_url+str(page), auth=self.auth).json()
                if len(all_tags) != 0:
                    for tag_list in all_tags:
                        for tag in tag_list['tags']:
                            tag = rep+":"+tag['name']
                            print(tag)
                            tags.append(tag)
                    page += 1
                    #time.sleep(0.1)
                else:
                    flag = False
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
        result = HarborGetArtifacts(schema="https", harbor_domain=args.domain, username=args.username, password=args.password, project_name=args.project, output_name=args.output)
    except Exception as e:
        print(e)
