

-- =============================================
-- Object:			dbo.mmsMemberActivities_GLPosting
-- Author:			
-- Create date: 	
-- Description:		
-- Modified date:	4/28/2008 GRB: added parm to variably filter transaction type
--					3/24/2008 GRB: added TransactionType field to SELECT statement and
--					additional condition to WHERE clause;
-- 	
-- Exec mmsMemberActivities_GLPosting '200803', 'refund'
-- =============================================

CREATE      PROC [dbo].[mmsMemberActivities_GLPosting] (
	@YearMonth VARCHAR(10),
	@TranType VARCHAR(10)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity int
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

SELECT	R.Description AS RegionDescription, C.ClubName, RAS.MAProductGroupDescription, 
		P.Description AS ProductDescription, RAS.GLRevenueAccount, C.GLClubID, 
		RAS.GLRevenueSubAccount, RAS.RevenueMonthAllocation, RAS.GLRevenueMonth,
		RAS.ProductID, 
		TransactionType		-- 3/24/2008 GRB
FROM vMemberActivitiesRevenueAllocationSummary RAS
      JOIN vCLUB C
        ON C.ClubID=RAS.MMSClubID
      JOIN vValRegion R
        ON R.ValRegionID=C.ValRegionID
      JOIN vProduct P
        ON RAS.ProductID=P.ProductID
  
WHERE RAS.GLRevenueMonth=@YearMonth AND
--	(TransactionType <> 'Refund' OR TransactionType IS NULL)	-- 3/24/2008 GRB
	(TransactionType <> @TranType OR TransactionType IS NULL)	-- 4/28/2008 GRB

 -- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
