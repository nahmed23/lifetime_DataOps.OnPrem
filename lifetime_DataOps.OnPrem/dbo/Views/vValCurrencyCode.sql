CREATE VIEW dbo.vValCurrencyCode AS 
SELECT ValCurrencyCodeID,Description,CurrencyCode,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValCurrencyCode WITH(NOLOCK)
