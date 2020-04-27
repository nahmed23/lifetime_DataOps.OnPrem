CREATE VIEW dbo.vWebOrderItem AS 
SELECT WebOrderItemID,WebOrderID,WebItemID,ValWebOrderItemStatusID
FROM MMS_Archive.dbo.WebOrderItem WITH(NOLOCK)
