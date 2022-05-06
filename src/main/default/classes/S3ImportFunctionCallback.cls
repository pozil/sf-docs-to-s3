public with sharing class S3ImportFunctionCallback implements functions.FunctionCallback {
    public void handleResponse(functions.FunctionInvocation invocation) {
        try {
            functions.FunctionInvocationStatus status = invocation.getStatus();
            switch on status {
                when SUCCESS {
                    handleSuccess(invocation.getResponse());
                }
                when ERROR {
                    handleFailure(invocation.getResponse());
                }
            }
        } catch (Exception e) {
            throw new FunctionException(
                's3import function callback error: ' + e
            );
        }
    }

    private void handleSuccess(String rawResponse) {
        // Parse JSON response
        S3ImportResponse response;
        try {
            response = (S3ImportResponse) JSON.deserializeStrict(
                rawResponse,
                S3ImportResponse.class
            );
        } catch (Exception e) {
            throw new FunctionException(
                'failed to parse JSON response: ' + rawResponse
            );
        }
        // Delete original ContentDocument records
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
    }

    private void handleFailure(String rawResponse) {
        throw new FunctionException('received error response: ' + rawResponse);
    }

    private class FunctionException extends Exception {
    }

    private class S3ImportResponse {
        public List<Id> salesforceDocIds;
    }
}
