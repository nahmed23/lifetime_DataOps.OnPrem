
CREATE VIEW dbo.vValCommissionable AS 
SELECT ValCommissionableID,Description,SortOrder
FROM MMS.dbo.ValCommissionable WITH (NoLock)

