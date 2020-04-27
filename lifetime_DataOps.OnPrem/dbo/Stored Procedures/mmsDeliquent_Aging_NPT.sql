


CREATE     PROC [dbo].[mmsDeliquent_Aging_NPT] (
  @ClubIDList VARCHAR(2000),
  @CancelDate SMALLDATETIME,
  @PaymentTypeList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- returns deliquent accounts terminated for non-payment within specified parameters 
--
-- Parameters: clubids, membership status, payment type, member type
-- EXEC mmsDeliquent_Aging_NPT '141','04/01/2011','Visa'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(15))
IF @ClubIDList <> 'All'
BEGIN
--   INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

CREATE TABLE #PaymentType (Description VARCHAR(50))
       IF @PaymentTypeList <> 'All'
       BEGIN
          --INSERT INTO #PaymentType EXEC procParseStringList @PaymentTypeList
	   EXEC procParseStringList @PaymentTypeList
	   INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
	   TRUNCATE TABLE #tmpList
       END

SELECT C.ClubName, VR.Description AS RegionDescription, M.MemberID,
       M.FirstName, M.LastName, MSS.Description AS MembershipstatusDescription,
       MSP.AreaCode, MSP.Number, 
       VEO.Description AS EFTOptionDesc, VPT.Description AS EFTPaymentMethodDescription, 
       TI.TranItemID, P.Description AS MembershipTypeDescription,
       MMST.TranDate, MMST.PostDateTime,
       MS.ExpirationDate, GETDATE()AS QueryDate, MS.CancellationRequestDate, M.emailaddress,
       MA.AddressLine1, MA.AddressLine2, MA.City, VS.Description AS State, MA.Zip,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TB.TranBalanceAmount * #PlanRate.PlanRate as TranBalanceAmount,	  
	   TB.TranBalanceAmount as LocalCurrency_TranBalanceAmount,	  
	   TB.TranBalanceAmount * #ToUSDPlanRate.PlanRate as USD_TranBalanceAmount	   
/***************************************/

  FROM dbo.vMember M
  JOIN dbo.vMembership MS 
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValEFTOption VEO
       ON VEO.ValEFTOptionID = MS.ValEFTOptionID
  JOIN dbo.vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN dbo.vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vValMembershipStatus MSS
       ON MSS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vValTerminationReason VTR
       ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID
  JOIN dbo.vTranBalance TB 
       ON TB.MembershipID = MS.MembershipID
  LEFT OUTER JOIN dbo.vTranItem TI 
       ON (TB.TranItemID = TI.TranItemID) 
  LEFT OUTER JOIN dbo.vMMSTran MMST 
       ON (TI.MMSTranID = MMST.MMSTranID)
  LEFT OUTER JOIN dbo.vPrimaryPhone PP 
       ON (MS.MembershipID = PP.MembershipID) 
  LEFT OUTER JOIN dbo.vMembershipPhone MSP 
       ON (PP.ValPhoneTypeID = MSP.ValPhoneTypeID AND 
       PP.MembershipID = MSP.MembershipID) 
  LEFT OUTER JOIN dbo.vEFTAccountDetail EAD 
       ON (MS.MembershipID = EAD.MembershipID) 
  LEFT OUTER JOIN dbo.vValPaymentType VPT 
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  LEFT OUTER JOIN dbo.vMembershipAddress MA
       ON (MS.MembershipID = MA.MembershipID)
  LEFT OUTER JOIN dbo.vValState VS
       ON (MA.ValStateID = VS.ValStateID)
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/
 WHERE TB.TranBalanceAmount>0 AND
       VTR.Description = 'Non-Payment Terms' AND
       MS.CancellationRequestDate = @CancelDate AND
       M.ValMemberTypeID = 1 AND
       C.ClubID IN (SELECT ClubID FROM #Clubs)AND
--       C.ClubName IN (SELECT ClubName FROM #Clubs)AND
       C.DisplayUIFlag = 1 AND
       (ISNULL(VPT.Description, 'Undefined') IN (SELECT Description FROM #PaymentType) OR
       @PaymentTypeList  =  'All')

DROP TABLE #Clubs
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

