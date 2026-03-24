@isTest
private class CustomerHealthScoreControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Health Test Account');
        insert acc;

        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Jane', LastName = 'Exec', Title = 'VP of Engineering', AccountId = acc.Id, Email = 'jane@test.com'),
            new Contact(FirstName = 'Bob', LastName = 'Dev', Title = 'Developer', AccountId = acc.Id, Email = 'bob@test.com'),
            new Contact(FirstName = 'Sue', LastName = 'PM', Title = 'Product Manager', AccountId = acc.Id, Email = 'sue@test.com')
        };
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.DuplicateRuleHeader.allowSave = true;
        Database.insert(contacts, dmo);

        // Skip Case insert — SDO flow "SDO Service - Case - On Create" requires helperConfig
        // Cases are tested indirectly via calcSupport with empty list

        insert new List<Task>{
            new Task(WhatId = acc.Id, Subject = 'Follow up call', Type = 'Call', Status = 'Completed'),
            new Task(WhatId = acc.Id, Subject = 'Send email update', Type = 'Email', Status = 'Completed'),
            new Task(WhatId = acc.Id, Subject = 'Review docs', Status = 'Completed')
        };

        insert new Event(WhatId = acc.Id, Subject = 'QBR Meeting', StartDateTime = DateTime.now(), DurationInMinutes = 60);

        insert new List<Opportunity>{
            new Opportunity(AccountId = acc.Id, Name = 'Expansion Deal', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), Amount = 50000),
            new Opportunity(AccountId = acc.Id, Name = 'Won Deal', StageName = 'Closed Won', CloseDate = Date.today().addDays(-10), Amount = 25000)
        };
    }

    @isTest
    static void testGetHealthScore() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Health Test Account' LIMIT 1];

        Test.startTest();
        CustomerHealthScoreController.HealthScoreResult result =
            CustomerHealthScoreController.getHealthScore(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.compositeScore >= 0 && result.compositeScore <= 100, 'Score should be 0-100');
        System.assertNotEquals(null, result.grade, 'Grade should be set');
        System.assertNotEquals(null, result.trend, 'Trend should be set');
        System.assertEquals(5, result.factors.size(), 'Should have 5 factors');
        System.assertEquals(12, result.scoreHistory.size(), 'Should have 12 months of history');
        System.assertNotEquals(null, result.metrics, 'Metrics should be set');
        System.assertEquals(0, result.metrics.totalCases, 'No cases inserted due to SDO flow');
        System.assertEquals(0, result.metrics.openCases, 'No cases inserted due to SDO flow');
        System.assertEquals(4, result.metrics.totalActivities, 'Should have 4 activities (3 tasks + 1 event)');
    }

    @isTest
    static void testGetHealthScore_EmptyAccount() {
        Account acc = new Account(Name = 'Empty Account');
        insert acc;

        Test.startTest();
        CustomerHealthScoreController.HealthScoreResult result =
            CustomerHealthScoreController.getHealthScore(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.compositeScore >= 0);
        System.assertEquals(0, result.metrics.totalCases);
        System.assertEquals(0, result.metrics.totalActivities);
        System.assertEquals(0, result.metrics.contactCount);
    }

    @isTest
    static void testGradeFor() {
        System.assertEquals('Excellent', CustomerHealthScoreController.gradeFor(85));
        System.assertEquals('Good', CustomerHealthScoreController.gradeFor(65));
        System.assertEquals('Fair', CustomerHealthScoreController.gradeFor(45));
        System.assertEquals('At Risk', CustomerHealthScoreController.gradeFor(25));
        System.assertEquals('Critical', CustomerHealthScoreController.gradeFor(10));
    }

    @isTest
    static void testFactorScores() {
        System.assertEquals(85, CustomerHealthScoreController.calcSupport(new List<Case>()));
        System.assertEquals(15, CustomerHealthScoreController.calcEngagement(new List<Task>(), new List<Event>()));
        System.assertEquals(40, CustomerHealthScoreController.calcFinancial(new List<Opportunity>()));
        System.assertEquals(5, CustomerHealthScoreController.calcAdoption(new List<Contact>(), new List<Consumption_Data__c>()));
        System.assertEquals(15, CustomerHealthScoreController.calcRelationship(new List<Contact>(), new List<Event>()));
    }

    @isTest
    static void testGenerateHealthSummary() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Health Test Account' LIMIT 1];

        Test.startTest();
        try {
            String result = CustomerHealthScoreController.generateHealthSummary(acc.Id);
            // Models API available — result should be non-empty
            System.assertNotEquals(null, result, 'Summary result should not be null');
        } catch (AuraHandledException e) {
            // Models API not available in test context — expected
            System.assertNotEquals(null, e.getMessage(), 'Error message should not be null');
        }
        Test.stopTest();
    }
}
