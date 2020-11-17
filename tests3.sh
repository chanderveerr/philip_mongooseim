#!/bin/sh
# Create some text file
echo qwerty > tmp.txt

# Get the size of the file
filesize="$(wc -c tmp.txt | awk '{print $1}')"

# Set the content type
content_type="text/plain"

# Generate upload/download URLs
urls="$(_build/prod/rel/mongooseim/bin/mongooseimctl http_upload localhost test.txt "$filesize" "$content_type" 600)"
put_url="$(echo "$urls" | awk '/PutURL:/ {print $2}')"
get_url="$(echo "$urls" | awk '/GetURL:/ {print $2}')"

# Try to upload a file. Note that if 'add_acl' option is
# enabled, then you must also add 'x-amz-acl' header:
#    -H "x-amz-acl: public-read"
curl -v -T "./tmp.txt" -H "Content-Type: $content_type" "$put_url"

# Try to download a file
curl -i "$get_url"

