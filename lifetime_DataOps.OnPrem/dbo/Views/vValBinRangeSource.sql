CREATE VIEW dbo.vValBinRangeSource AS 
SELECT ValBinRangeSourceID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValBinRangeSource WITH(NOLOCK)
