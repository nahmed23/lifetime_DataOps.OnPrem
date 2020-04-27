






CREATE PROC [dbo].[procCognos_EFTRecoveryAnalysisByClubDetailDrillThrough] (
        @ReportingCurrencyCode VARCHAR(3),
        @PageType VARCHAR(15),
        @PaymentTypeList VARCHAR(1000),
        @ClubID INT,
        @MembershipStatus VARCHAR(50)
)

AS
BEGIN 
SET XACT_ABORT ON
SET NOCOUNT ON

/*    =============================================
      Object:           procCognos_EFTRecoveryAnalysisByClubDetailDrillThrough
      Author:                       
      Create date:            
      Description:      Returns membership level information on EFT drafts month to date, whether or not they 
                        were initially rejected and if they are currently recovered ( based upon the membership account balance).
      Modified date:          
      EXEC procCognos_EFTRecoveryAnalysisByClubDetailDrillThrough 'USD','Credit Card','American Express|Discover',12,'Non-Terminated'
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

/********  Foreign Currency Stuff ********/
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
  
CREATE TABLE #Results (PageType VARCHAR(15),
         EFTDate VARCHAR(50),
         RegionDescription VARCHAR(50),
         ClubID INT,
         ClubCode VARCHAR(3),
         ClubName VARCHAR(50),
         MembershipID INT,
         MembershipCreatedDate VARCHAR(50),
         MembershipExpirationDate VARCHAR(50),
         PrimaryMemberID INT, 
         PrimaryMemberFirstName VARCHAR(50),
         PrimaryMemberLastName VARCHAR(50),
         EFTPaymentTypeDescription VARCHAR(50),  
         EFTStatusDescription VARCHAR(50),
         ChargeBackPostDateTime VARCHAR(50),
         ReportingCurrencyCode VARCHAR(3),
         EFTAmount Decimal(14,4),
         DeclinedEFTAmount Decimal(14,4),
         ChargeBackTranAmount Decimal(14,4),
         EFTYetUnrecoveredAmount_Dues Decimal(14,4),
		 EFTYetUnrecoveredAmount_Products Decimal(14,4),
         MembershipBalance_CommittedBalance_Dues Decimal(14,4),
		 MembershipBalance_CommittedBalance_Products Decimal(14,4),
         MembershipBalance_EFTAmount_Dues Decimal(14,4),
		 MembershipBalance_EFTAmount_Products Decimal(14,4),
         PlanRate Decimal(14,4),
         LocalCurrencyCode VARCHAR(3),
         LocalCurrency_EFTAmount Decimal(14,2),
         LocalCurrency_MembershipBalance_CommittedBalance_Dues Decimal(14,2),
		 LocalCurrency_MembershipBalance_CommittedBalance_Products Decimal(14,2),
         LocalCurrency_MembershipBalance_EFTAmount_Dues Decimal(14,2),
		 LocalCurrency_MembershipBalance_EFTAmount_Products Decimal(14,2),
         LocalCurrency_ChargeBackTranAmount Decimal(14,2),
         USD_EFTAmount Decimal(14,4),
         USD_MembershipBalance_CommittedBalance_Dues Decimal(14,4),
		 USD_MembershipBalance_CommittedBalance_Products Decimal(14,4),
         USD_MembershipBalance_EFTAmount_Dues Decimal(14,4),
		 USD_MembershipBalance_EFTAmount_Products Decimal(14,4),
         USD_ChargeBackTranAmount Decimal(14,4),
         ReportRunDateTime VARCHAR(50),
         MembershipStatus VARCHAR(50),
         HeaderPaymentTypeList VARCHAR(1000))
         
CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #PaymentType (ValPaymentTypeID INT, PaymentTypeDescription VARCHAR(50))
  
IF @PageType = 'ACH'

BEGIN


