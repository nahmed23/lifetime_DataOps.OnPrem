
CREATE PROC [dbo].[mmsACHChargeBack] (
  @ClubIDList VARCHAR(2000),
  @StartDate        SMALLDATETIME,
  @EndDate          SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- looks at ACH  activity for one club over a supplied date range
-- parameters: Club, StartDate, EndDate
--EXEC mmsACHChargeBack '141', 'Apr 1, 2011', 'Apr 10, 2011'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(15))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

SELECT C.ClubID, C.ClubName, C.ValRegionID, C.DisplayUIFlag
INTO #ClubID
FROM #Clubs CS JOIN vClub C ON CS.ClubID = C.ClubID

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@StartDate)
  AND PlanYear <= Year(@EndDate)
  AND ToCurrencyCode = 'USD'

SELECT mt.MMSTranID, 
       mt.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.ComputerName, mt.IPAddress,
       mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID,
       ms.ValEFTOptionID
INTO #MMSTran
FROM vMMSTran mt WITH (NOLOCK)
JOIN vMembership ms
  ON ms.MembershipID = mt.MembershipID

WHERE mt.PostDateTime BETWEEN @StartDate AND @EndDate --limit from result query
  AND mt.ReasonCodeID != 75 --limit from result query
  AND mt.EmployeeID = -2 --limit from result query
  AND mt.ValTranTypeID = 4 --limit from result query

CREATE INDEX IX_ClubID ON #MMSTran(ClubID)

/***************************************/

SELECT MMST.MMSTranID, C.ClubName,
       VR.Description AS RegionDescription, 
       MMST.PostDateTime, MMST.MemberID,
       RC.Description AS ReasonCodeDescription, 
       VEO.Description AS EFTOptionDescription, 
       M.FirstName, M.LastName,       
       GETDATE() AS CurrentDate,
       MSP.AreaCode, MSP.Number AS PhoneNumber,
       VPT.Description AS PaymentTypeDescription,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MMST.TranAmount as LocalCurrency_TranAmount,
       MMST.TranAmount * #PlanRate.PlanRate as TranAmount,
       MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
       MSB.CurrentBalance as LocalCurrency_CurrentBalance,
       MSB.CurrentBalance * #PlanRate.PlanRate as CurrentBalance, 
       MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_CurrentBalance
/***************************************/
  FROM #MMSTran MMST
  --JOIN vMembership MS
       --ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MMST.MemberID = M.MemberID
  JOIN dbo.vDrawerActivity DA
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN #ClubID C
       ON MMST.ClubID = C.ClubID
/********** Foreign Currency Stuff **********/ 
  JOIN dbo.vClub CS
       ON CS.ClubID = C.ClubID OR C.ClubID = 0
  JOIN dbo.vValCurrencyCode VCC 
       ON CS.ValCurrencyCodeID = VCC.ValCurrencyCodeID  
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValEFTOption VEO
       ON MMST.ValEFTOptionID = VEO.ValEFTOptionID --Was MS instead of MMST
  JOIN dbo.vMembershipBalance MSB
       ON MMST.MembershipID = MSB.MembershipID --Was MS instead of MMST
  LEFT JOIN dbo.vEFTAccountDetail EAD
       ON (MMST.MembershipID = EAD.MembershipID) --Was MS instead of MMST
  LEFT JOIN dbo.vValPaymentType VPT
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MMST.MembershipID = PP.MembershipID --Was MS instead of MMST
  LEFT JOIN dbo.vMembershipPhone MSP
       ON (PP.MembershipID = MSP.MembershipID AND
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID)
 WHERE DA.DrawerID = 25 AND
       MMST.EmployeeID = -2 AND
       MMST.ValTranTypeID = 4 AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       C.DisplayUIFlag = 1 AND
       MMST.ReasonCodeID != 75

DROP TABLE #Clubs
DROP TABLE #ClubID
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
drop table #mmstran

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

