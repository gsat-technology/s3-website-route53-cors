
# S3 public website demonstration
A scripted demo of using the AWS CLI to create two S3 'website enabled' sites. The first website is a public facing site with a Google Map view. The second website is public facing but is intended as a remote datasource for the first website to request data from.

This demo also shows how to configure CORS on the second website which is required as a mechanism so that the first website can make requests without the user's browser enforcing the same-origin-policy

Requirements
- The AWS CLI tool must be installed
- A Route53 hosted zone is required

Setup
- edit s3-website.sh to edit variables at start of script (see comments in script)
- To find `ROUTE_53_HOSTED_ZONE_ID` go to http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region and find table under the _Amazon Simple Storage Service Website Endpoints_ section
- Edit index.html and change `map.data.loadGeoJson('http://<datasource-bucket/sample.geojson');` so that the domain is as per your value in `S3_BUCKET_2` in s3-websites.sh

#### Create
```bash
./s3-websites.sh create
```

#### Teardown
```bash
./s3-websites.sh remove
```
