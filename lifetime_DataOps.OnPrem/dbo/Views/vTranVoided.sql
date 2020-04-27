






CREATE VIEW dbo.vTranVoided AS 
SELECT TranVoidedID,EmployeeID,VoidDateTime,Comments,UTCVoidDateTime,VoidDateTimeZone,InsertedDateTime
FROM MMS_Archive.dbo.TranVoided With (NOLOCK)






