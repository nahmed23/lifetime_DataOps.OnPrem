

CREATE  PROC [dbo].[procCognos_EFTReturnAndACHChargeBackDetail](

  @ClubIDList VARCHAR(2000),
  @StartDate DATETIME,
  @EndDate DATETIME,
  @ReturnType VARCHAR(50)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @HeaderStartDate  Varchar(110)
DECLARE @HeaderEndDate   Varchar(110)
DECLARE @EndDateTime DATETIME
DECLARE @ReportRunDateTime  VARCHAR(110)

SET @HeaderStartDate = Replace(SubString(Convert(Varchar,@StartDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,@StartDate),5,DataLength(Convert(Varchar,@StartDate))-12)),' '+Convert(Varchar,Year(@StartDate)),', '+Convert(Varchar,Year(@StartDate))) 
SET @HeaderEndDate = Replace(SubString(Convert(Varchar,@EndDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,@EndDate),5,DataLength(Convert(Varchar,@EndDate))-12)),' '+Convert(Varchar,Year(@EndDate)),', '+Convert(Varchar,Year(@EndDate)))
SET @EndDateTime = DATEADD(D,1,@EndDate)
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
   INSERT INTO #Clubs (ClubID) (SELECT ClubID FROM vClub)
END   

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 'All'
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
  
CREATE TABLE #Results (RegionDescription VARCHAR(50),
         ClubName VARCHAR(50),
         MemberID INT, 
         FirstName VARCHAR(50),
         LastName VARCHAR(50),
         ACH_CC  VARCHAR(11),
         PaymentTypeDescription VARCHAR(50),  
         EFTDate VARCHAR(50),
         ReasonCodeDescription VARCHAR(50),
         MembershipType_ProductDescription VARCHAR(50),
         ReturnCodeDescription VARCHAR(50),
         EFTReturn_StopEFTFlag VARCHAR(1),
         EFTReturn_RoutingNumber VARCHAR(50),
         EFTReturn_AccountNumber VARCHAR(50), 
         EFTReturn_AccountExpirationDate VARCHAR(50),  
         MembershipPhone VARCHAR(14),
         EmailAddress VARCHAR(140), 
         ChargeBack_PostDateTime VARCHAR(50),
         ChargeBack_MembershipEFTOptionDescription VARCHAR(50),
         ChargeBack_MMSTranID INT,
         ChargeBack_TranAmount DECIMAL(14,4),
         LocalCurrency_ChargeBack_TranAmount DECIMAL(14,2),
         USD_ChargeBack_TranAmount DECIMAL(14,4),        
         LocalCurrencyCode VARCHAR(3),
         PlanRate DECIMAL(14,4),
         ReportingCurrencyCode VARCHAR(3),
         EFTReturn_EFTAmount DECIMAL(14,4),   
         Membership_CurrentBalance_Dues DECIMAL(14,4),
		 Membership_CurrentBalance_Products DECIMAL(14,4),
         LocalCurrency_EFTReturn_EFTAmount DECIMAL(14,2),       
         LocalCurrency_Membership_CurrentBalance_Dues DECIMAL(14,2),
		 LocalCurrency_Membership_CurrentBalance_Products DECIMAL(14,2),
         USD_EFTReturn_EFTAmount DECIMAL(14,4),
         USD_Membership_CurrentBalance_Dues DECIMAL(14,4),
		 USD_Membership_CurrentBalance_Products DECIMAL(14,4),
         HeaderReturnType VARCHAR(50),       
         HeaderDateRange VARCHAR(100),
         ReportRunDateTime VARCHAR(50))

  
IF @ReturnType = 'EFT Returns'

BEGIN

--LFF Acquisition changes begin
SELECT ms.MembershipID,
      ms.ClubID,
      ms.MembershipTypeID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
JOIN #Clubs C
On ms.ClubID = C.ClubID


CREATE INDEX IX_ClubID ON #Membership(ClubID)
CREATE INDEX IX_MembershipTypeID ON #Membership(MembershipTypeID)

