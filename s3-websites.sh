#!/bin/bash

echo "running $0"
#Bucket 1 will be the public-facing website
#Bucket 2 will be a datasource for XHR 
S3_BUCKET_1=<add bucket name e.g website.your-route53-hosted-zone>
S3_BUCKET_2=<add bucket name e.g datasource.your-route53-hosted-zone>

#ID of your hosted zone
HOSTED_ZONE_ID=<route 53 hosted zone id>

#ID of S3 Hosted Zone ID
#For values, refer to http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region
ROUTE_53_HOSTED_ZONE_ID=<e.g. Z1WCIGYICN2BYD for Sydney>

REGION=<e.g. ap-southeast-1>

#temporary locations for 'file://' 
BUCKET_POLICY_1=./bucket_policy_1.json
WEBSITE_CONFIG_1=./website_config_1.json
CHANGE_BATCH_1=./change_batch_1.json

WEBSITE_2_CORS=./website_2_cors.json
BUCKET_POLICY_2=./bucket_policy_2.json
WEBSITE_CONFIG_2=./website_config_2.json
CHANGE_BATCH_2=./change_batch_2.json


create_resources()
{

  #Creates the S3 bucket policy for bucket 1
  cat >$BUCKET_POLICY_1  <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForGetBucketObjects",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$S3_BUCKET_1/*"
    }
  ]
}
EOF

  #Creates the S3 website config for bucket 1
  cat >$WEBSITE_CONFIG_1 <<EOF
{
  "IndexDocument": {
      "Suffix": "index.html"
  },
  "ErrorDocument": {
      "Key": "error.html"
  }
}
EOF

  #Creates the batch file for Route53 record set
  cat >$CHANGE_BATCH_1 <<EOF
{
  "Comment": "A record for $S3_BUCKET_1",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$S3_BUCKET_1",
        "Type":"A",
        "AliasTarget": {
          "HostedZoneId": "$ROUTE_53_HOSTED_ZONE_ID",
          "DNSName": "s3-website-$REGION.amazonaws.com.",
          "EvaluateTargetHealth": false 
        }
      }
    }
  ]
}
EOF

  #Creates the S3 bucket policy for bucket 2
  cat >$BUCKET_POLICY_2  <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForGetBucketObjects",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$S3_BUCKET_2/*"
    }
  ]
}
EOF

  #Creates the S3 website config for bucket 1
  cat >$WEBSITE_CONFIG_2 <<EOF
{
  "IndexDocument": {
      "Suffix": "index.html"
  },
  "ErrorDocument": {
      "Key": "error.html"
  }
}
EOF

  cat >$WEBSITE_2_CORS <<EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT", "POST", "DELETE"],
      "MaxAgeSeconds": 3000,
      "ExposeHeaders": ["x-amz-server-side-encryption"]
    },
    {
      "AllowedOrigins": ["*"],
      "AllowedHeaders": ["Authorization"],
      "AllowedMethods": ["GET"],
      "MaxAgeSeconds": 3000
    }
  ]
}

EOF

  #Creates the batch file for Route53 record set
  cat >$CHANGE_BATCH_2 <<EOF
{
  "Comment": "A record for $S3_BUCKET_2",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$S3_BUCKET_2",
        "Type":"A",
        "AliasTarget": {
          "HostedZoneId": "$ROUTE_53_HOSTED_ZONE_ID",
          "DNSName": "s3-website-$REGION.amazonaws.com.",
          "EvaluateTargetHealth": false 
        }
      }
    }
  ]
}
EOF

  #Create the S3 buckets
  aws s3 mb s3://$S3_BUCKET_1 
  aws s3 mb s3://$S3_BUCKET_2 

  #Enable website hosting on bucket 1
  aws s3api put-bucket-website --region $REGION \
                               --bucket $S3_BUCKET_1 \
                               --website-configuration file://$WEBSITE_CONFIG_1

  #Enable website hosting on bucket 2
  aws s3api put-bucket-website --region $REGION \
                               --bucket $S3_BUCKET_2 \
                               --website-configuration file://$WEBSITE_CONFIG_2

  #Allow public access to bucket 2
  aws s3api put-bucket-policy --region $REGION \
                              --bucket $S3_BUCKET_1 \
                              --policy file://$BUCKET_POLICY_1

  #Allow public access to bucket 2
  aws s3api put-bucket-policy --region $REGION \
                              --bucket $S3_BUCKET_2 \
                              --policy file://$BUCKET_POLICY_2


  #Allow cors on bucket 2
  echo "about to put cors"
  aws s3api put-bucket-cors --bucket $S3_BUCKET_2 \
                            --cors-configuration file://$WEBSITE_2_CORS
  echo "cors done?"

  #upload index.html and error.html files to bucket 1
  aws s3 cp ./index.html s3://$S3_BUCKET_1
  aws s3 cp ./error.html s3://$S3_BUCKET_1

  #upload index.html and error.html files to bucket 2
  aws s3 cp ./index-datasource.html s3://$S3_BUCKET_2/index.html
  aws s3 cp ./error.html s3://$S3_BUCKET_2
  aws s3 cp ./sample.geojson s3://$S3_BUCKET_2


  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
                                          --change-batch file://$CHANGE_BATCH_1

  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
                                          --change-batch file://$CHANGE_BATCH_2

  #Clean up
  rm $BUCKET_POLICY_1 
  rm $WEBSITE_CONFIG_1
  rm $CHANGE_BATCH_1

  rm $BUCKET_POLICY_2
  rm $WEBSITE_CONFIG_2
  rm $CHANGE_BATCH_2
  rm $WEBSITE_2_CORS

  echo "resource creation complete"

}

remove_resources()
{
  echo "removing resources"

  #Creates the batch file for Route53 record set
  cat >$CHANGE_BATCH_1 <<EOF
{
  "Comment": "A record for $S3_BUCKET_1",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "$S3_BUCKET_1",
        "Type":"A",
        "AliasTarget": {
          "HostedZoneId": "$ROUTE_53_HOSTED_ZONE_ID",
          "DNSName": "s3-website-$REGION.amazonaws.com.",
          "EvaluateTargetHealth": false 
        }
      }
    }
  ]
}
EOF

  #DELETEs the batch file for Route53 record set
  cat >$CHANGE_BATCH_2 <<EOF
{
  "Comment": "A record for $S3_BUCKET_2",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "$S3_BUCKET_2",
        "Type":"A",
        "AliasTarget": {
          "HostedZoneId": "$ROUTE_53_HOSTED_ZONE_ID",
          "DNSName": "s3-website-$REGION.amazonaws.com.",
          "EvaluateTargetHealth": false 
        }
      }
    }
  ]
}
EOF
  
  #DELETEs the s3 buckets (with --force will remove files)
  aws s3 rb s3://$S3_BUCKET_1 --force
  aws s3 rb s3://$S3_BUCKET_2 --force

  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
                                          --change-batch file://$CHANGE_BATCH_1

  aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
                                          --change-batch file://$CHANGE_BATCH_2

  echo "finished removing resources"
}


case "$1" in

    create)
    create_resources
    exit 0
    ;;
    remove)
    remove_resources
    exit 0
    ;;
    *)
    echo "Usage: supply 'create' or 'remove'"
    exit 0
    ;;
esac

