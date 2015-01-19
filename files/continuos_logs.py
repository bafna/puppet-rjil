# /bin/python

import boto
import boto.s3.connection
import glob
import ntpath
import socket
#import key
from key import *
listing = glob.glob('/var/log/ceph/*.log')

for files in listing:
    filename=ntpath.basename(files)+"-"+socket.gethostname()
    print filename
    print files
    conn = boto.connect_s3(aws_access_key_id = access_key,aws_secret_access_key = secret_key,port=7480,debug=2,host = '10.140.214.196',          is_secure=False, calling_format = boto.s3.connection.OrdinaryCallingFormat(),)
    bucket = conn.create_bucket('log_bucket')
    key = bucket.new_key(filename);
    key.set_contents_from_filename(files);


