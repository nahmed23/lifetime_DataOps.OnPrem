﻿CREATE VIEW dbo.vCompany AS 
SELECT CompanyID,AccountRepInitials,CompanyName,PrintUsageReportFlag,CorporateCode,InsertedDateTime,StartDate,EndDate,AccountRepName,InitiationFee,UpdatedDateTime,EnrollmentDiscPercentage,MACEnrollmentDiscPercentage,InvoiceFlag,DollarDiscount,AdminFee,OverridePercentage,EFTAccountNumber,UsageReportFlag,ReportToEmailAddress,UsageReportMemberType,SmallBusinessFlag,AccountOwner,SubsidyMeasurement,ActiveAccountFlag,NumberOfEmployees,TotalEligibleEmployees,OpportunityRecordType
FROM MMS.dbo.Company WITH(NOLOCK)
