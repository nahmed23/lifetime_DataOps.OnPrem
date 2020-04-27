
CREATE VIEW [dbo].[vProfitCenterTerminal] AS
SELECT IGTerminalID AS ProfitCenterTerminalID,PTCreditCardTerminalID,TerminalNumber,ValIGProfitCenterID AS ValProfitCenterID,EmployeeID,AutoCommitFlag,ValProductSalesChannelID
FROM MMS.dbo.IGTerminal
