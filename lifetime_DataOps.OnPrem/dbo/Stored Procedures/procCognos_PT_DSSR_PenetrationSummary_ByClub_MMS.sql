
CREATE PROC [dbo].[procCognos_PT_DSSR_PenetrationSummary_ByClub_MMS] (
    @ReportedData Varchar(50),
	 @ReportSort Varchar(50)
)


/*------  Sample execution

Exec procCognos_PT_DSSR_PenetrationSummary_ByClub_MMS 'Entire PT Division','By Region And Club'

*/ -------

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @StartDate AS DATETIME
DECLARE @ENDDate AS DATETIME
DECLARE @ReportDate AS VARCHAR(20)
DECLARE @ReportRunDateTime AS DATETIME
DECLARE @FirstOfPriorMonth AS DATETIME
DECLARE @FirstOfCurrentMonth DATETIME
DECLARE @PriorMonthCommaYear as VARCHAR(20)


SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
SET @ENDDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
SET @ReportDate = Replace(Substring(convert(varchar,getdate()-1,100),1,6)+', '+Substring(convert(varchar,getdate()-1,100),8,4),'  ',' ')
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')
SET @FirstOfPriorMonth = DATEADD(m,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))
SET @FirstOfCurrentMonth = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE() - DAY(GETDATE()-1),110),110)
SET @PriorMonthCommaYear = (DateName(month,@FirstOfPriorMonth)+', '+ DateName(year,@FirstOfPriorMonth))


  --- gather total member counts
SELECT C.ClubID as MMSClubID, Count (M.MemberID) AdultMemberCount,
       SUM( CASE
            WHEN M.JoinDate >= @FirstOfPriorMonth AND
                 M.JoinDate < @FirstOfCurrentMonth
            THEN 1
            ELSE 0
            END) NewAdultMemberCount_JoinedLastMonth
  INTO #TotalMemberCounts
  FROM dbo.vMember M
  JOIN dbo.vMembership MS
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
 WHERE (MS.ExpirationDate > @FirstOfCurrentMonth OR MS.ExpirationDate IS Null)
        AND M.ActiveFlag = 1
		AND M.ValMemberTypeID in (1,2,3)   ---- all except Juniors
        AND MS.ValMembershipStatusID <> 3 ----- Membership is not in Suspended status
		AND C.ValPreSaleID = 1
		AND M.JoinDate < @ENDDate
GROUP BY C.ClubName, C.ClubID




  ---gather Purchaser counts

SELECT MMSR.PostingClubName, 
       MMSR.PostingClubid, 
       ----TranTypeDescription, 
       MMSR.MemberID, 
       -----MMSR.EmployeeID,
       MMSR.PostingRegionDescription,
       @ReportDate ReportDate,
       CASE WHEN MMSR.PostDateTime < @StartDate 
	         THEN 1 
			 ELSE 0 
			 END PriorMonthTransactionFlag,
	   CASE WHEN M.JoinDate >=@FirstOfPriorMonth AND M.JoinDate < @FirstOfCurrentMonth
	         THEN 1
			 ELSE 0
			 END PriorMonthNewMemberFlag,
	   CASE WHEN ReportDimReportingHierarchy.SubdivisionName = 'Pilates'
	        THEN 'Pilates'
			ELSE 'Not Pilates'
			End ReportingHierarchyProductSubdivision,
       ----ReportDimProduct.DimReportingHierarchyKey,--vValProductGroup.ValProductGroupID,
       ----ReportDimReportingHierarchy.ProductGroupName,--vValProductGroup.Description AS ValProductGroupDescription,
       ----ReportDimReportingHierarchy.DepartmentName,--vValProductGroup.RevenueReportingDepartment,
	   (CAST(CONVERT(DATETIME, CONVERT(VARCHAR(10), MMSR.PostDateTime, 101) , 101) - 
           CONVERT(DATETIME, CONVERT(VARCHAR(10), M.JoinDate, 101) , 101) AS INT)) AS MembershipAgeInDays_AtPostDate       
