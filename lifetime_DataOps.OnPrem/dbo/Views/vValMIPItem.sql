
CREATE VIEW dbo.vValMIPItem AS 
SELECT ValMIPItemID,Description,SortOrder
FROM MMS.dbo.ValMIPItem WITH (NoLock)

