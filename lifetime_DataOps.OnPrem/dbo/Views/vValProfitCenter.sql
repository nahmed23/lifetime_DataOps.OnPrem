CREATE VIEW [dbo].[vValProfitCenter] AS 
SELECT ValIGProfitCenterID AS ValProfitCenterID,Description,ProfitCenterNumber,SortOrder,ClubID,AutoReconcileTipsFlag,ValProductSalesChannelID
FROM MMS.dbo.ValIGProfitCenter
