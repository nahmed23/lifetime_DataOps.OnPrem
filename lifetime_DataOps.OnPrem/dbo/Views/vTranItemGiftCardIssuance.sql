
CREATE VIEW dbo.vTranItemGiftCardIssuance AS 
SELECT TranItemGiftCardIssuanceID,TranItemID,IssuanceAmount,PTStoredValueCardTransactionID
FROM MMS_Archive.dbo.TranItemGiftCardIssuance WITH(NOLOCK)

