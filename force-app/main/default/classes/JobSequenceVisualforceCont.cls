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
 * This controller handles functions for Job Sequencer visualforce pages
 */
public with sharing class JobSequenceVisualforceCont {
    public JobSequenceVisualforceCont() {}

    /**
     * This function will get the page reference for the sequence jobs so the users can be re-directed to it after
     * clicking on the tab.
     *
     * @return  The page reference for the Sequence Job custom meta data type
     */
    public PageReference getPageRefForSequenceJobs() {
        String prefix = Sequence_Job__mdt.SObjectType.getDescribe().getKeyPrefix();
        PageReference pr = new PageReference('/'+prefix+'?setupid=CustomMetadata');
        pr.setRedirect(true);
        return pr;
    }

    /**
     * This function will return the page reference for the sequence job custom settings, so they users can be re-directed
     * after clicking on the tab
     *
     * @return  The page reference to the custom settings for the sequence Job
     */
    public PageReference getPageRefForSequenceJobCustomSettingSetup() {
       String preFix = Sequence_Jobs_Settings__c.SObjectType.getDescribe().getKeyPrefix();
        PageReference pr = new PageReference('/setup/ui/listCustomSettingsData.apexp?id='+preFix);
        pr.setRedirect(true);
        return pr;
    }

    /**
     * Schedules all of the out of the box job sequence runs
     */
    public void scheduleAllRuns() {
        JobSequenceUtilities.scheduleAllRuns();
    }

    /**
     * This function will schedule the hourly class
     */
    public void scheduleHourlyRun() {
        JobSequenceUtilities.scheduleHourlyRun();
    }

    /**
     * This function will schedule the daily class
     */
    public void scheduleDailyRun() {
        JobSequenceUtilities.scheduleDailyRun();
    }

    /**
     * This function will schedule the weekly class
     */
    public void scheduleWeeklyRun() {
        JobSequenceUtilities.scheduleWeeklyRun();
    }

    /**
     * This function will schedule the monthly class
     */
    public void scheduleMonthlyRun() {
        JobSequenceUtilities.scheduleMonthlyRun();
    }

    /**
     * This function will schedule the quarterly class
     */
    public void scheduleQuarterlyRun() {
        JobSequenceUtilities.scheduleQuarterlyRun();
    }

    /**
     * This function will schedule the yearly class
     */
    public void scheduleYearlyRun() {
        JobSequenceUtilities.scheduleYearlyRun();
    }
}