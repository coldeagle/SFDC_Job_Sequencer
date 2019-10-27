/**
 * Copyright 2019 Jason Hardy
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
@IsTest
public with sharing class JobSequenceTests {
    @TestSetup static void createData() {
        User thisUser = [SELECT Id FROM User WHERE Id =:UserInfo.getUserId()];
        System.runAs(thisUser) {
            update thisUser;
        }
    }

    @IsTest static void JobSequenceClassRetryTest() {
        Test.startTest();
        JobSequence js = new JobSequence();
        List<Job_Sequence_Error__c> jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(jse.isEmpty(),'Errors already present!');
        String frequency = 'Test Only';
        List<Sequence_Job__mdt> sjs = Database.query(JobSequenceQueueable.constructSequenceJobQuery(frequency));
        js = new JobSequence(sjs[0]);
        js.scheduleRetry(js);
        js.numRetries = Integer.valueOf(js.sjcs.MaxRetries__c)+1;
        Boolean errorThrown = false;
        try {
            js.scheduleRetry(js);
        } catch(Exception e) {
            errorThrown = true;
        }
        System.assert(errorThrown,'An error was not thrown when max retries were hit');
        errorThrown = false;
        try {
            js.noParametersFoundError();
        } catch(Exception e) {
            errorThrown = true;
        }
        System.assert(errorThrown,'An error was not thrown when max retries were hit');
        Test.stopTest();
    }

    @IsTest static void JobSequenceBatchInvalidFunctionTest() {
        Test.startTest();
        List<Job_Sequence_Error__c> jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(jse.isEmpty(),'Errors already present!');
        JobSequence js = new JobSequence();
        String frequency = 'Test Only';
        List<Sequence_Job__mdt> sjs = Database.query(JobSequenceQueueable.constructSequenceJobQuery(frequency));
        js = new JobSequence(sjs[0]);
        js.executionJob = 'thisIsNotAValidFunction';
        js.query = 'SELECT Id FROM User LIMIT 1';
        js.isBatchJob = true;
        JobSequenceBatch jsb = new JobSequenceBatch(js);
        Database.executeBatch(jsb,200);
        Test.stopTest();
        jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(!jse.isEmpty(),'Errors were not created!');
    }

    @IsTest static void JobSequenceExeBadHandlerTest() {
        Job_Sequence_Error__c jse = new Job_Sequence_Error__c(JobFrequency__c='Test Only',BatchJobId__c='Test',Exception__c='Testing');
        insert jse;
        Test.startTest();
        JobSequence js = constructTestJobSequenceErrorJobSequenceObj();
        js.handlerName = 'JobSequenceTests';
        JobSequenceExe.executeQueueable(js);

        Test.stopTest();
        List<Job_Sequence_Error__c> jses = [SELECT Id FROM Job_Sequence_Error__c WHERE Id <> :jse.Id];
        js.sendErrorEmail(null,jses);
        System.assert(!jses.isEmpty(),'Errors were not created for a bad handler name!');
    }

    @IsTest static void JobSequenceExeDeleteTest() {
        Job_Sequence_Error__c jse = new Job_Sequence_Error__c(JobFrequency__c='Test Only',BatchJobId__c='Test',Exception__c='Testing');
        insert jse;
        Test.startTest();
        JobSequence js = constructTestJobSequenceErrorJobSequenceObj();
        JobSequenceExe.executeQueueable(js);

        Test.stopTest();
        List<Job_Sequence_Error__c> jses = [SELECT Id FROM Job_Sequence_Error__c WHERE Id =:jse.Id];
        System.assert(jses.isEmpty(),'The errors were not deleted');
    }

    @IsTest static void JobSequenceExeUpsertTests() {
        Job_Sequence_Error__c jse = new Job_Sequence_Error__c(JobFrequency__c='Test Only',BatchJobId__c='Test',Exception__c='Testing');
        insert jse;
        Test.startTest();
        JobSequence js = constructTestJobSequenceErrorJobSequenceObj();
        js.executionJob = 'UPSERT';
        JobSequenceExe.executeQueueable(js);

        Test.stopTest();
        List<Job_Sequence_Error__c> jses = [SELECT Id FROM Job_Sequence_Error__c WHERE Id <> :jse.Id];
        System.assert(jses.isEmpty(),'New error records were created!');
    }

    @IsTest static void JobSequenceQueueableInvalidFunctionTest() {
        Test.startTest();
        List<Job_Sequence_Error__c> jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(jse.isEmpty(),'Errors already present!');
        JobSequence js = new JobSequence();
        String frequency = 'Test Only';
        List<Sequence_Job__mdt> sjs = Database.query(JobSequenceQueueable.constructSequenceJobQuery(frequency));
        sjs[0].ExecutionJob__c = 'thisIsNotAValidFunction';
        sjs[0].IsBatchJob__c = false;
        js = new JobSequence(sjs[0]);
        System.enqueueJob(new JobSequenceQueueable(js,true));
        Test.stopTest();
        jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(!jse.isEmpty(),'Errors were not created!');
    }

    @IsTest static void JobSequenceQueueableTests() {
        Test.startTest();
        System.enqueueJob(new JobSequenceQueueable('Test Only'));
        Test.stopTest();
        List<Sequence_Job__mdt> testOnlySequences = Database.query(JobSequenceQueueable.constructSequenceJobQuery('Test Only'));
        Sequence_Job__mdt mainTest;
        for (Sequence_Job__mdt sj : testOnlySequences) {
            if (sj.DeveloperName == 'TEST_FIELDSHIFT_FUNCTION') mainTest = sj;
        }
        Map<String,String> params = new Map<String,String>();
        for (String param : mainTest.Parameters__c.split(',')) {
            List<String> paramList = param.split(':');
            params.put(paramList[0],paramList[1]);
        }
        Boolean testsPassed = false;
        Set<String> paramsFound = new Set<String>();
        JobSequence js = new JobSequence(mainTest);
        for (User u : (List<User>) Database.query(js.query)) {
            for (String param : params.keySet()) {
                String fldVal = u.getPopulatedFieldsAsMap().containsKey(param) ? String.valueOf(u.get(param)) : '';
                if (param.containsIgnoreCase('Test.IsRunningTest')) paramsFound.add(param);
                if (!paramsFound.contains(param)) {
                    if (fldVal == params.get(param)) {
                        paramsFound.add(param);
                    }
                }
            }
            if (paramsFound.size() == params.size()) {
                testsPassed = true;
                break;
            }
        }
        System.assert(testsPassed,'The test did not pass!');
    }

    @IsTest static void JobSequenceSchedulableTests() {
        Test.startTest();
        List<Job_Sequence_Error__c> jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(jse.isEmpty(),'Errors already present!');
        String frequency = 'Test Only';
        List<Sequence_Job__mdt> sjs = Database.query(JobSequenceQueueable.constructSequenceJobQuery(frequency));
        JobSequence js = new JobSequence(sjs[0]);
        JobSequenceSchedulable jss = new JobSequenceSchedulable(js);
        jss.execute(null);
        JobSequenceSchedulable.getJobSequenceErrorMessage();
        JobSequenceSchedulable.getQueueableNullError();
        js.numRetries = Integer.valueOf(js.sjcs.MaxRetries__c)+1;
        jss = new JobSequenceSchedulable(js,true);
        System.schedule('testSchedule', '0 0 * * * ?', jss);
        Test.stopTest();
        jse = [SELECT Id FROM Job_Sequence_Error__c];
        System.assert(!jse.isEmpty(),'Errors were not created!');
    }

    @IsTest static void JobSequenceHourlyTests() {
        Test.startTest();
        new JobSequenceHourly().execute(null);
        Test.stopTest();
    }

    @IsTest static void JobSequenceDailyTests() {
        Test.startTest();
        new JobSequenceDaily().execute(null);
        Test.stopTest();
    }

    @IsTest static void JobSequenceWeeklyTests() {
        Test.startTest();
        new JobSequenceWeekly().execute(null);
        Test.stopTest();
    }

    @IsTest static void JobSequenceMonthlyTests() {
        Test.startTest();
        new JobSequenceMonthly().execute(null);
        Test.stopTest();
    }

    @IsTest static void JobSequenceYearlyTests() {
        Test.startTest();
        new JobSequenceYearly().execute(null);
        Test.stopTest();
    }

    @IsTest static void JobSequenceUtilitiesScheduleAll() {
        Test.startTest();
        JobSequenceUtilities.scheduleAllRuns();
        Test.stopTest();
    }

    @IsTest static void JobSequenceUtilitiesChangeSobjectValueFromParameters() {
        Test.startTest();
        Opportunity opp = new Opportunity();
        Opportunity adjustedOpp = (Opportunity) JobSequenceUtilities.changeSobjectValueFromParameters(
                opp,
                opp.getSObjectType().getDescribe().fields.getMap(),
                new Map<String,String>{
                        'Amount'=>'100',
                        'CloseDate'=>String.valueOf(Date.today()),
                        'IsPrivate'=>'true',
                        'Name'=>'test'
                }
        );
        System.assertEquals(adjustedOpp.Amount,100,'The amount was not set!');
        System.assertEquals(adjustedOpp.CloseDate.format(),Date.today().format(),'The Close Date was not set!');
        System.assertEquals(adjustedOpp.Name,'test','The name was not set!');
        System.assert(adjustedOpp.IsPrivate,'Is Private was not set!');

        Test.stopTest();
    }

    @IsTest static void JobSequenceVisualforceContTests() {
        Test.startTest();
        JobSequenceVisualforceCont jsvc = new JobSequenceVisualforceCont();
        System.assert(jsvc.getPageRefForSequenceJobs() != null, 'The page reference was returned as null');
        System.assert(jsvc.getPageRefForSequenceJobCustomSettingSetup() != null, 'The page reference was returned as null');
        jsvc.scheduleHourlyRun();
        jsvc.scheduleDailyRun();
        jsvc.scheduleWeeklyRun();
        jsvc.scheduleMonthlyRun();
        jsvc.scheduleQuarterlyRun();
        jsvc.scheduleYearlyRun();
        System.assertEquals(6,[SELECT Id FROM AsyncApexJob].size(),'The correct number of jobs were not scheduled');
        jsvc.scheduleAllRuns();

        Test.stopTest();
    }

    @IsTest static void JobSequenceVisualforceContSchAllTests() {
        Test.startTest();
        JobSequenceVisualforceCont jsvc = new JobSequenceVisualforceCont();
        jsvc.scheduleAllRuns();
        System.assertEquals(6,[SELECT Id FROM AsyncApexJob].size(),'The correct number of jobs were not scheduled');
        Test.stopTest();
    }

    private static JobSequence constructTestJobSequenceErrorJobSequenceObj() {
        JobSequence js = new JobSequence();
        js.allOrNone = true;
        js.batchSize = 200;
        js.currentJob = 'Test';
        js.executionJob = 'DELETE';
        js.jobFrequency = 'Test Only';
        js.jobType = 'DML';
        js.paramStringsByStrings = null;
        js.query = 'SELECT Id FROM Job_Sequence_Error__c WHERE BatchJobId__c = \'Test\'';
        js.permDelete = true;
        js.upsertField = null;
        js.isBatchJob = false;
        js.handlerName = 'JobSequenceDefaultHandler';
        return js;
    }

}