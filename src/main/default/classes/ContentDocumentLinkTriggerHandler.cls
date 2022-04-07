public with sharing class ContentDocumentLinkTriggerHandler {
    private static final String S3_IMPORT_FUNCTION = 's3demo.s3import';

    public void afterInsert(List<ContentDocumentLink> newDocLinks) {
        processNewDocumentLinks(newDocLinks);
    }

    private void processNewDocumentLinks(List<ContentDocumentLink> docLinks) {
        // Get settings
        List<S3_Document_Setting__mdt> settings = S3_Document_Setting__mdt.getAll()
            .values();
        Set<String> enabledEntities = new Set<String>();
        for (S3_Document_Setting__mdt setting : settings) {
            enabledEntities.add(setting.Object_API_Name__c);
        }
        // Filter docs based on settings
        Map<Id, String> entyTypes = new Map<Id, String>();
        Map<Id, ContentDocumentLink> filteredLinks = new Map<Id, ContentDocumentLink>();
        for (ContentDocumentLink link : docLinks) {
            // Get linked entity object type
            String objectAPIName = link.LinkedEntityId.getSObjectType()
                .getDescribe()
                .getName();
            entyTypes.put(link.ContentDocumentId, objectAPIName);
            // Filter entities based on object type
            if (enabledEntities.contains(objectApiName)) {
                filteredLinks.put(link.ContentDocumentId, link);
            }
        }
        // Share and import relevant docs
        if (filteredLinks.size() > 0) {
            shareDocuments(filteredLinks.values());
            List<SalesforceDocInfo> docs = getDocumentInfos(
                filteredLinks,
                entyTypes
            );
            importDocumentInS3(docs);
        }
    }

    /**
     * Share documents with the cloud integration user for Function access
     */
    private void shareDocuments(List<ContentDocumentLink> docLinks) {
        User cloudIntegrationUser = [
            SELECT Id, UserName
            FROM User
            WHERE username LIKE 'cloud@00d%'
            LIMIT 1
        ];
        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (ContentDocumentLink docLink : docLinks) {
            ContentDocumentLink newLink = new ContentDocumentLink();
            newLink.ContentDocumentId = docLink.ContentDocumentId;
            newLink.LinkedEntityId = cloudIntegrationUser.Id;
            newLink.ShareType = 'V';
            newLinks.add(newLink);
        }
        insert newLinks;
    }

    private List<SalesforceDocInfo> getDocumentInfos(
        Map<Id, ContentDocumentLink> docMap,
        Map<Id, String> entyTypes
    ) {
        List<SalesforceDocInfo> docs = new List<SalesforceDocInfo>();
        Set<Id> docIds = docMap.keySet();
        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, PathOnClient, OwnerId
            FROM ContentVersion
            WHERE IsLatest = TRUE AND ContentDocumentId IN :docIds
        ];
        for (ContentVersion version : versions) {
            ContentDocumentLink docLink = docMap.get(version.ContentDocumentId);
            SalesforceDocInfo doc = new SalesforceDocInfo();
            doc.contentVersionId = version.Id;
            doc.contentDocumentId = version.ContentDocumentId;
            doc.linkedEntityId = docLink.LinkedEntityId;
            doc.linkedEntityApiName = entyTypes.get(version.ContentDocumentId);
            doc.pathOnClient = version.PathOnClient;
            doc.ownerId = version.OwnerId;
            docs.add(doc);
        }
        return docs;
    }

    private void importDocumentInS3(List<SalesforceDocInfo> docs) {
        String payload = JSON.serialize(docs);
        functions.Function function = functions.Function.get(
            S3_IMPORT_FUNCTION
        );
        functions.FunctionInvocation invocation = function.invoke(
            payload,
            new S3ImportCallback()
        );
    }

    public class S3ImportCallback implements functions.FunctionCallback {
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
            FunctionResponse response = (FunctionResponse) JSON.deserializeStrict(
                rawResponse,
                FunctionResponse.class
            );
            insert response.s3docs;
            delete [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN :response.salesforceDocIds
            ];
        }

        private void handleFailure(String response) {
            throw new FunctionException(
                S3_IMPORT_FUNCTION +
                ' function invocation failed: ' +
                response
            );
        }
    }

    public class FunctionException extends Exception {
    }

    public class FunctionResponse {
        public List<S3_Document__c> s3docs;
        public List<Id> salesforceDocIds;
    }

    public class SalesforceDocInfo {
        public Id contentDocumentId;
        public Id contentVersionId;
        public Id linkedEntityId;
        public String linkedEntityApiName;
        public String pathOnClient;
        public Id ownerId;
    }
}
