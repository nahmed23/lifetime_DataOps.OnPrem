
CREATE PROC [dbo].[procCognos_DelinquentAgingDashboard_CollectionsMTDByProductCategory] 

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

----- Sample Execution
--- Exec procCognos_DelinquentAgingDashboard_CollectionsMTDByProductCategory 
-----


DECLARE @ReportRunDateTime DateTime
SELECT @ReportRunDateTime = GetDate()


DECLARE @QueryDateTime DateTime
SET @QueryDateTime = Cast(GETDATE() AS Date) 


--- to get a list of memberships and balances outstanding at BOM

Select BOM.MembershipID,
       BOM.TranProductCategory,
       MS.ClubID,
       Sum(BOM.AmountDue) AS BalanceDueAtBOM
	INTO #DelinquentMembershipsBOM
 FROM DelinquentMembershipBalance_BeginningOfMonth  BOM
   JOIN vMembership MS
     ON BOM.MembershipID = MS.MembershipID
 Where BOM.EffectiveDate <= @QueryDateTime
  AND  BOM.ExpirationDate > @QueryDateTime
  GROUP BY BOM.MembershipID,MS.ClubID,BOM.TranProductCategory


 ---- to get a list of these memberships and their balances outstanding at report date
  Select MB.MembershipID,
       'Products' AS TranProductCategory,
		MB.CurrentBalanceProducts AS AmountDue
 INTO #MembershipsStillDelinquentAtReportDate
FROM vMembershipBalance MB
 JOIN #DelinquentMembershipsBOM MS
   ON MS.MembershipID = MB.MembershipID
WHERE MB.CurrentBalanceProducts <> 0
  AND MS.TranProductCategory = 'Products'

UNION ALL

Select MB.MembershipID,
       'Dues' AS TranProductCategory,
		MB.CurrentBalance AS AmountDue
FROM vMembershipBalance MB
 JOIN #DelinquentMembershipsBOM MS
   ON MS.MembershipID = MB.MembershipID
WHERE MB.CurrentBalance <> 0
  AND MS.TranProductCategory = 'Dues'



SELECT Region.Description AS MMSRegion,
	   Club.ClubCode,
       BOM.ClubID,
       BOM.TranProductCategory,
	   SUM(BOM.BalanceDueAtBOM) AS AmountDueBOM,
	   SUM(DEL.AmountDue) AS AmountDue,
	   Sum(CASE WHEN (BOM.BalanceDueAtBOM - IsNull(DEL.AmountDue,0)) < 0   ---Del. amount increased
	        THEN 0
			ELSE (BOM.BalanceDueAtBOM - IsNull(DEL.AmountDue,0))
			END)  CollectedAmount,
       Sum(CASE WHEN BOM.TranProductCategory = 'Dues'
	        THEN BOM.BalanceDueAtBOM
			ELSE 0
			END) AmountDueBOM_Dues,
	   Sum(CASE WHEN BOM.TranProductCategory = 'Dues'
	        THEN DEL.AmountDue
			ELSE 0
			END) AmountDue_Dues,
	   Sum(CASE WHEN BOM.TranProductCategory = 'Dues'
	        THEN CASE WHEN (BOM.BalanceDueAtBOM - IsNull(DEL.AmountDue,0)) < 0   ---Del. amount increased
	                  THEN 0
			          ELSE (BOM.BalanceDueAtBOM - IsNull(DEL.AmountDue,0))
			           END 
			ELSE 0
			END) CollectedAmount_Dues,
	   Sum(CASE WHEN BOM.TranProductCategory = 'Products'
	        THEN BOM.BalanceDueAtBOM
			ELSE 0
			END) AmountDueBOM_Products,
	   Sum(CASE WHEN BOM.TranProductCategory = 'Products'
	        THEN DEL.AmountDue
			ELSE 0
			END) AmountDue_Products,
	   Sum(CASE WHEN BOM.TranProductCategory = 'Products'
	        THEN CASE WHEN (BOM.BalanceDueAtBOM - IsNull(DEL.AmountDue,0)) < 0   ---Del. amount increased
	                  THEN 0
			          ELSE (BOM.BalanceDueAtBOM - IsNull(DEL.AmountDue,0))
			           END 
			ELSE 0
			END) CollectedAmount_Products,
		@ReportRunDateTime AS ReportRunDateTime,
		@QueryDateTime AS ReportDate
  FROM #DelinquentMembershipsBOM BOM
   JOIN vClub Club
     ON BOM.ClubID = Club.ClubID
   JOIN vValRegion Region
     ON Club.ValRegionID = Region.ValRegionID
   LEFT JOIN #MembershipsStillDelinquentAtReportDate DEL
     ON BOM.MembershipID = DEL.MembershipID
	  AND BOM.TranProductCategory = DEL.TranProductCategory
   GROUP BY Region.Description,
	   Club.ClubCode,
       BOM.ClubID,
       BOM.TranProductCategory

DROP TABLE #DelinquentMembershipsBOM
DROP TABLE #MembershipsStillDelinquentAtReportDate
END
