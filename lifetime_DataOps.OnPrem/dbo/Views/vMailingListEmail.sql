CREATE VIEW dbo.vMailingListEmail AS 
SELECT MailingListEmailID,EmailName,Campaign,Segment,TransactionalFlag,StatusFromDate,StatusThruDate,InsertedDateTime,UpdatedDateTime,EmailKey
FROM MMS.dbo.MailingListEmail WITH(NOLOCK)
