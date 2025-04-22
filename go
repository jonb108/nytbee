#!/bin/sh
scp logical9@logicalpoetry.com:/tmp/cgi.tar .; scp logical9@logicalpoetry.com:/tmp/html.tar .
cd cgi-bin
tar xvf ../cgi.tar
cd ../nytbee
tar xvf ../html.tar
cd ..
rm *.tar
