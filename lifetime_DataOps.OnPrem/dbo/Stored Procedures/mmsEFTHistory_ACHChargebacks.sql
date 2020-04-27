
CREATE PROC [dbo].[mmsEFTHistory_ACHChargebacks] (
  @MemberID INT,
  @StartDate SMALLDATETIME,
  @EndDate   SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
-- Returns all ACH chargeback activity for one member over a supplied date range
-- parameters: Member ID, StartDate, EndDate
-- EXEC mmsEFTHistory_ACHChargebacks '100329658', 'Mar 1, 2011 12:00 AM', 'Mar 2, 2011 11:59 PM'

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C  
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
/***************************************/

--LFF Acquisition changes begin
SELECT ms.MembershipID,
       ms.ClubID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
 
SELECT DISTINCT mt.MMSTranID, 
       mt.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID, mt.DomainName, mt.ReceiptNumber, 
       mt.ReceiptComment, mt.PostDateTime, mt.EmployeeID, mt.TranDate, mt.POSAmount,
       mt.TranAmount, mt.OriginalDrawerActivityID, mt.ChangeRendered, mt.UTCPostDateTime, 
       mt.PostDateTimeZone, mt.OriginalMMSTranID, mt.TranEditedFlag,
       mt.TranEditedEmployeeID, mt.TranEditedDateTime, mt.UTCTranEditedDateTime, 
       mt.TranEditedDateTimeZone, mt.ReverseTranFlag, mt.ComputerName, mt.IPAddress,
       mt.ValCurrencyCodeID,mt.CorporatePartnerID,mt.ConvertedAmount,mt.ConvertedValCurrencyCodeID
INTO #MMSTran
FROM vMMSTran mt WITH (NOLOCK)
JOIN #Membership ms
  ON ms.MembershipID = mt.MembershipID
JOIN vMember M
  ON mt.MemberID = M.MemberID
WHERE mt.PostDateTime BETWEEN @StartDate AND @EndDate 
  AND M.MemberID = @MemberID
  AND mt.ReasonCodeID != 75 
  AND mt.EmployeeID = -2
  AND mt.ValTranTypeID = 4 


SELECT MMST.MMSTranID, MMST.PostDateTime, 
       MMST.MemberID,RC.Description AS ReasonCodeDescription, 
       VEO.Description AS EFTOptionDescription, 
       GETDATE() AS CurrentDate,
       VPT.Description AS PaymentTypeDescription,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MMST.TranAmount * #PlanRate.PlanRate as TranAmount,       
       MMST.TranAmount as LocalCurrency_TranAmount,       
       MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount            
/***************************************/
  FROM #MMSTran MMST
  JOIN dbo.vClub C
       ON MMST.ClubID = C.ClubID
  JOIN vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MMST.MemberID = M.MemberID
  JOIN dbo.vDrawerActivity DA
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vValEFTOption VEO
       ON MS.ValEFTOptionID = VEO.ValEFTOptionID
/********** Foreign Currency Stuff **********/  
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN dbo.vEFTAccountDetail EAD
       ON (MS.MembershipID = EAD.MembershipID)
  LEFT JOIN dbo.vValPaymentType VPT
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
 WHERE DA.DrawerID = 25 AND
       MMST.EmployeeID = -2 AND
       MMST.ValTranTypeID = 4 AND
       M.MemberID = @MemberID AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       MMST.ReasonCodeID != 75 

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

