


CREATE VIEW dbo.vSettlementAccount AS SELECT SettlementAccountID,DestinationName,CompanyName,CompanyCode,EntryDescription,DestinationMerchantNumber,OriginACH,OriginName 
FROM MMS.dbo.SettlementAccount With (NOLOCK)


