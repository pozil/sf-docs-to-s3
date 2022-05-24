# Offload Salesforce Documents to Amazon S3

## About

This project is an integration between a Salesforce Org, Salesforce Functions and Amazon S3.
The goal of the integration is to export documents from Salesforce to S3 to reduce file storage consumption on the Salesforce side.

Thanks to Functions, we transfer documents to S3 with the following scenario:

1. User uploads and attaches a document to a record in Salesforce.
1. Apex trigger kicks in after the document is saved and calls a handler class with the document metadata (not the document binary content to avoid Apex limits).
1. Apex trigger handler class invokes a Salesforce Function asynchronously with the document metadata.
1. Function retrieves the document content using the Salesforce REST API.
1. Function uploads the document content to an Amazon S3 bucket.
1. Once the Function completes, it calls an Apex callback method on the trigger handler class.
1. Apex callback method removes the original document from Salesforce and creates a record that links the document stored in S3 to the record.

![Integration architecture](/doc-gfx/architecture.jpg)

## Installation

### Prerequisites

#### Salesforce Resources

1. [Sign up for a Salesforce Functions trial org](https://functions.salesforce.com/signups/).
1. [Enable Dev Hub](https://help.salesforce.com/s/articleView?id=sf.sfdx_setup_enable_devhub.htm&type=5) in your org.
1. [Install the Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli).
1. [Authorize](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_auth.htm) your Dev Hub in the Salesforce CLI.

#### AWS Resources

1. [Sign up for a AWS free-tier account](https://portal.aws.amazon.com/billing/signup).
1. [Create a S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html).
1. Complete these steps in the Identity and Access Management (IAM) console:
    1. [Create a policy](https://docs.amazonaws.cn/en_us/IAM/latest/UserGuide/access_policies_create-console.html) that grants write access on your S3 bucket.
    1. [Create a user](https://docs.amazonaws.cn/en_us/IAM/latest/UserGuide/id_users_create.html#id_users_create_console).
    1. [Assign your policy to the user](https://docs.amazonaws.cn/en_us/IAM/latest/UserGuide/id_users_change-permissions.html#users_change_permissions-add-console).

### Step 1: Deploy and configure the Salesforce Org

1. Install the project in a Scratch org by running this script:

    **MacOS or Linux**

    ```sh
    ./install-dev.sh
    ```

    **Windows**

    ```sh
    install-dev.bat
    ```

    You can install the project on other types of Salesforce orgs by looking at the content of the scripts and changing the commands.

1. For each Object that you would like to export document for (Account in this example), create a record for the custom metadata type "S3 Document Setting"

    1. Navigate to **Custom Code > Custom Metadata Types** in Salesforce Setup

    1. Click **Manage Records** for "S3 Document Setting"

    1. Click **New**

    1. Assuming that we want to work with the Account object, enter those values then click **Save**:
        - Label: `S3 Account Document`
        - S3 Document Setting Name: `S3_Account_Document`
        - Object API Name: `Account`

1. For each Object that you would like to export document for, create a junction object between `S3_Document__c` and your object (Account based on the previous example)

    ![Junction object](/doc-gfx/junction-object.jpg)

    1. Navigate to **Object Manager** in Salesforce Setup
    1. Click **Create** and select **Custom Object**
    1. Enter those values then click **Save**:

        - Label: `S3 Account Document`
        - Plural Label: `S3 Account Documents`
        - Object Name: `S3_Account_Document__c`
        - Record Name: `S3 Account Document ID`
        - Data Type: `Auto Number`
        - Display Format: `S3-ACC-DOC-{0000}`
        - Starting Number: `0`

    **Note:** The object name is automatically selected by the Function so naming must follow this convention: `S3_OBJECT_Document__c` where `OBJECT` is the API name of the object without the trailling `__c` for custom objects. For example, if you have a `My_Custom_Object__c` object, you should enter `S3_My_Custom_Object_Document__c`.

1. Optional: for each Object that you would like to export document for, configure related list layout to display relevant fields

    ![Related list layout configuration](/doc-gfx/related-list-layout.png)

### Step 2: Deploy and configure the Salesforce Function

1. Log in to Salesforce Functions (you may have to repeat this command later as this will eventually time out)

    ```sh
    sf login functions
    ```

1. Create a compute environment:

    ```sh
    sf env create compute --alias s3env --connected-org s3
    ```

1. Deploy the Salesforce Function:

    ```sh
    cd functions/s3import
    sf deploy functions -o s3
    ```

1. Configure the Salesforce Function with environment variables (make sure to replace values accordingly):

    ```sh
    sf env var set AWS_ACCESS_KEY_ID=XXXXXXXXXX -e s3env
    sf env var set AWS_SECRET_ACCESS_KEY=XXXXXXXXXX -e s3env
    sf env var set AWS_REGION=XXXXXXXXXX -e s3env
    sf env var set AWS_S3_BUCKET=XXXXXXXXXX -e s3env
    ```

    | Variable Name           | Description                                  | Example       |
    | ----------------------- | -------------------------------------------- | ------------- |
    | `AWS_ACCESS_KEY_ID`     | The access key ID for your AWS IAM user.     | _secret_      |
    | `AWS_SECRET_ACCESS_KEY` | The secret access key for your AWS IAM user. | _secret_      |
    | `AWS_REGION`            | The region of your S3 bucket.                | `eu-west-3`   |
    | `AWS_S3_BUCKET`         | The name of your S3 bucket.                  | `poz-sf-demo` |

## Troubleshooting

Monitor Salesforce Function's logs by running:

```sh
sf env log tail -e s3env
```

Monitor Salesforce logs by running:

```sh
sfdx force:apex:log:tail -c
```
