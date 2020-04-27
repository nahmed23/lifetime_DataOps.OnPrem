


CREATE PROC [dbo].[procCognos_EFTTransactionHistory] (  
  @StartDate SMALLDATETIME,
  @EndDate SMALLDATETIME,
  @RegionList VARCHAR(4000), -- All
  @ClubIDList VARCHAR(2000), --All
  @MemberList VARCHAR(1000), --0
  @PaymentTypeList VARCHAR(1000), -- All
  @AcctNumL4 VARCHAR(4),
  @AcctNumF6 VARCHAR(6),
  @DollarAmountMin int,
  @DollarAmountMax int,
  @MembershipCompanyIDList Varchar(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


/*-- =============================================
-- Description:        Returns EFT transaction within selected parameters
Exec procCognos_EFTTransactionHistory '11/3/2016', '11/10/2016', 'All', '2|151', '0', 'All', '0', '0', 0, 10000,'0'
  -- =============================================*/

DECLARE @PlanYearStart int, @PlanYearEnd int
SET @PlanYearStart = Year(@StartDate)
SET @PlanYearEnd = Year(@EndDate)

DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

DECLARE @EndDateAdj DATETIME
SET @EndDateAdj =  DATEADD(DAY,1, @EndDate)

-- SELECTED CREDIT CARDS OR BANK ACCOUNTS
CREATE TABLE #AccountNumber (AcctNumF6 VARCHAR(6), AcctNumL4 VARCHAR(4))   
INSERT INTO #AccountNumber (AcctNumF6, AcctNumL4) VALUES (@AcctNumF6, @AcctNumL4)

-- EFT TRANSACTIONS FOR SELECTED DATE RANGE , ACCOUNTS AND AMOUNTS
SELECT *
INTO #EFT
FROM vEFT EFT
  JOIN #AccountNumber ACC 
      ON (ACC.AcctNumF6 = LEFT(EFT.MaskedAccountNumber64, LEN(@AcctNumF6)) OR ACC.AcctNumF6 = '0')
      AND (ACC.AcctNumL4 = RIGHT(EFT.MaskedAccountNumber, LEN(@AcctNumL4)) OR ACC.AcctNumL4 = '0')	
WHERE EFT.EFTDate >= @StartDate AND 
       EFT.EFTDate < @EndDateAdj AND
      ((EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) BETWEEN @DollarAmountMin AND @DollarAmountMax)      ------ EFT Draft Separation Project
  
      
CREATE TABLE #tmpList (StringField VARCHAR(50))

CREATE TABLE #Regions (RegionName VARCHAR(50))
EXEC procParseStringList @RegionList
INSERT INTO #Regions (RegionName) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList


CREATE TABLE #MembershipCompanyIDList (CompanyID VARCHAR(50))
EXEC procParseStringList @MembershipCompanyIDList
INSERT INTO #MembershipCompanyIDList (CompanyID) SELECT StringField FROM #tmpList
TRUNCATE TABLE #tmpList



CREATE TABLE #Clubs (ClubID VARCHAR(50))
    IF @ClubIDList <> 'All'
    BEGIN
           EXEC procParseStringList @ClubIDList
           INSERT INTO #Clubs (ClubID) 
           SELECT StringField FROM #tmpList tL
           JOIN vClub C ON C.ClubID = convert(int,tl.StringField) AND C.DisplayUIFlag = 1
           JOIN vValRegion VR ON VR.ValRegionID = C.ValRegionID
		   JOIN #Regions R ON R.RegionName = VR.Description OR R.RegionName = 'All'
		   Where tL.StringField <> 'All'   ---'All' could be one of multiple clubs selected from the prompt, but we want to ignore it here if it is not the only selection.
           TRUNCATE TABLE #tmpList
    END  
ELSE
	BEGIN
		   INSERT INTO #Clubs 
		   SELECT C.ClubID
		   FROM vClub C 
		   JOIN vValRegion VR ON VR.ValRegionID = C.ValRegionID
		   JOIN #Regions R ON R.RegionName = VR.Description OR R.RegionName = 'All'
		   WHERE C.DisplayUIFlag = 1
	END  


CREATE TABLE #Member (Member VARCHAR(50))
       IF @MemberList <> '0'
       BEGIN
           EXEC procParseStringList @MemberList
           INSERT INTO #Member (Member) 
           SELECT  PM.MemberID 
           FROM #tmpList tL 
           JOIN vMember M ON M.MemberID = convert(int,tL.StringField)
           JOIN vMember PM ON PM.MembershipID = M.MembershipID -- primary member
           WHERE PM.ValMemberTypeID = 1 
		   GROUP BY   PM.MemberID        
           TRUNCATE TABLE #tmpList
       END 
       ELSE
       BEGIN
		   INSERT INTO #Member 
           SELECT M.MemberID 
           FROM #EFT EFT
           JOIN vMembership MS ON MS.MemberSHIPID = EFT.MembershipID
           JOIN vMember M ON M.MembershipID = MS.MembershipID
           WHERE M.ValMemberTypeID = 1 
		   GROUP BY M.MemberID 
       END
	
    
CREATE TABLE #PaymentType (Description VARCHAR(50))
       IF @PaymentTypeList <> 'All'
       BEGIN
           EXEC procParseStringList @PaymentTypeList
           INSERT INTO #PaymentType (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
       ELSE 
           INSERT INTO #PaymentType (Description) VALUES ('All')

DECLARE @HeaderEFTTypeList AS VARCHAR(2000)
SET @HeaderEFTTypeList = STUFF((SELECT DISTINCT ', ' + ACCT.Description 
                                       FROM #PaymentType PT
                                       JOIN vValPaymentType VPT ON PT.Description = VPT.Description OR PT.Description = 'All'
                                       JOIN vValEFTAccountType ACCT ON VPT.ValEFTAccountTypeID = ACCT.ValEFTAccountTypeID
                                       FOR XML PATH('')),1,1,'')   
                                                  

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C 
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID 
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= @PlanYearStart
  AND PlanYear <= @PlanYearEnd
  AND ToCurrencyCode = @ReportingCurrencyCode

/************************************************/

SELECT 
       Replace(Substring(convert(varchar,EFT.EFTDate,100),1,6)+', '+Substring(convert(varchar,EFT.EFTDate,100),8,4),'  ',' ') as EFTDate,
       CONVERT(VARCHAR(30), EFT.EFTDate, 112) AS EFTDate_Sort,
       C.ClubName, 
       M.MemberID,
       M.FirstName, 
       M.LastName, 
       EFT.MaskedAccountNumber AS AccountNumber,
       EFT.RoutingNumber,           
       VPT.Description AS PaymentTypeDescription,
       EFT.ValPaymentTypeID, 
       ACCT.Description  as EFTAccountTypeDescription,
       VR.Description AS RegionDescription,
       EFT.ValEFTStatusID,
       VES.Description AS EFTStatusDescription,
/******  Foreign Currency Stuff  *********/
       @ReportingCurrencyCode as ReportingCurrencyCode,
       (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) * #PlanRate.PlanRate as EFTAmount,    ----- EFT Draft Separation Project,
	   EFT.EFTAmount * #PlanRate.PlanRate as EFTAmount_Dues,
	   IsNull(EFT.EFTAmountProducts,0) * #PlanRate.PlanRate as EFTAmount_Product,
	   (EFT.EFTAmount + IsNull(EFT.EFTAmountProducts,0)) as EFTAmount_LocalCurrency,    
	   EFT.EFTAmount  as EFTAmount_Dues_LocalCurrency,
	   IsNull(EFT.EFTAmountProducts,0)  as EFTAmount_Product_LocalCurrency,
/***************************************/
       @HeaderEFTTypeList as HeaderEFTType,
       @HeaderDateRange as HeaderDateRange,
       @ReportRunDateTime as ReportRunDateTime,
	   MembershipCompany.CorporateCode,
	   MembershipCompany.CompanyID,
	   CASE When @MembershipCompanyIDList = '0'
	        Then ' '
			ELSE MembershipCompany.CompanyName
			END CompanyName

  INTO #EFTTransaction
  FROM #EFT EFT
  JOIN vMembership MS 
       ON EFT.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID AND M.ValMemberTypeID = 1
  JOIN #Member tM
       ON M.MemberID = tM.Member
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs tC 
       ON tC.ClubID = C.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValEFTStatus VES
       ON EFT.ValEFTStatusID = VES.ValEFTStatusID  
  LEFT JOIN dbo.vValPaymentType VPT
       ON (EFT.ValPaymentTypeID = VPT.ValPaymentTypeID) 
  LEFT JOIN vValEFTAccountType ACCT 
       ON VPT.ValEFTAccountTypeID = ACCT.ValEFTAccountTypeID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(EFT.EFTDate) = #PlanRate.PlanYear
/*******************************************/
  JOIN #PaymentType PT
	 ON PT.Description = VPT.Description OR PT.Description ='All'
  Left Join vCompany MembershipCompany
     ON MS.CompanyID = MembershipCompany.CompanyID



             
-- Chargebacks: (Note: will only return chargebacks if the original draft is in the same selected date range - due to #Member being drawn from #EFT)
SELECT 
	   Replace(Substring(convert(varchar,MMST.PostDateTime,100),1,6)+', '+Substring(convert(varchar,MMST.PostDateTime,100),8,4),'  ',' ') as PostDate,
       CONVERT(VARCHAR(30), MMST.PostDateTime, 112) AS PostDate_Sort,
       C.ClubName, 
       M.MemberID,
       M.FirstName, 
       M.LastName,
	   VPT.ValPaymentTypeID,       
       VPT.Description AS PaymentTypeDescription,
       ACCT.Description  as EFTAccountTypeDescription,       
       VR.Description AS RegionDescription,           
       RC.Description AS ReasonCodeDescription, 
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MMST.TranAmount * #PlanRate.PlanRate * (-1) as TranAmount,
	   MMST.TranAmount * (-1) as TranAmount_LocalCurrency,
	   MembershipCompany.CorporateCode,
	   MembershipCompany.CompanyID,
	   CASE When @MembershipCompanyIDList = '0'
	        Then ' '
			ELSE MembershipCompany.CompanyName
			END CompanyName 
   
  INTO #Chargeback 
  FROM vMMSTran MMST
  JOIN dbo.vClub C
       ON MMST.ClubID = C.ClubID
  JOIN #Clubs tC 
       ON tC.ClubID = C.ClubID  
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID  
  JOIN vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON MS.MembershipID = M.MembershipID
  JOIN #Member tM 
       ON M.MemberID = tM.Member          
  JOIN dbo.vDrawerActivity DA
       ON MMST.DrawerActivityID = DA.DrawerActivityID
  JOIN dbo.vReasonCode RC
       ON RC.ReasonCodeID = MMST.ReasonCodeID
  JOIN dbo.vValEFTOption VEO
       ON MS.ValEFTOptionID = VEO.ValEFTOptionID
/********** Foreign Currency Stuff **********/  
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.PostDateTime) = #PlanRate.PlanYear
/*******************************************/
  JOIN dbo.vEFTAccountDetail EAD
       ON MS.MembershipID = EAD.MembershipID
  JOIN dbo.vValPaymentType VPT
       ON EAD.ValPaymentTypeID = VPT.ValPaymentTypeID   
  JOIN #PaymentType PT
	 ON PT.Description = VPT.Description OR PT.Description ='All'   
  LEFT JOIN vValEFTAccountType ACCT 
       ON VPT.ValEFTAccountTypeID = ACCT.ValEFTAccountTypeID
  LEFT Join vCompany MembershipCompany
       ON MS.CompanyID = MembershipCompany.CompanyID

  WHERE DA.DrawerID = 25 AND
       MMST.EmployeeID = -2 AND
       MMST.ValTranTypeID = 4 AND
       ----M.MemberID = @MemberID AND
       MMST.PostDateTime >= @StartDate AND 
       MMST.PostDateTime < @EndDateAdj AND
       MMST.ReasonCodeID != 75 



--- final query
SELECT 
       EFTDate,
       EFTDate_Sort,
       ClubName, 
       MemberID,
       FirstName, 
       LastName, 
       AccountNumber,
       RoutingNumber,           
       PaymentTypeDescription,
       ValPaymentTypeID, 
       EFTAccountTypeDescription,
       RegionDescription,
       ValEFTStatusID,
       EFTStatusDescription,
       ReportingCurrencyCode,
       EFTAmount,
	   EFTAmount_Dues,
	   EFTAmount_Product,
	   EFTAmount_LocalCurrency,
	   EFTAmount_Dues_LocalCurrency,
	   EFTAmount_Product_LocalCurrency,
       HeaderEFTType,
       HeaderDateRange,
       ReportRunDateTime,
	   IsNull(CorporateCode,'') as CorporateCode,
	   IsNull(#EFTTransaction.CompanyID,0) as CompanyID,
	   IsNull(CompanyName,'') as MembershipCompanyName 

FROM #EFTTransaction
Left Join #MembershipCompanyIDList 
On Convert(Varchar,#EFTTransaction.CompanyID) = #MembershipCompanyIDList.CompanyID
Where IsNull(#MembershipCompanyIDList.CompanyID,0) <> 0 or @MembershipCompanyIDList = '0'

UNION ALL
SELECT 
       PostDate,
       PostDate_Sort,
       ClubName, 
       MemberID,
       FirstName, 
       LastName, 
       '' AS AccountNumber,
       '' AS RoutingNumber,                       
       PaymentTypeDescription,       
       ValPaymentTypeID, 
       EFTAccountTypeDescription,       
       RegionDescription,           
       NULL AS ValEFTStatusID,       
       ReasonCodeDescription, 
       ReportingCurrencyCode,
       TranAmount AS EFTAmount,
	   NULL AS EFTAmount_Dues,
	   NULL AS EFTAmount_Product,
	   TranAmount_LocalCurrency AS EFTAmount_LocalCurrency,
	   NULL AS EFTAmount_Dues_LocalCurrency,
	   NULL AS EFTAmount_Product_LocalCurrency,   
       @HeaderEFTTypeList as HeaderEFTType,
       @HeaderDateRange as HeaderDateRange,
       @ReportRunDateTime as ReportRunDateTime,
	   IsNull(CorporateCode,'') as CorporateCode,
	   IsNull(#Chargeback.CompanyID,0) as CompanyID,
	   IsNull(CompanyName,'') as MembershipCompanyName 

       
 FROM #Chargeback 
 Left Join #MembershipCompanyIDList 
  On Convert(Varchar,#Chargeback.CompanyID) = #MembershipCompanyIDList.CompanyID
 Where IsNull(#MembershipCompanyIDList.CompanyID,0) <> 0 or @MembershipCompanyIDList = '0'




    
DROP TABLE #Clubs
DROP TABLE #Member
DROP TABLE #PaymentType
DROP TABLE #tmpList
DROP TABLE #PlanRate
DROP TABLE #Chargeback 
DROP TABLE #EFTTransaction 
DROP TABLE #EFT
DROP TABLE #AccountNumber
DROP TABLE #Regions
DROP TABLE #MembershipCompanyIDList

END



