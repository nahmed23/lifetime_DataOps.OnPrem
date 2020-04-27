CREATE VIEW dbo.vWebCart AS 
SELECT WebCartID,PartyEncryptionID,ValProductSalesChannelID,CartTotal,ExpirationDateTime,WebOrderID
FROM MMS.dbo.WebCart WITH(NOLOCK)
