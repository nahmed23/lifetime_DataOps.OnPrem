CREATE VIEW dbo.vPhoneNumberStatus AS 
SELECT PhoneNumberStatusID,AreaCode,Number,Status,Source,Reason,StatusFromDate,StatusThruDate,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.PhoneNumberStatus WITH(NOLOCK)
