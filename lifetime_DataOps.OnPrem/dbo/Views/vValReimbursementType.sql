CREATE VIEW dbo.vValReimbursementType AS 
SELECT ValReimbursementTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValReimbursementType WITH(NOLOCK)
