CREATE VIEW dbo.vMMSTranRefundMMSTran AS 
SELECT MMSTranRefundMMSTranID,OriginalMMSTranID,MMSTranRefundID
FROM MMS_Archive.dbo.MMSTranRefundMMSTran WITH(NOLOCK)
