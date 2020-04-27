CREATE VIEW dbo.vValEmailTemplateType AS 
SELECT ValEmailTemplateTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValEmailTemplateType WITH(NOLOCK)
