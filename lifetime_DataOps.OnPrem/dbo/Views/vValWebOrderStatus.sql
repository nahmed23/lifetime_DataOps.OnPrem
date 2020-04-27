CREATE VIEW dbo.vValWebOrderStatus AS 
SELECT ValWebOrderStatusID,Description,SortOrder
FROM MMS.dbo.ValWebOrderStatus WITH(NOLOCK)
