CREATE VIEW dbo.vValState AS 
SELECT ValStateID,Description,SortOrder,ValCountryID,InsertedDateTime,Abbreviation,UpdatedDateTime,CreditCardSurchargeFlag
FROM MMS.dbo.ValState WITH(NOLOCK)
