﻿CREATE VIEW dbo.vSubsidyCompanyTransactionSummary AS 
SELECT SubsidyCompanyTransactionSummaryID,SubsidyCompanyReimbursementProgramTransactionID,TransactionCount,TransactionTotal,ValCurrencyCodeID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.SubsidyCompanyTransactionSummary WITH(NOLOCK)