/***************************************/
INSERT INTO #Results
  SELECT VR.Description AS RegionDescription,
         C.ClubName,
         M.MemberID, 
         M.FirstName,
         M.LastName,
         CASE
           WHEN EFT.ValPaymentTypeID IN(3,4,5,8)
             THEN 'Credit Card'
           ELSE 'ACH'
           END ACH_CC,
         VPTT.Description AS PaymentTypeDescription,
         Replace(SubString(Convert(Varchar,EFT.EFTDate),1,3)+' '+LTRIM(SubString(Convert(Varchar,EFT.EFTDate),5,DataLength(Convert(Varchar,EFT.EFTDate))-12)),' '+Convert(Varchar,Year(EFT.EFTDate)),', '+Convert(Varchar,Year(EFT.EFTDate))) + '  ' + LTRIM(SubString(Convert(Varchar,EFT.EFTDate,22),10,5) + ' ' + Right(ConverT(Varchar,EFT.EFTDate,22),2))  AS EFTDate,
         RC.Description AS ReasonCodeDescription,
         P.Description AS MembershipType_ProductDescription,
         ERC.Description AS ReturnCodeDescription,
         ERC.StopEFTFlag AS  EFTReturn_StopEFTFlag,
         EFT.RoutingNumber AS EFTReturn_RoutingNumber,
         EFT.MaskedAccountNumber AS EFTReturn_AccountNumber,
         Replace(SubString(Convert(Varchar,GetDate()),1,3)+' '+LTRIM(SubString(Convert(Varchar,GetDate()),5,DataLength(Convert(Varchar,GetDate()))-12)),' '+Convert(Varchar,Year(GetDate())),', '+Convert(Varchar,Year(GetDate()))) AS  EFTReturn_AccountExpirationDate,  
         '('+MSP.AreaCode+') '+ Substring( MSP.Number, 1, 3 )+'-'+ Substring( MSP.Number, 4, 4 ) AS MembershipPhone,
         M.EmailAddress, 
/****** Columns needed for query union *******/
         '' AS  ChargeBack_PostDateTime,
         '' AS ChargeBack_MembershipEFTOptionDescription,
         '' AS ChargeBack_MMSTranID,
         0 AS ChargeBack_TranAmount,
         0 AS LocalCurrency_ChargeBack_TranAmount,
         0 AS USD_ChargeBack_TranAmount,        
/******  Foreign Currency Stuff  *********/
         VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
         EFT.EFTAmount * #PlanRate.PlanRate as EFTReturn_EFTAmount,   
         MSB.CurrentBalance * #PlanRate.PlanRate as Membership_CurrentBalance_Dues,
		 MSB.CurrentBalanceProducts * #PlanRate.PlanRate as Membership_CurrentBalance_Products,
         EFT.EFTAmount as LocalCurrency_EFTReturn_EFTAmount,       
         MSB.CurrentBalance as LocalCurrency_Membership_CurrentBalance_Dues,
		 MSB.CurrentBalanceProducts as LocalCurrency_Membership_CurrentBalance_Products,
         EFT.EFTAmount * #ToUSDPlanRate.PlanRate as USD_EFTReturn_EFTAmount,
         MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_Membership_CurrentBalance_Dues,
		 MSB.CurrentBalanceProducts * #ToUSDPlanRate.PlanRate as USD_Membership_CurrentBalance_Products,
/***************************************/         
         @ReturnType as HeaderReturnType,       
         @HeaderStartDate +'  through  '+ @HeaderEndDate AS HeaderDateRange,
         @ReportRunDateTime  AS ReportRunDateTime 

    FROM #Membership 
    JOIN vMember M  
         ON #Membership.MembershipID = M.MembershipID
    JOIN dbo.vMembershipType MST
         ON #Membership.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P
         ON MST.ProductID = P.ProductID     
    JOIN dbo.vClub C
         ON #Membership.ClubID = C.ClubID
    JOIN dbo.vValRegion VR
         ON C.ValRegionID = VR.ValRegionID
    JOIN dbo.vEFT EFT
         ON EFT.MembershipID = #Membership.MembershipID
    JOIN dbo.vEFTReturnCode ERC
         ON EFT.EFTReturnCodeID = ERC.EFTReturnCodeID
    JOIN dbo.vReasonCode RC
         ON ERC.ReasonCodeID = RC.ReasonCodeID
    LEFT JOIN dbo.vValPaymentType VPTT
         ON EFT.ValPaymentTypeID = VPTT.ValPaymentTypeID  
    LEFT JOIN dbo.vPrimaryPhone PP
         ON #Membership.MembershipID = PP.MembershipID
    LEFT JOIN dbo.vMembershipPhone MSP
         ON PP.MembershipID = MSP.MembershipID AND 
         PP.ValPhoneTypeID = MSP.ValPhoneTypeID
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
    LEFT JOIN dbo.vMembershipBalance MSB
         ON #Membership.MembershipID = MSB.MembershipID

   WHERE M.ValMemberTypeID = 1 
         AND EFT.ValEFTStatusID = 2 
         AND EFT.EFTDate >= @StartDate 
         AND EFT.EFTDate < @EndDateTime 


  DROP TABLE #tmpList
  DROP TABLE #Membership
  DROP TABLE #Clubs
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate
END
ELSE
BEGIN

