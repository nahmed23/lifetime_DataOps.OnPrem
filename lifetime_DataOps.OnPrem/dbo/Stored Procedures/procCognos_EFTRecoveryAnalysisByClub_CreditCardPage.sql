



CREATE PROC [dbo].[procCognos_EFTRecoveryAnalysisByClub_CreditCardPage] (
    @ClubIDList VARCHAR(2000),
    @PaymentTypeList VARCHAR(1000),
    @RegionList VARCHAR(2000),
    @MembershipStatusList VARCHAR(100)

)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

/*    =============================================
      Object:           procCognos_EFTRecoveryAnalysisByClub_CreditCardPage
      Author:                       
      Create date:            
      Description:            Returns information on credit card EFT drafts month to date, whether or not they 
                                          were initially rejected and if they are currently recovered ( based upon the membership account balance).
      Modified date:          
      EXEC procCognos_EFTRecoveryAnalysisByClub_CreditCardPage '151|14|10','American Express|Discover','All Regions','Non-Terminated'
    =============================================   
 */

DECLARE @ReportRunDateTime  VARCHAR(110)
SET @ReportRunDateTime = Replace(SubString(Convert(Varchar,GetDate()),1,3)+' '+LTRIM(SubString(Convert(Varchar,GetDate()),5,DataLength(Convert(Varchar,GetDate()))-12)),' '+Convert(Varchar,Year(GetDate())),', '+Convert(Varchar,Year(GetDate()))) + '  ' + LTRIM(SubString(Convert(Varchar,GetDate(),22),10,5) + ' ' + Right(ConverT(Varchar,GetDate(),22),2))

DECLARE @FirstOfMonth DATETIME
DECLARE @FourthOfMonth DATETIME
SET @FirstOfMonth = cast(DATEPART(month,GETDATE()) as varchar(2))+'/01/'+cast(DATEPART(year,GETDATE()) as varchar(4))
SET @FourthOfMonth = cast(DATEPART(month,GETDATE()) as varchar(2))+'/04/'+cast(DATEPART(year,GETDATE()) as varchar(4))


CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID VARCHAR(50))
   
INSERT INTO #Clubs (ClubID) 
  SELECT DISTINCT Club.ClubID
  FROM vValRegion ValRegion
  Join vClub Club
    On ValRegion.ValRegionID = Club.ValRegionID
  JOIN fnParsePipeList(@RegionList) RegionList
    ON RegionList.Item = ValRegion.Description
      OR RegionList.Item = 'All Regions'
  JOIN fnParsePipeList(@ClubIDList) ClubIDList
    ON ClubIDList.Item = Club.ClubID
      OR ClubIDList.Item = 0

      TRUNCATE TABLE #tmpList


DECLARE @EFTEndDate DATETIME
SET  @EFTEndDate = (    
SELECT DATEADD(Day,1,Convert(DateTime,(CONVERT(Varchar,Min(EFTDate),101))))
From vEFT EFT 
Where EFTDate >= @FirstOfMonth
AND   EFTDate < @FourthOfMonth )

EXEC procParseStringList @PaymentTypeList
CREATE TABLE #PaymentType (ValPaymentTypeID INT, PaymentTypeDescription VARCHAR(50))
INSERT INTO #PaymentType (ValPaymentTypeID,PaymentTypeDescription )
SELECT vValPaymentType.ValPaymentTypeID,vValPaymentType.Description
  FROM vValPaymentType
