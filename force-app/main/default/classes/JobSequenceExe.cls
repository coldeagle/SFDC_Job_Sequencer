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
 * This class is responsible for handling the job sequence execution logic. It will take the handler file name that is
 * defined in the sequence job custom metadata record (translated into the job sequence wrapper object) and execute the
 * handler that extends the job sequence interface. This will help simplify the management of multiple job sequences
 * where custom code has been written for functions or base DML updates
 */
global without sharing class JobSequenceExe {
    private static JobSequenceInterface handler;

    /**
     * When called this function will either execute a batch or queueable job based on the job sequence record passed.
     * These are kept separate due to the rules governing Batch and Queueable processing.
     *
     * @param js    The Job Sequence object wrapper to process
     * @param scope The records to process
     */
    global static void execute(JobSequence js, List<SObject> scope) {
        try {
            if (js != null) {
                if (js.isBatchJob) executeBatch(js, scope);
                if (!js.isBatchJob) executeQueueable(js);
            }
            if (js == null) throw new JobSequenceException(Label.Job_Sequence_No_Job_Sequence_Object_Found_Error);
        } catch (Exception e) {
            JobSequenceUtilities.logError(js, scope, e);
        }
    }

    /**
     * When this function is called, it will execute a job with the assumption that it is a batch execution.
     *
     * @param js        The Job Sequence object wrapper to process
     * @param scope     The records to process
     */
    global static void executeBatch(JobSequence js, List<SObject> scope) {
        try {
            if (js != null) {
                if (handler == null) handler = getHandler(js);
                if (handler != null && String.isNotBlank(js.jobType)) {
                    if (js.jobType.equalsIgnoreCase('DML')) handler.executeDML(js, scope);
                    if (js.jobType.equalsIgnoreCase('Function')) handler.executeFunction(js, scope);
                    handler.finishJobSequence(js);
                }
            }
            if (js == null) throw new JobSequenceException(Label.Job_Sequence_No_Job_Sequence_Object_Found_Error);
        } catch (Exception e) {
            JobSequenceUtilities.logError(js, scope, e);
        }
    }

    /**
     * When this function is called, it will execute the job with the assumption that it was called from a queueable
     * type job. It will query any appropriate records ahead of time if it's called for by the job, so no scope need be
     * passed into it.
     *
     * @param js    The Job Sequence object wrapper to process
     */
    global static void executeQueueable(JobSequence js) {
        executeQueueable(js, String.isNotBlank(js.query) ? Database.query(js.query) : null);
    }

    /**
     * When this function is called, it will execute the job with the assumption that it was called from a queueable
     * type job. It will query any appropriate records ahead of time if it's called for by the job, so no scope need be
     * passed into it.
     *
     * @param js        The Job Sequence object wrapper to process
     * @param scope     The records to process
     */
    global static void executeQueueable(JobSequence js, List<SObject> scope) {
        try {
            if (js != null) {
                if (handler == null) handler = getHandler(js);
                if (handler != null && String.isNotBlank(js.jobType)) {
                    scope = String.isNotBlank(js.query) && (scope == null || scope.isEmpty()) ? Database.query(js.query) : scope;
                    if (js.jobType.equalsIgnoreCase('DML')) handler.executeDML(js, scope);
                    if (js.jobType.equalsIgnoreCase('Function')) handler.executeFunction(js, scope);
                    handler.finishJobSequence(js);
                }
            }
            if (js == null) throw new JobSequenceException(Label.Job_Sequence_No_Job_Sequence_Object_Found_Error);
        } catch (Exception e) {
            JobSequenceUtilities.logError(js, scope, e);
        }
    }

    /**
     * This method will get the handler based on the handler name passed by the job sequence record
     *
     * @param js    The job sequence object wrapper
     *
     * @return      The job sequence interface handler that is used to execute the job sequence logic
     */
    private static JobSequenceInterface getHandler(JobSequence js) {
        JobSequenceInterface jobSequenceInterface;
        try {
            Type h = Type.forName(js.handlerName);
            if (h != null && h.newInstance() instanceof JobSequenceInterface) {
                jobSequenceInterface = (JobSequenceInterface) h.newInstance();
            } else {
                throw new JobSequenceException(Label.Job_Sequence_No_Handler_Found_Error);
            }

        } catch (Exception e) {
            JobSequenceUtilities.logError(js, null, e);
        }
        return jobSequenceInterface;
    }


}