SELECT C.ClubID, C.ClubName, C.ValRegionID, C.DisplayUIFlag
INTO #ClubID
FROM #Clubs CS JOIN vClub C ON CS.ClubID = C.ClubID

SELECT mt.MMSTranID, 
       mt.ClubID,
       mt.MembershipID, mt.MemberID, mt.DrawerActivityID,
       mt.TranVoidedID, mt.ReasonCodeID, mt.ValTranTypeID,
       mt.PostDateTime, mt.EmployeeID, mt.TranAmount

INTO #MMSTran
FROM vMMSTran mt WITH (NOLOCK)
Join #ClubID C
   On mt.ClubID = C.ClubID
JOIN vDrawerActivity DA
   ON mt.DrawerActivityID = DA.DrawerActivityID
WHERE  mt.PostDateTime >= @StartDate 
  AND mt.PostDateTime < @EndDateTime
  AND mt.ReasonCodeID != 75      ----- Charged EFT in Error reason ID
  AND mt.EmployeeID = -2         ----- AUTOMTED TRIGGER "employee"
  AND mt.ValTranTypeID = 4       ----- Adjustment tran type
  AND mt.TranVoidedID Is Null
  AND DA.DrawerID = 25           ----- EFT INTERNAL club drawer
  
CREATE INDEX IX_ClubID ON #MMSTran(ClubID)

/***************************************/

INSERT INTO #Results

SELECT VR.Description AS RegionDescription,
       C.ClubName,
       MMST.MemberID,
       M.FirstName, 
       M.LastName,                 
       'ACH        ' AS ACH_CC,                         -----Cognos FM would not accept simple 'ACH' assignment, but this works  srm
       VPT.Description AS PaymentTypeDescription,
       '' AS EFTDate,
       RC.Description AS ReasonCodeDescription, 
       P.Description AS MembershipType_ProductDescription,
       '' AS ReturnCodeDescription,
       '' AS EFTReturn_StopEFTFlag,
       '' AS EFTReturn_RoutingNumber,
       '' AS EFTReturn_AccountNumber,
       '' AS EFTReturn_AccountExpirationDate,
       '('+MSP.AreaCode+') '+ Substring( MSP.Number, 1, 3 )+'-'+ Substring( MSP.Number, 4, 4 ) AS MembershipPhone,
       M.EmailAddress,
       Replace(SubString(Convert(Varchar,MMST.PostDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar,MMST.PostDateTime),5,DataLength(Convert(Varchar,MMST.PostDateTime))-12)),' '+Convert(Varchar,Year(MMST.PostDateTime)),', '+Convert(Varchar,Year(MMST.PostDateTime))) + '  ' + LTRIM(SubString(Convert(Varchar,MMST.PostDateTime,22),10,5) + ' ' + Right(ConverT(Varchar,MMST.PostDateTime,22),2)) AS ChargeBack_PostDateTime,
       VEO.Description AS ChargeBack_MembershipEFTOptionDescription,
       MMST.MMSTranID AS ChargeBack_MMSTranID, 
       
/******  Foreign Currency Stuff  *********/
       MMST.TranAmount * #PlanRate.PlanRate as ChargeBack_TranAmount,       
       MMST.TranAmount as LocalCurrency_ChargeBack_TranAmount,       
       MMST.TranAmount * #ToUSDPlanRate.PlanRate as USD_ChargeBack_TranAmount,
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       0 AS EFTReturn_EFTAmount,
       MSB.CurrentBalance * #PlanRate.PlanRate as Membership_CurrentBalance_Dues,
	   MSB.CurrentBalanceProducts * #PlanRate.PlanRate as Membership_CurrentBalance_Products,
       0 AS LocalCurrency_EFTReturn_EFTAmount,       
       MSB.CurrentBalance as LocalCurrency_Membership_CurrentBalance_Dues,
	   MSB.CurrentBalanceProducts as LocalCurrency_Membership_CurrentBalance_Products,
       0 AS USD_EFTReturn_EFTAmount,
       MSB.CurrentBalance * #ToUSDPlanRate.PlanRate as USD_Membership_CurrentBalance_Dues,
	   MSB.CurrentBalanceProducts * #ToUSDPlanRate.PlanRate as USD_Membership_CurrentBalance_Products,
       @ReturnType as HeaderReturnType,
       @HeaderStartDate +'  through  '+ @HeaderEndDate AS HeaderDateRange,
       @ReportRunDateTime AS ReportRunDateTime 
