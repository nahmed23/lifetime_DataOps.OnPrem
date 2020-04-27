
CREATE    PROC [dbo].[mmsFitnessAndNutrition_Revenue_MTD]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Author:        Susan Myrick
-- Create date: 5/28/08
-- Updates      07/15/2010 MLL Add Discounts
--              1/18/2011 BSD Added 'Mixed Combat Arts'
--              2/22/2011 BSD Returning additional column RevenueReportingDepartment
--              3/24/2011 BSD: Excluding ProductID 5234 QC6883
--              4/4/2011 BSD: Including ProductID 5234 QC6963
--              2/22/2012 BSD: Results now return in USD
-- Description:    Created to allow the combining of Fitness Program revenue and Nutrition sales revenue
--              on the same report ( task # 2168 )
-- 
-- Parameters include a date range and 'All' for All Clubs with a | separated list of the Departments
--
-- This proc calculates yesterday's date, then from there, what the first day of that
-- Month is.
-- =============================================

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  --DECLARE @ToDay DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))+ ' 23:59:59'
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  --SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MMSR.PostingClubName, 
       MMSR.ItemAmount * ToUSDPlanExchangeRate.PlanExchangeRate ItemAmount, --BSD 2/22/2012 QC#1750
       MMSR.DeptDescription, MMSR.ProductDescription, MMSR.MembershipClubname,
       MMSR.PostingClubid, MMSR.DrawerActivityID, MMSR.PostDateTime, MMSR.TranDate, MMSR.TranTypeDescription, 
       MMSR.ValTranTypeID,MMSR.MemberID, 
       MMSR.ItemSalesTax * ToUSDPlanExchangeRate.PlanExchangeRate ItemSalesTax, --BSD 2/22/2012 QC#1750
       MMSR.EmployeeID, MMSR.PostingRegionDescription, MMSR.MemberFirstname, MMSR.MemberLastname,
       MMSR.EmployeeFirstname, MMSR.EmployeeLastname, MMSR.ReasonCodeDescription, MMSR.TranItemID, MMSR.TranMemberJoinDate,
       MMSR.MembershipID, MMSR.ProductID, MMSR.TranClubid, MMSR.Quantity, @FirstOfMonth AS ReportStartDate,
       @Yesterday AS ReportEndDate, CO.CompanyName, CO.CorporateCode, VPG.Description AS ProductGroupDescription,
       VPG.RevenueReportingDepartment, --2/22/2011 BSD
       MMSR.ItemDiscountAmount * ToUSDPlanExchangeRate.PlanExchangeRate ItemDiscountAmount, --BSD 2/22/2012 QC#1750
       MMSR.DiscountAmount1 * ToUSDPlanExchangeRate.PlanExchangeRate DiscountAmount1, --BSD 2/22/2012 QC#1750
       MMSR.DiscountAmount2 * ToUSDPlanExchangeRate.PlanExchangeRate DiscountAmount2, --BSD 2/22/2012 QC#1750
       MMSR.DiscountAmount3 * ToUSDPlanExchangeRate.PlanExchangeRate DiscountAmount3, --BSD 2/22/2012 QC#1750
       MMSR.DiscountAmount4 * ToUSDPlanExchangeRate.PlanExchangeRate DiscountAmount4, --BSD 2/22/2012 QC#1750
       MMSR.DiscountAmount5 * ToUSDPlanExchangeRate.PlanExchangeRate DiscountAmount5, --BSD 2/22/2012 QC#1750
       MMSR.Discount1,
       MMSR.Discount2,
       MMSR.Discount3,
       MMSR.Discount4,
       MMSR.Discount5,
       VPG.ValProductGroupID AS ProgramID,
       P.PackageProductFlag,
       CSS.SalesPersonFirstName,
       CSS.SalesPersonLastName,
       CSS.SalesEmployeeID,
       CSS.CommissionCount AS Count2
  FROM vMMSRevenueReportSummary MMSR
  JOIN vMembership MS 
    ON MS.MembershipID = MMSR.MembershipID
  JOIN vProduct P
    ON MMSR.ProductID = P.ProductID
  LEFT JOIN vCompany CO 
    ON MS.CompanyID = CO.CompanyID
  LEFT JOIN vProductGroup PG
    ON MMSR.ProductID = PG.ProductID
  LEFT JOIN vValProductGroup VPG
    ON PG.ValProductGroupID = VPG.ValProductGroupID
  LEFT Join vMMSCommissionableSalesSummary CSS
    ON MMSR.TranItemID = CSS.TranItemID
  JOIN vPlanExchangeRate ToUSDPlanExchangeRate --BSD 2/22/2012 QC#1750
    ON MMSR.LocalCurrencyCode = ToUSDPlanExchangeRate.FromCurrencyCode
   AND 'USD' = ToUSDPlanExchangeRate.ToCurrencyCode
   AND YEAR(@Yesterday) = ToUSDPlanExchangeRate.PlanYear
 WHERE MMSR.PostDateTime >= @FirstOfMonth 
   AND MMSR.PostDateTime <= @Yesterday 
   AND (MMSR.DeptDescription in('Personal Training', 'Nutrition Coaching', 'Mind Body','Merchandise','Mixed Combat Arts')AND MMSR.ItemAmount <> 0)--  1/18/2011 BSD



-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
