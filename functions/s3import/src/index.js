import 'dotenv/config';
import { HttpService } from './httpService.js';
import { S3Service } from './s3Service.js';

// Check and retrieve Function environment variables
[
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION',
    'AWS_S3_BUCKET'
].forEach((varName) => {
    if (!process.env[varName]) {
        console.error(`Missing ${varName} environment variable`);
        process.exit(-1);
    }
});
const { AWS_REGION, AWS_S3_BUCKET } = process.env;
S3Service.init(AWS_REGION);

// Polyfill for Error cause
const OriginalError = global.Error;
class Error extends OriginalError {
    constructor(msg, options) {
        super(msg);
        if (options?.cause) {
            this.cause = options.cause;
        }
    }

    toString() {
        let value = this.message;
        if (this.cause) {
            value += `\nCaused by: ${this.cause}`;
        }
        return value;
    }
}

/**
 * Uploads the provided documents to AWS S3 and removes the original documents
 * @param event: represents the data associated with the occurrence of an event, and
 *                 supporting metadata about the source of that occurrence.
 * @param context: represents the connection to Functions and your Salesforce org.
 * @param logger: logging handler used to capture application logs and trace specifically
 *                 to a given execution of a function.
 */
export default async function (event, context, logger) {
    const docs = event.data || [];
    const s3Docs = [];
    for (const doc of docs) {
        try {
            s3Docs.push(await processDocument(doc, context, logger));
        } catch (err) {
            const newErr = new Error(
                `Failed to import ${JSON.stringify(doc)} in S3`,
                {
                    cause: err
                }
            );
            logger.error(newErr.toString());
            throw newErr;
        }
    }
    return {
        s3Docs,
        salesforceDocIds: docs.map((doc) => doc.contentDocumentId)
    };
}

async function processDocument(doc, context, logger) {
    try {
        const docContent = await downloadSalesforceDoc(
            doc.contentVersionId,
            context
        );
        const s3DocKey = await uploadS3Doc(doc, docContent, logger);
        // Return an S3 Document record
        return {
            attributes: {
                type: 'S3_Document__c'
            },
            Name: doc.pathOnClient,
            URL__c: encodeURI(
                `https://${AWS_S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com/${s3DocKey}`
            ),
            Account__c: doc.linkedEntityId
        };
    } catch (err) {
        throw new Error(`Failed to process document`, {
            cause: err
        });
    }
}

/**
 * Downloads a document using Salesforce REST API
 * @param {string} contentVersionId
 * @param {*} context function context
 * @returns byte buffer that contains document content
 */
async function downloadSalesforceDoc(contentVersionId, context) {
    const { apiVersion, domainUrl } = context.org;
    const { accessToken } = context.org.dataApi;
    const options = {
        hostname: domainUrl.substring(8), // Remove https://
        path: `/services/data/v${apiVersion}/sobjects/ContentVersion/${contentVersionId}/VersionData`,
        headers: {
            Authorization: `Bearer ${accessToken}`
        }
    };
    try {
        return await HttpService.get(options);
    } catch (err) {
        throw new Error(`Failed to download Salesforce doc`, { cause: err });
    }
}

/**
 * Uploads a document to an S3 bucket
 * @param {S3Service} s3Service S3 service
 * @param {*} doc document metadata
 * @param {Buffer} docContent byte buffer that contains document content
 * @param {*} logger function logger
 * @returns S3 document key
 */
async function uploadS3Doc(doc, docContent, logger) {
    const Key = `${doc.linkedEntityId}/${doc.pathOnClient}`;
    const bucketParams = {
        Bucket: AWS_S3_BUCKET,
        Key,
        Body: docContent,
        Metadata: {
            'sfdc-owner-id': doc.ownerId,
            'sfdc-linked-entity-id': doc.linkedEntityId,
            'sfdc-linked-entity-api-name': doc.linkedEntityApiName
        }
    };

    try {
        logger.debug(`Uploading doc to S3 ${JSON.stringify(bucketParams)}`);
        await S3Service.uploadDoc(bucketParams);
        return Key;
    } catch (err) {
        throw new Error(`Failed to upload doc to S3`, { cause: err });
    }
}