/***************************************/

  FROM #MMSTran MMST
  JOIN vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN vMembershipType MST
       ON MS.MembershipTypeID = MST.MembershipTypeID
  JOIN vProduct P
       ON MST.ProductID = P.ProductID
  JOIN dbo.vMember M
       ON MMST.MemberID = M.MemberID
  JOIN dbo.vDrawerActivity DA
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN #ClubID C
       ON MMST.ClubID = C.ClubID
/********** Foreign Currency Stuff **********/ 
  JOIN dbo.vClub CS
       ON CS.ClubID = C.ClubID
  JOIN dbo.vValCurrencyCode VCC 
       ON CS.ValCurrencyCodeID = VCC.ValCurrencyCodeID  
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValEFTOption VEO
       ON MS.ValEFTOptionID = VEO.ValEFTOptionID 
  JOIN dbo.vMembershipBalance MSB
       ON MMST.MembershipID = MSB.MembershipID 
  LEFT JOIN dbo.vEFTAccountDetail EAD
       ON (MMST.MembershipID = EAD.MembershipID) 
  LEFT JOIN dbo.vValPaymentType VPT
       ON (EAD.ValPaymentTypeID = VPT.ValPaymentTypeID)
  LEFT JOIN dbo.vPrimaryPhone PP
       ON MMST.MembershipID = PP.MembershipID 
  LEFT JOIN dbo.vMembershipPhone MSP
       ON (PP.MembershipID = MSP.MembershipID AND
       PP.ValPhoneTypeID = MSP.ValPhoneTypeID)


DROP TABLE #Clubs
DROP TABLE #ClubID
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate
DROP TABLE #MMSTran

END


Select RegionDescription,
         ClubName,
         MemberID, 
         FirstName,
         LastName,
         ACH_CC,
         PaymentTypeDescription, 
         EFTDate,
         ReasonCodeDescription,
         MembershipType_ProductDescription,
         ISNULL(ReturnCodeDescription,'') AS ReturnCodeDescription,
         ISNULL(EFTReturn_StopEFTFlag,'') AS EFTReturn_StopEFTFlag,
         ISNULL(EFTReturn_RoutingNumber,'') AS EFTReturn_RoutingNumber,
         ISNULL(EFTReturn_AccountNumber,'') AS EFTReturn_AccountNumber, 
         ISNULL(EFTReturn_AccountExpirationDate,'') AS EFTReturn_AccountExpirationDate,  
         MembershipPhone,
         EmailAddress, 
         ISNULL(ChargeBack_PostDateTime,'') AS ChargeBack_PostDateTime,
         ISNULL(ChargeBack_MembershipEFTOptionDescription,'') AS ChargeBack_MembershipEFTOptionDescription,
         ISNULL(ChargeBack_MMSTranID,'') AS ChargeBack_MMSTranID,
         ISNULL(ChargeBack_TranAmount,0) AS ChargeBack_TranAmount,
         ISNULL(LocalCurrency_ChargeBack_TranAmount,0) AS LocalCurrency_ChargeBack_TranAmount,
         ISNULL(USD_ChargeBack_TranAmount,0) AS USD_ChargeBack_TranAmount,        
         LocalCurrencyCode,
         PlanRate,
         ReportingCurrencyCode,
         ISNULL(EFTReturn_EFTAmount,0) AS EFTReturn_EFTAmount,   
         (ISNULL(Membership_CurrentBalance_Dues,0)+ ISNULL(Membership_CurrentBalance_Products,0)) AS Membership_CurrentBalance,
         ISNULL(LocalCurrency_EFTReturn_EFTAmount,0) AS LocalCurrency_EFTReturn_EFTAmount,       
         (ISNULL(LocalCurrency_Membership_CurrentBalance_Dues,0) + ISNULL(LocalCurrency_Membership_CurrentBalance_Products,0)) AS LocalCurrency_Membership_CurrentBalance,
         ISNULL(USD_EFTReturn_EFTAmount,0) AS USD_EFTReturn_EFTAmount,
         (ISNULL(USD_Membership_CurrentBalance_Dues,0)+ISNULL(USD_Membership_CurrentBalance_Products,0)) AS USD_Membership_CurrentBalance,
         HeaderReturnType,       
         HeaderDateRange,
         ReportRunDateTime
         
         From #Results
         
                  
         Drop Table #Results


END



