
CREATE PROC [dbo].[mmsEFTSummary_Summary] (
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @ClubIDList VARCHAR(2000),
  @PaymentTypeList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*	=============================================
	Object:				dbo.mmsEFTSummary_Summary
	Author:				
	Create date: 		
	Description:		Returns EFT transaction records within selected parameters

	Parameters:			clubid, payment type, startdate, endate

	Modified date:		1/8/2010 GRB: add vMembership.CreatedDateTime to end of result set to facilitate 
							the high volume of internet sales via PK; dbcr_5508 deploying 1/8/2010 via ECR
                        4/1/2011 SC: added support for foreign currency
                        12/28/2011 BSD: Added LFF Acquisition logic

	EXEC mmsEFTSummary_Summary '5/1/2013', '5/1/2013 11:59 PM', '188', 'All'
	EXEC mmsEFTSummary_Summary 'Mar 1, 2011 12:00 AM', 'Mar 2, 2011 11:59 PM', '141', 'Visa'
	=============================================	*/


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
   INSERT INTO #Clubs VALUES(0) -- all clubs
END   

CREATE TABLE #PaymentType (Description VARCHAR(50))
IF @PaymentTypeList <> 'All'
BEGIN
  
   EXEC procParseStringList @PaymentTypeList
   INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #PaymentType VALUES('All') 
END  

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

/***************************************/

SELECT C.ClubName, 
       VR.Description AS RegionDescription,
       EFTDate,    
       MS.MembershipID, 
       EFT.EFTReturnCodeID, 
       EFT.AccountNumber, 
       EFT.ValPaymentTypeID,
       EFT.PaymentID, 
       EFT.ValEFTStatusID, 
       VPT.Description AS PaymentTypeDescription,  
       VES.Description AS EFTStatusDescription,
       M.MemberID AS PrimaryMemberID,
       M.FirstName AS PrimaryFirstName,
       M.LastName AS PrimaryLastName, 
       Replace(Substring(convert(varchar,MS.ExpirationDate,100),1,6)+', '+Substring(convert(varchar,MS.ExpirationDate,100),8,10)+' '+Substring(convert(varchar,MS.ExpirationDate,100),18,2),'  ',' ') ExpirationDate,
       Replace(Substring(convert(varchar,AAM.AssociateMembershipActivationDate,100),1,6)+', '+Substring(convert(varchar,AAM.AssociateMembershipActivationDate,100),8,10)+' '+Substring(convert(varchar,AAM.AssociateMembershipActivationDate,100),18,2),'  ',' ') RecurrentProductActivationDate,              
       P.Description AS RecurrentProductDescription,
       C.GLClubID,       
       CreatedDateTime,
	   @StartDate AS Report_StartDate,
	   @EndDate AS Report_EndDate,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount,
	   MSB.EFTAmount * #PlanRate.PlanRate as MembershipBalanceEFTAmount,
	   MSB.CommittedBalance * #PlanRate.PlanRate as CommittedBalance,
	   EFT.EFTAmount as LocalCurrency_EFTAmount,
	   MSB.CommittedBalance as LocalCurrency_CommittedBalance,
	   MSB.EFTAmount as LocalCurrency_MembershipBalanceEFTAmount,
	   EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount,
	   MSB.CommittedBalance * #ToUSDPlanRate.PlanRate as USD_CommittedBalance,
	   MSB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipBalanceEFTAmount
	   	
/***************************************/
  FROM vMembership MS
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID OR CS.ClubID = 0
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vEFT EFT
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN #PaymentType PT
       ON VPT.Description = PT.Description OR PT.Description = 'All'
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
  JOIN dbo.vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  JOIN dbo.vMember M 
       ON MS.MembershipID = M.MembershipID
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
  LEFT JOIN vActiveAssociateMemberships AAM
       ON AAM.MembershipID = MS.MembershipID
  LEFT JOIN vProduct P
       ON P.ProductID = AAM.ProductID
 WHERE C.DisplayUIFlag = 1 AND
       EFT.EFTDate BETWEEN @StartDate AND @EndDate AND
       VPT.ViewBankAccountTypeFlag = 1 AND
       M.ValMemberTypeID = 1 AND
	   EFT.EFTReturnCodeID is not null AND
	   EFT.EFTReturnCodeID <> 42 AND
       EFT.ValEFTTypeID <> 3 -- automated EFT refunds are not included

 Order By VR.Description,C.ClubName,MS.MembershipID,EFT.EFTDate
       
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
