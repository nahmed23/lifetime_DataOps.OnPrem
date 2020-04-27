CREATE VIEW dbo.vValExactTargetMIPItem AS 
SELECT ValExactTargetMIPItemID,ValMIPItemID,Description,SortOrder
FROM MMS.dbo.ValExactTargetMIPItem WITH(NOLOCK)
