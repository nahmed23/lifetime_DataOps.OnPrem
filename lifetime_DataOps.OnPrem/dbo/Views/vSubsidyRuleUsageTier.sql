﻿CREATE VIEW dbo.vSubsidyRuleUsageTier AS 
SELECT SubsidyRuleUsageTierID,SubsidyRuleID,UsageTierNumber,UsageCount,UsageAmount,InsertedDateTime,UpdatedDateTime,UsageAmountLTMatch
FROM MMS.dbo.SubsidyRuleUsageTier WITH(NOLOCK)
