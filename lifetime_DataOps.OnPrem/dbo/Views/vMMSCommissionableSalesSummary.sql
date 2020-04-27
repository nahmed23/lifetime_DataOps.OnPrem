﻿
CREATE VIEW vMMSCommissionableSalesSummary
AS
SELECT MMSCommissionableSalesSummaryID, 
       ClubID, 
       ClubName, 
       SalesPersonFirstName, 
       SalesPersonLastName, 
       SalesEmployeeID, 
       ReceiptNumber, 
       MemberID, 
       MemberFirstName, 
       MemberLastName, 
       CorporateCode, 
       MembershipTypeID, 
       MembershipTypeDescription, 
       ItemAmount, 
       Quantity, 
       CommissionCount, 
       PostDateTime, 
       UTCPostDateTime,
       TranItemID, 
       ValRegionID, 
       RegionDescription, 
       DepartmentID, 
       DeptDescription, 
       ProductID, 
       ProductDescription, 
       InsertedDateTime, 
       AdvisorID, 
       AdvisorFirstName, 
       AdvisorLastName, 
       ItemDiscountAmount
  FROM Report_MMS.dbo.MMSCommissionableSalesSummary WITH (NoLock)