CREATE VIEW dbo.vValWebOrderItemStatus AS 
SELECT ValWebOrderItemStatusID,Description,SortOrder
FROM MMS.dbo.ValWebOrderItemStatus WITH(NOLOCK)
