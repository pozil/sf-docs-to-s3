# Offload Salesforce Documents to Amazon S3

create scratch org

sf login functions
sf env create compute --alias s3env --connected-org s3

cd functions/s3import
sf deploy functions -o s3
sf env var set AWS_ACCESS_KEY_ID=XXXXXXXXXX -e s3env
sf env var set AWS_SECRET_ACCESS_KEY=XXXXXXXXXX -e s3env
sf env var set AWS_REGION=XXXXXXXXXX -e s3env
sf env var set AWS_S3_BUCKET=XXXXXXXXXX -e s3env

sf env log tail -e s3env

Create custom metadata type "S3 Document Setting" record for Account

Create pivot table object

Configure related list layout to display relevant fields
