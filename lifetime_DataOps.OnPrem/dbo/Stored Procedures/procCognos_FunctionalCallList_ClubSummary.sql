
CREATE PROC [dbo].[procCognos_FunctionalCallList_ClubSummary] (
   @RegionList VARCHAR(8000),
   @ClubIDList VARCHAR(8000),
   @MembershipStatusList VARCHAR(1000),
   @BalanceOwed INT
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

------ Sample Execution
--- Exec procCognos_FunctionalCallList_ClubSummary 'All Regions','All Clubs','Active|Pending Termination|Suspended|Late Activation|Non-Paid|Non-Paid, Late Activation',0
------  

 ----- Declare variables and temp tables
DECLARE @ReportDate DATETIME
DECLARE @FirstOfReportMonth DATETIME
DECLARE @ReportDatePlus1 DATETIME
DECLARE @ReportRunDateTime VARCHAR(21)

SET @ReportDate = Cast(GetDate() AS Date)
SET @FirstOfReportMonth = (SELECT CalendarMonthStartingDate FROM vReportDimDate WHERE CalendarDate = @ReportDate )						
SET @ReportDatePlus1 = DATEADD(Day,1,@ReportDate)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')



CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #MembershipStatusList (MembershipStatus VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
INSERT INTO #MembershipStatusList (MembershipStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT DISTINCT Club.ClubID as ClubID, Region.Description AS Region, Club.ClubName
  INTO #Clubs
  FROM vClub Club
  JOIN fnParsePipeList(@ClubIDList) MMSClubIDList
    ON Convert(Varchar,Club.ClubID) = MMSClubIDList.Item
    OR @ClubIDList like '%All Clubs%'
  JOIN vValRegion Region
    ON Club.ValRegionID = Region.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON Region.Description = RegionList.Item
    OR @RegionList like '%All Regions%'


DECLARE @HeaderMembershipStatusList  VARCHAR(1000)
DECLARE @HeaderAllRegionsSelected VARCHAR(1000)
DECLARE @HeaderAllClubsSelected VARCHAR(100)

SET @HeaderMembershipStatusList = STUFF((SELECT DISTINCT ', ' + tMSL.MembershipStatus
                                       FROM #MembershipStatusList tMSL                                 
                                       FOR XML PATH('')),1,1,'') 
SET @HeaderAllRegionsSelected = CASE WHEN @RegionList Like'%All Regions%' 
                                            AND @ClubIDList Like'%All Clubs%'
                                     THEN 'Selected Regions: All Regions'
									 ELSE 'Selected Regions: ' + STUFF((SELECT DISTINCT ', ' + tMSL.Region
                                       FROM #Clubs tMSL                                 
                                       FOR XML PATH('')),1,1,'') 
									 END
SET @HeaderAllClubsSelected = CASE WHEN @ClubIDList Like'%All Clubs%' 
                                     THEN 'Selected Clubs: All Clubs'
								   WHEN (Select Count(ClubID) from #Clubs) = 1
								     THEN 'Selected Club: ' + (Select ClubName from #Clubs) 
									 ELSE 'Selected Clubs: Multiple Clubs'
									 END



  --- Find all membership IDs for selected parameters - 
SELECT MB.MembershipID,
       MB.CommittedBalanceProducts 
INTO #DelinquentMembershipIDs
FROM vMembershipBalance MB
JOIN vMembership MS
 ON MB.MembershipID = MS.MembershipID
JOIN #Clubs Club
 ON MS.ClubID = Club.ClubID
JOIN vValMembershipStatus VMS
 ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN #MembershipStatusList MSL
 ON VMS.Description = MSL.MembershipStatus
WHERE MB.CommittedBalanceProducts > 0                ------ to limit the report to memberships which only have product balances (no Dues balance)
  AND MB.CommittedBalance <= 0
  AND (MB.CommittedBalanceProducts + MB.CommittedBalance) > 0


  ------  Find all Product Charge transactions for the selected memberships for the report month
  SELECT  MT.MMSTranID,
          MT.MembershipID,
		  1 AS ProductAssessCount,
		  MT.TranAmount AS ProductAssessAmount,
          MT.EmployeeID,
		  E.FirstName, 
		  E.LastName,
		  MT.TranDate, 
		  RC.Description AS TranReason
INTO #ProductAssessments
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID

WHERE MT.ValTranTypeID = 1
  AND MT.TranDate >= @FirstOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0
  AND MT.DomainName = 'eft_assess_products'

  ---- separate result to just return totals
SELECT MembershipID,
       Sum(ProductAssessCount) AS TotalProductAssessmentCount, 
	   SUM(ProductAssessAmount) AS TotalProductAssessmentAmount,
	   MAX(TranDate) AS MaxTranDate
INTO #ProductAssessmentTotals
FROM #ProductAssessments
GROUP BY MembershipID


  ----- Find all payments on account for selected memberships for 1st of month through report date
SELECT MT.MMSTranID,
       MT.MembershipID,1 AS PaymentCount,
	   MT.TranAmount AS PaymentAmount,
       MT.EmployeeID,
	   E.FirstName, 
	   E.LastName,
	   MT.TranDate, 
	   RC.Description AS TranReason
INTO #Payment
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
ON MT.ReasonCodeID = RC.ReasonCodeID
WHERE MT.ValTranTypeID = 2
  AND MT.TranDate >= @FirstOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0

  ---- separate result to just return totals
SELECT MembershipID,
       Sum(PaymentCount) AS TotalPaymentCount, 
	   SUM(PaymentAmount) AS TotalPaymentAmount,
	   MAX(TranDate) AS MaxPaymentDate
INTO #PaymentTotals
FROM #Payment
GROUP BY MembershipID

 ----- Find all adjustments for selected memberships for 2nd of month through report date
SELECT MT.MMSTranID,
       MT.MembershipID,
	   1  AS AdjustmentCount,
	   MT.TranAmount AS AdjustmentAmount,
       MT.EmployeeID,
	   E.FirstName, 
	   E.LastName,
	   MT.TranDate, 
	   RC.Description AS TranReason
INTO #Adjustment
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID
WHERE MT.ValTranTypeID = 4
  AND MT.TranDate >= @FirstOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0

    ---- separate result to just return totals
SELECT MembershipID,
       Sum(AdjustmentCount) AS TotalAdjustmentCount, 
	   SUM(AdjustmentAmount) AS TotalAdjustmentAmount,
	   MAX(TranDate) AS MaxAdjustmentDate
INTO #AdjustmentTotals
FROM #Adjustment
GROUP BY MembershipID



 --- grab additional membership data and related data
SELECT IDs.MembershipID, 
	   MS.AdvisorEmployeeID AS SellingAdvisorEmployeeID,
	   Advisor.FirstName AS AdvisorFirstName,
	   Advisor.LastName AS AdvisorLastName,
	   VMS.Description AS MembershipStatus,
	   MS.CreatedDateTime AS MembershipCreatedDate,
	   MS.ExpirationDate,
	   MS.ValMembershipStatusID,
	   Region.Description as MMSRegion,
	   HomeClub.ClubName,
	   HomeClub.ClubID
INTO #Memberships
FROM #DelinquentMembershipIDs  IDs
JOIN vMembership MS
  ON IDs.MembershipID = MS.MembershipID
JOIN vValMembershipStatus VMS
  ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN vClub HomeClub
  ON MS.ClubID = HomeClub.ClubID
JOIN vValRegion Region
  ON HomeClub.ValRegionID = Region.ValRegionID
LEFT JOIN vEmployee Advisor
  ON MS.AdvisorEmployeeID = Advisor.EmployeeID


  --- combine all returned data
SELECT 
       MS.MMSRegion,
	   MS.ClubName,
	   MS.ClubID,
	   MS.MembershipID, 
	   MS.SellingAdvisorEmployeeID,
	   MS.AdvisorFirstName,
	   MS.AdvisorLastName,
	   MS.MembershipStatus,
	   MS.MembershipCreatedDate,
	   MS.ExpirationDate,

	   MB.CurrentBalance AS CurrentBalanceDues,
	   MB.CurrentBalanceProducts,

	   PAT.TotalProductAssessmentCount AS MTD_ProductAssessmentCount,
	   PAT.TotalProductAssessmentAmount AS MTD_ProductAssessmentAmount,
	   PAT.MaxTranDate AS MTD_MostRecentAssessmentDate,
	   PT.TotalPaymentCount AS MTD_PaymentCount,
	   PT.TotalPaymentAmount AS MTD_PaymentOnAccount,
	   PT.MaxPaymentDate AS MTD_MostRecentPaymentDate,
	   AT.TotalAdjustmentCount AS MTD_AdjustmentCount,
	   AT.TotalAdjustmentAmount AS MTD_AdjustmentAmount,
	   AT.MaxAdjustmentDate AS MTD_MostRecentAdjustmentDate

INTO #SummaryDetail
FROM #Memberships MS

LEFT JOIN vMembershipBalance MB
   ON MS.MembershipID = MB.MembershipID

LEFT JOIN #PaymentTotals PT
   ON MS.MembershipID = PT.MembershipID
LEFT JOIN #AdjustmentTotals AT
   ON MS.MembershipID = AT.MembershipID
LEFT JOIN #ProductAssessmentTotals PAT
   ON MS.MembershipID = PAT.MembershipID
   WHERE MB.CurrentBalance < @BalanceOwed

ORDER BY MS.MembershipID


SELECT MMSRegion,
	   ClubName,
	   COUNT(MembershipID) AS MembershipCount,
	   SUM(CurrentBalanceDues) AS CurrentBalanceDues,
	   SUM(CurrentBalanceProducts) AS CurrentBalanceProducts,
	   SUM(MTD_ProductAssessmentCount) AS MTD_ProductAssessmentCount,
	   SUM(MTD_ProductAssessmentAmount) AS MTD_ProductAssessmentAmount,
	   SUM(MTD_PaymentCount) AS MTD_PaymentCount,
	   SUM(MTD_PaymentOnAccount) AS MTD_PaymentOnAccount,
	   SUM(MTD_AdjustmentCount) AS MTD_AdjustmentCount,
	   SUM(MTD_AdjustmentAmount) AS MTD_AdjustmentAmount,	   
	   @ReportRunDateTime AS ReportRunDateTime,
	   @ReportDate AS HeaderReportDate,
	   @HeaderMembershipStatusList AS HeaderMembershipStatusList,
	   @HeaderAllRegionsSelected AS HeaderAllRegionsSelected,
	   @HeaderAllClubsSelected AS HeaderAllClubsSelected,
	   ClubID
 FROM #SummaryDetail
 GROUP BY MMSRegion,
	   ClubName,
	   ClubID

DROP TABLE #tmpList
DROP TABLE #MembershipStatusList
DROP TABLE #Clubs
DROP TABLE #DelinquentMembershipIDs
DROP TABLE #ProductAssessmentTotals
DROP TABLE #ProductAssessments
DROP TABLE #Payment
DROP TABLE #PaymentTotals
DROP TABLE #Adjustment
DROP TABLE #AdjustmentTotals

DROP TABLE #Memberships
DROP TABLE #SummaryDetail



END
