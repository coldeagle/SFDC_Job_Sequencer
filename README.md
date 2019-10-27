# What is the Job Sequencer
The tool provides it's users with the ability to schedule jobs on a hourly, daily, weekly, monthly, quarterly or yearly basis. Sequence jobs are created with a frequency based on those Schedules.

# Why should I care
This tools ability to create sequence jobs that run on a schedule. This provides a level of flexibility that is difficult to achieve out of the box. 

And you're saying to your self "Ok that sounds great but why is this important." Well think about it this way. You've got 10 things that need to run on x basis. Traditionally, you would need to either create a class that would run a bunch of code synchronously and run the risk of hitting governor limits.  Another approach could be create separate classes and schedule them to run; however, you could run into limits there as there are a finite number of classes that can be scheduled (100 total). Additionally, if you've got two jobs running at the same time, you could run into row locks. If the jobs are batch apex, you have a limit there as well.

Another problem with these approaches is that it's difficult for you to create those jobs without writing code unless you try to use time-based workflow's. There are some limits there too. 

# How does the tool work
So now you know why the tool could be helpful, now let's see how it works. Once installed, this tool has a metadata type "Sequence Job" that can be configured with the frequency that the it should be run at (hourly, daily, etc). Each sequence job is run asynchronously in either a batch or queueable context. 

Once the actual scheduled job is run by Salesforce, queueable apex is used to execute each of the sequence job's serially. Each sequence job is enqueued based on which type of job its defined as being (either batch or queueable). Once the job completes, a queueable job is enqueued that will run the next sequence job. 

Each of the sequence jobs can be setup to either run a function or a DML statement. 

## DML

The DML options that are available to be run are either UPDATE or DELETE. The update portion is helpful if you want to replace a time-based workflow rule. For example, let's say that you want an email alert to be sent when the CloseDate of an opportunity is today. You would setup a sequence job with a query like this:

```SELECT Id FROM Opportunity WHERE CloseDate = TODAY AND IsClosed = FALSE```

When the sequence job runs, it would simply run an update to those records. Then your workflow rule/process builder/trigger would see that the close date is today and the opportunity isn't closed, and then send out the email alert to the owner that they should go and update the opportunity or close it. 

## Functions

There is one function that can be executed out of the box, FieldShift. This allows you to query records and define which fields should be shifted to what value. 

For example, let's say that you want close all opportunities that have not been modified in the last 30 days. You would run a query like this

```SELECT Id FROM Opportunity WHERE IsClosed = false AND LastModifiedDate <= LAST_N_DAYS:30```

Then you would define parameters:

```
StageName:"Closed Lost",
Closed_Lost_Reason__c:"Auto closed"
```

Then when the sequence job is run, all of the opportunities queried would have the **StageName** set to _"Closed Lost"_ and the custom field **Closed_Lost_Reason__c** set to _"Auto Closed"_.

Developers also have the option of creating additional functions that can be used. More details can be found in the "Job Sequencer Help" tab as well as the code comments of the of the "JobSequenceDefaultHandler" class. 

# Link to Unmanaged Package Installer
https://login.salesforce.com/packaging/installPackage.apexp?p0=04t4P000002icUM