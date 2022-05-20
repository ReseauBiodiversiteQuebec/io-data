# pip install python-decouple

import os
from decouple import config
from shutil import which
from typing import List
from pathlib import Path
import tempfile
from run_command import run_command
from lib.pipelinelib import Status, StacItem, Collection

import pystac
from pystac.extensions.raster import RasterBand
from pystac.extensions.raster import RasterExtension
from pystac.extensions.projection import ProjectionExtension
from datetime import datetime
import rasterio
from shapely.geometry import Polygon, mapping
import requests

import s3io
import traceback
import json

# retreive environment variables from system or .env file (system is prioritized)
def getenv(varname):
	return os.getenv(varname) if os.getenv(varname) is not None else  config(varname)

def post_or_put(url: str, data: dict):
    """Post or put data to url."""
    r = requests.post(url, json=data)
    if r.status_code == 409:
        # Exists, so update
        r = requests.put(url, json=data)
        # Unchanged may throw a 404
        if not r.status_code == 404:
            r.raise_for_status()
    else:
        r.raise_for_status()

# function to upload file to any S3 client
def upload_tiff_to_server_S3(s3_client, file_path,host="", bucket="bq-io", destination="io"):
    
	""" 
	s3_client : S3 client that connect and send the files to s3 server 
				it should has method called upload_file with 4 params
	
	file_path: location of the file to be uploaded

	bucket: bucket name on S3 server

	destination: file location in the bucket, it includes filename ex: io/newfile.tiff
	"""
	status: Status = Status()

	try:
		response = s3_client.upload_file(file_path, bucket, destination, ExtraArgs={'ACL': 'public-read'})
		status._message = "file upload successful to: " + host+'/'+bucket+'/'+destination
		#print(json.dumps(response.__dict__))

	except Exception as e:
		status._message = "There was an error uploading file to: " + host+'/'+bucket+'/'+destination
		status._message += '\n' + traceback.print_exc()
		pass
	return status


# function to upload file for specifics S3 server with a specific S3 client
def upload_file_bq_sql_backup(item: StacItem):

	s3_client = s3io.create_s3_res();
	host="https://object-arbutus.cloud.computecanada.ca"
	bucket = "bq-sql-backup"
	filePath = item.getCogFilePath()
	destination =  "io/"+item.getFileName()
	return upload_tiff_to_server_S3(s3_client,filePath,host, bucket, destination)

def push_to_api(stacobject, api_host:str):

	if isinstance(stacobject,pystac.Collection):
		print(stacobject.to_dict())
		post_or_put(f"{api_host}/collections",stacobject.to_dict())
		return

	if isinstance(stacobject,pystac.Item):
		print(stacobject.to_dict())
		post_or_put(f"{api_host}/collections/{stacobject.to_dict()['collection']}/items",stacobject.to_dict())
		return
