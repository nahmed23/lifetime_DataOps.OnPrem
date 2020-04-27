CREATE VIEW dbo.vWebOrderMMSTran AS 
SELECT WebOrderMMSTranID,WebOrderID,MMSTranID
FROM MMS_Archive.dbo.WebOrderMMSTran WITH(NOLOCK)
