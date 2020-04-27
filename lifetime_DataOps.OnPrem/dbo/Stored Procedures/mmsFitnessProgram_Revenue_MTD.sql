
/***********************************************************/

CREATE        PROC [dbo].[mmsFitnessProgram_Revenue_MTD]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- Parameters include a date range and 'All' for All Clubs with a | separated list of the Departments
--
-- This proc calculates yesterday's date, then from there, what the first day of that
-- Month is.
--

  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfMonth DATETIME
  DECLARE @ToDay DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))+ ' 11:59 PM'
  SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,@yesterday,112),1,6) + '01', 112)
  SET @ToDay  =  CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT MMSR.PostingClubName, MMSR.ItemAmount, MMSR.DeptDescription, MMSR.ProductDescription, MMSR.MembershipClubname,
                 MMSR.PostingClubid, MMSR.DrawerActivityID, MMSR.PostDateTime, MMSR.TranDate, MMSR.TranTypeDescription, MMSR.ValTranTypeID,
                 MMSR.MemberID, MMSR.ItemSalesTax, MMSR.EmployeeID, MMSR.PostingRegionDescription, MMSR.MemberFirstname, MMSR.MemberLastname,
                 MMSR.EmployeeFirstname, MMSR.EmployeeLastname, MMSR.ReasonCodeDescription, MMSR.TranItemID, MMSR.TranMemberJoinDate,
                 MMSR.MembershipID, MMSR.ProductID, MMSR.TranClubid, MMSR.Quantity, @FirstOfMonth AS ReportStartDate,
                 @Yesterday AS ReportEndDate, CO.CompanyName, CO.CorporateCode
          FROM vMMSRevenueReportSummary MMSR
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
 	           LEFT JOIN dbo.vCompany CO 
                 ON CO.CompanyID = MS.CompanyID
          WHERE MMSR.PostDateTime >= @FirstOfMonth 
                AND MMSR.PostDateTime <= @Yesterday 
                AND MMSR.DeptDescription in ('Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts')
                AND MMSR.ItemAmount <> 0
					  
 UNION

  SELECT MMSR.PostingClubName, MMSR.ItemAmount, MMSR.DeptDescription, MMSR.ProductDescription, MMSR.MembershipClubname,
                 MMSR.PostingClubid, MMSR.DrawerActivityID, MMSR.PostDateTime, MMSR.TranDate, MMSR.TranTypeDescription, MMSR.ValTranTypeID,
                 MMSR.MemberID, MMSR.ItemSalesTax, MMSR.EmployeeID, MMSR.PostingRegionDescription, MMSR.MemberFirstname, MMSR.MemberLastname,
                 MMSR.EmployeeFirstname, MMSR.EmployeeLastname, MMSR.ReasonCodeDescription, MMSR.TranItemID, MMSR.TranMemberJoinDate,
                 MMSR.MembershipID, MMSR.ProductID, MMSR.TranClubid, MMSR.Quantity, @FirstOfMonth AS ReportStartDate,
                 @Yesterday AS ReportEndDate, CO.CompanyName, CO.CorporateCode
          FROM vMMSRevenueReportSummary MMSR
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
 	           LEFT JOIN dbo.vCompany CO 
                 ON CO.CompanyID = MS.CompanyID
               JOIN vProductGroup PG
                 ON PG.ProductID = MMSR.ProductID
          WHERE MMSR.PostDateTime >= @FirstOfMonth 
                AND MMSR.PostDateTime <= @Yesterday 
                AND MMSR.DeptDescription = 'Merchandise'
 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
