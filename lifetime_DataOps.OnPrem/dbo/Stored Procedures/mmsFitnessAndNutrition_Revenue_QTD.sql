



CREATE    PROC [dbo].[mmsFitnessAndNutrition_Revenue_QTD]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
	Author:			Ruslan Condratiuc
	Create date:	4/23/09
	Description:	Created to allow the combining of Fitness Program revenue and Nutrition sales revenue
			  on the same report ( task # 2168 )
					This proc calculates yesterday's date, then from there, what the first day of that Quarter is.
	Parameters:		include a date range and 'All' for All Clubs with a | separated list of the Departments
	Modified date:	4/4/2011 BSD: Including ProductID 5234 QC6963
                    3/24/2011 BSD: Excluding ProductID 5234 QC6883
                    2/7/2011 BSD: RR427 now returning @Yesterday and @FirstOfQuarter
                    1/18/2011 BSD: Added 'Mixed Combat Arts' RR426
                    12/08/2009 GRB: added 'Garmin' per QC# 4117;
					02/18/10 RC: removed filter for commissioned products only for 'MMS non Polar/Garmin merchandise'
                    07/16/2010 MLL: Add Discount information
	exec mmsFitnessAndNutrition_Revenue_QTD
	=============================================	*/


  DECLARE @Yesterday DATETIME
  DECLARE @FirstOfQuarter DATETIME

  SET @Yesterday  =  DATEADD(dd, -1, CONVERT(DATETIME, CONVERT(VARCHAR, GETDATE(), 102), 102))+ ' 23:59:59'
  SET @FirstOfQuarter  =  DATEADD(qq, DATEDIFF(qq,0,@Yesterday), 0)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT MMSR.PostingClubid, MMSR.PostingClubName, MMSR.ProductID, 'MMS Fitness Data' AS DataType,  SUM(MMSR.ItemAmount) AS ItemAmount,
         SUM(MMSR.ItemDiscountAmount) AS ItemDiscountAmount, @Yesterday Report_EndDate, @FirstOfQuarter Report_StartDate 
		 --MMSR.DeptDescription, MMSR.ProductDescription, MMSR.PostDateTime, MMSR.TranDate, MMSR.TranTypeDescription
          FROM vMMSRevenueReportSummary MMSR
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
-- 	           LEFT JOIN dbo.vCompany CO 
--                 ON CO.CompanyID = MS.CompanyID
          WHERE MMSR.PostDateTime >= @FirstOfQuarter
                AND MMSR.PostDateTime <= @Yesterday 
                AND MMSR.DeptDescription in ('Personal Training', 'Nutrition Coaching', 'Mind Body','Mixed Combat Arts')AND MMSR.ItemAmount <> 0 --  1/18/2011 BSD
		  GROUP BY MMSR.PostingClubid, MMSR.PostingClubName, MMSR.ProductID

UNION

  SELECT MMSR.PostingClubid, MMSR.PostingClubName, MMSR.ProductID, 'MMS Fitness Data' AS DataType,  SUM(MMSR.ItemAmount) AS ItemAmount,
         SUM(MMSR.ItemDiscountAmount) AS ItemDiscountAmount, @Yesterday Report_EndDate, @FirstOfQuarter Report_StartDate 
		 --MMSR.DeptDescription, MMSR.ProductDescription, MMSR.PostDateTime, MMSR.TranDate, MMSR.TranTypeDescription
          FROM vMMSRevenueReportSummary MMSR
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
-- 	           LEFT JOIN dbo.vCompany CO 
--                 ON CO.CompanyID = MS.CompanyID
               JOIN dbo.vProductGroup PG
                 ON PG.ProductID = MMSR.ProductID
          WHERE MMSR.PostDateTime >= @FirstOfQuarter
                AND MMSR.PostDateTime <= @Yesterday 
                AND MMSR.DeptDescription = 'Merchandise'
		  GROUP BY MMSR.PostingClubid, MMSR.PostingClubName, MMSR.ProductID


UNION

SELECT PostingClubid, PostingClubName, ProductID, 'MMS non Polar/Garmin merchandise' AS DataType, SUM(ItemAmount) AS ItemAmount,
       SUM(ItemDiscountAmount) AS ItemDiscountAmount, @Yesterday Report_EndDate, @FirstOfQuarter Report_StartDate 
FROM
(
  SELECT DISTINCT 
		  MMSR.PostingClubid, MMSR.PostingClubName, MMSR.ProductID, mmsr.TranItemID, MMSR.ItemAmount, MMSR.ItemDiscountAmount
          FROM vMMSRevenueReportSummary MMSR
 	           JOIN dbo.vMembership MS 
		         ON MS.MembershipID = MMSR.MembershipID
-- 	           LEFT JOIN dbo.vCompany CO 
--                 ON CO.CompanyID = MS.CompanyID
			   LEFT JOIN vMMSCommissionableSalesSummary CSS
				 ON MMSR.TranItemID = CSS.TranItemID
               LEFT JOIN vProductGroup PG
                 ON MMSR.ProductID = PG.ProductID 
          WHERE MMSR.PostDateTime >= @FirstOfQuarter
                AND MMSR.PostDateTime <= @Yesterday 
                AND (MMSR.DeptDescription in('Merchandise')AND MMSR.ItemAmount <> 0)
			    AND PG.ProductID IS NULL
				-- commissioned products only
			    --AND CSS.TranItemID IS NOT NULL 
) AS T
GROUP BY PostingClubid, PostingClubName, ProductID 

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
