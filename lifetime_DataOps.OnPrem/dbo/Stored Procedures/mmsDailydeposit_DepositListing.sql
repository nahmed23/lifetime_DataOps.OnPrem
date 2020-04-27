




--
-- Returns drawer activity amounts totalled up by date within club and broken into paymenttypes
-- It will return a record for each club without activity during the given timeframe
--
-- Parameters: A start date and end date for drawer activity closed dates to look for
--
-- EXEC mmsDailydeposit_DepositListing 'Apr 1, 2011', 'Apr 2, 2011'

CREATE      PROC [dbo].[mmsDailydeposit_DepositListing] (
  @CloseStartDate SMALLDATETIME,
  @CloseEndDate SMALLDATETIME
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
WHERE PlanYear >= Year(@CloseStartDate)
  AND PlanYear <= Year(@CloseEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@CloseStartDate)
  AND PlanYear <= Year(@CloseEndDate)
  AND ToCurrencyCode = 'USD'
/***************************************/

SELECT C.ClubID, C.ClubName,
       CONVERT(VARCHAR(10), DA.CloseDateTime, 101) AS ClosedDate,
       C.GLClubID AccountingClubID,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 1  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as CashTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 2  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as CheckTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 8  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as AMEXTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 3  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as VISATotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 4  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as MCTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 5  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as DiscoverTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 7  THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as GiftCertTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 14 THEN (DAA.TranTotalAmount * #PlanRate.PlanRate) ELSE 0 END) as GiftCardTotals,

	 SUM(CASE WHEN VPT.ValPaymentTypeID = 1  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_CashTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 2  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_CheckTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 8  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_AMEXTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 3  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_VISATotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 4  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_MCTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 5  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_DiscoverTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 7  THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_GiftCertTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 14 THEN DAA.TranTotalAmount ELSE 0 END) as LocalCurrency_GiftCardTotals,

	 SUM(CASE WHEN VPT.ValPaymentTypeID = 1  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_CashTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 2  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_CheckTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 8  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_AMEXTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 3  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_VISATotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 4  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_MCTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 5  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_DiscoverTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 7  THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_GiftCertTotals,
       SUM(CASE WHEN VPT.ValPaymentTypeID = 14 THEN (DAA.TranTotalAmount * #ToUSDPlanRate.PlanRate) ELSE 0 END) as USD_GiftCardTotals
  
FROM dbo.vClub C
  LEFT JOIN dbo.vDrawer D ON C.ClubID = D.ClubID 
  LEFT JOIN dbo.vDrawerActivity DA ON DA.DrawerID = D.DrawerID AND
                                      DA.CloseDateTime >= @CloseStartDate AND
                                      DA.CloseDateTime <= @CloseEndDate
  LEFT JOIN dbo.vDrawerActivityAmount DAA ON DAA.DrawerActivityID = DA.DrawerActivityID
  LEFT JOIN dbo.vValPaymentType VPT ON DAA.ValPaymentTypeID = VPT.ValPaymentTypeID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(DA.CloseDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(DA.CloseDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
 WHERE C.DisplayUIFlag = 1 or c.clubid =13 -- corporate internal
 GROUP BY C.ClubID, C.ClubName, C.GLClubID, CONVERT(VARCHAR(10), DA.CloseDateTime, 101) 

DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END

