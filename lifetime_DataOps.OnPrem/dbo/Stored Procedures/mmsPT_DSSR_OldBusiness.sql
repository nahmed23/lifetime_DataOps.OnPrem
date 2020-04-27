





CREATE       PROCEDURE [dbo].[mmsPT_DSSR_OldBusiness]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- =============================================
-- Object:			dbo.mmsPT_DSSR_OldBusiness
-- Author:			
-- Create date: 	
-- Description:		THIS PROCEDURE RETURNS REVENUE TRANSACTIONS FOR SELECTED PT PRODUCTS
--					WHICH OCCURRED IN THE PAST 3 MONTHS
-- Modified date:	12/23/2008 GRB: added product ids associated with rr370;
--                  09/17/2010 MLL: Updated to only return Sum(MMSR.ItemAmount) and MMSR.MemberID
--                  03/04/2011 BSD: Updated filter to filter out EmployeeID = -5
--                  05/04/2011 BSD: Removed 'Mixed Combat Arts' DepartmentID 33 QC#7087
-- 	
-- Exec mmsPT_DSSR_OldBusiness 
-- =============================================


DECLARE @FirstOf3MonthsPrior DATETIME
DECLARE @FirstOfCurrentMonth DATETIME

SET @FirstOf3MonthsPrior = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-3, GETDATE() - DAY(GETDATE()-1)),110),110)
SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE() - DAY(GETDATE()-1),110),110)

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT SUM(MMSR.ItemAmount) AS Sum_ItemAmount,
       MMSR.MemberID
  FROM vMMSRevenueReportSummary MMSR
  JOIN vProductGroup PG
    ON PG.ProductID = MMSR.ProductID
  JOIN vProduct P
    ON P.ProductID = PG.ProductID
  JOIN vDepartment D
    ON D.DepartmentID = P.DepartmentID
 WHERE D.DepartmentID in (7,9,10,19)   ------ Merchandise, Personal Training, Mind Body, Nutrition Coaching
   AND PG.Old_vs_NewBusiness_TrackingFlag = 1
   AND MMSR.PostDateTime >= @FirstOf3MonthsPrior
   AND MMSR.PostDateTime < @FirstOfCurrentMonth
   AND MMSR.EmployeeID <> -5 --3/4/2011 BSD
 GROUP BY MMSR.MemberID

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
