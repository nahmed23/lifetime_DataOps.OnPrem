



CREATE PROC [dbo].[procCognos_DelinquentAging_MembershipDetail] (
    @ReportDate DATETIME,
	@RegionList VARCHAR(8000),
    @ClubIDList VARCHAR(8000),
    @DelinquentStatusList VARCHAR(100),
    @MembershipStatusList VARCHAR(1000),
    @MembershipTypeList VARCHAR(1000)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

IF 1=0 BEGIN
       SET FMTONLY OFF
     END

  -------------
  ------ Sample execution 
  ------ Exec procCognos_DelinquentAging_MembershipDetail '7/10/2016','All Regions','All Clubs','0-30|31-60|61-90','Active|Late Activation|Suspended|Non-Paid|Non-Paid Late Activation|Pending Termination|Terminated','All Memberships - Excluding Founders'
  -------------
--DECLARE @ReportDate DATETIME = '7/10/2018'
--DECLARE @RegionList VARCHAR(8000) = 'All Regions'
--DECLARE @ClubIDList VARCHAR(8000) = 'All Clubs'
--DECLARE @DelinquentStatusList VARCHAR(100) = '0-30|31-60|61-90'
--DECLARE @MembershipStatusList VARCHAR(1000) = 'Active|Late Activation|Suspended|Non-Paid|Non-Paid Late Activation|Pending Termination|Terminated'
--DECLARE @MembershipTypeList VARCHAR(1000) = 'All Memberships - Excluding Founders'


SET @ReportDate = CASE WHEN @ReportDate = 'Jan 1, 1900' THEN DATEADD(d,-1,DATEADD(mm, DATEDIFF(m,0,GETDATE())+1,0)) ELSE @ReportDate END  --Last Day of the Month

 ----- Declare variables and temp tables
DECLARE @FirstOfReportMonth DateTime
DECLARE @SecondOfReportMonth DateTime
DECLARE @ReportDatePlus1 DateTime
DECLARE @FirstOfNextMonth DateTime
DECLARE @FirstOf3MonthsPrior DateTime
SET @FirstOfReportMonth = (SELECT CalendarMonthStartingDate 
                             FROM vReportDimDate 
							 WHERE CalendarDate = @ReportDate)
SET @SecondOfReportMonth = DATEADD(day,1,@FirstOfReportMonth)
SET @ReportDatePlus1 = DATEADD(Day,1,@ReportDate)
SET @FirstOfNextMonth = DATEADD(Month,1,@FirstOfReportMonth)
SET @FirstOf3MonthsPrior = DATEADD(Month,-3,@FirstOfReportMonth)

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #DelinquentStatusList (DelinquentStatus VARCHAR(50))
EXEC procParseStringList @DelinquentStatusList 
INSERT INTO #DelinquentStatusList (DelinquentStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

CREATE TABLE #MembershipStatusList (MembershipStatus VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
INSERT INTO #MembershipStatusList (MembershipStatus) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList

SELECT Cast(MembershipTypeList.Item AS VARCHAR(255)) MembershipType
  INTO #MembershipTypeList
  FROM fnParsePipeList(@MembershipTypeList) MembershipTypeList

SELECT MembershipType.ProductID
INTO #LoyaltyMembershipProductIDs
FROM vMembershipType MembershipType
 JOIN vMembershipTypeAttribute MembershipTypeAttribute
   ON MembershipType.MembershipTypeID = MembershipTypeAttribute.MembershipTypeID
WHERE MembershipTypeAttribute.ValMembershipTypeAttributeID = 49   ----"Loyalty Membership" 

SELECT DISTINCT MMSProductID ProductID
  INTO #IncludeMembershipProducts
  FROM vReportDimProduct
 WHERE SalesCategoryDescription = 'Membership Type'
   AND ((MembershipTypeFoundersFlag = 'N' AND 'All Memberships - Excluding Founders' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeHouseAccountFlag = 'N' AND 'All Memberships - Excluding House Account' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeCorporateFlexFlag = 'Y' AND 'Corporate Flex Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeEmployeeFlag = 'Y' AND 'Employee Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeFlexiblePassFlag = 'Y' AND 'Flexible Pass Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))									
        OR (MembershipTypeFoundersFlag = 'Y' AND 'Founders Type Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeHouseAccountFlag = 'Y' AND 'House Account Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeInvestorFlag = 'Y' AND 'Investor Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeMyHealthCheckFlag = 'Y' AND 'myHealthCheck Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeNonAccessFlag = 'Y' AND 'Non-Access Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))												--Non-Access
        OR (MembershipTypePendingNonAccessFlag = 'Y' AND 'Pending Non-Access Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeShortTermFlag = 'Y' AND 'Short Term Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))											--Month to Month?
        OR (MembershipTypeStudentFlexFlag = 'Y' AND 'Student Flex Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeTradeOutFlag = 'Y' AND 'Trade Out Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeVIPFlag = 'Y' AND 'VIP Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))															
        OR (MembershipType26AndUnderFlag = 'Y' AND '26 and Under Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MembershipTypeLifeTimeHealthFlag = 'Y' AND 'Life Time Health Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))
        OR (MMSProductID IN(SELECT ProductID FROM #LoyaltyMembershipProductIDs) AND 'Loyalty Memberships' IN (SELECT MembershipType FROM #MembershipTypeList))             --Loyalty
		OR ('< Ignore this prompt >' IN (SELECT MembershipType FROM #MembershipTypeList)))
CREATE UNIQUE CLUSTERED INDEX IX_ProductID ON #IncludeMembershipProducts(ProductID)

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

DECLARE @ReportRunDateTime VARCHAR(21)
DECLARE @HeaderMembershipStatusList  VARCHAR(1000)
DECLARE @HeaderDelinquentStatusList VARCHAR(100)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

SET @HeaderMembershipStatusList = STUFF((SELECT DISTINCT ', ' + tMSL.MembershipStatus
                                       FROM #MembershipStatusList tMSL                                 
                                       FOR XML PATH('')),1,1,'') 
SET @HeaderDelinquentStatusList = STUFF((SELECT DISTINCT ', ' + tDSL.DelinquentStatus
                                       FROM #DelinquentStatusList tDSL                                 
                                       FOR XML PATH('')),1,1,'')    


  --- Find all membership IDs for selected parameters - 
Select MA.MembershipID,MA.AttributeValue, MembershipReportDimProduct.ProductDescription, MA.EffectiveFromDateTime
INTO #DelinquentMembershipIDs
FROM vMembershipAttribute MA
JOIN #DelinquentStatusList DSL
  ON MA.AttributeValue = DSL.DelinquentStatus
JOIN vMembership MS
  ON MA.MembershipID = MS.MembershipID
JOIN vMembershipType MT
  On MS.MembershipTypeID = MT.MembershipTypeID
JOIN #IncludeMembershipProducts
  ON MT.ProductID = #IncludeMembershipProducts.ProductID
JOIN vReportDimProduct MembershipReportDimProduct
  ON MT.ProductID = MembershipReportDimProduct.MMSProductID
JOIN #Clubs Club
  ON MS.ClubID = Club.ClubID
JOIN vValMembershipStatus VMS
  ON MS.ValMembershipStatusID = VMS.ValMembershipStatusID
JOIN #MembershipStatusList MSL
  ON VMS.Description = MSL.MembershipStatus
WHERE ((MA.InsertedDateTime >= @FirstOfReportMonth AND MA.InsertedDateTime < @FirstOfNextMonth)  --- to return all inserts MTD
      OR 
	  (MA.EffectiveFromDateTime <= @FirstOfReportMonth 
	      AND IsNull(MA.EffectiveThruDateTime,@ReportDatePlus1) > @FirstOfReportMonth))  --- to return all carry overs from prior Month
AND MA.ValMembershipAttributeTypeID = 6
ORDER BY MA.MembershipID


  ----- Find all payments on account for selected memberships for 1st of month through report date
SELECT MT.MMSTranID,MT.MembershipID,1 AS PaymentCount,MT.TranAmount AS PaymentAmount,
MT.EmployeeID,E.FirstName, E.LastName,MT.TranDate, RC.Description AS TranReason
INTO #Payment
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID
WHERE MT.ValTranTypeID = 2
  AND MT.TranDate >= @SecondOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0

  ---- separate result to just return totals
SELECT MembershipID,Sum(PaymentCount) AS TotalPaymentCount, SUM(PaymentAmount) AS TotalPaymentAmount
INTO #PaymentTotals
FROM #Payment
GROUP BY MembershipID

  ----- Find most recent payment date
SELECT MT.MembershipID, Max(MT.TranDate) AS MostRecentPaymentDate
INTO #LastPayment
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
WHERE MT.ValTranTypeID = 2
  AND MT.TranDate >= @FirstOf3MonthsPrior
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0
GROUP BY MT.MembershipID


 ----- Find all adjustments for selected memberships for 1st of month through report date
SELECT MT.MMSTranID,MT.MembershipID,1  AS AdjustmentCount,MT.TranAmount AS AdjustmentAmount,
MT.EmployeeID,E.FirstName, E.LastName,MT.TranDate, RC.Description AS TranReason
INTO #Adjustment
FROM vMMSTran MT
JOIN #DelinquentMembershipIDs IDs
  ON MT.MembershipID = IDs.MembershipID
JOIN vEmployee E
  ON MT.EmployeeID = E.EmployeeID
JOIN vReasonCode RC
  ON MT.ReasonCodeID = RC.ReasonCodeID
WHERE MT.ValTranTypeID = 4
  AND MT.TranDate >= @SecondOfReportMonth
  AND MT.TranDate < @ReportDatePlus1
  AND IsNull(MT.TranVoidedID,0) = 0

    ---- separate result to just return totals
SELECT MembershipID,Sum(AdjustmentCount) AS TotalAdjustmentCount, SUM(AdjustmentAmount) AS TotalAdjustmentAmount
INTO #AdjustmentTotals
FROM #Adjustment
GROUP BY MembershipID

  --- Find the most recent EFT Draft record for each membership in the period
SELECT IDs.MembershipID,Max(EFT.EFTID) AS EFTID
INTO #MostRecentEFTID
FROM vEFT EFT
JOIN #DelinquentMembershipIDs IDs
  ON EFT.MembershipID = IDs.MembershipID
Where EFT.EFTDate >= @FirstOfReportMonth
  AND EFT.EFTDate < @ReportDatePlus1
GROUP BY IDs.MembershipID


  --- get detail from the membership's most recent draft record in the period
SELECT EFT.MembershipID,EFT.ReturnCode,EFT.EFTDate
INTO #EFTReturnCodeAndDate
FROM vEFT AS EFT
JOIN #MostRecentEFTID  AS IDs
  ON EFT.EFTID = IDs.EFTID

  ---  See if the membership account information was updated through myLT in the period
SELECT IDs.MembershipID,'Y' AS UpdateAccountViaMyLT,
max(OpenDateTime) DateMyLTUpdate /* New Column Added as per REP-3996 */
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
       IDs.AttributeValue,
	   IDs.ProductDescription MembershipTypeDescription,
	   IDs.EffectiveFromDateTime,
	   VMS.Description AS MembershipStatus,
	   MS.CreatedDateTime AS MembershipCreatedDate,
	   MS.ExpirationDate,
	   MS.ValMembershipStatusID,
	   Region.Description as MMSRegion,
	   HomeClub.ClubName
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


  --- combine all returned data
SELECT 
       MS.MMSRegion,
	   MS.ClubName,
	   MS.MembershipID, 
	   MS.MembershipStatus,
	   MS.MembershipTypeDescription,
	   MS.EffectiveFromDateTime DelinquentEffectiveDate,
	   MS.MembershipCreatedDate,
	   MS.ExpirationDate,
	   MSA.AddressLine1,
	   MSA.AddressLine2,
	   MSA.City,
	   VS.Abbreviation,
	   MSA.Zip,
	   MP.HomePhoneNumber,
	   MP.BusinessPhoneNumber,
	   M.JoinDate AS PrimaryMemberJoinDate,
	   M.EmailAddress,
	   M.MemberID AS PrimaryMemberID,
	   M.FirstName AS PrimaryMemberFirstName,
	   M.LastName AS PrimaryMemberLastName,
	   MS.AttributeValue AS DelinquentStatus,
	   VPT.Description AS EFTType,
	   EFTOption.Description AS EFTStatus,
	   EFT.ReturnCode AS MostRecentReturnCode,
	   EFT.EFTDate AS MostRecentReturnDate,
	   EFTAcct.ExpirationDate AS EFTExpirationDate,
	   PT.TotalPaymentCount,
	   PT.TotalPaymentAmount,
	   Payment.MMSTranID AS PaymentMMSTranID,
	   Payment.PaymentCount,
	   Payment.PaymentAmount,
	   Payment.EmployeeID AS PaymentEmployeeID,
	   Payment.FirstName AS PaymentEmployeeFirstName,
	   Payment.LastName AS PaymentEmployeeLastName,
	   Payment.TranDate AS PaymentTranDate, 
	   Payment.TranReason AS PaymentTranReason,
	   AT.TotalAdjustmentCount,
	   AT.TotalAdjustmentAmount,
	   Adjustment.MMSTranID AS AdjustmentMMSTranID,
	   Adjustment.AdjustmentCount,
	   Adjustment.AdjustmentAmount,
	   Adjustment.EmployeeID AS AdjustmentEmployeeID,
	   Adjustment.FirstName AS AdjustmentEmployeeFirstName,
	   Adjustment.LastName AS AdjustmentEmployeeLastName,
	   Adjustment.TranDate AS AdjustmentTranDate, 
	   Adjustment.TranReason AS AdjustmentTranReason,
	   MyLTUpdate.UpdateAccountViaMyLT,
	   @ReportRunDateTime AS ReportRunDateTime,
	   @ReportDate AS HeaderReportDate,
	   @HeaderMembershipStatusList AS HeaderMembershipStatusList,
	   @HeaderDelinquentStatusList AS HeaderDelinquentStatusList,
	   LP.MostRecentPaymentDate,
	   MB.CurrentBalance AS MembershipDuesCurrentBalance,
	   MyLTUpdate.DateMyLTUpdate /* New Column Added as per REP-3996 */
FROM #Memberships MS
JOIN vMembershipAddress MSA
  ON MS.MembershipID = MSA.MembershipID
JOIN vValState VS
  ON MSA.ValStateID = VS.ValStateID
JOIN vMember M
  ON MS.MembershipID = M.MembershipID
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
LEFT JOIN #Payment Payment
  ON MS.MembershipID = Payment.MembershipID
LEFT JOIN #Adjustment Adjustment
  ON MS.MembershipID = Adjustment.MembershipID
LEFT JOIN #EFTReturnCodeAndDate EFT
  ON MS.MembershipID = EFT.MembershipID
LEFT JOIN #MyLTUpdate MyLTUpdate
  ON MS.MembershipID = MyLTUpdate.MembershipID
LEFT JOIN #PaymentTotals PT
  ON MS.MembershipID = PT.MembershipID
LEFT JOIN #AdjustmentTotals AT
  ON MS.MembershipID = AT.MembershipID
LEFT JOIN #LastPayment LP
  ON MS.MembershipID = LP.MembershipID
WHERE MSA.ValAddressTypeID = 1  ----- Membership Address
  AND M.ValMemberTypeID = 1   ----- PrimaryMember
----ORDER BY MS.MembershipID

DROP TABLE #tmpList
DROP TABLE #DelinquentStatusList
DROP TABLE #MembershipStatusList
DROP TABLE #MembershipTypeList
DROP TABLE #LoyaltyMembershipProductIDs
DROP TABLE #IncludeMembershipProducts
DROP TABLE #Clubs
DROP TABLE #DelinquentMembershipIDs
DROP TABLE #Payment
DROP TABLE #Adjustment
DROP TABLE #MostRecentEFTID
DROP TABLE #EFTReturnCodeAndDate
DROP TABLE #MyLTUpdate
DROP TABLE #Memberships
DROP TABLE #PaymentTotals
DROP TABLE #AdjustmentTotals
DROP TABLE #LastPayment

END

