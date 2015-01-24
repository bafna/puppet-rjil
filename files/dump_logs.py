# /bin/python

import boto
import boto.s3.connection
import glob
import ntpath
import socket
#import key
from key import *
import datetime
from datetime import date, timedelta
date_before=(datetime.date.today() - timedelta(1)).strftime("%Y%m%d")
file_pattern = '/var/log/ceph/'+'*'+date_before+'.gz'
listing = glob.glob(file_pattern)


for files in listing:
    if "radosgw" in files:
        filename=ntpath.basename(files)+"-"+socket.gethostname()
    else:
        filename=ntpath.basename(files)
    print filename
    print files
    conn = boto.connect_s3(aws_access_key_id = access_key,aws_secret_access_key = secret_key,port=port_number, debug=2,host = hostname,          is_secure=False, calling_format = boto.s3.connection.OrdinaryCallingFormat(),)
    bucket = conn.create_bucket('log_bucket')
    key = bucket.new_key(filename);
    key.set_contents_from_filename(files);

