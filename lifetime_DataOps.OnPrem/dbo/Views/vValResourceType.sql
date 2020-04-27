CREATE VIEW dbo.vValResourceType AS 
SELECT ValResourceTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValResourceType WITH(NOLOCK)
