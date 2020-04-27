




CREATE PROC [dbo].[mmsEFTRecovery] (
  @RegionList VARCHAR(1000),
  @PaymentTypeList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON
/*	=============================================
	Object:				dbo.mmsEFTRecovery
	Author:				
	Create date: 		
	Description:		Returns information on credit card EFT drafts month to date, whether or not they 
							were initially rejected and if they are currently recovered ( based upon the membership account balance).

	Modified date:		1/8/2010 GRB: add vMembership.CreatedDateTime to end of result set to facilitate 
							the high volume of internet sales via PK; dbcr_5508 deploying 1/8/2010 via ECR
					    12/28/2011 BSD: Added LFF Acquisition logic.

	EXEC mmsEFTRecovery 'All', 'All'
	=============================================	*/

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

DECLARE @FirstOfMonth DATETIME
DECLARE @FourthOfMonth DATETIME
SET @FirstOfMonth = cast(DATEPART(month,GETDATE()) as varchar(2))+'/01/'+cast(DATEPART(year,GETDATE()) as varchar(4))
SET @FourthOfMonth = cast(DATEPART(month,GETDATE()) as varchar(2))+'/04/'+cast(DATEPART(year,GETDATE()) as varchar(4))


CREATE TABLE #tmpList (StringField VARCHAR(50))

EXEC procParseStringList @RegionList
CREATE TABLE #Clubs (ClubID INT)
INSERT INTO #Clubs (ClubID)
SELECT vClub.ClubID 
  FROM vClub 
  JOIN vValRegion ON vClub.ValRegionID= vValRegion.ValRegionID
 WHERE vValRegion.ValRegionID IN (SELECT StringField FROM #tmpList)
    OR @RegionList = 'All'
    
TRUNCATE TABLE #tmpList
 
EXEC procParseStringList @PaymentTypeList
CREATE TABLE #PaymentType (ValPaymentTypeID INT)
INSERT INTO #PaymentType (ValPaymentTypeID)
SELECT vValPaymentType.ValPaymentTypeID
  FROM vValPaymentType
 WHERE Description IN (SELECT StringField FROM #tmpList)
    OR @PaymentTypeList = 'All'


/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = CASE WHEN @RegionList = 'All' THEN 'USD'
                                  ELSE (SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' 
                                                    ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
                                          FROM vClub C  
                                          JOIN #Clubs ON C.ClubID = #Clubs.ClubID
                                          JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID) END

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= cast(DATEPART(year,GETDATE()) as varchar(4))
  AND PlanYear <= cast(DATEPART(year,GETDATE()) as varchar(4))
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= cast(DATEPART(year,GETDATE()) as varchar(4))
  AND PlanYear <= cast(DATEPART(year,GETDATE()) as varchar(4))
  AND ToCurrencyCode = 'USD'
/***************************************/



SELECT C.ClubName, VR.Description AS RegionDescription, 
       EFT.EFTDate, MS.MembershipID, EFT.EFTReturnCodeID, EFT.AccountNumber,
       EFT.PaymentID, EFT.ValEFTStatusID,
       VPT.Description AS PaymentTypeDescription, 
       VPT.ValPaymentTypeID, 
       VES.Description AS EFTStatusDescription,
       M.MemberID AS PrimaryMemberID, M.FirstName AS PrimaryFirstName, 
       M.LastName AS PrimaryLastName,
       GETDATE() AS Today, MS.ExpirationDate, C.ClubID, VR.ValRegionID,
       Null AS RecurrentProductActivationDate,   ----- Removed recurrent product data as it was causing duplications - SRM
       Null AS RecurrentProductTerminationDate,
       Null AS RecurrentProductDescription,
		MS.CreatedDateTime,			-- added 1/8/2010 GRB
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount,
	   MSB.EFTAmount * #PlanRate.PlanRate as MembershipBalanceEFTAmount,	   
	   EFT.EFTAmount as LocalCurrency_EFTAmount,	   
	   MSB.EFTAmount as LocalCurrency_MembershipBalanceEFTAmount,
	   EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount,	   
	   MSB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipBalanceEFTAmount,
	   MS.ValMembershipStatusID	   	
/***************************************/

  FROM dbo.vEFT EFT
  JOIN vMembership MS 
       ON EFT.MembershipID = MS.MembershipID
  JOIN #Clubs
      ON MS.ClubID = #Clubs.ClubID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
  JOIN dbo.vValPaymentType VPT 
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN #PaymentType
       ON VPT.ValPaymentTypeID = #PaymentType.ValPaymentTypeID
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

 WHERE EFT.EFTDate >= @FirstOfMonth AND
       EFT.EFTDate <= @FourthOfMonth AND
       M.ValMemberTypeID = 1

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





