﻿CREATE VIEW dbo.vValPTCreditCardEntryDataSource AS 
SELECT ValPTCreditCardEntryDataSourceID,Description,SortOrder,EntryDataSource
FROM MMS.dbo.ValPTCreditCardEntryDataSource WITH(NOLOCK)
