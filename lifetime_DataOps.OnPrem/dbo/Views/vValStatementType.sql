
CREATE VIEW dbo.vValStatementType AS 
SELECT ValStatementTypeID,Description,SortOrder
FROM MMS.dbo.ValStatementType WITH (NoLock)