WHERE Description IN (SELECT StringField FROM #tmpList)
    AND vValPaymentType.ValEFTAccountTypeID = 2   ----- Credit Card payment types
    TRUNCATE TABLE #tmpList
    
DECLARE  @HeaderCCPaymentTypeList VARCHAR(1000)     
SET @HeaderCCPaymentTypeList = STUFF((SELECT DISTINCT ', '+PaymentTypeDescription
                                         FROM #PaymentType
                                          FOR XML PATH('')),1,1,'')     
                                          
CREATE TABLE #MembershipStatus ( MembershipStatusItem VARCHAR(50))
EXEC procParseStringList @MembershipStatusList
   INSERT INTO #MembershipStatus (MembershipStatusItem)
    (SELECT StringField FROM #tmpList)
    TRUNCATE TABLE #tmpList
                                             

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = CASE WHEN @ClubIDList = 'All' THEN 'USD'
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


SELECT VR.Description AS RegionDescription,
       C.ClubName, 
       C.ClubID, 
       Replace(SubString(Convert(Varchar,EFT.EFTDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,EFT.EFTDate),5,DataLength(Convert(Varchar,EFT.EFTDate))-12)),' '+Convert(Varchar,Year(EFT.EFTDate)),', '+Convert(Varchar,Year(EFT.EFTDate))) AS EFTDate, 
       CASE WHEN MS.ValMembershipStatusID = 1
            THEN 'Terminated'
            ELSE 'Non-Terminated'
            End  MembershipStatus,
       Count(EFT.EFTID) AS EFTCount,
       Sum(EFT.EFTAmount * #PlanRate.PlanRate) as EFTAmount,
       Sum(CASE WHEN EFT.ValEFTStatusID = 3
                THEN 1
                ELSE 0 END )  AS ApprovedEFTCount,       
       Sum(CASE WHEN EFT.ValEFTStatusID = 3
                THEN EFT.EFTAmount * #PlanRate.PlanRate
                ELSE 0 END )  AS ApprovedEFTAmount,
       Sum(CASE WHEN EFT.ValEFTStatusID = 2
                THEN 1
                ELSE 0 END) AS DeclinedEFTCount,
       Sum(CASE WHEN EFT.ValEFTStatusID = 2
                THEN EFT.EFTAmount * #PlanRate.PlanRate
                ELSE 0 END) AS DeclinedEFTAmount,
       Sum(CASE WHEN MSB.EFTAmount >0
                THEN 1
                ELSE 0 END) AS EFTYetUnrecoveredCount_Dues,
       Sum(CASE WHEN MSB.EFTAmount >0
                THEN MSB.EFTAmount * #PlanRate.PlanRate
                ELSE 0 END) AS EFTYetUnrecoveredAmount_Dues,
	   Sum(CASE WHEN MSB.EFTAmountProducts >0
                THEN 1
                ELSE 0 END) AS EFTYetUnrecoveredCount_Products,
       Sum(CASE WHEN MSB.EFTAmountProducts >0
                THEN MSB.EFTAmountProducts * #PlanRate.PlanRate
                ELSE 0 END) AS EFTYetUnrecoveredAmount_Products,      
       @ReportingCurrencyCode as ReportingCurrencyCode,
       @HeaderCCPaymentTypeList AS HeaderCCPaymentTypeList,        
       @ReportRunDateTime AS ReportRunDateTime,
       'Credit Card' AS PageType
  INTO #Results
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
       EFT.EFTDate <= @EFTEndDate 
       
Group By C.ClubName, VR.Description,
       Replace(SubString(Convert(Varchar,EFT.EFTDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,EFT.EFTDate),5,DataLength(Convert(Varchar,EFT.EFTDate))-12)),' '+Convert(Varchar,Year(EFT.EFTDate)),', '+Convert(Varchar,Year(EFT.EFTDate))), 
       C.ClubID, VR.ValRegionID,
       CASE WHEN MS.ValMembershipStatusID = 1
            THEN 'Terminated'
            ELSE 'Non-Terminated'
            End,
       VCC.CurrencyCode,#PlanRate.PlanRate
       
Order By MembershipStatus,VR.Description,C.ClubName

Select RegionDescription,
ClubName,
ClubID,
EFTDate,
MembershipStatus,
EFTCount,
EFTAmount,
ApprovedEFTCount,
ApprovedEFTAmount,
DeclinedEFTCount,
DeclinedEFTAmount,
EFTYetUnrecoveredCount_Dues,
EFTYetUnrecoveredAmount_Dues,
EFTYetUnrecoveredCount_Products,
EFTYetUnrecoveredAmount_Products,
ReportingCurrencyCode,
HeaderCCPaymentTypeList,
ReportRunDateTime,
PageType
from #Results  AS Results
Join #MembershipStatus AS Status
On Results.MembershipStatus = Status.MembershipStatusItem


DROP TABLE #Clubs
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #MembershipStatus
DROP TABLE #Results

END


