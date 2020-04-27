


CREATE VIEW dbo.vReasonCode AS SELECT ReasonCodeID,Name,Description,SortOrder,DisplayUIFlag 
FROM MMS.dbo.ReasonCode With (NOLOCK)


