﻿CREATE VIEW dbo.vSubsidyCompany AS 
SELECT SubsidyCompanyID,CompanyID,Description,LTFEmailDistributionList,InsertedDateTime,UpdatedDateTime,PartnerEmailDistributionList
FROM MMS.dbo.SubsidyCompany WITH(NOLOCK)