EXEC procParseStringList @PaymentTypeList
   INSERT INTO #PaymentType (ValPaymentTypeID,PaymentTypeDescription)
     SELECT vValPaymentType.ValPaymentTypeID, vValPaymentType.Description
     FROM vValPaymentType
     WHERE Description IN (SELECT StringField FROM #tmpList)
      AND vValPaymentType.ValEFTAccountTypeID = 1

DECLARE  @HeaderACHPaymentTypeList VARCHAR(1000)     
SET @HeaderACHPaymentTypeList = STUFF((SELECT DISTINCT ', '+PaymentTypeDescription
                                         FROM #PaymentType
                                          FOR XML PATH('')),1,1,'')  
      
      
SELECT MMST.MMSTranID, 
       MMST.ClubID,
       MMST.MembershipID,
       MMST.PostDateTime,
       MMST.TranAmount
INTO #MMSTran
FROM vMMSTran MMST WITH (NOLOCK)
JOIN vDrawerActivity DA
  ON MMST.DrawerActivityID = DA.DrawerActivityID

WHERE DA.DrawerID = 25       ----EFT INTERNAL club drawer
  AND MMST.EmployeeID = -2    ----- AUTOMATED TRIGGER "employee"
  AND MMST.ValTranTypeID = 4   ------ Adjustment Transaction type
  AND MMST.ReasonCodeID != 75   ---- Charged EFT in Error ID#
  AND (DATEDIFF(month,MMST.PostDateTime,GetDate()) = 0)
  AND MMST.ClubID = @ClubID
  

/***************************************/
INSERT INTO #Results
   SELECT @PageType AS PageType,
          Replace(SubString(Convert(Varchar,EFT.EFTDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,EFT.EFTDate),5,DataLength(Convert(Varchar,EFT.EFTDate))-12)),' '+Convert(Varchar,Year(EFT.EFTDate)),', '+Convert(Varchar,Year(EFT.EFTDate))) AS EFTDate,
          VR.Description AS RegionDescription,
          C.ClubID,
          C.ClubCode,
          C.ClubName,
          EFT.MembershipID,
          Replace(SubString(Convert(Varchar,MS.CreatedDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar,MS.CreatedDateTime),5,DataLength(Convert(Varchar,MS.CreatedDateTime))-12)),' '+Convert(Varchar,Year(MS.CreatedDateTime)),', '+Convert(Varchar,Year(MS.CreatedDateTime))) AS MembershipCreatedDate,
          Replace(SubString(Convert(Varchar,MS.ExpirationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,MS.ExpirationDate),5,DataLength(Convert(Varchar,MS.ExpirationDate))-12)),' '+Convert(Varchar,Year(MS.ExpirationDate)),', '+Convert(Varchar,Year(MS.ExpirationDate))) AS MembershipExpirationDate,
          M.MemberID AS PrimaryMemberID,
          M.FirstName AS PrimaryMemberFirstName,
          M.LastName AS PrimaryMemberLastName,
          VPT.Description AS EFTPaymentTypeDescription,        
          VES.Description AS EFTStatusDescription, 
          Replace(SubString(Convert(Varchar,T1.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar,T1.PostDateTime),5,DataLength(Convert(Varchar,T1.PostDateTime))-12)),' '+Convert(Varchar,Year(T1.PostDateTime)),', '+Convert(Varchar,Year(T1.PostDateTime))) + '  ' + LTRIM(SubString(Convert(Varchar,T1.PostDateTime,22),10,5) + ' ' + Right(ConverT(Varchar,T1.PostDateTime,22),2))AS ChargebackPostdatetime,       
          @ReportingCurrencyCode as ReportingCurrencyCode,
          (EFT.EFTAmount * #PlanRate.PlanRate) as EFTAmount,
          CASE WHEN EFT.ValEFTStatusID = 2
               THEN (EFT.EFTAmount * #PlanRate.PlanRate)
               ELSE 0
               END  DeclinedEFTAmount,
          (T1.TranAmount * #PlanRate.PlanRate) as ChargebackTranAmount,
          CASE WHEN MSB.CommittedBalance >0
               THEN (MSB.CommittedBalance * #PlanRate.PlanRate)
               ELSE 0
               END EFTYetUnrecoveredAmount_Dues,
		  CASE WHEN MSB.CommittedBalanceProducts >0
               THEN (MSB.CommittedBalanceProducts * #PlanRate.PlanRate)
               ELSE 0
               END EFTYetUnrecoveredAmount_Products,
          MSB.CommittedBalance * #PlanRate.PlanRate as MembershipBalance_CommittedBalance_Dues,
		  MSB.CommittedBalanceProducts * #PlanRate.PlanRate as MembershipBalance_CommittedBalance_Products,
          MSB.EFTAmount * #PlanRate.PlanRate as MembershipBalance_EFTAmount_Dues,
		  MSB.EFTAmountProducts * #PlanRate.PlanRate as MembershipBalance_EFTAmount_Products,
/******  Foreign Currency Stuff  *********/
       #PlanRate.PlanRate,
       VCC.CurrencyCode as LocalCurrencyCode,
       EFT.EFTAmount as LocalCurrency_EFTAmount,
       MSB.CommittedBalance as LocalCurrency_MembershipBalance_CommittedBalance_Dues,
	   MSB.CommittedBalanceProducts as LocalCurrency_MembershipBalance_CommittedBalance_Products,
       MSB.EFTAmount  as LocalCurrency_MembershipBalance_EFTAmount_Dues,
	   MSB.EFTAmountProducts  as LocalCurrency_MembershipBalance_EFTAmount_Products,
       T1.TranAmount as LocalCurrency_ChargebackTranAmount,
       EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTAmount,
       MSB.CommittedBalance * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_CommittedBalance_Dues,
	   MSB.CommittedBalanceProducts * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_CommittedBalance_Products,
       MSB.EFTAmount * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_EFTAmount,
	   MSB.EFTAmountProducts * #ToUSDPlanRate.PlanRate as USD_MembershipBalance_EFTAmount_Products,
       T1.TranAmount * #ToUSDPlanRate.PlanRate as USD_ChargebackTranAmount,                     
       @ReportRunDateTime AS ReportRunDateTime,
       CASE When MS.ValMembershipStatusID = 1
            THEN 'Terminated'
            ELSE 'Non-Terminated'
            END MembershipStatus,
       @HeaderACHPaymentTypeList AS HeaderPaymentTypeList
  FROM dbo.vEFT EFT
  JOIN vMembership MS
       ON EFT.MembershipID = MS.MembershipID
  JOIN vMember M
       On MS.MembershipID = M.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN dbo.vValPaymentType VPT
       ON EFT.ValPaymentTypeID = VPT.ValPaymentTypeID
  JOIN #PaymentType PT
       ON (VPT.ValPaymentTypeID = PT.ValPaymentTypeID )
  JOIN dbo.vMembershipBalance MSB
       ON MS.MembershipID = MSB.MembershipID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID
  JOIN dbo.vValRegion VR 
       ON C.ValRegionID = VR.ValRegionID

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
       ON T1.MembershipID = MS.MembershipID 
       
 WHERE EFT.EFTDate >= @FirstOfMonth
   AND EFT.EFTDate <= @EFTEndDate
   AND C.ClubID = @ClubID
   AND M.ValMemberTypeID = 1

  DROP TABLE #MMSTran
  DROP TABLE #tmpList
  DROP TABLE #PaymentType
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

   
  END
  
ELSE IF @PageType = 'Credit Card'
BEGIN
  
EXEC procParseStringList @PaymentTypeList
   INSERT INTO #PaymentType (ValPaymentTypeID,PaymentTypeDescription)
     SELECT vValPaymentType.ValPaymentTypeID, vValPaymentType.Description
     FROM vValPaymentType
     WHERE Description IN (SELECT StringField FROM #tmpList)
      AND vValPaymentType.ValEFTAccountTypeID = 2

DECLARE  @HeaderCCPaymentTypeList VARCHAR(1000)     
SET @HeaderCCPaymentTypeList = STUFF((SELECT DISTINCT ', '+PaymentTypeDescription
                                         FROM #PaymentType
                                          FOR XML PATH('')),1,1,'')  

  
INSERT INTO #Results
  SELECT @PageType AS PageType,
         Replace(SubString(Convert(Varchar,EFT.EFTDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,EFT.EFTDate),5,DataLength(Convert(Varchar,EFT.EFTDate))-12)),' '+Convert(Varchar,Year(EFT.EFTDate)),', '+Convert(Varchar,Year(EFT.EFTDate))) AS EFTDate,
         VR.Description AS RegionDescription,
         C.ClubID,
         C.ClubCode,
         C.ClubName,  
         MS.MembershipID, 
         Replace(SubString(Convert(Varchar,MS.CreatedDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar,MS.CreatedDateTime),5,DataLength(Convert(Varchar,MS.CreatedDateTime))-12)),' '+Convert(Varchar,Year(MS.CreatedDateTime)),', '+Convert(Varchar,Year(MS.CreatedDateTime))) AS MembershipCreatedDate,
         Replace(SubString(Convert(Varchar,MS.ExpirationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,MS.ExpirationDate),5,DataLength(Convert(Varchar,MS.ExpirationDate))-12)),' '+Convert(Varchar,Year(MS.ExpirationDate)),', '+Convert(Varchar,Year(MS.ExpirationDate))) AS MembershipExpirationDate,
         M.MemberID AS PrimaryMemberID,
         M.FirstName AS PrimaryMemberFirstName,
         M.LastName AS PrimaryMemberLastName,
         VPT.Description AS EFTPaymentTypeDescription,
         VES.Description AS EFTStatusDescription,
         '' AS ChargeBackPostDateTime,
         @ReportingCurrencyCode as ReportingCurrencyCode,
         (EFT.EFTAmount * #PlanRate.PlanRate) as EFTAmount,
         CASE WHEN EFT.ValEFTStatusID = 2
               THEN (EFT.EFTAmount * #PlanRate.PlanRate)
               ELSE 0
               END  DeclinedEFTAmount,
         0 AS ChargeBackTranAmount,
         CASE WHEN  MSB.EFTAmount > 0
               THEN (MSB.EFTAmount * #PlanRate.PlanRate)
               ELSE 0
               END EFTYetUnrecoveredAmount_Dues,
		 CASE WHEN  MSB.EFTAmountProducts > 0
               THEN (MSB.EFTAmount * #PlanRate.PlanRate)
               ELSE 0
               END EFTYetUnrecoveredAmount_Products,
         (MSB.CommittedBalance * #PlanRate.PlanRate) as MembershipBalance_CommittedBalance_Dues,
		 (MSB.CommittedBalanceProducts * #PlanRate.PlanRate) as MembershipBalance_CommittedBalance_Products,
         (MSB.EFTAmount * #PlanRate.PlanRate) as MembershipBalance_EFTAmount_Dues,
		 (MSB.EFTAmountProducts * #PlanRate.PlanRate) as MembershipBalance_EFTAmount_Products,
         /******  Foreign Currency Stuff  *********/
         #PlanRate.PlanRate,
         VCC.CurrencyCode as LocalCurrencyCode,
         EFT.EFTAmount as LocalCurrency_EFTAmount,
         MSB.CommittedBalance as LocalCurrency_MembershipBalance_CommittedBalance_Dues,
		 MSB.CommittedBalanceProducts as LocalCurrency_MembershipBalance_CommittedBalance_Products,
         MSB.EFTAmount as LocalCurrency_MembershipBalance_EFTAmount_Dues,
		 MSB.EFTAmountProducts as LocalCurrency_MembershipBalance_EFTAmount_Products,
         0 AS LocalCurrency_ChargeBackTranAmount,
         (EFT.EFTAmount * #ToUSDPlanRate.PlanRate) as USD_EFTAmount,
         (MSB.CommittedBalance * #ToUSDPlanRate.PlanRate) as USD_MembershipBalance_CommittedBalance_Dues,
		 (MSB.CommittedBalanceProducts * #ToUSDPlanRate.PlanRate) as USD_MembershipBalance_CommittedBalance_Products,
         (MSB.EFTAmount * #ToUSDPlanRate.PlanRate) as USD_MembershipBalance_EFTAmount_Dues,
		 (MSB.EFTAmountProducts * #ToUSDPlanRate.PlanRate) as USD_MembershipBalance_EFTAmount_Products,
         0 AS LocalCurrency_ChargeBackTranAmount,
         @ReportRunDateTime AS ReportRunDateTime,
  	     CASE When MS.ValMembershipStatusID = 1
            THEN 'Terminated'
            ELSE 'Non-Terminated'
            END MembershipStatus,
         @HeaderCCPaymentTypeList AS HeaderPaymentTypeList   
/***************************************/

  FROM dbo.vEFT EFT
  JOIN vMembership MS 
       ON EFT.MembershipID = MS.MembershipID
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

 WHERE EFT.EFTDate >= @FirstOfMonth 
   AND EFT.EFTDate < @EFTEndDate 
   AND M.ValMemberTypeID = 1
   AND MS.ClubID = @ClubID
      
  DROP TABLE #tmpList
  DROP TABLE #PaymentType
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate
  

  
END


Select   PageType,
         EFTDate,
         RegionDescription,
         ClubID,
         ClubCode,
         ClubName,
         MembershipID,
         MembershipCreatedDate,
         MembershipExpirationDate,
         PrimaryMemberID, 
         PrimaryMemberFirstName,
         PrimaryMemberLastName,
         EFTPaymentTypeDescription,  
         EFTStatusDescription,
         ChargeBackPostDateTime,
         ReportingCurrencyCode,
         EFTAmount,
         ChargeBackTranAmount,
         (IsNull(MembershipBalance_CommittedBalance_Dues,0) + IsNull(MembershipBalance_CommittedBalance_Products,0)) as MembershipBalance_CommittedBalance,
         (IsNull(MembershipBalance_EFTAmount_Dues,0) + IsNull(MembershipBalance_EFTAmount_Products,0)) as MembershipBalance_EFTAmount,
         PlanRate,
         LocalCurrencyCode,
         LocalCurrency_EFTAmount,
         (IsNull(LocalCurrency_MembershipBalance_CommittedBalance_Dues,0) + IsNull(LocalCurrency_MembershipBalance_CommittedBalance_Products,0)) as LocalCurrency_MembershipBalance_CommittedBalance,
         (IsNull(LocalCurrency_MembershipBalance_EFTAmount_Dues,0)+ IsNull(LocalCurrency_MembershipBalance_EFTAmount_Products,0)) as LocalCurrency_MembershipBalance_EFTAmount,
         LocalCurrency_ChargeBackTranAmount,
         USD_EFTAmount,
         (IsNull(USD_MembershipBalance_CommittedBalance_Dues,0)+ IsNull(USD_MembershipBalance_CommittedBalance_Products,0)) as USD_MembershipBalance_CommittedBalance,
         (IsNull(USD_MembershipBalance_EFTAmount_Dues,0)+IsNull(USD_MembershipBalance_EFTAmount_Products,0)) as USD_MembershipBalance_EFTAmount,
         USD_ChargeBackTranAmount,
         ReportRunDateTime,
         MembershipStatus,
         HeaderPaymentTypeList
 from #Results
 Where MembershipStatus = @MembershipStatus
 
DROP TABLE #Results

END

