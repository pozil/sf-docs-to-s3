@isTest
private class ContentDocumentLinkTriggerHandlerTest {
    private static Integer fakeIdCounter = 0;

    private static final String INVOCATION_ID = '000000000000000';
    private static final String DOC_NAME = 'sample.pdf';
    private static final String DOC_URL = 'https://mock.com/sample.pdf';

    @isTest
    static void afterInsert_works() {
        Account acc = new Account(Name = 'Test account');
        insert acc;
        Contact con = new Contact(LastName = 'Test contact');
        insert con;
        // Create test docs and link them to an account and a contact
        ContentVersion accDocVersion = createTestDoc(DOC_NAME);
        ContentVersion conDocVersion = createTestDoc('conDocPath');
        Id accDocId = accDocVersion.ContentDocumentId;
        Id conDocId = conDocVersion.ContentDocumentId;
        List<ContentDocumentLink> newDocLinks = new List<ContentDocumentLink>{
            new ContentDocumentLink(
                LinkedEntityId = acc.Id,
                ContentDocumentId = accDocId
            ),
            new ContentDocumentLink(
                LinkedEntityId = con.Id,
                ContentDocumentId = conDocId
            )
        };

        // Prepare mock function (not testing callback)
        MockS3ImportFunction mockFunction = new MockS3ImportFunction();
        mockFunction.response = '{ "s3docs": [], "salesforceDocIds": [] }';
        Test.setMock(functions.FunctionInvokeMock.class, mockFunction);

        // Call trigger handler with docs
        new ContentDocumentLinkTriggerHandler().afterInsert(newDocLinks);

        // Check that only the account doc is passed to the function
        ContentDocumentLinkTriggerHandler.SalesforceDocInfo doc = new ContentDocumentLinkTriggerHandler.SalesforceDocInfo();
        doc.contentDocumentId = accDocId;
        doc.contentVersionId = accDocVersion.Id;
        doc.linkedEntityId = acc.Id;
        doc.linkedEntityApiName = 'Account';
        doc.pathOnClient = DOC_NAME;
        doc.ownerId = UserInfo.getUserId();
        List<ContentDocumentLinkTriggerHandler.SalesforceDocInfo> expectedRequest = new List<ContentDocumentLinkTriggerHandler.SalesforceDocInfo>{
            doc
        };
        String expectedRequestJson = JSON.serialize(expectedRequest);
        System.assertEquals(expectedRequestJson, mockFunction.requestPayload);
    }

    @isTest
    static void s3ImportCallback_works() {
        // Create a test account and two docs
        Account acc = new Account(Name = 'Test account');
        insert acc;
        ContentVersion accDocVersion = createTestDoc(DOC_NAME);
        Id accDocId = accDocVersion.ContentDocumentId;
        createTestDoc('other');
        // Prepare function response
        ContentDocumentLinkTriggerHandler.FunctionResponse response = new ContentDocumentLinkTriggerHandler.FunctionResponse();
        response.s3docs = new List<S3_Document__c>{
            new S3_Document__c(
                Name = DOC_NAME,
                URL__c = DOC_URL,
                Account__c = acc.Id
            )
        };
        response.salesforceDocIds = new List<Id>{ accDocId };

        // Test function callback
        functions.FunctionInvocation invocation = functions.MockFunctionInvocationFactory.createSuccessResponse(
            INVOCATION_ID,
            JSON.serialize(response)
        );
        new ContentDocumentLinkTriggerHandler.S3ImportCallback()
            .handleResponse(invocation);

        // Check that Salesforce doc was removed for the account
        List<ContentDocument> sfDocs = [SELECT Title FROM ContentDocument];
        System.assertEquals(
            1,
            sfDocs.size(),
            'Expected a single ContentDocument'
        );
        System.assertNotEquals(DOC_NAME, sfDocs[0].Title);

        // Check that S3 doc was added for the account
        List<S3_Document__c> s3Docs = [
            SELECT Name, URL__c, Account__c
            FROM S3_Document__c
        ];
        System.assertEquals(
            1,
            s3Docs.size(),
            'Expected a single S3_Document__c for Account'
        );
        System.assertEquals(DOC_NAME, s3Docs[0].Name);
        System.assertEquals(DOC_URL, s3Docs[0].URL__c);
        System.assertEquals(acc.Id, s3Docs[0].Account__c);
    }

    private static ContentVersion createTestDoc(String pathOnClient) {
        ContentVersion docVersion = new ContentVersion(
            Title = 'TestDocVersion',
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert docVersion;
        docVersion = [
            SELECT Id, ContentDocumentId, OwnerId
            FROM ContentVersion
            WHERE Id = :docVersion.Id
            LIMIT 1
        ];
        return docVersion;
    }

    public class MockS3ImportFunction implements functions.FunctionInvokeMock {
        public String response = '{"message": "Default success message"}';
        public String error = 'Function returned an error!';
        public Boolean throwError = false;
        public String requestPayload = '';

        public functions.FunctionInvocation respond(
            String functionName,
            String requestPayload
        ) {
            this.requestPayload = requestPayload;

            if (throwError) {
                return functions.MockFunctionInvocationFactory.createErrorResponse(
                    INVOCATION_ID,
                    functions.FunctionErrorType.FUNCTION_EXCEPTION,
                    error
                );
            }

            return functions.MockFunctionInvocationFactory.createSuccessResponse(
                INVOCATION_ID,
                response
            );
        }
    }
}
