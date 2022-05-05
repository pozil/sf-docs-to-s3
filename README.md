# Offload Salesforce Documents to Amazon S3

sf login functions
sf env create compute --alias s3env --connected-org s3
sf deploy functions -o s3

sf env var set AWS_ACCESS_KEY_ID=XXXXXXXXXX -e s3env
sf env var set AWS_SECRET_ACCESS_KEY=XXXXXXXXXX -e s3env
sf env var set AWS_REGION=XXXXXXXXXX -e s3env
sf env var set AWS_S3_BUCKET=XXXXXXXXXX -e s3env

sf env log tail -e s3env
