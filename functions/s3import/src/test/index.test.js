import { expect } from 'chai';
import { readFileSync } from 'fs';
import { createSandbox } from 'sinon';

// Mocked dependencies
import { HttpService } from '../httpService.js';
import { S3Service } from '../s3Service.js';

import execute from '../index.js';
const PAYLOAD = JSON.parse(
    readFileSync(new URL('data/payload.json', import.meta.url))
);
const RESULTS = JSON.parse(
    readFileSync(new URL('data/results.json', import.meta.url))
);
const MOCK_DOMAIN = 'mockDomain';
const MOCK_API_VERSION = 'mockApiVersion';
const MOCK_ACCESS_TOKEN = 'mockAccessToken';
const EXPECTED_GET_PARAMS = {
    hostname: MOCK_DOMAIN,
    path: `/services/data/v${MOCK_API_VERSION}/sobjects/ContentVersion/${PAYLOAD[0].contentVersionId}/VersionData`,
    headers: { Authorization: `Bearer ${MOCK_ACCESS_TOKEN}` }
};

describe('s3import', () => {
    let sandbox;
    const mockContext = {
        org: {
            apiVersion: MOCK_API_VERSION,
            domainUrl: `https://${MOCK_DOMAIN}`,
            dataApi: {
                accessToken: MOCK_ACCESS_TOKEN
            }
        }
    };
    const mockLogger = {
        info: console.info,
        error: console.error,
        debug: () => {}
    };

    beforeEach(() => {
        sandbox = createSandbox();
        sandbox.stub(HttpService, 'get').returns(Buffer.from('mockContent'));
        sandbox.stub(S3Service, 'init');
        sandbox.stub(S3Service, 'uploadDoc');
    });

    afterEach(() => {
        sandbox.restore();
    });

    it('Invoke s3import with valid data', async () => {
        // Invoke function
        const results = await execute(
            { data: PAYLOAD },
            mockContext,
            mockLogger
        );

        // Check for service accesses
        sandbox.assert.calledOnce(HttpService.get);
        sandbox.assert.calledWith(HttpService.get, EXPECTED_GET_PARAMS);
        sandbox.assert.calledOnce(S3Service.uploadDoc);

        // Validate results
        expect(results).to.be.eql(RESULTS);
    });
});
