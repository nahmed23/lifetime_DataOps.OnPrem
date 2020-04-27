CREATE VIEW [dbo].[vMMSTranRefund] AS 
SELECT MMSTranRefundID,MMSTranID,RequestingClubID,InsertedDateTime
FROM MMS_Archive.dbo.MMSTranRefund WITH(NOLOCK)
