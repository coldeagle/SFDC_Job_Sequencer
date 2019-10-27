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
 * This class is responsible for handling queuing up new job sequences as well as running any sequence jobs that are
 * set to run in a non batch context.
 */
global with sharing class JobSequenceQueueable implements Queueable, Database.AllowsCallouts {
    global JobSequence js {Get;Set;}

    global void execute(QueueableContext context) {
        if (js != null && js.sj != null && js.sjcs.Enabled__c) {
            try {
                Boolean canProcessBatch = (js.isBatchJob && [SELECT count() FROM AsyncApexJob WHERE JobType='BatchApex' AND (Status = 'Processing' OR Status = 'Preparing')] < 5);

                if (canProcessBatch && js.isBatchJob) Database.executeBatch(new JobSequenceBatch(js),js.batchSize);
                if (!canProcessBatch && js.isBatchJob) new JobSequence().scheduleRetry(js);
                if (!js.isBatchJob) {
                    JobSequenceExe.executeQueueable(js);
                    //Setting up the next run after the queueable job has finished running
                    //Batch jobs will automatically kick off this same function in their finish context
                    if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) System.enqueueJob(new JobSequenceQueueable(js));
                }
            } catch(Exception e) {
                System.debug(LoggingLevel.Error, '*** e: ' + e);
                js.logError(context.getJobId(), e, null);
                if (js != null && js.jobId != null) js.sendErrorEmail(js.jobId, [SELECT Id FROM Job_Sequence_Error__c WHERE BatchJobId__c = :js.jobId]);
            }
        }
    }

    /**
     * Constructs a job sequence queueable object based on the frequency that the jobs should be run on. This function
     * will query all of the sequence jobs with the matching frequency and work through all of them. This function
     * can be helpful when you wish to test the sequence jobs without scheduling a run. Example code to run anonymous
     * that will run all of the "Hourly" sequence jobs:
     *
     * System.enqueueJob(new JobSequenceQueueable('Hourly'));
     *
     * @param frequency The frequency of the sequence jobs that you wish to be run
     */
    global JobSequenceQueueable(String frequency) {
        this.js = getNextJob(frequency,null);
    }

    /**
     * Constructs a job schedule queueable object based on the job sequence
     *
     * @param js    The current job sequence. Used to determine what the next sequence will be
     */
    global JobSequenceQueueable(JobSequence js) {
        this.js = getNextJob(js.jobFrequency,js);
    }

    /**
     * Constructs a job schedule queueable object based on the job sequence and whether or not it's a retry
     *
     * @param js        The current job sequence. Used to determine what the next sequence will be
     * @param isRetry   Indicates if this is a retry attempt (e.g. there were not enough available batch jobs when last run so a retry is needed)
     */
    global JobSequenceQueueable(JobSequence js, Boolean isRetry) {
        if (isRetry == null || !isRetry) this.js = getNextJob(js.jobFrequency,js);
        if (isRetry) this.js = js;
    }

    /**
     * This method will return the next job in the Sequence Job object.
     * If it is the first run, it will return the first record found
     * The first run is determined by the js parameter being null
     *
     * @param frequency The run frequency, this will be used to determine which sequences should be pulled
     * @param js        The current job sequence. Used to determine what the next sequence will be
     *
     * @return          The next job sequence that needs to be run
     */
    private JobSequence getNextJob(String frequency, JobSequence js) {
        JobSequence returnRecord;
        try {
            List<Sequence_Job__mdt> seqJobs = getSequenceJobs(frequency,js);
            //Going through each of the sequence job's to try to find the next one in line
            for (Integer i=0; i < seqJobs.size(); i++) {
                Sequence_Job__mdt sj = seqJobs[i];
                //If the job sequence is null, then we'll grab the first one we find
                returnRecord = js == null ? new JobSequence(sj) : returnRecord;
                Boolean hasNext = returnRecord == null && ((i+1) < (seqJobs.size()));
                //If the job sequence is defined, then we will check if there's another job after current iteration
                if (hasNext && js != null && js.sj != null) returnRecord = sj.Id == js.sj.Id ? new JobSequence(seqJobs[i+1]) : returnRecord;

                if (returnRecord != null) break;
            }
        } catch (Exception e) {
            JobSequenceUtilities.logError(js == null ? null : js.jobId, js == null ? null : js.currentJob, js == null ? null : js.jobFrequency, e, null);
        }

        return returnRecord;
    }

    /**
     * Method will query the sequence job metadata table and return the records for the indicated frequency
     *
     * @param frequency The run frequency, this will be used to determine which sequences should be pulled
     * @param js        The current job sequence. Used to determine what the next sequence will be.
     *
     * @return The list of sequence job metadata records
     */
    private List<Sequence_Job__mdt> getSequenceJobs(String frequency, JobSequence js) {
        List<Sequence_Job__mdt> returnList;
        frequency = String.isBlank(frequency) && js != null ? js.jobFrequency : frequency;
        if (String.isBlank(frequency)) throw new JobSequenceException(Label.Job_Sequence_JobSequenceQueueable_Initialization_Error);

        returnList = Database.query(constructSequenceJobQuery(frequency));
        if (returnList.isEmpty() && !frequency.equalsIgnoreCase('notapplicable')) throw new JobSequenceException('No active Sequence Jobs were found for '+frequency+' frequency');
        return returnList;
    }

    /**
     * Constructs the sequence job query based on the frequency passed
     *
     * @param frequency The run frequency, this will be used to determine which sequences should be pulled
     *
     * @return          The query string
     */
    @TestVisible static String constructSequenceJobQuery(String frequency) {
        String query = String.format('SELECT {0} FROM {1} WHERE {2} ORDER BY {3}',new List<String>{
                String.join(new List<String>(Sequence_Job__mdt.SObjectType.getDescribe().fields.getMap().keySet()),','),
                'Sequence_Job__mdt',
                'Active__c = true AND Frequency__c = \''+frequency+'\'',
                'Order__c ASC'
        });

        return query;
    }
}