



CREATE PROC [dbo].[procCognos_EFTProjectedSummaryByClub] (
  @ClubIDList VARCHAR(1000)

)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON



-- =============================================
--	Object:			dbo.procCognos_EFTProjectedSummaryByClub
--	Author:			
--	Create date: 	10/15/2013
--	Description:	
--	Modified date:	
--	EXEC procCognos_EFTProjectedSummaryByClub '151'
-- =============================================


DECLARE  @ReportRunDateTime VARCHAR(110) 
SET @ReportRunDateTime = Replace(SubString(Convert(Varchar,GetDate()),1,3)+' '+LTRIM(SubString(Convert(Varchar,GetDate()),5,DataLength(Convert(Varchar,GetDate()))-12)),' '+Convert(Varchar,Year(GetDate())),', '+Convert(Varchar,Year(GetDate()))) + '  ' + LTRIM(SubString(Convert(Varchar,GetDate(),22),10,5) + ' ' + Right(ConverT(Varchar,GetDate(),22),2))


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
   INSERT INTO #Clubs VALUES (0) -- all clubs
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
WHERE PlanYear = Year(GETDATE())
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear = Year(GETDATE())
  AND ToCurrencyCode = 'USD'
  


/***************************************/
  
  SELECT C.ClubID,
         VR.Description+'  -  '+C.ClubName AS Region_Club,
         COUNT (DISTINCT (MS.MembershipID)) AS MembershipCount, 
         CASE WHEN VPT.Description is null
              THEN 'Undefined'
              ELSE VPT.Description
              END EFTPaymentMethod,
        @ReportRunDateTime AS  ReportRunDateTime,

/******  Foreign Currency Stuff  *********/
       #PlanRate.PlanRate,
       @ReportingCurrencyCode AS ReportingCurrencyCode,	 	     
	   SUM (CASE WHEN VPT.Description is null THEN 0 ELSE MSB.EFTAmount * #PlanRate.PlanRate END ) AS EFTAmount_Dues,
	   SUM (CASE WHEN VPT.Description is null THEN 0 ELSE IsNull(MSB.EFTAmountProducts,0) * #PlanRate.PlanRate END ) AS EFTAmount_Products	   	     	   	
/***************************************/

    FROM dbo.vClub C
    JOIN #Clubs CS
         ON C.ClubID = CS.ClubID or CS.ClubID = 0
    JOIN vMembership MS
         ON MS.ClubID = C.ClubID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vMembershipBalance MSB
         ON MS.MembershipID = MSB.MembershipID
    LEFT JOIN dbo.vEFTAccountDetail EFTD
         ON MS.MembershipID = EFTD.MembershipID
    LEFT JOIN dbo.vValPaymentType VPT
         ON EFTD.ValPaymentTypeID = VPT.ValPaymentTypeID 
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


   WHERE C.DisplayUIFlag = 1 
         AND MS.ValEFTOptionID = 1  ----ValEFTOptionID of 1 is "Active EFT"
         AND ((IsNull(MSB.EFTAmount,0) + IsNull(MSB.EFTAmountProducts,0)) > 0)
   GROUP BY C.ClubName, C.ClubID, VCC.CurrencyCode, #PlanRate.PlanRate, VR.Description,VPT.Description  

  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate


END 



