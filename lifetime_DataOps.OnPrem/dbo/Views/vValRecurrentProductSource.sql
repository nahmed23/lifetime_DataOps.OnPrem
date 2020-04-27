CREATE VIEW dbo.vValRecurrentProductSource AS 
SELECT ValRecurrentProductSourceID,Description,SortOrder
FROM MMS.dbo.ValRecurrentProductSource WITH(NOLOCK)
