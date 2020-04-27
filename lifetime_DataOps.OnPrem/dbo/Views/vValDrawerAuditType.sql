
CREATE VIEW dbo.vValDrawerAuditType AS 
SELECT ValDrawerAuditTypeID,Description,SortOrder
FROM MMS.dbo.ValDrawerAuditType WITH (NoLock)

