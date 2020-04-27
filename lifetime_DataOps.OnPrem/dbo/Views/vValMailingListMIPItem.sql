CREATE VIEW dbo.vValMailingListMIPItem AS 
SELECT ValMailingListMIPItemID,ValMIPItemID,Description,SortOrder
FROM MMS.dbo.ValMailingListMIPItem WITH(NOLOCK)
