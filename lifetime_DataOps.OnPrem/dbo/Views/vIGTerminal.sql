﻿CREATE VIEW dbo.vIGTerminal AS 
SELECT IGTerminalID,PTCreditCardTerminalID,TerminalNumber,ValIGProfitCenterID,InsertedDateTime,UpdatedDateTime,EmployeeID,AutoCommitFlag,ValProductSalesChannelID
FROM MMS.dbo.IGTerminal WITH(NOLOCK)
