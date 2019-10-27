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
 *
 * ----------------------------------------------------------------------------------------
 *
 * This is the a wrapper class which is used by the various job sequence management class to exchange a job. Additionally,
 * contains various functions to manage aspects of a particular job sequence.
 */
global without sharing class JobSequence {
    global Boolean allOrNone {
        get {
            if (this.allOrNone == null) this.allOrNone = true;
            return this.allOrNone;
        }
        set;
    }
    global Boolean isBatchJob {
        get {
            if (this.isBatchJob == null) this.isBatchJob = false;
            return this.isBatchJob;
        }
        set;
    }
    global Boolean permDelete {
        get {
            if (this.permDelete == null) this.permDelete = false;
            return this.permDelete;
        }
        set;
    }
    //This property is used primarily when a date time variable needs to be used to query against if it's specific
    //has to be hard wired like this because of the way that dynamic queries work.
    private Datetime g_DateTimeVar {get;set;}

    global Id jobId {get;set;}

    global String currentJob {get;set;}
    global String executionJob {get;set;}
    global String handlerName { //The name of the handler class that will be run. If none, we'll use the default
        get {
            if (this.handlerName == null) this.handlerName = 'JobSequenceDefaultHandler';
            return this.handlerName;
        }
        set;
    }
    global String jobFrequency {get;set;}
    global String jobType {get;set;}
    public String query {get;set;}
    global String upsertField {get;set;}

    global Integer batchSize {
        get {
            if (this.batchSize == null) this.batchSize = 200;
            return this.batchSize;
        }
        set;
    }
    global Integer numRetries {
        get {
            if (this.numRetries == null) this.numRetries = 0;
            return this.numRetries;
        }
        set;
    }

    global Map<String,String> paramStringsByStrings {get;set;}

    global Sequence_Job__mdt sj {get;set;} //The current sequence job record

    global Sequence_Jobs_Settings__c sjcs { //The sequence job settings, used to check the state of the custom setting
        get {
            this.sjcs = this.sjcs == null ? Sequence_Jobs_Settings__c.getInstance() : this.sjcs;
            //If there isn't a sequence job custom setting active in the org, one will be created here. Particularly
            //useful for when unit tests are running, this gives us the chance to get the default settings from the CS
            if (sjcs == null || sjcs.Name == null) {
                this.sjcs = (Sequence_Jobs_Settings__c) Sequence_Jobs_Settings__c.SObjectType.newSObject(null, true);
                this.sjcs.Name = 'default';
                //Not actually upserting here during testing because it can be problematic when running parallel tests
                if (!Test.isRunningTest()) upsert this.sjcs;
            }
            return sjcs;
        }
        set;
    }

    global JobSequence(){}

    /**
     * Job sequence constructor using a sequence job record
     *
     * @param sj    The sequence job record to initialize with
     */
    global JobSequence(Sequence_Job__mdt sj) {
        this.allOrNone = sj.AllOrNone__c;
        this.batchSize = Integer.valueOf(sj.BatchLimit__c);
        this.currentJob = sj.DeveloperName;
        this.executionJob = sj.ExecutionJob__c;
        this.jobFrequency = sj.Frequency__c;
        this.jobType = sj.Type__c;
        this.paramStringsByStrings = getParamsFromSequenceJob(sj);
        this.query = constructQuery(sj);
        this.sj = sj;
        this.permDelete = sj.PermDelete__c;
        this.upsertField = sj.UpsertExtIdField__c;
        this.isBatchJob = sj.IsBatchJob__c;
        if (this.paramStringsByStrings != null && String.isNotBlank(query)) {
            this.query = updateQueryFromParams(this.query, this.paramStringsByStrings);
        }
        this.handlerName = sj.HandlerClass__c;
    }

    /**
     * Method will log an error in the Job Sequence error object
     *
     * @param jobId     The job Id to log against
     * @param e         The exception
     * @param idScope   The ids that failed
     */
    global void logError(Id jobId, Exception e, Set<Id> idScope) {
        JobSequenceUtilities.logError(jobId, this.currentJob, this.jobFrequency, e, idScope);
    }

    /**
     * Will throw a maximum retry limit reached error
     */
    global void maxRetryLimitReachedError() {
        throw new JobSequenceException(
            String.format(
                    Label.Job_Sequence_Max_Retry_Error,
                    new List<String> {
                            String.valueOf(sjcs.MaxRetries__c),
                            this.sj.DeveloperName,
                            this.executionJob
                    }
            )
        );
    }

    /**
     * Will throw a no function found error
     */
    global void noFunctionFoundError() {
        String errorMsg = String.format(
            Label.Job_Sequence_No_Function_Found_Error,
            new List<String>{
                    this.executionJob
            }
        );
        throw new JobSequenceException(errorMsg);
    }

    /**
     * Will throw a no parameters found error
     */
    global void noParametersFoundError() {
        throw new JobSequenceException(
            String.format(
                Label.Job_Sequence_Parameters_Not_Found,
                new List<String> {
                        this.executionJob,
                        this.sj.Id
                }
            )
        );
    }

    /**
     * Function will schedule a future run for the current job sequence
     *
     * @param js    The current job sequence.
     */
    global void scheduleRetry(JobSequence js) {
        if (js.numRetries >= this.sjcs.MaxRetries__c) js.maxRetryLimitReachedError();
        if (js.numRetries <= this.sjcs.MaxRetries__c) {
            js.numRetries++;
            Datetime futureRunTime = Datetime.now().addMinutes(Integer.valueOf(this.sjcs.MinutesUntilRetry__c));
            String timeForScheduler = futureRunTime.format('s m H d M \'?\' yyyy');
            System.schedule(js.currentJob+' Retry:'+timeForScheduler,timeForScheduler,new JobSequenceSchedulable(js,true));
        }
    }

    /**
     * This function will send error emails if applicable
     *
     * @param jobId     The job Id that will be used to identify the job that errored out
     * @param errors    The error message records
     */
    global void sendErrorEmail(Id jobId, List<Job_Sequence_Error__c> errors) {
        sendErrorEmail(jobId,this.currentJob, this.jobFrequency, errors);
    }

    /**
     * Function will structure a query based on the data found in the sequence job record
     *
     * @param sj    The Sequence Job object record
     *
     * @return      The constructed query
     */
    private String constructQuery(Sequence_Job__mdt sj) {
        String returnQuery = 'SELECT {0} FROM {1} WHERE {2} ORDER BY {3}';
        String limitStr = sj.Limit__c != null ? String.valueOf(sj.Limit__c) : null;
        limitStr = String.isNotBlank(limitStr) && limitStr.endsWith('.0') ? limitStr.left(limitStr.length()-2) : limitStr;
        returnQuery += String.isNotBlank(limitStr) ? ' LIMIT '+limitStr : '';
        return String.format(returnQuery,new List<String>{sj.Select__c,sj.From__c,sj.Where__c,sj.OrderBy__c});
    }

    /**
     * Method will get parameters from the sequence job passed
     *
     * @param sj    The Sequence Job object record
     *
     * @return      The parameter map
     */
    private Map<String,String> getParamsFromSequenceJob(Sequence_Job__mdt sj) {
        Map<String,String> returnMap;
        if (String.isNotBlank(sj.Parameters__c)) {
            returnMap = new Map<String,String>();
            List<String> paramList = sj.Parameters__c.replaceAll('(\\r|\\n)+','').trim().split(',');
            for (String params : paramList) {
                List<String> paramPair = params.split(':');
                returnMap.put(JobSequenceUtilities.trimCharacters(paramPair[0].trim().toLowerCase(),'"'),JobSequenceUtilities.trimCharacters(paramPair[1],'"'));
            }
        }
        return returnMap;
    }

    /**
     * This function will send error emails if applicable
     *
     * @param jobId         The job Id that will be used to identify the job that errored out
     * @param currentJob    The name of the current job
     * @param jobFrequency  The frequency of the current job
     * @param errors        The error message records
     */
    private void sendErrorEmail(Id jobId, String currentJob, String jobFrequency, List<Job_Sequence_Error__c> errors) {
        if (errors != null && !errors.isEmpty()) {
            String notificationEmail = this.sj == null ? UserInfo.getUserEmail() : this.sj.NotificationEmail__c;
            List<String> emails = (this.sj == null || String.isBlank(this.sj.NotificationEmail__c)) ?
                    null : new List<String>{notificationEmail};
            JobSequenceUtilities.sendEmailNotification(
                    null,
                    emails,
                    null,
                    UserInfo.getUserId(),
                    String.format(Label.Job_Sequence_Error_Email_Subject,new List<String>{currentJob,jobFrequency}),
                    String.format(Label.Job_Sequence_Error_Email_Body,new List<String>{jobId}),
                    null,
                    'High'
            );

        }
    }

    /**
     * This function will update the date time variable stored at the class level
     *
     * @param paramMap  The map of parameters to be used to to update date time variable
     */
    @TestVisible void updateDateTimeVar(String testingParam, Map<String,String> paramMap) {
        if (paramMap.containsKey(testingParam)) {
            String paramVal = paramMap.get(testingParam);
            if (paramVal.containsIgnoreCase('DateTimeVar')) {
                this.g_DateTimeVar = System.now().addMinutes(Integer.valueOf(paramVal.split('=')[1]));
            }
        }
    }

    /**
     * This function will update the query based on params. This is particularly useful for testing scenarios where
     * we need to swap out values based on whether or not testing is running
     *
     * @param q         The query to update
     * @param paramMap  The parameter map containing the updated value
     *
     * @return          The updated query
     */
    @TestVisible String updateQueryFromParams(String q, Map<String,String> paramMap) {
        String testingParam = Test.isRunningTest() ?
                Label.Job_Sequence_Test_Is_Running_Param : Label.Job_Sequence_Test_Is_Not_Running_Param;
        testingParam = testingParam.toLowerCase();
        //Checking to see if the query has a parameter update that it's looking for
        if (q.contains('{0}')) {
            q = q.contains('\'') ? q.replaceAll('\'','\'\'') : q;
            String testingParamVal = paramMap.containsKey(testingParam) ? paramMap.get(testingParam) : '';
            q = String.isNotBlank(testingParamVal) ? String.format(q, new List<String> {testingParamVal}) : q;
        }
        //Processing date times that are present
        if (q.containsIgnoreCase('DateTimeVar') && !q.contains('{0}')) {
            updateDateTimeVar(testingParam,paramMap);
            if (this.g_DateTimeVar != null) {
                //Replacing the variable name in the where clause with {0} so we can input the date time as a string
                q = q.replaceAll('(?i)\\:\\s*g_dateTimeVar|\\:\\s*dateTimeVar','{0}');
                q = q.contains('\'') ? q.replaceAll('\'','\'\'') : q;
                q = q.contains('{0}') ?
                        String.format(q,new List<String>{this.g_DateTimeVar.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')}) : q;
            }
        }
        return q;
    }
}