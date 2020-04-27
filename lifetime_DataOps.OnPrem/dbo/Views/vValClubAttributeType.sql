CREATE VIEW dbo.vValClubAttributeType AS 
SELECT ValClubAttributeTypeid,description,sortorder,InsertedDatetime,UpdatedDateTime
FROM MMS.dbo.ValClubAttributeType WITH(NOLOCK)
