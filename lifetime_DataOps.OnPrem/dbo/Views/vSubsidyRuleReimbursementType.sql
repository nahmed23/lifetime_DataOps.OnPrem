﻿CREATE VIEW dbo.vSubsidyRuleReimbursementType AS 
SELECT SubsidyRuleReimbursementTypeID,SubsidyRuleID,ValReimbursementTypeID,ReimbursementAmount,ReimbursementPercentage,IncludeTaxFlag,InsertedDateTime,UpdatedDateTime,ReimbursementAmountLTMatch,ReimbursementPercentageLTMatch
FROM MMS.dbo.SubsidyRuleReimbursementType WITH(NOLOCK)
