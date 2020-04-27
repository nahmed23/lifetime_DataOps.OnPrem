




CREATE PROC [dbo].[procCognos_FunctionalCallListDetail] (
   @RegionList VARCHAR(8000),
   @ClubIDList VARCHAR(8000),
   @MembershipStatusList VARCHAR(1000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END


------ Sample Execution
--- Exec procCognos_FunctionalCallListDetail 'All Regions','All Clubs','Active|Pending Termination|Suspended|Late Activation|Non-Paid|Non-Paid, Late Activation'
------
--DECLARE @RegionList VARCHAR(8000) = 'All Regions'
--DECLARE @ClubIDList VARCHAR(8000) = 'All Clubs'
--DECLARE @MembershipStatusLIst VARCHAR(8000) = 'Active|Pending Termination|Suspended|Late Activation|Non-Paid|Non-Paid, Late Activation'

-- ----- Declare variables and temp tables
DECLARE @ReportDate DATETIME
DECLARE @FirstOfReportMonth DateTime
DECLARE @ReportDatePlus1 DateTime
DECLARE @ReportDateMinus120 DateTime
DECLARE @ReportRunDateTime VARCHAR(21)

SET @ReportDate = Cast(GetDate() AS Date)
SET @FirstOfReportMonth = (SELECT CalendarMonthStartingDate FROM vReportDimDate WHERE CalendarDate = @ReportDate )						
SET @ReportDatePlus1 = DATEADD(Day,1,@ReportDate)
SET @ReportDateMinus120 = DATEADD(Day,-120,@ReportDate)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')



CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #MembershipStatusList (MembershipStatus VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
INSERT INTO #MembershipStatusList (MembershipStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT DISTINCT Club.ClubID as ClubID
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

SET @HeaderMembershipStatusList = STUFF((SELECT DISTINCT ', ' + tMSL.MembershipStatus
                                       FROM #MembershipStatusList tMSL                                 
                                       FOR XML PATH('')),1,1,'') 


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
  --AND MB.CommittedBalance <= 0
  AND (MB.CommittedBalanceProducts + MB.CommittedBalance) > 0


  ------  Find all Product Charge transactions for the selected memberships for the past 120 days
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
  AND MT.TranDate >= @ReportDateMinus120
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


  ----- Find all payments on account for selected memberships for past 120 days
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
  AND MT.TranDate >= @ReportDateMinus120
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

 ----- Find all adjustments for selected memberships for last 120 days  (this will include subsidy adjustments)
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
  AND MT.TranDate >= @ReportDateMinus120
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

  --- Find the most recent EFT Draft record for each membership in the last 120 days
SELECT IDs.MembershipID,
       Max(EFT.EFTID) AS EFTID
INTO #MostRecentEFTID
FROM vEFT EFT
JOIN #DelinquentMembershipIDs IDs
  ON EFT.MembershipID = IDs.MembershipID
WHERE EFT.EFTDate >= @ReportDateMinus120
  AND EFT.EFTDate < @ReportDatePlus1
GROUP BY IDs.MembershipID


  --- get detail from the membership's most recent draft record in the period
SELECT EFT.MembershipID,
       EFT.EFTDate,
       EFT.ReturnCode,
	   ReturnCode.Description AS ReturnCodeDescription
INTO #EFTReturnCodeAndDate
FROM vEFT AS EFT
JOIN #MostRecentEFTID  AS IDs
  ON EFT.EFTID = IDs.EFTID
JOIN vEFTReturnCode ReturnCode
  ON EFT.EFTReturnCodeID = ReturnCode.EFTReturnCodeID


  ---  See if the membership account information was updated through myLT in the period
SELECT IDs.MembershipID,
       'Y' AS UpdateAccountViaMyLT,
	   MAX(Substring(MM.Comment,43,(Len(MM.Comment)-57))) AS myLTUser
INTO #MyLTUpdate
FROM vMembershipMessage MM
JOIN #DelinquentMembershipIDs IDs
  ON MM.MembershipID = IDs.MembershipID
WHERE  MM.ValMembershipMessageTypeID in (64, 65) ------ Changed Credit Card EFT / Changed Bank EFT
  AND MM.OpenEmployeeID = -3     ---- "My Account"
  AND MM.OpenDateTime >= @FirstOfReportMonth
  AND MM.OpenDateTime < @ReportDatePlus1
GROUP BY IDs.MembershipID

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
	   MembershipTypeProduct.Description AS MembershipType,
	   M.JoinDate AS PrimaryMemberJoinDate,
	   M.EmailAddress,
	   M.MemberID AS PrimaryMemberID,
	   M.FirstName AS PrimaryMemberFirstName,
	   M.LastName AS PrimaryMemberLastName,
	   M.Party_ID
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
JOIN vProduct MembershipTypeProduct
  ON MS.MembershipTypeID = MembershipTypeProduct.ProductID
JOIN vMember M
   ON IDs.MembershipID = M.MembershipID
LEFT JOIN vEmployee Advisor
  ON MS.AdvisorEmployeeID = Advisor.EmployeeID
WHERE M.ValMemberTypeID = 1   ----- PrimaryMember


 ---- Find myLT Username for the primary member from delinquent memberships
SELECT  LTFIdentity.party_id, 
        LTFIdentity.ltf_user_name AS myLT_Username,
        #Memberships.MembershipID,
		#Memberships.PrimaryMemberID
  INTO #myLTUsernames
  FROM [Report_LTFEB].[dbo].[vLTFUserIdentity] LTFIdentity
    JOIN #Memberships
      ON #Memberships.Party_ID = LTFIdentity.party_id 



  Select IDs.MembershipID, 
		 SUM(TranBalance.TranBalanceAmount) AS SumTranBalanceAmount,
		 MT.PostDateTime,
		 TranBalance.TranItemID,
		 CASE WHEN IsNull(TranBalance.TranItemID,0) = 0 
		      THEN 'over 120'
		      WHEN DateDiff(day,MT.PostDateTime,@ReportDate) <31
		      THEN '0-30'
			  WHEN DateDiff(day,MT.PostDateTime,@ReportDate) >= 31
			    AND DateDiff(day,MT.PostDateTime,@ReportDate) < 61
			  THEN '31-60'
			  WHEN DateDiff(day,MT.PostDateTime,@ReportDate) >= 61
			    AND DateDiff(day,MT.PostDateTime,@ReportDate) < 91
			  THEN '61-90'
			  WHEN DateDiff(day,MT.PostDateTime,@ReportDate) >= 91
			    AND DateDiff(day,MT.PostDateTime,@ReportDate) < 121
			  THEN '91-120'
			   ELSE 'over 120'
			  END ProductAging,
		 MMSDepartment.Description AS MMSDepartment,
		 Product.Description AS ProductDescription,
		 Club.ClubName As TransactionClub,
		 MRP.ActivationDate,
		 MRP.TerminationDate,
		 TermReason.Description AS TerminationReason
    INTO #DelProductAging
   FROM #DelinquentMembershipIDs IDs
   JOIN vTranBalance  TranBalance
     ON IDs.MembershipID = TranBalance.MembershipID
   LEFT JOIN vTranItem TI
     ON TranBalance.TranItemID = TI.TranItemID
   LEFT JOIN vMMSTran MT
     ON TI.MMSTranID = MT.MMSTranID
   LEFT JOIN vProduct Product
     ON TI.ProductID = Product.ProductID
   LEFT JOIN vDepartment MMSDepartment
     ON Product.DepartmentID = MMSDepartment.DepartmentID
   LEFT JOIN vClub Club
     ON MT.ClubID = Club.ClubID
   LEFT JOIN vMembershipRecurrentProductTranItem MRPTI
     ON MRPTI.TranItemID = TI.TranItemID
   LEFT JOIN vMembershipRecurrentProduct MRP
	 ON MRP.MembershipRecurrentProductID = MRPTI.MembershipRecurrentProductID
   LEFT JOIN vValRecurrentProductTerminationReason TermReason
     ON MRP.ValRecurrentProductTerminationReasonID = TermReason.ValRecurrentProductTerminationReasonID
  WHERE TranBalance.TranProductCategory = 'Products'
  GROUP BY IDs.MembershipID, 
           MT.PostDateTime,
		   TranBalance.TranItemID,
		   MMSDepartment.Description,
		   Product.Description,
		   Club.ClubName,
		   MRP.ActivationDate,
		   MRP.TerminationDate,
		   TermReason.Description


  --- combine all returned data
SELECT 
       MS.MMSRegion,
	   MS.ClubName,
	   MS.MembershipID, 
	   MS.SellingAdvisorEmployeeID,
	   MS.AdvisorFirstName,
	   MS.AdvisorLastName,
	   MS.MembershipStatus,
	   MS.MembershipCreatedDate,
	   MS.ExpirationDate,
	   MSA.AddressLine1,
	   MSA.AddressLine2,
	   MSA.City,
	   VS.Abbreviation,
	   MSA.Zip,
	   MP.HomePhoneNumber,
	   MP.BusinessPhoneNumber,
	   MS.PrimaryMemberJoinDate,
	   MS.EmailAddress,
	   MS.PrimaryMemberID,
	   MS.PrimaryMemberFirstName,
	   MS.PrimaryMemberLastName,
	   MB.CommittedBalance AS CommittedBalanceDues,
	   MB.CurrentBalance AS CurrentBalanceDues,
	   MB.CurrentBalanceProducts,
	   VPT.Description AS EFTType,
	   EFTOption.Description AS EFTStatus,
	   EFTAcct.ExpirationDate AS EFTExpirationDate,
	   EFT.ReturnCode AS MostRecentReturnCode_120Days,
	   EFT.ReturnCodeDescription,
	   EFT.EFTDate AS MostRecentReturnDate_120Days,
	   PAT.TotalProductAssessmentCount AS ProductAssessmentCount_120Days,
	   PAT.TotalProductAssessmentAmount AS ProductAssessmentAmount_120Days,
	   PAT.MaxTranDate AS MostRecentAssessmentDate_120Days,
	   PT.TotalPaymentCount AS PaymentCount_120Days,
	   PT.TotalPaymentAmount AS PaymentOnAccount_120Days,
	   PT.MaxPaymentDate AS MostRecentPaymentDate_120Days,
	   AT.TotalAdjustmentCount AS AdjustmentCount_120Days,
	   AT.TotalAdjustmentAmount AS AdjustmentAmount_120Days,
	   AT.MaxAdjustmentDate AS MostRecentAdjustmentDate_120Days,
	   MyLTUpdate.UpdateAccountViaMyLT AS ReportMonthAccountUpdateViaMyLT,
	   MyLTUpdate.myLTUser,
	   @ReportRunDateTime AS ReportRunDateTime,
	   @ReportDate AS HeaderReportDate,
	   @HeaderMembershipStatusList AS HeaderMembershipStatusList,
	   MS.MembershipType,
	   DelAging.MMSDepartment,
	   DelAging.ProductDescription,
	   DelAging.PostDateTime AS AssessmentDateTime,
	   DelAging.ProductAging,
	   DelAging.SumTranBalanceAmount AS AgingAmount,
	   DelAging.TransactionClub,
	   DelAging.ActivationDate,
	   DelAging.TerminationDate,
	   DelAging.TerminationReason,
	   myLTUsernames.myLT_Username AS PrimaryMember_myLT_Username
FROM #Memberships MS
JOIN vMembershipAddress MSA
   ON MS.MembershipID = MSA.MembershipID
JOIN vValState VS
   ON MSA.ValStateID = VS.ValStateID
LEFT JOIN vMemberPhoneNumbers MP
   ON MS.MembershipID = MP.MembershipID
LEFT JOIN vMembershipBalance MB
   ON MS.MembershipID = MB.MembershipID
LEFT JOIN vEFTPaymentAccount EFTAcct
   ON MS.MembershipID = EFTAcct.MembershipID
LEFT JOIN vValPaymentType VPT
   ON EFTAcct.ValPaymentTypeID = VPT.ValPaymentTypeID
LEFT JOIN vValEFTOption EFTOption
   ON EFTAcct.ValEFTOptionID = EFTOption.ValEFTOptionID
LEFT JOIN #EFTReturnCodeAndDate EFT
   ON MS.MembershipID = EFT.MembershipID
LEFT JOIN #MyLTUpdate MyLTUpdate
   ON MS.MembershipID = MyLTUpdate.MembershipID
LEFT JOIN #PaymentTotals PT
   ON MS.MembershipID = PT.MembershipID
LEFT JOIN #AdjustmentTotals AT
   ON MS.MembershipID = AT.MembershipID
LEFT JOIN #ProductAssessmentTotals PAT
   ON MS.MembershipID = PAT.MembershipID
LEFT JOIN #DelProductAging DelAging
   ON MS.MembershipID = DelAging.MembershipID
LEFT JOIN #myLTUsernames myLTUsernames
   ON MS.PrimaryMemberID = myLTUsernames.PrimaryMemberID
WHERE MSA.ValAddressTypeID = 1  ----- Membership Address
 -- AND MB.CurrentBalance <= 0
ORDER BY MS.MMSRegion,
	   MS.ClubName, MS.MembershipID

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
DROP TABLE #MostRecentEFTID
DROP TABLE #EFTReturnCodeAndDate
DROP TABLE #MyLTUpdate
DROP TABLE #Memberships
DROP TABLE #DelProductAging
DROP TABLE #myLTUsernames



END





