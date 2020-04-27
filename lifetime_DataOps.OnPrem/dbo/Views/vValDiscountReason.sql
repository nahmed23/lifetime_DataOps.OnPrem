CREATE VIEW dbo.vValDiscountReason AS 
SELECT ValDiscountReasonID,Description,SortOrder,DisplayUIFlag,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValDiscountReason WITH(NOLOCK)
