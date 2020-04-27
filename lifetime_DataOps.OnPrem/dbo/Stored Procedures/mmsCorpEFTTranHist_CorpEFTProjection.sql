


--
-- Returns a recordset specific to the CorpEFTTranHist Brio Document for
-- the CorpEFTTranProjection Query section
-- 
-- Parameters required: corporate code
-- exec mmsCorpEFTTranHist_CorpEFTProjection '00025'

CREATE     PROC [dbo].[mmsCorpEFTTranHist_CorpEFTProjection] (
  @CorporateCode varchar(50)
  )
AS
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @TwentiethOfMonth DATETIME
SET @TwentiethOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,GETDATE(),112),1,6) + '20', 112)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

-- total tax percentage for a given product and club 
CREATE TABLE #ClubProductTaxRate (
	ClubID INT, 
	ProductID INT, 
	TaxPercentage SMALLMONEY 
	)

INSERT INTO #ClubProductTaxRate 
	SELECT CPTR.ClubID, CPTR.ProductID, Sum(TR.TaxPercentage) AS TaxPercentage 
	FROM dbo.vClubProductTaxRate CPTR
	JOIN dbo.vTaxRate TR ON  TR.TaxRateID = CPTR.TaxRateID
	--WHERE CLUBID = 11 AND PRODUCTID =2929
	GROUP BY CPTR.ClubID, CPTR.ProductID

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

SELECT 
	   CO.CompanyName,VPT.Description PaymentTypeDescription, VR.Description RegionDescription, 
       C.ClubName, M.MemberID, M.FirstName, M.LastName, 
       CASE WHEN CPTR.taxpercentage is null THEN CP.Price * #PlanRate.PlanRate ELSE
		 (CP.Price * #PlanRate.PlanRate) + ((CP.Price * #PlanRate.PlanRate)*CPTR.taxpercentage/100) END DuesPrice, 
	   CASE WHEN CPTR.taxpercentage is null THEN CP.Price ELSE
		 CP.Price + (CP.Price*CPTR.taxpercentage/100) END LocalCurrency_DuesPrice, 
	   CASE WHEN CPTR.taxpercentage is null THEN CP.Price * #ToUSDPlanRate.PlanRate ELSE
		 (CP.Price * #ToUSDPlanRate.PlanRate) + ((CP.Price * #ToUSDPlanRate.PlanRate)*CPTR.taxpercentage/100) END USD_DuesPrice, 
	   VMS.Description MembershipStatusDescription, 
       MS.ActivationDate, MS.ExpirationDate, GETDATE() ReportDate, 
       VMS.ValMembershipStatusID, EFTO.ValEFTOptionID, 
       EFTO.Description EFTOptionDescription, EFTA.AccountNumber, CO.CorporateCode, 
       EFTA.MaskedAccountNumber,JuniorDuesCount.AssessableJrMembers,
	   CASE WHEN CPTR_JM.taxpercentage is null THEN CP2.Price * #PlanRate.PlanRate ELSE
		 (CP2.Price * #PlanRate.PlanRate) + ((CP2.Price * #PlanRate.PlanRate) * CPTR_JM.taxpercentage/100) END JuniorDuesPrice,
	   CASE WHEN CPTR_JM.taxpercentage is null THEN CP2.Price ELSE
		 CP2.Price + (CP2.Price * CPTR_JM.taxpercentage/100) END LocalCurrency_JuniorDuesPrice,
	   CASE WHEN CPTR_JM.taxpercentage is null THEN CP2.Price * #ToUSDPlanRate.PlanRate ELSE
		 (CP2.Price * #ToUSDPlanRate.PlanRate) + ((CP2.Price * #ToUSDPlanRate.PlanRate) * CPTR_JM.taxpercentage/100) END USD_JuniorDuesPrice,
       @TwentiethOfMonth ActivationCutOffDate,MS.CreatedDateTime,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MSB.CommittedBalance * #PlanRate.PlanRate as CommittedBalance,	  
	   MSB.CommittedBalance as LocalCurrency_CommittedBalance,	  
	   MSB.CommittedBalance * #ToUSDPlanRate.PlanRate as USD_CommittedBalance   
/***************************************/

  FROM dbo.vMembership MS
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MSB
       ON MSB.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValRegion VR
       ON VR.ValRegionID = C.ValRegionID
  JOIN dbo.vClubProduct CP
       ON C.ClubID = CP.ClubID
  JOIN dbo.vMembershipType MT
       ON MS.MembershipTypeID = MT.MembershipTypeID
       AND MT.ProductID = CP.ProductID
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
  -- membership type 
  LEFT JOIN #ClubProductTaxRate CPTR 
	   ON CPTR.ClubID = CP.ClubID 
	   AND CPTR.ProductID = CP.ProductID   
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vCompany CO
       ON CO.CompanyID = MS.CompanyID
  JOIN dbo.vValEFTOption EFTO
       ON MS.ValEFTOptionID = EFTO.ValEFTOptionID
  JOIN dbo.vEFTAccountDetail EFTA 
       ON MS.MembershipID = EFTA.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EFTA.ValPaymentTypeID = VPT.ValPaymentTypeID
  LEFT JOIN dbo.vClubProduct CP2
       ON C.ClubID = CP2.ClubID AND CP2.ProductID = ms.JrMemberDuesProductID --1497
  -- junior member 
  LEFT JOIN #ClubProductTaxRate CPTR_JM 
	   ON CPTR_JM.ClubID = CP2.ClubID 
	   AND CPTR_JM.ProductID = CP2.ProductID   

  LEFT JOIN (SELECT MS2.MembershipID,Count(M2.MemberID) AS AssessableJrMembers
              FROM dbo.vMembership MS2
	      JOIN dbo.vMember M2
		ON MS2.MembershipID = M2.MembershipID
              JOIN dbo.vCompany CO2
                ON CO2.CompanyID = MS2.CompanyID
              WHERE CO2.CorporateCode = @CorporateCode AND
                    MS2.AssessJrMemberDuesFlag = 1 AND
                    M2.ValMemberTypeID = 4 AND
                    M2.ActiveFlag = 1
	      GROUP BY MS2.MembershipID ) JuniorDuesCount
	ON MS.MembershipID = JuniorDuesCount.MembershipID
            
 WHERE M.ValMemberTypeID = 1 AND 
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 
           'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND 
       CO.CorporateCode = @CorporateCode

 DROP TABLE #ClubProductTaxRate
 DROP TABLE #PlanRate
 DROP TABLE #ToUSDPlanRate


-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

