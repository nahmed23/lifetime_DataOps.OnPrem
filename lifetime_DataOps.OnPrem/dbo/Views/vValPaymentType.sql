﻿CREATE VIEW dbo.vValPaymentType AS 
SELECT ValPaymentTypeID,Description,SortOrder,ValEFTAccountTypeID,ViewPaymentTypeFlag,ViewBankAccountTypeFlag,RequiresPaymentTerminalFlag
FROM MMS.dbo.ValPaymentType WITH(NOLOCK)