INTO #MMSPurchasers 
  FROM vMMSRevenueReportSummary MMSR 
  Join vMember M
    On MMSR.MemberID = M.MemberID
  JOIN vProduct P 
    ON P.ProductID = MMSR.ProductID
  JOIN vReportDimProduct ReportDimProduct --11/14/2012 Corporate transfer
    ON MMSR.ProductID = ReportDimProduct.MMSProductID
  JOIN vReportDimReportingHierarchy ReportDimReportingHierarchy --1/16/2012 conversion to DimReportingHierarchy
    ON ReportDimProduct.DimReportingHierarchyKey = ReportDimReportingHierarchy.DimReportingHierarchyKey
  JOIN vMembership 
    ON vMembership.MembershipID = MMSR.MembershipID
  JOIN vClub C 
    ON MMSR.PostingClubID = C.ClubID
  JOIN vTranItem TI
    ON MMSR.TranItemID = TI.TranItemID
  LEFT JOIN vMMSTranRefund MTR
    ON TI.MMSTranID = MTR.MMSTranID
  LEFT JOIN vMMSTranRefundMMSTran MTRMT
    ON MTR.MMSTranRefundID = MTRMT.MMSTranRefundID
  LEFT JOIN vMMSTran MMSTran2
    ON MTRMT.OriginalMMSTranID = MMSTran2.MMSTranID
 WHERE P.ProductID not in(1482,2569,2785,2786)
   -------AND MMSR.DeptDescription <> 'Mind Body'
   AND MMSR.TranTypeDescription <> 'Refund'
   AND C.ValPreSaleID = 1
   AND ((MMSR.PostDateTime >= @StartDate AND MMSR.PostDateTime < @ENDDate)
         or 
        (MMSR.PostDateTime >= @FirstOfPriorMonth AND MMSR.PostDateTime < @StartDate 
            AND MMSR.TranMemberJoinDate >= @FirstOfPriorMonth AND MMSR.TranMemberJoinDate  < @StartDate))
  AND (ReportDimReportingHierarchy.DivisionName = 'Personal Training'
        And (MMSR.ItemAmount <> 0 
             OR (MMSR.ItemAmount = 0 AND MMSR.EmployeeID = -5) 
             OR (MMSR.ItemAmount = 0 AND ReportDimProduct.CorporateTransferFlag = 'Y'))) --11/14/2012 Corporate transfer 

Order by MMSR.PostingClubid, MMSR.MemberID,MMSR.PostingRegionDescription


  --- count all purchasing members


Select #M.PostingClubID, Count(Distinct(#M.MemberID)) MMS_MTD_PTPurchaserCount 
INTO #MMSPurchasersByClub 
From #MMSPurchasers #M
Where #M.PriorMonthTransactionFlag = 0
AND (@ReportedData = 'Entire PT Division'
      OR
	  (@ReportedData = 'Pilates Subdivision Only'
	    AND ReportingHierarchyProductSubdivision = 'Pilates')
	  OR
	   (@ReportedData = 'PT Division Less Pilates'
	     AND ReportingHierarchyProductSubdivision <> 'Pilates'))
Group By #M.PostingClubID


  --- count all new purchasing members

Select #MNew.PostingClubID, Count(Distinct(#MNew.MemberID)) MMS_PriorMonthNewMember_30DayPurchaserCount
INTO #MMSNewPurchasersByClub
From #MMSPurchasers #MNew
Where #MNew.MembershipAgeInDays_AtPostDate <=30
AND #MNew.PriorMonthNewMemberFlag = 1
AND (@ReportedData = 'Entire PT Division'
      OR
	  (@ReportedData = 'Pilates Subdivision Only'
	    AND ReportingHierarchyProductSubdivision = 'Pilates')
	  OR
	   (@ReportedData = 'PT Division Less Pilates'
	     AND ReportingHierarchyProductSubdivision <> 'Pilates'))
Group By #MNew.PostingClubID


  --- combine in final result set
Select C.ClubID as MMSClubID,
C.ClubName,
PTRCLArea.Description as PTRCLRegion, 
ISNull(AdultMemberCount,0) as AdultMemberCount,
ISNull(#MC.MMS_MTD_PTPurchaserCount,0) as MTD_PTPurchaserCount,
IsNull(#T.NewAdultMemberCount_JoinedLastMonth,0) as NewAdultMemberCount_JoinedLastMonth,
IsNull(#MNC.MMS_PriorMonthNewMember_30DayPurchaserCount,0) as PriorMonthNewMember_30DayPurchaserCount,
@ReportedData as ReportedData,
@PriorMonthCommaYear as PriorMonthCommaYear,
@ReportDate as ReportDate,
@ReportRunDateTime as ReportRunDateTime,
@ReportSort as ReportSort

From vClub C
Join vValPTRCLArea PTRCLArea
On C.ValPTRCLAreaID = PTRCLArea.ValPTRCLAreaID
Left Join #MMSPurchasersByClub #MC
On C.ClubID = #MC.PostingClubID
Left Join #MMSNewPurchasersByClub #MNC
ON C.ClubID = #MNC.PostingClubID
Left Join #TotalMemberCounts #T
On C.ClubID = #T.MMSClubID


Drop Table #MMSPurchasers 
Drop Table #MMSPurchasersByClub 
Drop Table #MMSNewPurchasersByClub
Drop Table #TotalMemberCounts

END
