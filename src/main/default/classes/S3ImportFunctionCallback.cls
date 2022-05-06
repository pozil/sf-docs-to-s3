public without sharing class S3ImportFunctionCallback implements functions.FunctionCallback {
    public void handleResponse(functions.FunctionInvocation invocation) {
        functions.FunctionInvocationStatus status = invocation.getStatus();
        switch on status {
            when SUCCESS {
                handleSuccess(invocation.getResponse());
            }
            when ERROR {
                handleFailure(invocation.getResponse());
            }
        }
    }

    private void handleSuccess(String rawResponse) {
        try {
            S3ImportResponse response;
            try {
                response = (S3ImportResponse) JSON.deserializeStrict(
                    rawResponse,
                    S3ImportResponse.class
                );
            } catch (Exception e) {
                throw new FunctionException(
                    'failed to parse response: ' + rawResponse
                );
            }
            try {
                insert response.s3Docs;
            } catch (Exception e) {
                throw new FunctionException(
                    'failed to insert S3_Document__c records: ' +
                    response.s3Docs
                );
            }
            try {
                delete [
                    SELECT Id
                    FROM ContentDocument
                    WHERE Id IN :response.salesforceDocIds
                ];
            } catch (Exception e) {
                throw new FunctionException(
                    'failed to delete original ContentDocument records: ' +
                    response.salesforceDocIds
                );
            }
        } catch (Exception e) {
            throw new FunctionException(
                's3import function callback error: ' + e
            );
        }
    }

    private void handleFailure(String response) {
        throw new FunctionException(
            's3import function invocation failed: ' + response
        );
    }

    private class FunctionException extends Exception {
    }

    private class S3ImportResponse {
        public List<S3_Document__c> s3Docs;
        public List<Id> salesforceDocIds;
    }
}
