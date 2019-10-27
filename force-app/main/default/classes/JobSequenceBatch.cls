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
 * This class is responsible for handling items in a batch context.
 */
public without sharing class JobSequenceBatch implements Database.Batchable<SObject>,Database.Stateful, Database.AllowsCallouts {
    private JobSequence js {Get;Set;}

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Database.QueryLocator returnLocator;
        try {
            js.query = String.isBlank(js.query) ? 'SELECT Id FROM User LIMIT 0' : js.query;
            returnLocator = Database.getQueryLocator(js.query);
        } catch (Exception e) {
            js.logError(BC.getJobId(), e, null);
            returnLocator = Database.getQueryLocator('SELECT Id FROM '+js.query.toUpperCase().substringAfterLast(' FROM ').substringBefore(' ')+' LIMIT 0');
        }

        return returnLocator;
    }
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        try {
            JobSequenceExe.execute(js, scope);
        } catch (Exception e) {
            JobSequenceUtilities.logError(js,scope,e);
        }

    }
    public void finish(Database.BatchableContext BC) {
        handleFinish(bc,js);
    }

    public JobSequenceBatch(JobSequence js) {
        this.js = js;
    }

    /**
     * This function will handle the finish actions for the batch job and will send an email if errors are found
     * and enqueue the next job sequence
     *
     * @param bc    The batch context
     * @param js    The job sequence
     */
    private static void handleFinish(Database.BatchableContext bc, JobSequence js) {
        List<Job_Sequence_Error__c> errors = [SELECT Id FROM Job_Sequence_Error__c WHERE BatchJobId__c = :BC.getJobId()];
        if (!errors.isEmpty()) js.sendErrorEmail(bc.getJobId(), errors);
        System.enqueueJob(new JobSequenceQueueable(js));
    }

}