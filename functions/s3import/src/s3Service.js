import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

let s3Client;

export class S3Service {
    /**
     * Initializes the S3 service
     * @param {string} region
     */
    static init(region) {
        s3Client = new S3Client({ region });
    }

    /**
     * Uploads a document to an S3 bucket
     * @param {*} bucketParams
     */
    static async uploadDoc(bucketParams) {
        try {
            await s3Client.send(new PutObjectCommand(bucketParams));
        } catch (err) {
            throw new Error(`S3 error`, { cause: err });
        }
    }
}
