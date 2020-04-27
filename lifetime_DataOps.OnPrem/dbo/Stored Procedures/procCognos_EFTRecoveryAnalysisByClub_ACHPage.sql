


CREATE PROC [dbo].[procCognos_EFTRecoveryAnalysisByClub_ACHPage] (
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
      Object:           procCognos_EFTRecoveryAnalysisByClub_ACHPage
      Author:                       
      Create date:            
      Description:  Returns information on Bank Account type EFT drafts month to date;
                    evaluating whether or not they were initially rejected and if they are currently
                    recovered ( based upon the membership account balance).          
      Modified date:          
      EXEC procCognos_EFTRecoveryAnalysisByClub_ACHPage '151|14|10','Commercial Checking EFT|Individual Checking|Savings Account','West-MN-West','Non-Terminated'
    =============================================   
 */
 
DECLARE @FirstOfMonth DATETIME
DECLARE @FourthOfMonth DATETIME
DECLARE @ReportRunDateTime  VARCHAR(110)
SET @FirstOfMonth = cast(DATEPART(month,GETDATE()) as varchar(2))+'/01/'+cast(DATEPART(year,GETDATE()) as varchar(4))
SET @FourthOfMonth = cast(DATEPART(month,GETDATE()) as varchar(2))+'/04/'+cast(DATEPART(year,GETDATE()) as varchar(4))
SET @ReportRunDateTime = Replace(SubString(Convert(Varchar,GetDate()),1,3)+' '+LTRIM(SubString(Convert(Varchar,GetDate()),5,DataLength(Convert(Varchar,GetDate()))-12)),' '+Convert(Varchar,Year(GetDate())),', '+Convert(Varchar,Year(GetDate()))) + '  ' + LTRIM(SubString(Convert(Varchar,GetDate(),22),10,5) + ' ' + Right(ConverT(Varchar,GetDate(),22),2))

DECLARE @EFTEndDate DATETIME
SET  @EFTEndDate = (    
SELECT DATEADD(Day,1,Convert(DateTime,(CONVERT(Varchar,Min(EFTDate),101))))
From vEFT EFT 
Where EFTDate >= @FirstOfMonth
AND   EFTDate < @FourthOfMonth) 

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (MMSClubID VARCHAR(50))

 
  INSERT INTO #Clubs (MMSClubID) 
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


CREATE TABLE #PaymentType (ValPaymentTypeID INT, PaymentTypeDescription VARCHAR(50))
EXEC procParseStringList @PaymentTypeList
   INSERT INTO #PaymentType (ValPaymentTypeID, PaymentTypeDescription)
     SELECT vValPaymentType.ValPaymentTypeID, vValPaymentType.Description
     FROM vValPaymentType
     WHERE Description IN (SELECT StringField FROM #tmpList)
      AND vValPaymentType.ValEFTAccountTypeID = 1
      TRUNCATE TABLE #tmpList
 
DECLARE  @HeaderACHPaymentTypeList VARCHAR(1000)     
SET @HeaderACHPaymentTypeList = STUFF((SELECT DISTINCT ', '+PaymentTypeDescription
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
                                          JOIN #Clubs ON C.ClubID = #Clubs.MMSClubID
                                          JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID) END

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= cast(DATEPART(year,GetDate()) as varchar(4))
  AND PlanYear <= cast(DATEPART(year,GetDate()) as varchar(4))
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= cast(DATEPART(year,GetDate()) as varchar(4))
  AND PlanYear <= cast(DATEPART(year,GetDate()) as varchar(4))
  AND ToCurrencyCode = 'USD'
  


SELECT MMST.MMSTranID, 
       MMST.ClubID,
       MMST.MembershipID,
       MMST.PostDateTime,
       MMST.TranAmount
INTO #MMSTran
FROM vMMSTran MMST WITH (NOLOCK)
JOIN vDrawerActivity DA
  ON MMST.DrawerActivityID = DA.DrawerActivityID
JOIN #Clubs CS
  ON MMST.ClubID = CS.MMSClubID
WHERE DA.DrawerID = 25
  AND MMST.EmployeeID = -2
  AND MMST.ValTranTypeID = 4
  AND MMST.ReasonCodeID != 75
  AND (DATEDIFF(month,MMST.PostDateTime,GetDate()) = 0)
  
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)


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
       Sum(CASE WHEN EFT.ValEFTStatusID = 2
                THEN 1
                ELSE 0 END) AS DeclinedEFTCount,       
       Sum(CASE WHEN EFT.ValEFTStatusID = 2
                THEN EFT.EFTAmount * #PlanRate.PlanRate
                ELSE 0 END) AS DeclinedEFTAmount,
       Sum(CASE WHEN ISNULL(T1.TranAmount,0)=0 
                 THEN 0
                WHEN T1.TranAmount > 0 
                 THEN 1
                ELSE 0 END) AS ChargeBackTranCount,
       Sum(CASE WHEN ISNULL(T1.TranAmount,0)=0
                THEN 0
                ELSE (T1.TranAmount * #PlanRate.PlanRate)
                END ) as ChargebackTranAmount,
       Sum(CASE WHEN MSB.CommittedBalance >0
                THEN 1
                ELSE 0 END) AS EFTYetUnrecoveredCount_Dues,       
       Sum(CASE WHEN MSB.CommittedBalance >0
                THEN MSB.CommittedBalance * #PlanRate.PlanRate
                ELSE 0 END) AS EFTYetUnrecoveredAmount_Dues,
	   Sum(CASE WHEN MSB.CommittedBalanceProducts >0
                THEN 1
                ELSE 0 END) AS EFTYetUnrecoveredCount_Products,       
       Sum(CASE WHEN MSB.CommittedBalanceProducts >0
                THEN MSB.CommittedBalanceProducts * #PlanRate.PlanRate
                ELSE 0 END) AS EFTYetUnrecoveredAmount_Products,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       @HeaderACHPaymentTypeList AS HeaderACHPaymentTypeList,
       @ReportRunDateTime AS ReportRunDateTime,
       'ACH' AS PageType
  INTO #Results
  FROM dbo.vEFT EFT
  JOIN vMembership MS
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #PaymentType PT
       ON (EFT.ValPaymentTypeID = PT.ValPaymentTypeID )
  JOIN dbo.vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
  JOIN dbo.vValRegion VR 
       ON C.ValRegionID = VR.ValRegionID
  JOIN #Clubs CS
       ON C.ClubID = CS.MMSClubID 
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

  LEFT JOIN #MMSTran T1
       ON T1.MembershipID = MS.MembershipID AND
       C.ClubID = T1.ClubID
 WHERE EFT.EFTDate >= @FirstOfMonth  
  AND  EFT.EFTDate <  @EFTEndDate
       
Group By C.ClubName, VR.Description,
       Replace(SubString(Convert(Varchar,EFT.EFTDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,EFT.EFTDate),5,DataLength(Convert(Varchar,EFT.EFTDate))-12)),' '+Convert(Varchar,Year(EFT.EFTDate)),', '+Convert(Varchar,Year(EFT.EFTDate))), 
       C.ClubID,
       CASE WHEN MS.ValMembershipStatusID = 1
            THEN 'Terminated'
            ELSE 'Non-Terminated'
            End,
       VCC.CurrencyCode
       
 Select RegionDescription,
 ClubName,
 ClubID,
 EFTDate,
 MembershipStatus,
 EFTCount,
 EFTAmount,
 DeclinedEFTCount,
 DeclinedEFTAmount,
 ChargeBackTranCount,
 ChargebackTranAmount,
 EFTYetUnrecoveredCount_Dues,
 EFTYetUnrecoveredAmount_Dues,
 EFTYetUnrecoveredCount_Products,
 EFTYetUnrecoveredAmount_Products,
 ReportingCurrencyCode,
 HeaderACHPaymentTypeList,
 ReportRunDateTime,
 PageType
  from #Results AS Results
 Join #MembershipStatus As Status
 On Results.MembershipStatus = Status.MembershipStatusItem
       
  DROP TABLE #Clubs
  DROP TABLE #PaymentType
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate
  DROP TABLE #MMSTran
  DROP TABLE #MembershipStatus
  DROP TABLE #Results


END


