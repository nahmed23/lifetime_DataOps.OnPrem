

CREATE PROC [dbo].[procCognos_EFTSummary] (
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
	Object:				procCognos_EFTSummary
	Description:		Returns EFT transaction records within selected parameters
	Parameters:			clubid, payment type, startdate, endate
    procCognos_EFTSummary '10/1/2013 12:00 AM', '10/15/2013 12:00 AM', 
'0|-1|1|10|100|11|12|126|128|13|131|132|133|136|137|138|139|14|140|141|142|143|144|146|147|148|149|15|150|151|152|153|154|155|156|157|158|159|160|161|162|163|164|165|166|167|168|169|170|171|172|174|175|176|177|178|179|180|181|182|183|184|185|186|187|188|189|190|191|192|193|194|195|196|197|198|199|2|20|200|201|202|203|204|205|206|207|208|21|213|215|216|22|221|222|223|224|225|226|227|228|229|230|231|232|233|235|236|237|3|30|35|36|4|40|5|50|51|52|53|6|7|8|815|817|9|99|996|997|998|999|9999', 
'American Express|Commercial Checking EFT|Discover|Individual Checking|MasterCard|Savings Account|VISA'

	=============================================		*/

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
   
  EXEC procParseStringList @ClubIDList
  INSERT INTO #Clubs (ClubID) 
  SELECT DISTINCT ClubID FROM vClub C
  JOIN  #tmpList tC ON tC.StringField = C.ClubID OR tC.StringField = '0'
  TRUNCATE TABLE #tmpList
  

  CREATE TABLE #PaymentType (Description VARCHAR(50))
  
  EXEC procParseStringList @PaymentTypeList
  INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

SET @StartDate = CASE WHEN @StartDate = 'Jan 1, 1900' THEN DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0) ELSE @StartDate END
SET @EndDate = CASE WHEN @EndDate = 'Jan 1, 1900' THEN CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),101),101) ELSE @EndDate END

DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' through ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = CONVERT (varchar,getdate(), 107)+ ' ' + substring(CONVERT (varchar,getdate(), 100), 13,8)

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

SET @EndDate = DATEADD(DAY,1, @EndDate) -- next day midnght 

/***************************************/
SELECT 
		C.ClubName, 
		C.GLClubID,
		VR.Description AS RegionDescription,
		VPT.Description AS PaymentTypeDescription,  
		COUNT(EFT.MembershipID) AS TotalTransactionCount, 
		SUM((EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate) AS TotalTransactionAmount,
		SUM(CASE WHEN EFT.Valeftstatusid = 3 THEN 1 else 0 END) AS ApprovedCount,
		SUM(CASE WHEN EFT.Valeftstatusid = 3 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate else 0 END) AS ApprovedAmount,
		SUM(CASE WHEN EFT.Valeftstatusid = 2 THEN 1 else 0 END) AS ReturnedCount,
		SUM(CASE WHEN EFT.Valeftstatusid = 2 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate else 0 END) AS  ReturnedAmount,
		MAX(@ReportingCurrencyCode) as ReportingCurrencyCode,
		MAX(@HeaderDateRange) AS HeaderDateRange,
        MAX(@ReportRunDateTime) AS ReportRunDateTime,
        SUM(CASE WHEN VPT.ValPaymentTypeID in (9,10,13) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate else 0 END) Accum_ACHApprovedAmt_ByClub, -- ('Individual Checking', 'Savings Account', 'Commercial Checking EFT')		
        SUM(CASE WHEN VPT.ValPaymentTypeID in (3,4) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate else 0 END) Accum_VISA_MC_ApprovedAmt_ByClub, -- ('VISA', 'MasterCard') 		
        SUM(CASE WHEN VPT.ValPaymentTypeID in (5) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate else 0 END) Accum_Discover_ApprovedAmt_ByClub, -- ('Discover') 		
        SUM(CASE WHEN VPT.ValPaymentTypeID in (8) AND EFT.Valeftstatusid = 3
                 THEN (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate else 0 END) Accum_AMEX_ApprovedAmt_ByClub, -- ('American Express')
        MAX(1) UniqueClubFlag 		
			   	
/***************************************/
  FROM vMembership MS
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID 
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vEFT EFT
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN #PaymentType PT
       ON VPT.Description = PT.Description   
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #PlanRate.PlanYear
/*******************************************/
 WHERE C.DisplayUIFlag = 1 AND
       EFT.EFTDate > @StartDate AND EFT.EFTDate < @EndDate AND
       VPT.ViewBankAccountTypeFlag = 1 AND       
	   EFT.EFTReturnCodeID is not null AND
	   EFT.EFTReturnCodeID <> 42 AND
       EFT.ValEFTTypeID <> 3 -- refunds are not included
GROUP BY VR.Description, C.ClubName, C.GLClubID, VPT.Description 
Order By VR.Description,C.ClubName,VPT.Description

       
DROP TABLE #Clubs
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate


END


