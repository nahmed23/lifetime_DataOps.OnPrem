
CREATE PROC [dbo].[mmsEFTReturnDetail] (
  @ClubIDList VARCHAR(2000),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Returns a set of Returned EFT Transactions based upon
-- the user's selection parameters
-- 
-- Parameters required: Original EFT transaction Date range 
-- and one or more clubs
--EXEC mmsEFTReturnDetail 'All', 'Mar 1, 2011 12:00 AM', 'Mar 2, 2011 11:59 PM'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList <> 'All'
BEGIN
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs (ClubID) (SELECT ClubID FROM vClub)
END   

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 'All'
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
  
--LFF Acquisition changes begin
SELECT ms.MembershipID,
	ms.ClubID,
	ms.MembershipTypeID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
WHERE ms.ClubID IN (SELECT ClubID FROM #Clubs) --limit from result query

CREATE INDEX IX_ClubID ON #Membership(ClubID)
CREATE INDEX IX_MembershipTypeID ON #Membership(MembershipTypeID)

/***************************************/

  SELECT M.MemberID, P.Description AS ProductDescription, 
         M.FirstName, M.LastName,
         RC.Description AS ReasonCodeDescription,
         EFT.MaskedAccountNumber AS AccountNumber, EFT.ExpirationDate, VPT.ValPhoneTypeID,
         VPT.Description AS PhoneTypeDescription, 
         MSP.AreaCode, MSP.Number,
         EFT.EFTDate, EFT.RoutingNumber, EFT.ValPaymentTypeID,
         VPTT.Description AS PaymentTypeDescription, 
         VR.Description AS RegionDescription, 
         ERC.Description AS ReturnCodeDescription,
         C.ClubName, ERC.StopEFTFlag,
         M.EmailAddress, MPN.HomePhoneNumber, MPN.BusinessPhoneNumber,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount,	
	   MSB.CurrentBalance * #PlanRate.PlanRate as CurrentBalance,
	   EFT.EFTAmount as LocalCurrency_EFTAmount,	   
	   MSB.CurrentBalance as LocalCurrency_CurrentBalance,
	   EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount,
	   MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_CurrentBalance   	 
	  	
/***************************************/

    FROM dbo.vMember M
   RIGHT OUTER JOIN #Membership AL4 
         ON AL4.MembershipID = M.MembershipID
    JOIN dbo.vMembershipType MST
         ON AL4.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P
         ON MST.ProductID = P.ProductID     
    JOIN dbo.vClub C
         ON AL4.ClubID = C.ClubID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vEFT EFT
         ON EFT.MembershipID = AL4.MembershipID
    JOIN dbo.vEFTReturnCode ERC
         ON EFT.EFTReturnCodeID = ERC.EFTReturnCodeID
    JOIN dbo.vReasonCode RC
         ON ERC.ReasonCodeID = RC.ReasonCodeID
    LEFT JOIN dbo.vValPaymentType VPTT
         ON EFT.ValPaymentTypeID = VPTT.ValPaymentTypeID  
   RIGHT OUTER JOIN dbo.vPrimaryPhone PP
         ON AL4.MembershipID = PP.MembershipID
   JOIN dbo.vMembershipPhone MSP
         ON PP.MembershipID = MSP.MembershipID AND 
         PP.ValPhoneTypeID = MSP.ValPhoneTypeID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #ToUSDPlanRate.PlanYear
/*******************************************/
    LEFT JOIN dbo.vMembershipBalance MSB
         ON AL4.MembershipID = MSB.MembershipID
    LEFT JOIN dbo.vMemberPhoneNumbers MPN
         ON AL4.MembershipID = MPN.MembershipID
    LEFT JOIN dbo.vValPhoneType VPT
         ON VPT.ValPhoneTypeID = PP.ValPhoneTypeID 
   WHERE M.ValMemberTypeID = 1 AND
         EFT.ValEFTStatusID = 2 AND
         EFT.EFTDate BETWEEN @StartDate AND @EndDate AND
         AL4.ClubID IN (SELECT ClubID FROM #Clubs) AND
         C.DisplayUIFlag = 1

  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

