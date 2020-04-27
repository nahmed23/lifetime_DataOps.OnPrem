


--
-- Returns a recordset specific to the CorpEFTTranHist Brio Document for
-- the CorpEFTTranHistory Query section
-- 
-- Parameters required: account number and a date range for the transactions
--
--EXEC mmsCorpEFTTranHist_CorpEFTTranHistory '0007', 'Apr 1, 2011', 'Apr 3, 2011'
CREATE       PROC [dbo].[mmsCorpEFTTranHist_CorpEFTTranHistory] (
  @Last4AccountNumber varchar(4),
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME
  )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

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
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

SELECT EFT.MaskedAccountNumber AS AccountNumber, EFT.EFTDate as EFTDate_Sort,
	   Replace(Substring(convert(varchar,EFT.EFTDate,100),1,6)+', '+Substring(convert(varchar,EFT.EFTDate,100),8,10)+' '+Substring(convert(varchar,EFT.EFTDate,100),18,2),'  ',' ') as EFTDate,
--SELECT EFT.AccountNumber, EFT.EFTDate, EFT.EFTAmount, 
       EFT.ExpirationDate, EFT.RoutingNumber, C.CompanyName, 
       M.MemberID, M.FirstName, M.LastName, CL.ClubName, 
       VR.Description RegionDescription, VPT.Description PaymentTypeDescription,
       VES.Description EFTStatusDescription, EFT.ValEFTStatusID,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount,	  
	   EFT.EFTAmount as LocalCurrency_EFTAmount,	  
	   EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount	   
/***************************************/

  FROM dbo.vEFT EFT
  JOIN dbo.vMembership MS 
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vClub CL
       ON MS.ClubID = CL.ClubID
  JOIN dbo.vValRegion VR
       ON CL.ValRegionID = VR.ValRegionID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON CL.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #ToUSDPlanRate.PlanYear
/*******************************************/
  LEFT JOIN dbo.vCompany C 
       ON MS.CompanyID=C.CompanyID
-- WHERE EFT.AccountNumber = @AccountNumber AND 
-- WHERE Right(EFT.AccountNumber, 4) = @Last4AccountNumber AND 
 WHERE Right(EFT.MaskedAccountNumber, 4) = @Last4AccountNumber AND 
       EFT.EFTDate BETWEEN @StartDate AND @EndDate AND 
       M.ValMemberTypeID = 1
 ORDER BY EFT.AccountNumber, M.MemberID

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END

