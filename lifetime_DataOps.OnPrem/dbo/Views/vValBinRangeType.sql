CREATE VIEW dbo.vValBinRangeType AS 
SELECT ValBinRangeTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValBinRangeType WITH(NOLOCK)
