﻿CREATE VIEW dbo.vTerminalAreaIndustryCode AS 
SELECT TerminalAreaIndustryCodeID,TerminalAreaID,ValPTCreditCardIndustryCodeID
FROM MMS.dbo.TerminalAreaIndustryCode WITH(NOLOCK)
