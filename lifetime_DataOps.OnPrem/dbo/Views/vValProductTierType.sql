CREATE VIEW dbo.vValProductTierType AS 
SELECT ValProductTierTypeID,Description,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValProductTierType WITH(NOLOCK)
