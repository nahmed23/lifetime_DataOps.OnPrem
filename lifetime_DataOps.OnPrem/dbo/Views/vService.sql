



CREATE VIEW dbo.vService
AS
SELECT ServiceID, Name, Description, 
    ValServiceAccessCodeID
FROM MMS.dbo.Service WITH (NoLock)




