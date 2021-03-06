﻿CREATE VIEW dbo.vSubsidyRule AS 
SELECT SubsidyRuleID,SubsidyCompanyReimbursementProgramID,ValReimbursementUsageTypeID,Description,UsageMinimum,MaxVisitsPerDay,ReimbursementAmountPerUsage,IgnoreUsageMinimumFirstMonthFlag,IncludeTaxUsageTierFlag,InsertedDateTime,UpdatedDateTime,IgnoreUsageMinimumPreviousNonAccessFlag,ApplyUsageCreditsPreviousAccessFlag,ReimbursementAmountPerUsageLTMatch
FROM MMS.dbo.SubsidyRule WITH(NOLOCK)
