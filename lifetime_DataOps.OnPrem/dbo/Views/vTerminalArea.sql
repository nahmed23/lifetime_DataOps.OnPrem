﻿CREATE VIEW dbo.vTerminalArea AS 
SELECT TerminalAreaID,TerminalAreaName,ValPTCreditCardIndustryCodeID,ThirdPartyTerminal,ExcludeFromDrawer,DefaultTerminalName,DefaultTerminalDescription
FROM MMS.dbo.TerminalArea WITH(NOLOCK)
